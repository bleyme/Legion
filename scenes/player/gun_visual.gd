extends Node2D
const WeaponArt := preload("res://scripts/weapon_art.gd")
## Held weapon, drawn with the shared WeaponArt.

var weapon_id := "pistol"

func _draw() -> void:
	WeaponArt.draw_weapon(self, weapon_id)
