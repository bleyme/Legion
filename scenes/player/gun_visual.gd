extends Node2D
## Held weapon, drawn with the shared WeaponArt.

var weapon_id := "pistol"

func _draw() -> void:
	WeaponArt.draw_weapon(self, weapon_id)
