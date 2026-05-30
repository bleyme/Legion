extends Node2D

const C_PRIMARY := Color(0.29, 0.36, 0.22)
const C_DARK    := Color(0.18, 0.22, 0.13)
const C_HELMET  := Color(0.20, 0.25, 0.14)
const C_SKIN    := Color(0.78, 0.58, 0.42)
const C_BOOT    := Color(0.10, 0.07, 0.04)
const C_BELT    := Color(0.16, 0.12, 0.06)
const C_GOGGLE  := Color(0.12, 0.18, 0.28)
const C_VEST    := Color(0.34, 0.40, 0.26)

var walk_time: float = 0.0

func _process(delta: float) -> void:
	var parent := get_parent()
	if parent and "velocity" in parent:
		var vel_x: float = parent.velocity.x
		if abs(vel_x) > 5.0:
			walk_time += delta * 9.0
		if parent.has_node("GunPivot"):
			var grot: float = parent.get_node("GunPivot").rotation
			scale.x = -1.0 if abs(grot) > PI * 0.5 else 1.0
	queue_redraw()

func _draw() -> void:
	var t := walk_time

	# Back leg (opposite phase)
	var bl: float = sin(t + PI) * 0.38
	draw_set_transform(Vector2(-2, 16), bl)
	draw_rect(Rect2(-3, 0, 7, 11), C_DARK, true)
	draw_set_transform(Vector2(-2 + sin(bl) * 5, 26), 0.0)
	draw_rect(Rect2(-4, 0, 9, 4), C_BOOT, true)
	draw_set_transform(Vector2.ZERO, 0.0)

	# Body
	draw_rect(Rect2(-10, -5, 20, 17), C_PRIMARY, true)
	draw_rect(Rect2(-8, -3, 16, 12), C_VEST, true)
	draw_rect(Rect2(-10, 12, 20, 4), C_BELT, true)
	draw_rect(Rect2(-3, 12, 6, 4), Color(0.30, 0.22, 0.10), true)

	# Back arm
	draw_rect(Rect2(-14, -4, 5, 12), C_PRIMARY, true)
	draw_circle(Vector2(-12, 9), 3, C_SKIN)

	# Front leg
	var fl: float = sin(t) * 0.38
	draw_set_transform(Vector2(2, 16), fl)
	draw_rect(Rect2(-3, 0, 7, 11), C_DARK, true)
	draw_set_transform(Vector2(2 + sin(fl) * 5, 26), 0.0)
	draw_rect(Rect2(-3, 0, 9, 4), C_BOOT, true)
	draw_set_transform(Vector2.ZERO, 0.0)

	# Helmet
	draw_rect(Rect2(-10, -30, 20, 13), C_HELMET, true)
	draw_rect(Rect2(-12, -20, 24, 4), C_DARK, true)

	# Face
	draw_circle(Vector2(0, -13), 8, C_SKIN)
	draw_rect(Rect2(-9, -16, 5, 4), C_GOGGLE, true)
	draw_rect(Rect2(4, -16, 5, 4), C_GOGGLE, true)
	draw_line(Vector2(-4, -14), Vector2(4, -14), C_GOGGLE, 1.5)
