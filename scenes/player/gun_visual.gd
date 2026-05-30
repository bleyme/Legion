extends Node2D

var color_metal := Color(0.16, 0.16, 0.16)
var color_dark  := Color(0.10, 0.10, 0.10)
var color_wood  := Color(0.24, 0.17, 0.08)

func _draw() -> void:
	# Stock (wood)
	draw_rect(Rect2(-18, -3, 12, 6), color_wood, true)
	# Lower receiver
	draw_rect(Rect2(-7, -3, 20, 6), color_metal, true)
	# Grip
	draw_rect(Rect2(-2, 3,  6, 8), color_metal, true)
	# Magazine
	draw_rect(Rect2(5,  3,  4, 8), color_dark, true)
	# Upper receiver
	draw_rect(Rect2(-7, -6, 26, 5), color_metal, true)
	# Rail sights
	draw_rect(Rect2(-2, -9, 4, 3), color_dark, true)
	draw_rect(Rect2(12, -9, 4, 3), color_dark, true)
	# Handguard
	draw_rect(Rect2(12, -3, 10, 6), Color(0.20, 0.20, 0.20), true)
	# Barrel
	draw_rect(Rect2(20, -2, 18, 4), color_dark, true)
	# Muzzle tip
	draw_rect(Rect2(37, -3, 2, 6), Color(0.22, 0.22, 0.22), true)
