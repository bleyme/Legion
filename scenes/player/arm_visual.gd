extends Node2D

const C_SKIN := Color(0.78, 0.58, 0.42)
const C_ARM  := Color(0.29, 0.36, 0.22)

func _draw() -> void:
	# Upper arm connecting body to grip
	draw_rect(Rect2(-6, -3, 11, 6), C_ARM, true)
	# Back hand on pistol grip
	draw_circle(Vector2(6, 0), 4, C_SKIN)
	# Forearm toward foregrip
	draw_rect(Rect2(10, -2, 12, 5), C_ARM, true)
	# Front hand on foregrip
	draw_circle(Vector2(22, 0), 4, C_SKIN)
