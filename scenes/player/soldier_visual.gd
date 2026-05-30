extends Node2D

var color_primary := Color(0.29, 0.36, 0.22)
var color_dark    := Color(0.18, 0.22, 0.13)
var color_helmet  := Color(0.20, 0.25, 0.14)
var color_skin    := Color(0.78, 0.58, 0.42)
var color_boot    := Color(0.10, 0.07, 0.04)
var color_belt    := Color(0.16, 0.12, 0.06)
var color_goggle  := Color(0.12, 0.18, 0.28)

func _draw() -> void:
	# Helmet
	draw_rect(Rect2(-10, -30, 20, 13), color_helmet, true)
	draw_rect(Rect2(-12, -20, 24, 4), color_dark, true)
	# Face
	draw_circle(Vector2(0, -13), 8, color_skin)
	# Goggles
	draw_rect(Rect2(-9, -16, 5, 4), color_goggle, true)
	draw_rect(Rect2(4,  -16, 5, 4), color_goggle, true)
	draw_line(Vector2(-4, -14), Vector2(4, -14), color_goggle, 1.5)
	# Body / vest
	draw_rect(Rect2(-10, -5, 20, 17), color_primary, true)
	draw_rect(Rect2(-8,  -3, 16, 12), Color(0.34, 0.40, 0.26), true)
	# Belt
	draw_rect(Rect2(-10, 12, 20, 4), color_belt, true)
	draw_rect(Rect2(-3,  12,  6, 4), Color(0.30, 0.22, 0.10), true)
	# Left arm
	draw_rect(Rect2(-15, -5, 6, 14), color_primary, true)
	draw_circle(Vector2(-12, 10), 3, color_skin)
	# Right arm
	draw_rect(Rect2(9, -5, 6, 14), color_primary, true)
	draw_circle(Vector2(12, 10), 3, color_skin)
	# Left leg
	draw_rect(Rect2(-9, 16, 7, 13), color_dark, true)
	draw_rect(Rect2(-10, 27, 9, 4), color_boot, true)
	# Right leg
	draw_rect(Rect2(2,  16, 7, 13), color_dark, true)
	draw_rect(Rect2(1,  27, 9, 4), color_boot, true)
