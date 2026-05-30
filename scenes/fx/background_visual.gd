extends Node2D

func _draw() -> void:
	var W := 1280.0
	var H := 720.0

	# Sky gradient (approximated with bands)
	draw_rect(Rect2(0, 0, W, H * 0.4), Color(0.04, 0.06, 0.14), true)
	draw_rect(Rect2(0, H * 0.4, W, H * 0.35), Color(0.08, 0.10, 0.20), true)
	draw_rect(Rect2(0, H * 0.75, W, H * 0.25), Color(0.10, 0.13, 0.22), true)

	# Moon
	draw_circle(Vector2(1100, 85), 40, Color(0.88, 0.85, 0.72))
	draw_circle(Vector2(1116, 78), 37, Color(0.04, 0.06, 0.14))

	# Stars
	var stars := [
		Vector2(80, 50), Vector2(200, 30), Vector2(360, 70), Vector2(520, 25),
		Vector2(650, 55), Vector2(780, 40), Vector2(920, 65), Vector2(1050, 35),
		Vector2(1180, 70), Vector2(140, 110), Vector2(440, 90), Vector2(860, 100),
	]
	for s in stars:
		draw_circle(s, 1.5, Color(1, 1, 1, randf_range(0.4, 0.9)))

	# Distant buildings - left
	_draw_building(0,   440, 60,  280, Color(0.07, 0.09, 0.14))
	_draw_building(20,  400, 30,  320, Color(0.06, 0.08, 0.13))
	_draw_building(55,  460, 45,  260, Color(0.07, 0.09, 0.14))
	_draw_building(90,  420, 28,  300, Color(0.06, 0.08, 0.13))
	_draw_building(110, 450, 55,  270, Color(0.07, 0.09, 0.14))
	_draw_building(150, 380, 38,  340, Color(0.06, 0.08, 0.13))
	# Antenna
	draw_rect(Rect2(164, 358, 3, 24), Color(0.05, 0.07, 0.12), true)

	# Distant buildings - right
	_draw_building(1090, 445, 65, 280, Color(0.07, 0.09, 0.14))
	_draw_building(1128, 408, 42, 315, Color(0.06, 0.08, 0.13))
	_draw_building(1162, 438, 52, 282, Color(0.07, 0.09, 0.14))
	_draw_building(1200, 418, 45, 302, Color(0.06, 0.08, 0.13))
	_draw_building(1225, 455, 55, 265, Color(0.07, 0.09, 0.14))

	# Window lights
	var windows := [
		[Vector2(28, 415), Color(0.90, 0.80, 0.30, 0.6)],
		[Vector2(160, 398), Color(0.90, 0.80, 0.30, 0.5)],
		[Vector2(115, 435), Color(0.50, 0.70, 1.00, 0.5)],
		[Vector2(1135, 422), Color(0.90, 0.80, 0.30, 0.5)],
		[Vector2(1168, 450), Color(0.50, 0.70, 1.00, 0.5)],
		[Vector2(1205, 432), Color(0.90, 0.80, 0.30, 0.6)],
	]
	for w in windows:
		draw_rect(Rect2(w[0], Vector2(6, 4)), w[1], true)

	# Ground fog
	draw_rect(Rect2(0, 660, W, 60), Color(0.08, 0.10, 0.18, 0.5), true)

func _draw_building(x: float, y: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(x, y, w, h), col, true)
