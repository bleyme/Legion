extends Node

func assault_rifle() -> Dictionary:
	return {
		"weapon_name":  "Assault Rifle",
		"damage":       15.0,
		"fire_rate":    0.1,
		"mag_size":     30,
		"ammo_reserve": 150,
		"bullet_speed": 1200.0,
		"pellets":      1,
		"spread":       0.03,
		"reload_time":  1.8,
		"weapon_type":  0,
		"is_grenade":   false,
	}

func shotgun() -> Dictionary:
	return {
		"weapon_name":  "Shotgun",
		"damage":       20.0,
		"fire_rate":    0.75,
		"mag_size":     8,
		"ammo_reserve": 40,
		"bullet_speed": 900.0,
		"pellets":      7,
		"spread":       0.18,
		"reload_time":  2.2,
		"weapon_type":  1,
		"is_grenade":   false,
	}

func sniper() -> Dictionary:
	return {
		"weapon_name":  "Sniper",
		"damage":       85.0,
		"fire_rate":    1.5,
		"mag_size":     5,
		"ammo_reserve": 20,
		"bullet_speed": 2800.0,
		"pellets":      1,
		"spread":       0.0,
		"reload_time":  2.5,
		"weapon_type":  2,
		"is_grenade":   false,
	}

func grenade_launcher() -> Dictionary:
	return {
		"weapon_name":  "Grenade Launcher",
		"damage":       80.0,
		"fire_rate":    1.0,
		"mag_size":     4,
		"ammo_reserve": 16,
		"bullet_speed": 500.0,
		"pellets":      1,
		"spread":       0.0,
		"reload_time":  2.8,
		"weapon_type":  3,
		"is_grenade":   true,
	}

func from_type(type: int) -> Dictionary:
	match type:
		0: return assault_rifle()
		1: return shotgun()
		2: return sniper()
		3: return grenade_launcher()
	return assault_rifle()
