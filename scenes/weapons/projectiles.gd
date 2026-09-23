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
				"kind": def["kind"], "pos": origin, "vel": dir * speed + inherit,
				"def": def, "shooter": shooter, "life": 0.0, "traveled": 0.0,
				"fuse": def["fuse"], "bounces": 0,
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
		var alive := true
		match p["kind"]:
			"bullet":  alive = _step_bullet(p, delta, space)
			"rocket":  alive = _step_rocket(p, delta, space)
			"grenade": alive = _step_grenade(p, delta, space)
		if alive:
			i += 1
		else:
			_list.remove_at(i)
	queue_redraw()
	_glow.queue_redraw()

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

func _step_grenade(p: Dictionary, dt: float, space: PhysicsDirectSpaceState2D) -> bool:
	var def: Dictionary = p["def"]
	p["life"] += dt
	p["fuse"] -= dt
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
	if head:
		dmg *= float(def["head_mult"])
	target.take_damage(dmg, dir * float(def["knock"]), shooter, def["id"], head, at)

func explode(pos: Vector2, def: Dictionary, shooter: Node) -> void:
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

# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------

func _draw() -> void:
	for p in _list:
		var pos: Vector2 = p["pos"]
		match p["kind"]:
			"rocket":
				var ang: float = p["vel"].angle()
				draw_set_transform(pos, ang)
				draw_rect(Rect2(-12, -3, 16, 6), Color(0.3, 0.35, 0.25))
				draw_colored_polygon(PackedVector2Array([Vector2(4, -3), Vector2(10, 0), Vector2(4, 3)]), Color(0.8, 0.2, 0.15))
				draw_rect(Rect2(-14, -5, 4, 10), Color(0.2, 0.22, 0.2))
				draw_set_transform(Vector2.ZERO, 0.0)
			"grenade":
				var frag: bool = p["def"]["id"] == "frag"
				draw_circle(pos, 5.0 if frag else 4.5, Color(0.22, 0.28, 0.16) if frag else Color(0.25, 0.25, 0.28))
				draw_circle(pos + Vector2(-1.5, -1.5), 1.8, Color(0.45, 0.5, 0.35))
				if frag:
					draw_rect(Rect2(pos + Vector2(-2, -8), Vector2(4, 3)), Color(0.5, 0.5, 0.5))

func _draw_glow() -> void:
	for p in _list:
		var pos: Vector2 = p["pos"]
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
				var blink: bool = fmod(p["fuse"], 0.3) < 0.15 or p["fuse"] < 0.5
				if blink:
					_glow.draw_circle(pos, 7.0, Color(1.0, 0.2, 0.1, 0.6))
					_glow.draw_circle(pos, 2.5, Color(1.0, 0.6, 0.5, 1.0))
