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

const RENDER_TILE := 128   # texture tiles re-uploaded after a blast
const COLL_TILE   := 64    # collision tiles rebuilt after a blast (> any crater radius / 2)
const BEDROCK_DEPTH := 40.0

var hard: Array = []       # indestructible Rect2 (walls, bedrock)
var soft_rects: Array = [] # destructible blocks as authored
var terrain: Image         # destructible terrain, alpha = solid
var _render_tiles := {}    # Vector2i -> Sprite2D
var _coll_tiles := {}      # Vector2i -> Array[CollisionPolygon2D]
var _terrain_root: Node2D
var _terrain_body: StaticBody2D
var _brushes := {}         # radius -> [mask Image, empty Image]

func setup(map: Dictionary) -> void:
	data = map
	size = map["size"]
	theme = map["theme"]
	spawns = map["spawns"]
	platforms = map["platforms"]
	var t := 400.0
	hard = [
		Rect2(-t, -t, t, size.y + t * 2),        # left
		Rect2(size.x, -t, t, size.y + t * 2),    # right
		Rect2(-t, -t, size.x + t * 2, t),        # ceiling
		Rect2(-t, size.y, size.x + t * 2, t),    # below the map
	]
	for r in map["solids"]:
		# The main ground keeps an indestructible bedrock under a diggable crust.
		if r.size.x >= size.x - 1.0 and r.size.y > BEDROCK_DEPTH + 10.0:
			soft_rects.append(Rect2(r.position, Vector2(r.size.x, BEDROCK_DEPTH)))
			hard.append(Rect2(r.position + Vector2(0, BEDROCK_DEPTH), r.size - Vector2(0, BEDROCK_DEPTH)))
		else:
			soft_rects.append(r)
	solids = hard + soft_rects   # legacy list (authoring shapes), not used for collision

	var world := StaticBody2D.new()
	world.collision_layer = LAYER_WORLD
	world.collision_mask = 0
	add_child(world)
	for r in hard:
		world.add_child(_shape_for(r, false))

	var plat := StaticBody2D.new()
	plat.collision_layer = LAYER_PLATFORM
	plat.collision_mask = 0
	add_child(plat)
	for r in platforms:
		plat.add_child(_shape_for(r, true))

	_build_terrain()

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
# Destructible terrain
# --------------------------------------------------------------------------

func _build_terrain() -> void:
	terrain = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	for r in soft_rects:
		_paint_block(r)
	_terrain_root = Node2D.new()
	add_child(_terrain_root)
	_terrain_body = StaticBody2D.new()
	_terrain_body.collision_layer = LAYER_WORLD
	_terrain_body.collision_mask = 0
	add_child(_terrain_body)
	var full := Rect2i(Vector2i.ZERO, terrain.get_size())
	_refresh_render(full)
	_refresh_collision(full)

## Rasterises one authored block with the same look the static renderer had.
func _paint_block(r: Rect2) -> void:
	var block: Color = theme["block"]
	var edge: Color = theme["edge"]
	var ri := Rect2i(r.position, r.size).intersection(Rect2i(Vector2i.ZERO, Vector2i(size)))
	if ri.size.x <= 0 or ri.size.y <= 0:
		return
	terrain.fill_rect(ri, block)
	if ri.size.x > 12 and ri.size.y > 14:
		terrain.fill_rect(Rect2i(ri.position + Vector2i(4, 8), ri.size - Vector2i(8, 12)), block.darkened(0.12))
	# strata so craters read as solid matter
	var y := ri.position.y + 20
	while y < ri.end.y - 6:
		terrain.fill_rect(Rect2i(ri.position.x + 4, y, ri.size.x - 8, 1), block.darkened(0.2))
		y += 18
	var x := ri.position.x + 64
	while x < ri.end.x - 8:
		terrain.fill_rect(Rect2i(x, ri.position.y + 6, 2, ri.size.y - 6), block.darkened(0.3))
		if ri.size.y > 24:
			terrain.fill_rect(Rect2i(x - 9, ri.position.y + 13, 2, 2), edge.darkened(0.2))
			terrain.fill_rect(Rect2i(x + 9, ri.position.y + 13, 2, 2), edge.darkened(0.2))
		x += 64
	terrain.fill_rect(Rect2i(ri.position, Vector2i(ri.size.x, 4)), edge)
	terrain.fill_rect(Rect2i(ri.position + Vector2i(0, 4), Vector2i(ri.size.x, 2)), edge.darkened(0.4))
	terrain.fill_rect(Rect2i(ri.position, Vector2i(2, ri.size.y)), edge.darkened(0.25))
	terrain.fill_rect(Rect2i(ri.end.x - 2, ri.position.y, 2, ri.size.y), block.darkened(0.45))
	terrain.fill_rect(Rect2i(ri.position.x, ri.end.y - 3, ri.size.x, 3), block.darkened(0.5))

func _tiles_in(area: Rect2i, tile: int) -> Array:
	var out := []
	var x0 := maxi(0, area.position.x / tile)
	var y0 := maxi(0, area.position.y / tile)
	var x1 := mini((terrain.get_width() - 1) / tile, (area.end.x - 1) / tile)
	var y1 := mini((terrain.get_height() - 1) / tile, (area.end.y - 1) / tile)
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			out.append(Vector2i(tx, ty))
	return out

func _tile_rect(t: Vector2i, tile: int) -> Rect2i:
	return Rect2i(t * tile, Vector2i(tile, tile)).intersection(Rect2i(Vector2i.ZERO, terrain.get_size()))

func _refresh_render(area: Rect2i) -> void:
	for t in _tiles_in(area, RENDER_TILE):
		var rect := _tile_rect(t, RENDER_TILE)
		var img := terrain.get_region(rect)
		var spr: Sprite2D = _render_tiles.get(t)
		if img.is_invisible():
			if spr:
				spr.queue_free()
				_render_tiles.erase(t)
			continue
		if spr == null:
			spr = Sprite2D.new()
			spr.centered = false
			spr.position = Vector2(rect.position)
			spr.texture = ImageTexture.create_from_image(img)
			_terrain_root.add_child(spr)
			_render_tiles[t] = spr
		else:
			(spr.texture as ImageTexture).update(img)

func _refresh_collision(area: Rect2i) -> void:
	for t in _tiles_in(area, COLL_TILE):
		for old in _coll_tiles.get(t, []):
			old.queue_free()
		_coll_tiles.erase(t)
		var rect := _tile_rect(t, COLL_TILE)
		var img := terrain.get_region(rect)
		if img.is_invisible():
			continue
		var bm := BitMap.new()
		bm.create_from_image_alpha(img, 0.5)
		var shapes := []
		for poly in bm.opaque_to_polygons(Rect2i(Vector2i.ZERO, rect.size), 1.2):
			if poly.size() < 3:
				continue
			var cp := CollisionPolygon2D.new()
			cp.polygon = poly
			cp.position = Vector2(rect.position)
			_terrain_body.add_child(cp)
			shapes.append(cp)
		_coll_tiles[t] = shapes

## Blasts a round crater out of the destructible terrain.
func carve(center: Vector2, radius: float) -> void:
	var r := int(radius)
	if r < 8:
		return
	var brush := _brush(r)
	var dst := Vector2i(center) - Vector2i(r, r)
	var area := Rect2i(dst, Vector2i(r * 2, r * 2)).intersection(Rect2i(Vector2i.ZERO, terrain.get_size()))
	if area.size.x <= 0 or area.size.y <= 0:
		return
	var src_rect := Rect2i(area.position - dst, area.size)
	# Only touch the terrain if there is something to destroy.
	if terrain.get_region(area).is_invisible():
		return
	terrain.blit_rect_mask(brush[1], brush[0], src_rect, area.position)
	# Scorch the new crater rim.
	var scorch := Color(0.05, 0.04, 0.03)
	for i in 72:
		var dir := Vector2.from_angle(i * TAU / 72.0)
		for d in range(1, 6):
			var q := Vector2i(center + dir * (radius + d))
			if q.x < 0 or q.y < 0 or q.x >= terrain.get_width() or q.y >= terrain.get_height():
				continue
			var c := terrain.get_pixelv(q)
			if c.a > 0.5:
				terrain.set_pixelv(q, c.lerp(scorch, 0.55 - d * 0.08))
	var grown := area.grow(6).intersection(Rect2i(Vector2i.ZERO, terrain.get_size()))
	_refresh_render(grown)
	_refresh_collision(area)
	# Decals floating over the new hole go away.
	var before := _decals.size()
	_decals = _decals.filter(func(dcl): return dcl[0].distance_to(center) > radius - 2.0)
	if _decals.size() != before:
		_decal_layer.queue_redraw()
	Game.fx.debris(center, radius, theme["block"])

func _brush(r: int) -> Array:
	if _brushes.has(r):
		return _brushes[r]
	var mask := Image.create(r * 2, r * 2, false, Image.FORMAT_RGBA8)
	var rr := float(r * r)
	for y in r * 2:
		for x in r * 2:
			var d := Vector2(x - r + 0.5, y - r + 0.5).length_squared()
			if d <= rr:
				mask.set_pixel(x, y, Color(1, 1, 1, 1))
	var empty := Image.create(r * 2, r * 2, false, Image.FORMAT_RGBA8)
	_brushes[r] = [mask, empty]
	return _brushes[r]

func _terrain_solid(p: Vector2) -> bool:
	var x := int(p.x)
	var y := int(p.y)
	if x < 0 or y < 0 or x >= terrain.get_width() or y >= terrain.get_height():
		return false
	return terrain.get_pixel(x, y).a > 0.5

## Horizontal run of solid terrain through p, as a thin Rect2 (for bots).
func _row_span(p: Vector2) -> Rect2:
	var xl := p.x
	var xr := p.x
	while xl > 0 and _terrain_solid(Vector2(xl - 4, p.y)):
		xl -= 4
	while xr < size.x and _terrain_solid(Vector2(xr + 4, p.y)):
		xr += 4
	return Rect2(xl, p.y, xr - xl, 1)

# --------------------------------------------------------------------------
# Queries used by bots, particles and spawning
# --------------------------------------------------------------------------

func is_solid(p: Vector2) -> bool:
	for r in hard:
		if r.has_point(p):
			return true
	return _terrain_solid(p)

func solid_at(p: Vector2) -> Variant:
	for r in hard:
		if r.has_point(p):
			return r
	if _terrain_solid(p):
		return _row_span(p)
	return null

## Returns the rect (solid or platform) the given feet position stands on.
func support_under(feet: Vector2, tolerance := 6.0) -> Variant:
	for r in hard:
		if feet.x >= r.position.x - 4 and feet.x <= r.end.x + 4 and absf(feet.y - r.position.y) <= tolerance:
			return r
	for r in platforms:
		if feet.x >= r.position.x - 4 and feet.x <= r.end.x + 4 and absf(feet.y - r.position.y) <= tolerance:
			return r
	for dy in range(-int(tolerance), int(tolerance) + 1, 2):
		var q := feet + Vector2(0, dy + 1)
		if _terrain_solid(q) and not _terrain_solid(q + Vector2(0, -3)):
			var span := _row_span(q)
			span.position.y = q.y
			return span
	return null

func is_platform(r: Variant) -> bool:
	return r != null and platforms.has(r)

## Top surface y of the first floor below a point (solid or platform).
func floor_below(p: Vector2) -> float:
	var best := size.y
	for list in [hard, platforms]:
		for r in list:
			if p.x >= r.position.x and p.x <= r.end.x and r.position.y >= p.y and r.position.y < best:
				best = r.position.y
	var y := maxf(p.y, 0.0)
	while y < best:
		if _terrain_solid(Vector2(p.x, y)):
			return y
		y += 3.0
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

	for r in hard:
		if r.position.x >= 0.0 and r.end.x <= size.x and r.position.y >= 0.0 and r.end.y <= size.y:
			_draw_block(r, block.darkened(0.25), edge.darkened(0.3), accent)

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
