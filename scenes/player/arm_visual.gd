extends Node2D
## Arms holding the gun; hand placement depends on the weapon.

const C_SKIN := Color(0.78, 0.58, 0.42)

var weapon_id := "pistol"
var color := Color(0.29, 0.36, 0.22)

func _draw() -> void:
	var sleeve := color.darkened(0.45)
	var grip := 9.0
	var fore := 22.0
	match weapon_id:
		"pistol":
			fore = 12.0
		"smg":
			fore = 14.0
		"rocket":
			grip = 4.0
			fore = 16.0
		"minigun":
			grip = 0.0
			fore = 22.0
	# arm from the shoulder to the rear grip, then to the fore grip
	draw_line(Vector2(-6, 2), Vector2(grip, 3), sleeve, 6.0)
	draw_circle(Vector2(grip, 4), 3.6, C_SKIN)
	draw_line(Vector2(-2, 4), Vector2(fore - 2, 2), sleeve.lightened(0.08), 5.0)
	draw_circle(Vector2(fore, 1), 3.4, C_SKIN)
