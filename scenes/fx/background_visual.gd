extends Node2D
## Screen-space parallax backdrop (lives in a CanvasLayer behind the world).

const TILE := 1800.0

var theme: Dictionary
var _far: Array = []    # [x, w, h]
var _near: Array = []   # [x, w, h, windows:Array]
var _stars: Array = []  # [pos, size, phase]
var _time := 0.0

func setup(t: Dictionary) -> void:
	theme = t
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var x := 0.0
	while x < TILE:
		var w := rng.randf_range(50, 130)
		_far.append([x, w, rng.randf_range(90, 260)])
		x += w + rng.randf_range(-10, 20)
	x = 0.0
	while x < TILE:
		var w := rng.randf_range(70, 160)
		var h := rng.randf_range(120, 380)
		var windows := []
		var cols := int((w - 12) / 14.0)
		var rows := int((h - 24) / 20.0)
		var lit := rng.randf_range(0.05, 0.3)
		for cx in cols:
			for cy in rows:
				if rng.randf() < lit:
					windows.append(Vector2(8 + cx * 14, 14 + cy * 20))
		_near.append([x, w, h, windows])
		x += w + rng.randf_range(20, 90)
	for i in 90:
		_stars.append([Vector2(rng.randf(), rng.randf() * 0.6), rng.randf_range(0.8, 2.0), rng.randf() * TAU])

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if theme.is_empty():
		return
	var vs := get_viewport_rect().size
	var cam := Vector2.ZERO
	if Game.camera:
		cam = Game.camera.get_screen_center_position()
	var top: Color = theme["sky_top"]
	var bottom: Color = theme["sky_bottom"]
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]),
		PackedColorArray([top, top, bottom, bottom]))

	for s in _stars:
		var p: Vector2 = s[0] * vs
		p.x = fposmod(p.x - cam.x * 0.02, vs.x)
		var a := 0.35 + 0.35 * sin(_time * 1.5 + s[2])
		draw_rect(Rect2(p, Vector2(s[1], s[1])), Color(1, 1, 1, a))

	if theme.get("moon", false):
		var mp := Vector2(vs.x * 0.82 - cam.x * 0.01, vs.y * 0.16)
		draw_texture_rect(Game.soft_tex, Rect2(mp - Vector2(120, 120), Vector2(240, 240)), false, Color(0.9, 0.9, 1.0, 0.18))
		draw_circle(mp, 38, Color(0.92, 0.9, 0.8))
		draw_circle(mp + Vector2(12, -6), 34, top.lerp(bottom, 0.1))
	else:
		# furnace glow on the horizon
		var c: Color = theme["accent"]
		c.a = 0.35
		var r := vs.x * 0.75
		draw_texture_rect(Game.soft_tex, Rect2(Vector2(vs.x * 0.5 - r, vs.y * 1.1 - r), Vector2(r, r) * 2.0), false, c)

	var yshift := -cam.y * 0.04
	_draw_skyline(_far, theme["skyline"], vs, cam.x * 0.08, vs.y * 0.92 + yshift, false)
	_draw_skyline(_near, theme["skyline_near"], vs, cam.x * 0.18, vs.y * 1.02 + yshift * 1.8, true)

	var fog: Color = bottom
	fog.a = 0.35
	draw_rect(Rect2(0, vs.y * 0.82, vs.x, vs.y * 0.18), fog)

func _draw_skyline(list: Array, col: Color, vs: Vector2, scroll: float, base: float, windows: bool) -> void:
	var off := -fposmod(scroll, TILE)
	var win: Color = theme["window"]
	while off < vs.x:
		for b in list:
			var bx: float = off + b[0]
			if bx > vs.x or bx + b[1] < 0:
				continue
			var r := Rect2(bx, base - b[2], b[1], b[2] + 200)
			draw_rect(r, col)
			if windows:
				for w in b[3]:
					var wc := win
					wc.a = 0.3 + 0.12 * sin(_time * 0.5 + w.x * 0.1 + w.y)
					draw_rect(Rect2(r.position + w, Vector2(5, 4)), wc)
		off += TILE
