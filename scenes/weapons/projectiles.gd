extends Node2D
## Owns every projectile in flight. Each physics tick a projectile sweeps a ray
## from its previous position to its next one, so fast bullets never tunnel
## through thin platforms or players.

const WORLD    := 1
const PLAYERS  := 2
const PLATFORM := 4

var _list: Array = []   # Dictionaries
var _glow: Node2D
var _t := 0.0

func _ready() -> void:
	z_index = 4
	_glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw.connect(_draw_glow)
	add_child(_glow)

# --------------------------------------------------------------------------
# Spawning
# --------------------------------------------------------------------------

func fire(shooter: Node, origin: Vector2, dir: Vector2, def: Dictionary, inherit := Vector2.ZERO) -> void:
	match def["kind"]:
		"hitscan":
			_hitscan(shooter, origin, dir, def)
		_:
			var speed: float = def["speed"]
			var p := {
				"kind": def["kind"], "pos": origin, "prev": origin, "vel": dir * speed + inherit,
				"def": def, "shooter": shooter, "life": 0.0, "traveled": 0.0,
				"fuse": def["fuse"], "bounces": 0, "dir": signf(dir.x) if dir.x != 0.0 else 1.0,
				"grounded": false, "hops": 0, "sang": false,
			}
			_list.append(p)

func _hitscan(shooter: Node, origin: Vector2, dir: Vector2, def: Dictionary) -> void:
	var space := get_world_2d().direct_space_state
	var end: Vector2 = origin + dir * float(def["range"])
	var exclude := _excluded(shooter)
	var from := origin
	var hits := 0
	for i in 5:
		var q := PhysicsRayQueryParameters2D.create(from, end, WORLD | PLAYERS, exclude)
		var r := space.intersect_ray(q)
		if r.is_empty():
			break
		var col: Object = r["collider"]
		if col is Player:
			_damage_player(col, r["position"], dir, def, shooter, 1.0)
			hits += 1
			if not def["pierce"]:
				end = r["position"]
				break
			exclude.append(col.get_rid())
			from = r["position"]
		else:
			end = r["position"]
			Game.fx.impact(end, r["normal"], def["tracer"])
			break
	Game.fx.beam(origin, end, def["tracer"], 7.0 if def["pierce"] else 4.0, 0.35 if def["pierce"] else 0.22)

# --------------------------------------------------------------------------
# Simulation
# --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	var space := get_world_2d().direct_space_state
	var i := 0
	while i < _list.size():
		var p: Dictionary = _list[i]
		p["prev"] = p["pos"]
		var alive := true
		match p["kind"]:
			"bullet":  alive = _step_bullet(p, delta, space)
			"rocket":  alive = _step_rocket(p, delta, space)
			"grenade": alive = _step_grenade(p, delta, space)
			"sheep":   alive = _step_sheep(p, delta, space)
		if alive:
			i += 1
		else:
			_list.remove_at(i)

## Redraw every rendered frame, interpolating between physics ticks so
## projectiles stay smooth on high refresh rate screens.
func _process(_delta: float) -> void:
	queue_redraw()
	_glow.queue_redraw()

func _draw_pos(p: Dictionary) -> Vector2:
	return (p["prev"] as Vector2).lerp(p["pos"], Engine.get_physics_interpolation_fraction())

func _exclude_for(p: Dictionary) -> Array[RID]:
	return _excluded(p["shooter"])

## The shooter and their teammates: projectiles fly through allies.
func _excluded(shooter: Node) -> Array[RID]:
	var ex: Array[RID] = []
	if not is_instance_valid(shooter):
		return ex
	ex.append(shooter.get_rid())
	if shooter.team >= 0:
		for pl in Game.active_players():
			if pl != shooter and pl.team == shooter.team:
				ex.append(pl.get_rid())
	return ex

func _step_bullet(p: Dictionary, dt: float, space: PhysicsDirectSpaceState2D) -> bool:
	var def: Dictionary = p["def"]
	var from: Vector2 = p["pos"]
	var to: Vector2 = from + p["vel"] * dt
	var q := PhysicsRayQueryParameters2D.create(from, to, WORLD | PLAYERS, _exclude_for(p))
	var r := space.intersect_ray(q)
	p["traveled"] += from.distance_to(to)
	if not r.is_empty():
		var col: Object = r["collider"]
		var dir: Vector2 = p["vel"].normalized()
		if col is Player:
			var t: float = clampf(p["traveled"] / float(def["range"]), 0.0, 1.0)
			_damage_player(col, r["position"], dir, def, p["shooter"], lerpf(1.0, def["falloff"], t))
		else:
			Game.fx.impact(r["position"], r["normal"])
			if randf() < 0.15:
				SoundManager.play("ricochet", r["position"], -10.0)
		return false
	p["pos"] = to
	return p["traveled"] < float(def["range"])

func _step_rocket(p: Dictionary, dt: float, space: PhysicsDirectSpaceState2D) -> bool:
	var v: Vector2 = p["vel"]
	if v.length() < 1500.0:
		v *= 1.0 + dt * 1.2
	p["vel"] = v
	p["life"] += dt
	var from: Vector2 = p["pos"]
	var to: Vector2 = from + v * dt
	var q := PhysicsRayQueryParameters2D.create(from, to, WORLD | PLAYERS, _exclude_for(p))
	var r := space.intersect_ray(q)
	if not r.is_empty():
		explode(r["position"] - v.normalized() * 6.0, p["def"], p["shooter"])
		return false
	p["pos"] = to
	Game.fx.rocket_trail(to, v.normalized())
	if p["life"] > 4.0:
		explode(to, p["def"], p["shooter"])
		return false
	return true

## Kamikaze sheep: trots along the ground, hops over walls, turns around when
## stuck, and blows up next to the first enemy it meets.
func _step_sheep(p: Dictionary, dt: float, space: PhysicsDirectSpaceState2D) -> bool:
	var def: Dictionary = p["def"]
	p["life"] += dt
	p["fuse"] -= dt
	var pos: Vector2 = p["pos"]
	for pl in Game.active_players():
		if not pl.dead and pl != p["shooter"] and pos.distance_to(pl.global_position) < 38.0 \
				and (not is_instance_valid(p["shooter"]) or Game.is_enemy(p["shooter"], pl)):
			explode(pos, def, p["shooter"])
			return false
	if p["fuse"] <= 0.0:
		explode(pos, def, p["shooter"])
		return false
	var v: Vector2 = p["vel"]
	if p["grounded"]:
		v.x = float(p["dir"]) * float(def["speed"])
		v.y = 0.0
		var down := PhysicsRayQueryParameters2D.create(pos, pos + Vector2(0, 12), WORLD | PLATFORM)
		if space.intersect_ray(down).is_empty():
			p["grounded"] = false
	v.y = minf(v.y + float(def["gravity"]) * dt, 1100.0)
	var to := pos + v * dt
	var q := PhysicsRayQueryParameters2D.create(pos, to, WORLD | (PLATFORM if v.y > 0.0 else 0))
	var r := space.intersect_ray(q)
	if not r.is_empty():
		var n: Vector2 = r["normal"]
		if n.y < -0.6:
			p["grounded"] = true
			v.y = 0.0
			p["pos"] = r["position"] + n * 6.0
			p["hops"] = 0
		else:
			p["hops"] += 1
			if p["hops"] > 2:
				p["dir"] = -float(p["dir"])
				p["hops"] = 0
			v = Vector2(-float(p["dir"]) * 30.0, -520.0)
			p["grounded"] = false
			p["pos"] = r["position"] + n * 4.0
			SoundManager.play("baa", pos, -6.0, randf_range(0.9, 1.3))
	else:
		p["pos"] = to
	p["vel"] = v
	if randf() < 0.01:
		SoundManager.play("baa", pos, -8.0, randf_range(0.8, 1.2))
	return true

func _step_grenade(p: Dictionary, dt: float, space: PhysicsDirectSpaceState2D) -> bool:
	var def: Dictionary = p["def"]
	p["life"] += dt
	p["fuse"] -= dt
	if def.get("holy", false) and p["fuse"] < 1.1 and not p["sang"]:
		p["sang"] = true
		SoundManager.play("hallelujah", p["pos"], 2.0)
	if p["fuse"] <= 0.0:
		explode(p["pos"], def, p["shooter"])
		return false
	var v: Vector2 = p["vel"]
	v.y = minf(v.y + float(def["gravity"]) * dt, 1200.0)
	var from: Vector2 = p["pos"]
	var to: Vector2 = from + v * dt
	var mask := WORLD
	if v.y > 0.0:
		mask |= PLATFORM
	if def["contact"] and p["life"] > 0.05:
		mask |= PLAYERS
	var q := PhysicsRayQueryParameters2D.create(from, to, mask, _exclude_for(p))
	var r := space.intersect_ray(q)
	if not r.is_empty():
		if r["collider"] is Player:
			explode(r["position"], def, p["shooter"])
			return false
		var n: Vector2 = r["normal"]
		var speed := v.length()
		v = v.bounce(n) * 0.5
		if n.y < -0.7 and absf(v.y) < 90.0:
			v.y = 0.0
			v.x *= 0.8
		p["pos"] = r["position"] + n * 3.0
		p["bounces"] += 1
		if speed > 150.0:
			SoundManager.play("bounce", r["position"], -8.0)
	else:
		p["pos"] = to
	p["vel"] = v
	if Engine.get_physics_frames() % 3 == 0:
		Game.fx.grenade_trail(p["pos"])
	return true

# --------------------------------------------------------------------------
# Damage
# --------------------------------------------------------------------------

func _damage_player(target: Player, at: Vector2, dir: Vector2, def: Dictionary, shooter: Node, mult: float) -> void:
	var head: bool = target.is_head_hit(at)
	var dmg: float = float(def["damage"]) * mult
	if Game.instagib():
		dmg = 1000.0
	if head:
		dmg *= float(def["head_mult"])
	target.take_damage(dmg, dir * float(def["knock"]), shooter, def["id"], head, at)

func explode(pos: Vector2, def: Dictionary, shooter: Node) -> void:
	if def.has("cluster"):
		var bit := WeaponData.get_def("banana_bit")
		for i in int(def["cluster"]):
			var d := Vector2.from_angle(randf_range(-PI * 0.85, -PI * 0.15))
			var b := {
				"kind": "grenade", "pos": pos + Vector2(0, -6), "prev": pos, "vel": d * randf_range(380, 640),
				"def": bit, "shooter": shooter, "life": 0.0, "traveled": 0.0,
				"fuse": float(bit["fuse"]) + randf() * 0.5, "bounces": 0, "dir": 1.0,
				"grounded": false, "hops": 0, "sang": false,
			}
			_list.append(b)
	if def.has("airstrike"):
		_airstrike(pos, int(def["airstrike"]), shooter)
		return
	var radius: float = def["splash"]
	Game.fx.explosion(pos, radius)
	SoundManager.play("explosion", pos, 2.0)
	Game.shake(0.55, pos)
	var space := get_world_2d().direct_space_state
	for pl in Game.active_players():
		if pl.dead:
			continue
		var center: Vector2 = pl.global_position
		var dist := maxf(0.0, pos.distance_to(center) - 14.0)
		if dist > radius:
			continue
		# Line of sight to the body or the head, so cover blocks splash.
		var exposed := false
		for probe in [center, center + Vector2(0, -22), center + Vector2(0, 20)]:
			var q := PhysicsRayQueryParameters2D.create(pos, probe, WORLD)
			if space.intersect_ray(q).is_empty():
				exposed = true
				break
		if not exposed:
			continue
		var falloff := 1.0 - dist / radius
		var dir := (center - pos).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		var push := (dir + Vector2(0, -0.35)).normalized() * 950.0 * falloff
		var dmg := float(def["damage"]) * lerpf(0.25, 1.0, falloff)
		if pl == shooter:
			dmg *= 0.45
			push *= 1.25   # rocket jumping!
		pl.take_damage(dmg, push, shooter, def["id"], false, center)

func _airstrike(target: Vector2, count: int, shooter: Node) -> void:
	Game.fx.impact(target, Vector2.UP, Color(1.0, 0.2, 0.2))
	SoundManager.play("siren", target, 0.0)
	if Game.hud:
		Game.hud.announce("FRAPPE AÉRIENNE", Color(1.0, 0.35, 0.25), "", 1.0)
	var missile := WeaponData.get_def("strike_missile")
	for i in count:
		var x := target.x + (i - (count - 1) * 0.5) * 70.0 + randf_range(-15, 15)
		var start := Vector2(x - 180.0, -60.0 - i * 90.0)
		var dir := (Vector2(x, target.y) - start).normalized()
		_list.append({
			"kind": "rocket", "pos": start, "prev": start, "vel": dir * float(missile["speed"]),
			"def": missile, "shooter": shooter, "life": -0.4 - i * 0.12, "traveled": 0.0,
			"fuse": 0.0, "bounces": 0, "dir": 1.0, "grounded": false, "hops": 0, "sang": false,
		})

# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------

func _draw() -> void:
	for p in _list:
		var pos := _draw_pos(p)
		match p["kind"]:
			"rocket":
				var ang: float = p["vel"].angle()
				draw_set_transform(pos, ang)
				draw_rect(Rect2(-12, -3, 16, 6), Color(0.3, 0.35, 0.25))
				draw_colored_polygon(PackedVector2Array([Vector2(4, -3), Vector2(10, 0), Vector2(4, 3)]), Color(0.8, 0.2, 0.15))
				draw_rect(Rect2(-14, -5, 4, 10), Color(0.2, 0.22, 0.2))
				draw_set_transform(Vector2.ZERO, 0.0)
			"sheep":
				var f := float(p["dir"])
				var bob := sin(p["life"] * 22.0) * 1.5 if p["grounded"] else 0.0
				draw_set_transform(pos + Vector2(0, bob), 0.0, Vector2(f, 1))
				for o in [Vector2(-6, 0), Vector2(0, -3), Vector2(6, 0), Vector2(0, 3), Vector2(-3, -4), Vector2(3, -4)]:
					draw_circle(o, 6.5, Color(0.95, 0.95, 0.92))
				draw_circle(Vector2(10, -3), 4.5, Color(0.12, 0.12, 0.12))
				draw_circle(Vector2(11.5, -4.5), 1.2, Color(1, 1, 1))
				var leg := sin(p["life"] * 22.0) * 3.0
				draw_line(Vector2(-5, 5), Vector2(-5 + leg, 11), Color(0.1, 0.1, 0.1), 2.0)
				draw_line(Vector2(5, 5), Vector2(5 - leg, 11), Color(0.1, 0.1, 0.1), 2.0)
				draw_rect(Rect2(-4, -9, 8, 4), Color(0.8, 0.15, 0.15))   # dynamite
				draw_set_transform(Vector2.ZERO)
			"grenade":
				var gid: String = p["def"]["id"]
				if gid == "banana" or gid == "banana_bit":
					var sc := 1.0 if gid == "banana" else 0.6
					draw_set_transform(pos, p["life"] * 9.0, Vector2(sc, sc))
					draw_arc(Vector2.ZERO, 8.0, 0.3, 2.8, 10, Color(1.0, 0.85, 0.15), 5.0)
					draw_circle(Vector2(8, 3).rotated(0.0), 1.5, Color(0.3, 0.2, 0.05))
					draw_set_transform(Vector2.ZERO)
					continue
				if gid == "holy":
					draw_circle(pos, 7.0, Color(1.0, 0.82, 0.25))
					draw_rect(Rect2(pos + Vector2(-1, -12), Vector2(2, 7)), Color(1.0, 0.95, 0.6))
					draw_rect(Rect2(pos + Vector2(-3, -10), Vector2(6, 2)), Color(1.0, 0.95, 0.6))
					continue
				if gid == "airstrike":
					draw_rect(Rect2(pos + Vector2(-3, -6), Vector2(6, 12)), Color(0.8, 0.1, 0.1))
					continue
				var frag: bool = p["def"]["id"] == "frag"
				draw_circle(pos, 5.0 if frag else 4.5, Color(0.22, 0.28, 0.16) if frag else Color(0.25, 0.25, 0.28))
				draw_circle(pos + Vector2(-1.5, -1.5), 1.8, Color(0.45, 0.5, 0.35))
				if frag:
					draw_rect(Rect2(pos + Vector2(-2, -8), Vector2(4, 3)), Color(0.5, 0.5, 0.5))

func _draw_glow() -> void:
	for p in _list:
		var pos := _draw_pos(p)
		match p["kind"]:
			"bullet":
				var def: Dictionary = p["def"]
				var dir: Vector2 = p["vel"].normalized()
				var tl := minf(float(def["tracer_len"]), p["traveled"] + 4.0)
				var c: Color = def["tracer"]
				_glow.draw_line(pos - dir * tl * 1.6, pos, Color(c.r, c.g, c.b, 0.25), float(def["tracer_width"]) * 2.5)
				_glow.draw_line(pos - dir * tl, pos, c, float(def["tracer_width"]))
			"rocket":
				var dir: Vector2 = p["vel"].normalized()
				_glow.draw_circle(pos - dir * 14.0, 9.0, Color(1.0, 0.6, 0.2, 0.7))
				_glow.draw_circle(pos - dir * 14.0, 4.0, Color(1.0, 1.0, 0.8, 1.0))
			"grenade":
				if p["def"]["id"] == "holy":
					_glow.draw_circle(pos, 16.0 + sin(p["life"] * 10.0) * 4.0, Color(1.0, 0.9, 0.4, 0.35))
				if p["def"]["id"] == "airstrike":
					_glow.draw_circle(pos, 10.0, Color(1.0, 0.1, 0.1, 0.6 + 0.4 * sin(p["life"] * 30.0)))
					continue
				var blink: bool = fmod(p["fuse"], 0.3) < 0.15 or p["fuse"] < 0.5
				if blink:
					_glow.draw_circle(pos, 7.0, Color(1.0, 0.2, 0.1, 0.6))
					_glow.draw_circle(pos, 2.5, Color(1.0, 0.6, 0.5, 1.0))
