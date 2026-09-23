extends Node2D
## Builds collision for a MapData layout and renders it. Static geometry is
## drawn once; decals (bullet holes, scorch marks, blood) live on a child that
## only redraws when a decal is added.

const LAYER_WORLD    := 1
const LAYER_PLAYERS  := 2
const LAYER_PLATFORM := 4
const MAX_DECALS     := 500

var data: Dictionary
var size: Vector2
var theme: Dictionary
var solids: Array = []     # Rect2, includes border walls
var platforms: Array = []  # Rect2
var spawns: Array = []     # Vector2 feet positions

var _decals: Array = []    # [pos, radius, color]
var _decal_layer: Node2D
var _glow_layer: Node2D

func setup(map: Dictionary) -> void:
	data = map
	size = map["size"]
	theme = map["theme"]
	spawns = map["spawns"]
	platforms = map["platforms"]
	solids = map["solids"].duplicate()
	var t := 400.0
	solids.append(Rect2(-t, -t, t, size.y + t * 2))        # left
	solids.append(Rect2(size.x, -t, t, size.y + t * 2))    # right
	solids.append(Rect2(-t, -t, size.x + t * 2, t))        # ceiling
	solids.append(Rect2(-t, size.y, size.x + t * 2, t))    # floor below ground

	var world := StaticBody2D.new()
	world.collision_layer = LAYER_WORLD
	world.collision_mask = 0
	add_child(world)
	for r in solids:
		world.add_child(_shape_for(r, false))

	var plat := StaticBody2D.new()
	plat.collision_layer = LAYER_PLATFORM
	plat.collision_mask = 0
	add_child(plat)
	for r in platforms:
		plat.add_child(_shape_for(r, true))

	_decal_layer = Node2D.new()
	_decal_layer.draw.connect(_draw_decals)
	add_child(_decal_layer)

	_glow_layer = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_layer.material = mat
	_glow_layer.draw.connect(_draw_glow)
	_glow_layer.z_index = 1
	add_child(_glow_layer)
	queue_redraw()

func _shape_for(r: Rect2, one_way: bool) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	cs.one_way_collision = one_way
	cs.one_way_collision_margin = 8.0
	return cs

# --------------------------------------------------------------------------
# Queries used by bots and spawning
# --------------------------------------------------------------------------

func is_solid(p: Vector2) -> bool:
	for r in solids:
		if r.has_point(p):
			return true
	return false

func solid_at(p: Vector2) -> Variant:
	for r in solids:
		if r.has_point(p):
			return r
	return null

## Returns the rect (solid or platform) the given feet position stands on.
func support_under(feet: Vector2, tolerance := 6.0) -> Variant:
	for r in solids:
		if feet.x >= r.position.x - 4 and feet.x <= r.end.x + 4 and absf(feet.y - r.position.y) <= tolerance:
			return r
	for r in platforms:
		if feet.x >= r.position.x - 4 and feet.x <= r.end.x + 4 and absf(feet.y - r.position.y) <= tolerance:
			return r
	return null

func is_platform(r: Variant) -> bool:
	return r != null and platforms.has(r)

## Top surface y of the first floor below a point (solid or platform).
func floor_below(p: Vector2) -> float:
	var best := size.y
	for list in [solids, platforms]:
		for r in list:
			if p.x >= r.position.x and p.x <= r.end.x and r.position.y >= p.y and r.position.y < best:
				best = r.position.y
	return best

# --------------------------------------------------------------------------
# Decals
# --------------------------------------------------------------------------

func add_decal(pos: Vector2, radius: float, color: Color) -> void:
	_decals.append([pos, radius, color])
	if _decals.size() > MAX_DECALS:
		_decals.pop_front()
	_decal_layer.queue_redraw()

func _draw_decals() -> void:
	for d in _decals:
		_decal_layer.draw_circle(d[0], d[1], d[2])

# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------

func _draw() -> void:
	var block: Color = theme["block"]
	var edge: Color = theme["edge"]
	var plat: Color = theme["platform"]
	var accent: Color = theme["accent"]
	var strut := block.darkened(0.35)
	strut.a = 0.9

	# Support struts behind platforms and floating blocks, down to the floor below.
	for r in platforms + map_solids():
		if r.size.x > 1500:
			continue
		for x in [r.position.x + 18, r.end.x - 24]:
			var top: float = r.end.y
			var bottom := floor_below(Vector2(x + 3, top + 1))
			if bottom - top > 8 and bottom - top < 380:
				draw_rect(Rect2(x, top, 6, bottom - top), strut)
				var y := top + 30
				while y < bottom - 10:
					draw_rect(Rect2(x - 3, y, 12, 3), strut.darkened(0.2))
					y += 60

	# Lamps (fixture part; the glow is additive on its own layer)
	for l in data.get("lights", []):
		draw_rect(Rect2(l.x - 10, l.y - 6, 20, 6), block.darkened(0.3))
		draw_rect(Rect2(l.x - 7, l.y, 14, 3), accent.lightened(0.3))

	for r in map_solids():
		_draw_block(r, block, edge, accent)

	for r in platforms:
		_draw_platform(r, plat, edge, accent)

	# Border frame
	var frame := block.darkened(0.5)
	draw_rect(Rect2(-400, -400, 400, size.y + 800), frame)
	draw_rect(Rect2(size.x, -400, 400, size.y + 800), frame)
	draw_rect(Rect2(-400, -400, size.x + 800, 400), frame)
	draw_rect(Rect2(-6, 0, 6, size.y), edge.darkened(0.3))
	draw_rect(Rect2(size.x, 0, 6, size.y), edge.darkened(0.3))
	draw_rect(Rect2(0, -6, size.x, 6), edge.darkened(0.3))

func map_solids() -> Array:
	return data["solids"]

func _draw_block(r: Rect2, block: Color, edge: Color, accent: Color) -> void:
	draw_rect(r, block)
	# inner panel shading
	if r.size.y > 20 and r.size.x > 20:
		draw_rect(Rect2(r.position + Vector2(4, 8), r.size - Vector2(8, 12)), block.darkened(0.12))
	# vertical seams
	var x := r.position.x + 64.0
	while x < r.end.x - 8:
		draw_rect(Rect2(x, r.position.y + 6, 2, r.size.y - 6), block.darkened(0.3))
		if r.size.y > 24:
			draw_circle(Vector2(x - 8, r.position.y + 14), 1.8, edge.darkened(0.2))
			draw_circle(Vector2(x + 10, r.position.y + 14), 1.8, edge.darkened(0.2))
		x += 64.0
	# top edge highlight + hazard strip on thick blocks
	draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), edge)
	draw_rect(Rect2(r.position + Vector2(0, 4), Vector2(r.size.x, 2)), edge.darkened(0.4))
	if r.size.y >= 60 and r.size.x >= 100:
		var sx := r.position.x + 10
		var sy := r.position.y + 12
		var stripe := accent.darkened(0.25)
		stripe.a = 0.55
		while sx < r.end.x - 20:
			draw_colored_polygon(PackedVector2Array([
				Vector2(sx, sy + 8), Vector2(sx + 8, sy), Vector2(sx + 16, sy), Vector2(sx + 8, sy + 8)
			]), stripe)
			sx += 16
	# side edges and bottom shadow
	draw_rect(Rect2(r.position.x, r.position.y, 2, r.size.y), edge.darkened(0.25))
	draw_rect(Rect2(r.end.x - 2, r.position.y, 2, r.size.y), block.darkened(0.45))
	draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), block.darkened(0.5))

func _draw_platform(r: Rect2, plat: Color, edge: Color, accent: Color) -> void:
	var deck := Rect2(r.position, Vector2(r.size.x, 6))
	var truss_top := r.position.y + 6
	var truss_bot := r.end.y
	# truss zigzag
	var x := r.position.x
	var up := true
	var truss_col := plat.darkened(0.3)
	while x < r.end.x - 1:
		var nx := minf(x + 14.0, r.end.x)
		draw_line(Vector2(x, truss_top if up else truss_bot), Vector2(nx, truss_bot if up else truss_top), truss_col, 2.0)
		x = nx
		up = not up
	draw_rect(Rect2(r.position.x, truss_bot - 2, r.size.x, 2), truss_col)
	draw_rect(deck, plat)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), edge.lightened(0.1))
	# end caps with accent lights
	draw_rect(Rect2(r.position.x, r.position.y, 4, r.size.y), plat.darkened(0.2))
	draw_rect(Rect2(r.end.x - 4, r.position.y, 4, r.size.y), plat.darkened(0.2))
	draw_rect(Rect2(r.position.x + 1, r.position.y + 2, 2, 2), accent)
	draw_rect(Rect2(r.end.x - 3, r.position.y + 2, 2, 2), accent)

func _draw_glow() -> void:
	var accent: Color = theme["accent"]
	for l in data.get("lights", []):
		var c := accent
		c.a = 0.22
		_glow_layer.draw_texture_rect(Game.soft_tex, Rect2(l + Vector2(-150, -120), Vector2(300, 300)), false, c)
		c.a = 0.5
		_glow_layer.draw_texture_rect(Game.soft_tex, Rect2(l + Vector2(-30, -22), Vector2(60, 50)), false, c)
	# accent strip lights on platform ends
	for r in platforms:
		var c := accent
		c.a = 0.5
		_glow_layer.draw_texture_rect(Game.soft_tex, Rect2(r.position + Vector2(-10, -7), Vector2(24, 20)), false, c)
		_glow_layer.draw_texture_rect(Game.soft_tex, Rect2(Vector2(r.end.x - 14, r.position.y - 7), Vector2(24, 20)), false, c)
