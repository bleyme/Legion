extends Node2D
## All transient visual effects in one place. Particles are stored in packed
## arrays and drawn by two canvas items (normal + additive), so thousands of
## sparks cost a couple of draw passes instead of thousands of nodes.

enum { SQUARE, STREAK, SOFT, RING, FLASH }

const MAX_PARTICLES := 2200

class Pool:
	var pos := PackedVector2Array()
	var vel := PackedVector2Array()
	var life := PackedFloat32Array()
	var max_life := PackedFloat32Array()
	var size := PackedFloat32Array()
	var size_end := PackedFloat32Array()
	var col := PackedColorArray()
	var grav := PackedFloat32Array()
	var drag := PackedFloat32Array()
	var kind := PackedInt32Array()
	var collide := PackedByteArray()   # 0 none, 1 bounce, 2 stain (blood)
	var count := 0

	func emit(p: Vector2, v: Vector2, l: float, s0: float, s1: float, c: Color, g: float, d: float, k: int, coll := 0) -> void:
		if count >= MAX_PARTICLES:
			return
		if count == pos.size():
			var n := count + 256
			pos.resize(n); vel.resize(n); life.resize(n); max_life.resize(n)
			size.resize(n); size_end.resize(n); col.resize(n); grav.resize(n)
			drag.resize(n); kind.resize(n); collide.resize(n)
		var i := count
		pos[i] = p; vel[i] = v; life[i] = l; max_life[i] = l
		size[i] = s0; size_end[i] = s1; col[i] = c; grav[i] = g
		drag[i] = d; kind[i] = k; collide[i] = coll
		count += 1

	func _remove(i: int) -> void:
		var last := count - 1
		if i != last:
			pos[i] = pos[last]; vel[i] = vel[last]; life[i] = life[last]
			max_life[i] = max_life[last]; size[i] = size[last]; size_end[i] = size_end[last]
			col[i] = col[last]; grav[i] = grav[last]; drag[i] = drag[last]
			kind[i] = kind[last]; collide[i] = collide[last]
		count -= 1

	func update(dt: float, arena: Node) -> void:
		var i := 0
		while i < count:
			var l := life[i] - dt
			if l <= 0.0:
				_remove(i)
				continue
			life[i] = l
			var v := vel[i]
			v.y += grav[i] * dt
			if drag[i] > 0.0:
				v *= maxf(0.0, 1.0 - drag[i] * dt)
			var np := pos[i] + v * dt
			if collide[i] != 0 and arena and arena.is_solid(np):
				if collide[i] == 2:
					var c := col[i]
					c = c.darkened(0.25)
					c.a = 0.75
					arena.add_decal(pos[i], randf_range(1.5, 3.5), c)
					_remove(i)
					continue
				# bounce: figure out which axis hit
				if arena.is_solid(Vector2(np.x, pos[i].y)):
					v.x = -v.x * 0.4
				else:
					v.y = -v.y * 0.35
					v.x *= 0.7
				np = pos[i]
			vel[i] = v
			pos[i] = np
			i += 1

	func draw(ci: CanvasItem, tex: Texture2D) -> void:
		for i in count:
			var t := 1.0 - life[i] / max_life[i]
			var s := lerpf(size[i], size_end[i], t)
			var c := col[i]
			match kind[i]:
				SQUARE:
					c.a *= 1.0 - t * t
					ci.draw_rect(Rect2(pos[i] - Vector2(s, s) * 0.5, Vector2(s, s)), c)
				STREAK:
					c.a *= 1.0 - t
					var v := vel[i]
					ci.draw_line(pos[i], pos[i] - v * 0.025, c, s)
				SOFT:
					c.a *= (1.0 - t) * minf(1.0, t * 6.0 + 0.3)
					var r := s * 1.5
					ci.draw_texture_rect(tex, Rect2(pos[i] - Vector2(r, r), Vector2(r, r) * 2.0), false, c)
				RING:
					c.a *= 1.0 - t
					ci.draw_arc(pos[i], s, 0.0, TAU, 40, c, lerpf(8.0, 1.0, t))
				FLASH:
					c.a *= 1.0 - t
					var r := s * 1.6
					ci.draw_texture_rect(tex, Rect2(pos[i] - Vector2(r, r), Vector2(r, r) * 2.0), false, c)

var normal := Pool.new()
var glow := Pool.new()
var _glow_node: Node2D
var _texts: Array = []   # [pos, vel, text, color, life, max, size]
var _beams: Array = []   # [from, to, color, width, life, max]
var _font: Font
var _corpses: Array = []   # ragdoll pieces: {pos, vel, rot, spin, col, part, life}
const MAX_CORPSES := 60

func _ready() -> void:
	z_index = 5
	_font = ThemeDB.fallback_font
	_glow_node = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_node.material = mat
	_glow_node.draw.connect(_draw_glow)
	add_child(_glow_node)

func _process(delta: float) -> void:
	normal.update(delta, Game.arena)
	glow.update(delta, null)
	var i := 0
	while i < _texts.size():
		var t: Array = _texts[i]
		t[4] -= delta
		if t[4] <= 0.0:
			_texts.remove_at(i)
			continue
		t[0] += t[1] * delta
		t[1] *= 0.9
		i += 1
	_update_corpses(delta)
	i = 0
	while i < _beams.size():
		_beams[i][4] -= delta
		if _beams[i][4] <= 0.0:
			_beams.remove_at(i)
			continue
		i += 1
	queue_redraw()
	_glow_node.queue_redraw()

func _draw() -> void:
	_draw_corpses()
	normal.draw(self, Game.soft_tex)
	for t in _texts:
		var a: float = clampf(t[4] / t[5] * 2.0, 0.0, 1.0)
		var c: Color = t[3]
		c.a = a
		var sz: int = t[6]
		var w := _font.get_string_size(t[2], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var p: Vector2 = t[0] - Vector2(w * 0.5, 0)
		draw_string_outline(_font, p, t[2], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, Color(0, 0, 0, a * 0.8))
		draw_string(_font, p, t[2], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)

func _draw_glow() -> void:
	glow.draw(_glow_node, Game.soft_tex)
	for b in _beams:
		var t: float = b[4] / b[5]
		var c: Color = b[2]
		c.a = t
		_glow_node.draw_line(b[0], b[1], c, b[3] * (0.4 + t), true)
		var core := Color(1, 1, 1, t)
		_glow_node.draw_line(b[0], b[1], core, maxf(1.0, b[3] * 0.35 * t))

# --------------------------------------------------------------------------
# Effect recipes
# --------------------------------------------------------------------------

func muzzle_flash(p: Vector2, dir: Vector2, strength := 1.0) -> void:
	glow.emit(p, Vector2.ZERO, 0.06, 14.0 * strength, 4.0, Color(1.0, 0.8, 0.4, 0.9), 0, 0, FLASH)
	glow.emit(p + dir * 8.0, Vector2.ZERO, 0.05, 9.0 * strength, 2.0, Color(1.0, 1.0, 0.8, 1.0), 0, 0, FLASH)
	for i in int(4 * strength):
		var d := dir.rotated(randf_range(-0.35, 0.35)) * randf_range(250, 600)
		glow.emit(p, d, randf_range(0.04, 0.09), 2.0, 1.0, Color(1.0, 0.75, 0.3), 0, 0, STREAK)
	normal.emit(p + dir * 6, dir * 40 + Vector2(0, -20), 0.5, 3.0, 9.0, Color(0.6, 0.6, 0.6, 0.25), -30, 1.5, SOFT)

func shell(p: Vector2, facing: float, big := false) -> void:
	var v := Vector2(-facing * randf_range(60, 140), randf_range(-260, -160))
	var c := Color(0.9, 0.7, 0.25) if not big else Color(0.8, 0.2, 0.15)
	normal.emit(p, v, 1.4, 3.0 if not big else 4.0, 3.0, c, 1200, 0.2, SQUARE, 1)

func impact(p: Vector2, normal_dir: Vector2, color := Color(1.0, 0.8, 0.4)) -> void:
	for i in 6:
		var d := normal_dir.rotated(randf_range(-1.1, 1.1)) * randf_range(120, 380)
		glow.emit(p, d, randf_range(0.1, 0.25), 1.5, 1.0, color, 700, 1.0, STREAK)
	normal.emit(p, normal_dir * 30, 0.5, 2.0, 8.0, Color(0.55, 0.55, 0.6, 0.35), -20, 2.0, SOFT)
	for i in 3:
		var d := normal_dir.rotated(randf_range(-0.8, 0.8)) * randf_range(60, 200)
		normal.emit(p, d, 0.6, 2.5, 2.0, Color(0.3, 0.3, 0.32), 900, 0.5, SQUARE, 1)
	if Game.arena:
		Game.arena.add_decal(p - normal_dir * 1.5, 2.2, Color(0.02, 0.02, 0.03, 0.8))

func blood(p: Vector2, dir: Vector2, amount := 8, color := Color(0.75, 0.05, 0.05)) -> void:
	for i in amount:
		var d := dir.rotated(randf_range(-0.7, 0.7)) * randf_range(80, 360) + Vector2(0, -60)
		normal.emit(p, d, randf_range(0.4, 0.9), randf_range(2.0, 4.0), 1.5, color, 900, 0.3, SQUARE, 2)
	normal.emit(p, dir * 20, 0.25, 4.0, 10.0, Color(color.r, color.g, color.b, 0.5), 0, 3, SOFT)

func gibs(p: Vector2, team: Color, vel: Vector2) -> void:
	blood(p, Vector2.UP, 26)
	for i in 10:
		var d := Vector2.from_angle(randf() * TAU) * randf_range(120, 420) + vel * 0.4 + Vector2(0, -200)
		var c := team.darkened(randf_range(0.1, 0.5)) if i % 2 == 0 else Color(0.55, 0.08, 0.08)
		normal.emit(p, d, randf_range(1.2, 2.2), randf_range(4.0, 7.0), 3.0, c, 1000, 0.3, SQUARE, 1)
	glow.emit(p, Vector2.ZERO, 0.2, 30.0, 50.0, Color(1.0, 0.3, 0.2, 0.4), 0, 0, FLASH)

# --------------------------------------------------------------------------
# Ragdolls: a whole body, or the pieces of one when an explosion gets you
# --------------------------------------------------------------------------

func corpse(p: Vector2, vel: Vector2, team: Color, facing: float, dismember: bool) -> void:
	var armour := team.darkened(0.35).lerp(Color(0.25, 0.3, 0.2), 0.35)
	if not dismember:
		_add_piece(p, vel + Vector2(0, -120), armour, "body", facing, randf_range(-4, 4))
		return
	var parts := [["head", team.darkened(0.15), Vector2(0, -22)], ["torso", armour, Vector2.ZERO],
		["arm", armour.darkened(0.2), Vector2(-8, -6)], ["arm", armour.darkened(0.2), Vector2(8, -6)],
		["leg", armour.darkened(0.4), Vector2(-4, 16)], ["leg", armour.darkened(0.4), Vector2(4, 16)]]
	for part in parts:
		var burst := Vector2.from_angle(randf() * TAU) * randf_range(150, 420) + Vector2(0, -250)
		_add_piece(p + part[2], vel * 0.7 + burst, part[1], part[0], facing, randf_range(-14, 14))

func _add_piece(p: Vector2, v: Vector2, c: Color, part: String, facing: float, spin: float) -> void:
	_corpses.append({"pos": p, "vel": v, "rot": 0.0, "spin": spin, "col": c, "part": part,
		"life": 6.0, "facing": facing})
	if _corpses.size() > MAX_CORPSES:
		_corpses.pop_front()

func _update_corpses(dt: float) -> void:
	var i := 0
	while i < _corpses.size():
		var c: Dictionary = _corpses[i]
		c["life"] -= dt
		if c["life"] <= 0.0:
			_corpses.remove_at(i)
			continue
		var v: Vector2 = c["vel"]
		v.y = minf(v.y + 1500.0 * dt, 1100.0)
		var np: Vector2 = c["pos"] + v * dt
		if Game.arena and Game.arena.is_solid(np):
			if Game.arena.is_solid(Vector2(np.x, c["pos"].y)):
				v.x = -v.x * 0.35
			else:
				if v.y > 300.0 and c["part"] != "body":
					blood(c["pos"], Vector2.UP, 3)
				v.y = -v.y * 0.25
				v.x *= 0.55
				c["spin"] *= 0.5
			np = c["pos"]
		elif v.length() > 250.0 and c["part"] != "body" and randf() < 0.5:
			normal.emit(np, v * 0.1, 0.8, 2.5, 1.5, Color(0.7, 0.05, 0.05), 900, 0.3, SQUARE, 2)
		c["vel"] = v
		c["pos"] = np
		c["rot"] += c["spin"] * dt
		i += 1

func _draw_corpses() -> void:
	for c in _corpses:
		var a := clampf(c["life"], 0.0, 1.0)
		var col: Color = c["col"]
		col.a = a
		var skin := Color(0.78, 0.58, 0.42, a)
		draw_set_transform(c["pos"], c["rot"], Vector2(c["facing"], 1))
		match c["part"]:
			"body":
				draw_rect(Rect2(-9, -13, 18, 22), col)
				draw_circle(Vector2(1, -21), 7.5, skin)
				draw_circle(Vector2(0, -24), 8.0, col.lightened(0.15))
				draw_rect(Rect2(-6, 9, 5, 18), col.darkened(0.3))
				draw_rect(Rect2(2, 9, 5, 18), col.darkened(0.3))
			"head":
				draw_circle(Vector2.ZERO, 7.5, skin)
				draw_circle(Vector2(-1, -3), 8.0, col)
				draw_rect(Rect2(1, -1, 6, 3), Color(0.1, 0.14, 0.2, a))
			"torso":
				draw_rect(Rect2(-9, -11, 18, 20), col)
				draw_rect(Rect2(-9, 7, 18, 4), Color(0.5, 0.05, 0.05, a))
			"arm":
				draw_rect(Rect2(-2.5, -8, 5, 16), col)
				draw_circle(Vector2(0, 8), 3.0, skin)
			"leg":
				draw_rect(Rect2(-3, -9, 6, 16), col)
				draw_rect(Rect2(-3, 7, 8, 4), Color(0.09, 0.07, 0.05, a))
	draw_set_transform(Vector2.ZERO)

func explosion(p: Vector2, radius: float) -> void:
	glow.emit(p, Vector2.ZERO, 0.12, radius * 0.7, radius * 0.3, Color(1.0, 0.95, 0.8, 0.9), 0, 0, FLASH)
	glow.emit(p, Vector2.ZERO, 0.35, radius * 0.5, radius * 1.1, Color(1.0, 0.55, 0.15, 0.8), 0, 0, FLASH)
	glow.emit(p, Vector2.ZERO, 0.4, radius * 0.3, radius * 1.4, Color(1.0, 0.6, 0.3, 0.7), 0, 0, RING)
	for i in 26:
		var d := Vector2.from_angle(randf() * TAU) * randf_range(200, 700)
		glow.emit(p, d, randf_range(0.2, 0.5), 2.5, 1.0, Color(1.0, randf_range(0.5, 0.9), 0.2), 800, 1.5, STREAK)
	for i in 14:
		var d := Vector2.from_angle(randf() * TAU) * randf_range(30, radius * 1.4)
		glow.emit(p + d * 0.2, d, randf_range(0.25, 0.5), randf_range(10, 20), 2.0, Color(1.0, 0.45, 0.1, 0.6), -100, 3, SOFT)
	for i in 12:
		var d := Vector2.from_angle(randf() * TAU) * randf_range(20, radius)
		normal.emit(p + d * 0.3, d * 0.6 + Vector2(0, -40), randf_range(0.9, 1.8), randf_range(10, 16), randf_range(26, 40), Color(0.2, 0.19, 0.2, 0.55), -40, 1.8, SOFT)
	for i in 8:
		var d := Vector2.from_angle(randf_range(-PI, 0)) * randf_range(200, 500)
		normal.emit(p, d, randf_range(0.8, 1.6), 3.5, 3.0, Color(0.2, 0.18, 0.16), 1100, 0.2, SQUARE, 1)
	if Game.arena:
		for i in 14:
			var q := p + Vector2.from_angle(randf() * TAU) * randf_range(0.0, radius * 0.45)
			if Game.arena.is_solid(q):
				Game.arena.add_decal(q, randf_range(5.0, 11.0), Color(0.02, 0.02, 0.02, 0.35))

## Chunks of terrain flung out of a fresh crater.
func debris(p: Vector2, radius: float, col: Color) -> void:
	for i in int(clampf(radius * 0.25, 6, 30)):
		var d := Vector2.from_angle(randf_range(-PI, 0.0)) * randf_range(200, 650)
		normal.emit(p + Vector2.from_angle(randf() * TAU) * radius * 0.5, d, randf_range(0.8, 1.8),
			randf_range(3.0, 7.0), 2.0, col.lightened(randf_range(-0.2, 0.15)), 1300, 0.2, SQUARE, 1)
	for i in 6:
		normal.emit(p, Vector2.from_angle(randf() * TAU) * randf_range(20, 90), randf_range(1.0, 2.0),
			radius * 0.3, radius * 0.7, Color(0.35, 0.33, 0.32, 0.4), -30, 1.0, SOFT)

func rocket_trail(p: Vector2, dir: Vector2) -> void:
	glow.emit(p, -dir * 60, 0.08, 6.0, 2.0, Color(1.0, 0.7, 0.3, 0.9), 0, 0, FLASH)
	normal.emit(p, -dir * 40 + Vector2(randf_range(-15, 15), randf_range(-15, 15)), 0.8, 4.0, 14.0, Color(0.7, 0.7, 0.72, 0.35), -30, 1.2, SOFT)

func grenade_trail(p: Vector2) -> void:
	glow.emit(p, Vector2.ZERO, 0.15, 3.0, 0.5, Color(1.0, 0.4, 0.2, 0.7), 0, 0, FLASH)

func jet_flame(p: Vector2, vel: Vector2) -> void:
	glow.emit(p, Vector2(randf_range(-30, 30), randf_range(220, 380)) + vel * 0.3, 0.12, 5.0, 1.0, Color(1.0, randf_range(0.5, 0.8), 0.2, 0.9), 0, 1.0, FLASH)
	if randf() < 0.4:
		normal.emit(p + Vector2(0, 10), Vector2(randf_range(-20, 20), 120) + vel * 0.2, 0.6, 4.0, 12.0, Color(0.6, 0.6, 0.65, 0.2), -80, 2.0, SOFT)

func dust(p: Vector2, amount := 6) -> void:
	for i in amount:
		var d := Vector2(randf_range(-1, 1) * 140, randf_range(-50, -10))
		normal.emit(p, d, randf_range(0.3, 0.6), 3.0, 8.0, Color(0.6, 0.6, 0.65, 0.3), 0, 4, SOFT)

func spawn_burst(p: Vector2, c: Color) -> void:
	glow.emit(p, Vector2.ZERO, 0.4, 10.0, 60.0, Color(c.r, c.g, c.b, 0.9), 0, 0, RING)
	for i in 16:
		var d := Vector2.from_angle(i * TAU / 16.0) * 260
		glow.emit(p, d, 0.35, 2.0, 1.0, c, 0, 3.0, STREAK)

func pickup_burst(p: Vector2, c: Color) -> void:
	glow.emit(p, Vector2.ZERO, 0.3, 6.0, 34.0, Color(c.r, c.g, c.b, 0.8), 0, 0, RING)
	for i in 8:
		glow.emit(p, Vector2.from_angle(randf() * TAU) * randf_range(60, 160), 0.4, 3.0, 1.0, c, -200, 2.0, SQUARE)

func beam(from: Vector2, to: Vector2, c: Color, width := 6.0, life := 0.3) -> void:
	_beams.append([from, to, c, width, life, life])
	var dist := from.distance_to(to)
	var dir := (to - from) / maxf(dist, 1.0)
	var steps := int(dist / 40.0)
	for i in steps:
		var p := from + dir * (i * 40.0 + randf() * 40.0)
		normal.emit(p, Vector2(randf_range(-10, 10), randf_range(-25, -5)), randf_range(0.4, 0.8), 2.0, 7.0, Color(c.r, c.g, c.b, 0.18), 0, 1.0, SOFT)

func popup(p: Vector2, text: String, c: Color, font_size := 16) -> void:
	_texts.append([p, Vector2(randf_range(-30, 30), -90), text, c, 0.9, 0.9, font_size])
