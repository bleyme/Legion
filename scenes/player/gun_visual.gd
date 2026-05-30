extends Node2D

var weapon_type := 0

func _draw() -> void:
	match weapon_type:
		0: _draw_rifle()
		1: _draw_shotgun()
		2: _draw_sniper()
		3: _draw_grenade_launcher()

func _draw_rifle() -> void:
	draw_rect(Rect2(-18, -3, 12, 6), Color(0.24, 0.17, 0.08), true)
	draw_rect(Rect2(-7, -3, 20, 6),  Color(0.16, 0.16, 0.16), true)
	draw_rect(Rect2(-2, 3, 6, 8),    Color(0.14, 0.14, 0.14), true)
	draw_rect(Rect2(5, 3, 4, 8),     Color(0.10, 0.10, 0.10), true)
	draw_rect(Rect2(-7, -6, 26, 5),  Color(0.18, 0.18, 0.18), true)
	draw_rect(Rect2(-2, -9, 4, 3),   Color(0.10, 0.10, 0.10), true)
	draw_rect(Rect2(12, -9, 4, 3),   Color(0.10, 0.10, 0.10), true)
	draw_rect(Rect2(12, -3, 10, 6),  Color(0.20, 0.20, 0.20), true)
	draw_rect(Rect2(20, -2, 18, 4),  Color(0.10, 0.10, 0.10), true)

func _draw_shotgun() -> void:
	draw_rect(Rect2(-18, -4, 14, 8),  Color(0.35, 0.22, 0.08), true)
	draw_rect(Rect2(-6, -5, 28, 10),  Color(0.18, 0.15, 0.12), true)
	draw_rect(Rect2(-3, 5, 7, 9),     Color(0.16, 0.13, 0.10), true)
	draw_rect(Rect2(10, -6, 8, 12),   Color(0.25, 0.20, 0.15), true)
	draw_rect(Rect2(18, -3, 14, 6),   Color(0.12, 0.12, 0.12), true)
	draw_line(Vector2(18, -1), Vector2(32, -1), Color(0.07, 0.07, 0.07), 1.5)

func _draw_sniper() -> void:
	draw_rect(Rect2(-20, -3, 16, 6),  Color(0.28, 0.18, 0.08), true)
	draw_rect(Rect2(-6, -3, 20, 6),   Color(0.16, 0.16, 0.16), true)
	draw_rect(Rect2(-4, 3, 6, 8),     Color(0.14, 0.14, 0.14), true)
	draw_rect(Rect2(0, -9, 12, 5),    Color(0.10, 0.10, 0.10), true)
	draw_circle(Vector2(6, -7), 3,    Color(0.20, 0.30, 0.50))
	draw_circle(Vector2(6, -7), 2,    Color(0.30, 0.50, 0.80, 0.7))
	draw_rect(Rect2(12, -2, 28, 4),   Color(0.10, 0.10, 0.10), true)
	draw_line(Vector2(8, 3), Vector2(6, 10),   Color(0.10, 0.10, 0.10), 1.5)
	draw_line(Vector2(12, 3), Vector2(14, 10), Color(0.10, 0.10, 0.10), 1.5)

func _draw_grenade_launcher() -> void:
	draw_rect(Rect2(-18, -4, 14, 8),  Color(0.22, 0.30, 0.18), true)
	draw_rect(Rect2(-6, -4, 22, 8),   Color(0.20, 0.22, 0.18), true)
	draw_rect(Rect2(-3, 4, 7, 9),     Color(0.18, 0.20, 0.16), true)
	draw_circle(Vector2(6, 0), 7,     Color(0.12, 0.12, 0.12))
	draw_circle(Vector2(6, 0), 5,     Color(0.20, 0.22, 0.18))
	draw_rect(Rect2(12, -4, 14, 8),   Color(0.12, 0.12, 0.12), true)
	draw_circle(Vector2(26, 0), 4,    Color(0.10, 0.10, 0.10))
