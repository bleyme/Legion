extends Node
## Weapon definitions. Every weapon is a plain Dictionary so it can be tweaked
## in one place. `kind` selects the projectile behaviour:
##   bullet  - fast raycast projectile with tracer
##   hitscan - instant ray (sniper)
##   rocket  - straight explosive projectile
##   grenade - bouncing explosive with fuse

const DEFAULTS := {
	"kind": "bullet", "pellets": 1, "spread": 0.02, "speed": 1600.0,
	"range": 1400.0, "falloff": 1.0, "knock": 60.0, "recoil": 0.0,
	"shake": 0.08, "kick": 3.0, "muzzle": 36.0, "move_mult": 1.0,
	"splash": 0.0, "fuse": 0.0, "head_mult": 1.5, "tracer": Color(1.0, 0.85, 0.35),
	"tracer_len": 26.0, "tracer_width": 2.0, "auto": true, "weight": 0,
	"sound": "rifle", "gravity": 0.0, "contact": true,
}

var _db := {
	"pistol": {
		"name": "Pistolet", "damage": 17.0, "fire_rate": 0.22, "mag": 12, "reserve": -1,
		"speed": 1700.0, "spread": 0.025, "reload": 1.0, "knock": 50.0, "shake": 0.06,
		"kick": 4.0, "muzzle": 26.0, "sound": "pistol", "range": 1200.0,
	},
	"smg": {
		"name": "Mitraillette", "damage": 11.0, "fire_rate": 0.06, "mag": 36, "reserve": 144,
		"speed": 1500.0, "spread": 0.085, "reload": 1.4, "knock": 30.0, "shake": 0.05,
		"kick": 2.5, "muzzle": 32.0, "sound": "smg", "range": 1000.0, "weight": 10,
		"tracer": Color(1.0, 0.75, 0.3), "tracer_len": 20.0,
	},
	"rifle": {
		"name": "Fusil d'assaut", "damage": 17.0, "fire_rate": 0.1, "mag": 30, "reserve": 120,
		"speed": 1900.0, "spread": 0.03, "reload": 1.7, "knock": 45.0, "shake": 0.07,
		"kick": 3.5, "muzzle": 40.0, "sound": "rifle", "range": 1600.0, "weight": 10,
	},
	"shotgun": {
		"name": "Fusil à pompe", "damage": 13.0, "pellets": 9, "fire_rate": 0.8, "mag": 6,
		"reserve": 24, "speed": 1300.0, "spread": 0.2, "reload": 2.0, "range": 520.0,
		"falloff": 0.35, "knock": 45.0, "recoil": 260.0, "shake": 0.3, "kick": 9.0,
		"muzzle": 36.0, "sound": "shotgun", "weight": 9, "tracer": Color(1.0, 0.7, 0.25),
		"tracer_len": 16.0, "head_mult": 1.2,
	},
	"sniper": {
		"name": "Sniper", "kind": "hitscan", "damage": 90.0, "fire_rate": 1.25, "mag": 5,
		"reserve": 15, "spread": 0.0, "reload": 2.3, "range": 3200.0, "knock": 380.0,
		"recoil": 160.0, "shake": 0.35, "kick": 10.0, "muzzle": 46.0, "sound": "sniper",
		"head_mult": 2.0, "weight": 6, "tracer": Color(0.55, 0.85, 1.0), "move_mult": 0.9,
	},
	"minigun": {
		"name": "Minigun", "damage": 9.0, "fire_rate": 0.042, "mag": 120, "reserve": 120,
		"speed": 1700.0, "spread": 0.11, "reload": 3.0, "knock": 25.0, "recoil": 18.0,
		"shake": 0.06, "kick": 2.0, "muzzle": 44.0, "sound": "minigun", "move_mult": 0.7,
		"weight": 5, "tracer": Color(1.0, 0.55, 0.2), "range": 1200.0,
	},
	"rocket": {
		"name": "Lance-roquettes", "kind": "rocket", "damage": 105.0, "fire_rate": 0.9,
		"mag": 1, "reserve": 7, "speed": 820.0, "spread": 0.0, "reload": 1.1,
		"splash": 115.0, "knock": 0.0, "recoil": 120.0, "shake": 0.25, "kick": 8.0,
		"muzzle": 42.0, "sound": "rocket", "weight": 5, "range": 3000.0, "move_mult": 0.9,
	},
	"grenade_launcher": {
		"name": "Lance-grenades", "kind": "grenade", "damage": 90.0, "fire_rate": 0.65,
		"mag": 4, "reserve": 12, "speed": 780.0, "spread": 0.02, "reload": 2.2,
		"splash": 105.0, "fuse": 1.6, "gravity": 1300.0, "recoil": 60.0, "shake": 0.15,
		"kick": 6.0, "muzzle": 34.0, "sound": "launcher", "weight": 6, "range": 3000.0,
	},
	"railgun": {
		"name": "Railgun", "kind": "hitscan", "damage": 70.0, "fire_rate": 1.4, "mag": 3,
		"reserve": 9, "spread": 0.0, "reload": 2.0, "range": 3200.0, "knock": 250.0,
		"recoil": 200.0, "shake": 0.3, "kick": 9.0, "muzzle": 42.0, "sound": "rail",
		"head_mult": 1.5, "weight": 4, "tracer": Color(0.8, 0.4, 1.0), "pierce": true,
	},
	# ---- The absurd arsenal -------------------------------------------------
	"sheep": {
		"name": "Mouton kamikaze", "kind": "sheep", "damage": 130.0, "fire_rate": 1.2,
		"mag": 1, "reserve": 2, "speed": 250.0, "reload": 1.5, "splash": 150.0, "fuse": 7.0,
		"gravity": 1400.0, "recoil": 0.0, "shake": 0.1, "kick": 4.0, "muzzle": 30.0,
		"sound": "baa", "weight": 3, "range": 3000.0, "contact": false,
	},
	"banana": {
		"name": "Banane à fragmentation", "kind": "grenade", "damage": 70.0, "fire_rate": 1.0,
		"mag": 1, "reserve": 2, "speed": 700.0, "reload": 1.4, "splash": 95.0, "fuse": 2.0,
		"gravity": 1300.0, "sound": "throw", "weight": 3, "range": 3000.0, "contact": false,
		"cluster": 6, "muzzle": 26.0,
	},
	"banana_bit": {
		"name": "Banane à fragmentation", "kind": "grenade", "damage": 55.0, "speed": 0.0,
		"splash": 75.0, "fuse": 1.4, "gravity": 1300.0, "contact": true, "fire_rate": 1.0,
		"mag": 1, "reserve": 0, "reload": 0.0,
	},
	"holy": {
		"name": "Sainte grenade", "kind": "grenade", "damage": 170.0, "fire_rate": 1.0,
		"mag": 1, "reserve": 0, "speed": 620.0, "reload": 1.0, "splash": 240.0, "fuse": 3.0,
		"gravity": 1300.0, "sound": "throw", "weight": 2, "range": 3000.0, "contact": false,
		"holy": true, "muzzle": 26.0,
	},
	"airstrike": {
		"name": "Frappe aérienne", "kind": "grenade", "damage": 0.0, "fire_rate": 1.5,
		"mag": 1, "reserve": 1, "speed": 650.0, "reload": 1.0, "splash": 0.0, "fuse": 1.1,
		"gravity": 1300.0, "sound": "throw", "weight": 3, "range": 3000.0, "contact": false,
		"airstrike": 6, "muzzle": 26.0,
	},
	"strike_missile": {
		"name": "Frappe aérienne", "kind": "rocket", "damage": 75.0, "speed": 950.0,
		"splash": 95.0, "fire_rate": 1.0, "mag": 1, "reserve": 0, "reload": 0.0,
	},
	# Thrown frag grenade (not a carried weapon, used by the grenade key).
	"frag": {
		"name": "Grenade", "kind": "grenade", "damage": 100.0, "speed": 720.0,
		"splash": 125.0, "fuse": 1.8, "gravity": 1300.0, "sound": "throw",
		"contact": false, "fire_rate": 0.6, "mag": 1, "reserve": 0, "reload": 0.0,
	},
}

func _ready() -> void:
	for id in _db:
		var w: Dictionary = _db[id]
		for k in DEFAULTS:
			if not w.has(k):
				w[k] = DEFAULTS[k]
		w["id"] = id
		if not w.has("pierce"):
			w["pierce"] = false

func get_def(id: String) -> Dictionary:
	return _db.get(id, _db["pistol"])

func has(id: String) -> bool:
	return _db.has(id)

## Weapons that can appear in pickup spots, weighted.
func random_pickup_id(exclude := "") -> String:
	if Game.arsenal_weapon() != "":
		return Game.arsenal_weapon()
	var total := 0
	for id in _db:
		if id != exclude:
			total += int(_db[id]["weight"])
	var roll := randi() % maxi(total, 1)
	for id in _db:
		if id == exclude:
			continue
		roll -= int(_db[id]["weight"])
		if roll < 0:
			return id
	return "rifle"

func pickup_ids() -> Array:
	var out := []
	for id in _db:
		if int(_db[id]["weight"]) > 0:
			out.append(id)
	return out
