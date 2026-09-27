## Arena layouts. Coordinates are in pixels, interior starts at (0, 0).
## solids    - full collision blocks (Rect2)
## platforms - one-way catwalks you can jump through / drop through (Rect2)
## spawns    - feet positions
## pickups   - {pos, kind: weapon|health|frag, fixed?: weapon id}
## lights    - decorative glow positions

static func all() -> Array:
	return [outpost(), foundry(), duel()]

static func outpost() -> Dictionary:
	return {
		"name": "Avant-poste",
		"desc": "Grande arène symétrique, bunkers et passerelles.",
		"size": Vector2(2400, 1400),
		"theme": {
			"sky_top": Color(0.03, 0.04, 0.10), "sky_bottom": Color(0.14, 0.12, 0.24),
			"block": Color(0.16, 0.18, 0.23), "edge": Color(0.36, 0.42, 0.50),
			"platform": Color(0.30, 0.33, 0.38), "accent": Color(0.95, 0.65, 0.20),
			"skyline": Color(0.07, 0.08, 0.15), "skyline_near": Color(0.10, 0.10, 0.19),
			"window": Color(1.0, 0.78, 0.35), "moon": true,
		},
		"solids": [
			Rect2(0, 1300, 2400, 100),
			Rect2(1020, 1236, 360, 64),
			Rect2(240, 1150, 280, 30), Rect2(270, 1256, 40, 44), Rect2(490, 1256, 40, 44),
			Rect2(1880, 1150, 280, 30), Rect2(1870, 1256, 40, 44), Rect2(2090, 1256, 40, 44),
			Rect2(1080, 900, 240, 28),
			Rect2(0, 860, 300, 28), Rect2(2100, 860, 300, 28),
			Rect2(0, 420, 260, 28), Rect2(2140, 420, 260, 28),
			Rect2(700, 380, 120, 24), Rect2(1580, 380, 120, 24),
			Rect2(1186, 928, 28, 120),
		],
		"platforms": [
			Rect2(600, 1060, 300, 16), Rect2(1500, 1060, 300, 16),
			Rect2(430, 700, 280, 16), Rect2(1690, 700, 280, 16),
			Rect2(1020, 540, 360, 16),
			Rect2(300, 1000, 120, 16), Rect2(1980, 1000, 120, 16),
		],
		"spawns": [
			Vector2(120, 1300), Vector2(2280, 1300), Vector2(380, 1300), Vector2(2020, 1300),
			Vector2(150, 860), Vector2(2250, 860), Vector2(1140, 900), Vector2(1260, 900),
			Vector2(570, 700), Vector2(1830, 700), Vector2(130, 420), Vector2(2270, 420),
			Vector2(1200, 540), Vector2(760, 1060), Vector2(1640, 1060),
		],
		"pickups": [
			{"pos": Vector2(1200, 1210), "kind": "weapon"},
			{"pos": Vector2(750, 1034), "kind": "weapon"},
			{"pos": Vector2(1650, 1034), "kind": "weapon"},
			{"pos": Vector2(1130, 874), "kind": "weapon"},
			{"pos": Vector2(570, 674), "kind": "weapon"},
			{"pos": Vector2(1830, 674), "kind": "weapon"},
			{"pos": Vector2(1200, 514), "kind": "weapon", "fixed": "rocket"},
			{"pos": Vector2(760, 354), "kind": "weapon", "fixed": "sniper"},
			{"pos": Vector2(1640, 354), "kind": "weapon", "fixed": "railgun"},
			{"pos": Vector2(380, 1274), "kind": "health"},
			{"pos": Vector2(2020, 1274), "kind": "health"},
			{"pos": Vector2(130, 394), "kind": "health"},
			{"pos": Vector2(2270, 394), "kind": "health"},
			{"pos": Vector2(1270, 874), "kind": "health"},
			{"pos": Vector2(150, 834), "kind": "frag"},
			{"pos": Vector2(2250, 834), "kind": "frag"},
		],
		"lights": [
			Vector2(380, 1170), Vector2(2020, 1170), Vector2(1200, 920), Vector2(1200, 560),
			Vector2(150, 880), Vector2(2250, 880),
		],
	}

static func foundry() -> Dictionary:
	return {
		"name": "Fonderie",
		"desc": "Usine verticale sur quatre niveaux. Combats serrés.",
		"size": Vector2(2000, 1600),
		"theme": {
			"sky_top": Color(0.10, 0.03, 0.02), "sky_bottom": Color(0.32, 0.10, 0.04),
			"block": Color(0.20, 0.15, 0.13), "edge": Color(0.62, 0.40, 0.22),
			"platform": Color(0.36, 0.28, 0.22), "accent": Color(1.0, 0.45, 0.10),
			"skyline": Color(0.14, 0.05, 0.03), "skyline_near": Color(0.19, 0.07, 0.04),
			"window": Color(1.0, 0.5, 0.15), "moon": false,
		},
		"solids": [
			Rect2(0, 1500, 2000, 100),
			Rect2(900, 1400, 200, 100),
			Rect2(500, 1420, 40, 80), Rect2(1460, 1420, 40, 80),
			Rect2(140, 1180, 620, 32), Rect2(1240, 1180, 620, 32),
			Rect2(400, 1110, 30, 70), Rect2(1570, 1110, 30, 70),
			Rect2(200, 860, 500, 32), Rect2(1300, 860, 500, 32),
			Rect2(0, 540, 420, 32), Rect2(1580, 540, 420, 32), Rect2(820, 540, 360, 32),
			Rect2(985, 572, 30, 110),
		],
		"platforms": [
			Rect2(760, 1180, 480, 16),
			Rect2(880, 900, 240, 16),
			Rect2(300, 260, 400, 16), Rect2(1300, 260, 400, 16),
			Rect2(0, 1360, 140, 16), Rect2(1860, 1360, 140, 16),
			Rect2(0, 720, 150, 16), Rect2(1850, 720, 150, 16),
		],
		"spawns": [
			Vector2(100, 1500), Vector2(1900, 1500), Vector2(700, 1500), Vector2(1300, 1500),
			Vector2(300, 1180), Vector2(1700, 1180), Vector2(300, 860), Vector2(1700, 860),
			Vector2(100, 540), Vector2(1900, 540), Vector2(900, 540), Vector2(1100, 540),
			Vector2(500, 260), Vector2(1500, 260),
		],
		"pickups": [
			{"pos": Vector2(1000, 1374), "kind": "weapon", "fixed": "minigun"},
			{"pos": Vector2(1000, 1154), "kind": "weapon"},
			{"pos": Vector2(450, 834), "kind": "weapon"},
			{"pos": Vector2(1550, 834), "kind": "weapon"},
			{"pos": Vector2(1000, 514), "kind": "weapon", "fixed": "rocket"},
			{"pos": Vector2(500, 234), "kind": "weapon"},
			{"pos": Vector2(1500, 234), "kind": "weapon"},
			{"pos": Vector2(250, 1474), "kind": "weapon"},
			{"pos": Vector2(1750, 1474), "kind": "weapon"},
			{"pos": Vector2(100, 1474), "kind": "health"},
			{"pos": Vector2(1900, 1474), "kind": "health"},
			{"pos": Vector2(1000, 874), "kind": "health"},
			{"pos": Vector2(60, 514), "kind": "health"},
			{"pos": Vector2(1940, 514), "kind": "health"},
			{"pos": Vector2(250, 514), "kind": "frag"},
			{"pos": Vector2(1750, 514), "kind": "frag"},
		],
		"lights": [
			Vector2(1000, 1420), Vector2(380, 1200), Vector2(1620, 1200), Vector2(1000, 560),
			Vector2(450, 880), Vector2(1550, 880),
		],
	}

static func duel() -> Dictionary:
	return {
		"name": "Duel",
		"desc": "Petite arène pour les 1 contre 1 nerveux.",
		"size": Vector2(1600, 900),
		"theme": {
			"sky_top": Color(0.02, 0.07, 0.10), "sky_bottom": Color(0.06, 0.20, 0.24),
			"block": Color(0.13, 0.19, 0.21), "edge": Color(0.30, 0.62, 0.62),
			"platform": Color(0.24, 0.34, 0.36), "accent": Color(0.30, 0.95, 0.85),
			"skyline": Color(0.04, 0.10, 0.13), "skyline_near": Color(0.06, 0.14, 0.17),
			"window": Color(0.45, 1.0, 0.9), "moon": true,
		},
		"solids": [
			Rect2(0, 820, 1600, 80),
			Rect2(760, 760, 80, 60),
			Rect2(0, 420, 180, 24), Rect2(1420, 420, 180, 24),
		],
		"platforms": [
			Rect2(180, 640, 300, 16), Rect2(1120, 640, 300, 16),
			Rect2(650, 500, 300, 16),
			Rect2(560, 260, 480, 16),
		],
		"spawns": [
			Vector2(150, 820), Vector2(1450, 820), Vector2(330, 640), Vector2(1270, 640),
			Vector2(90, 420), Vector2(1510, 420), Vector2(800, 500),
		],
		"pickups": [
			{"pos": Vector2(800, 474), "kind": "weapon"},
			{"pos": Vector2(330, 614), "kind": "weapon"},
			{"pos": Vector2(1270, 614), "kind": "weapon"},
			{"pos": Vector2(800, 234), "kind": "weapon", "fixed": "sniper"},
			{"pos": Vector2(90, 394), "kind": "health"},
			{"pos": Vector2(1510, 394), "kind": "health"},
			{"pos": Vector2(800, 734), "kind": "frag"},
		],
		"lights": [Vector2(800, 520), Vector2(330, 660), Vector2(1270, 660)],
	}
