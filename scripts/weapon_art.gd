class_name WeaponArt
## Vector art for every weapon, drawn pointing +X with the grip near the origin.
## Shared by the held gun and the pickups so both always match.

const DARK   := Color(0.10, 0.10, 0.11)
const METAL  := Color(0.20, 0.21, 0.23)
const STEEL  := Color(0.32, 0.34, 0.37)
const WOOD   := Color(0.36, 0.22, 0.10)
const OLIVE  := Color(0.24, 0.30, 0.18)

static func draw_weapon(ci: CanvasItem, id: String) -> void:
	match id:
		"pistol":           _pistol(ci)
		"smg":              _smg(ci)
		"rifle":            _rifle(ci)
		"shotgun":          _shotgun(ci)
		"sniper":           _sniper(ci)
		"minigun":          _minigun(ci)
		"rocket":           _rocket(ci)
		"grenade_launcher": _launcher(ci)
		"railgun":          _railgun(ci)
		_:                  _rifle(ci)

## Colour used for pickups/HUD accents of each weapon.
static func accent(id: String) -> Color:
	match id:
		"pistol":           return Color(0.85, 0.85, 0.85)
		"smg":              return Color(1.0, 0.85, 0.3)
		"rifle":            return Color(0.9, 0.9, 0.6)
		"shotgun":          return Color(1.0, 0.55, 0.15)
		"sniper":           return Color(0.4, 0.8, 1.0)
		"minigun":          return Color(1.0, 0.35, 0.2)
		"rocket":           return Color(1.0, 0.3, 0.3)
		"grenade_launcher": return Color(0.5, 1.0, 0.35)
		"railgun":          return Color(0.8, 0.45, 1.0)
	return Color.WHITE

static func _pistol(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(6, -4, 18, 6), METAL)
	ci.draw_rect(Rect2(6, -5, 18, 2), STEEL)
	ci.draw_rect(Rect2(7, 1, 6, 9), DARK)
	ci.draw_rect(Rect2(13, 2, 3, 3), DARK)
	ci.draw_rect(Rect2(22, -4, 3, 1), STEEL)

static func _smg(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-8, -2, 10, 4), DARK)
	ci.draw_rect(Rect2(0, -5, 24, 8), METAL)
	ci.draw_rect(Rect2(0, -6, 24, 2), STEEL)
	ci.draw_rect(Rect2(4, 3, 5, 8), DARK)
	ci.draw_rect(Rect2(12, 3, 4, 12), DARK)
	ci.draw_rect(Rect2(24, -3, 8, 4), DARK)

static func _rifle(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-16, -3, 14, 7), WOOD)
	ci.draw_rect(Rect2(-3, -4, 22, 8), METAL)
	ci.draw_rect(Rect2(-3, -7, 26, 4), STEEL)
	ci.draw_rect(Rect2(1, 4, 5, 8), DARK)
	ci.draw_polygon(PackedVector2Array([Vector2(9, 4), Vector2(14, 4), Vector2(17, 13), Vector2(12, 13)]), PackedColorArray([DARK]))
	ci.draw_rect(Rect2(19, -3, 10, 6), WOOD.darkened(0.2))
	ci.draw_rect(Rect2(29, -2, 12, 3), DARK)
	ci.draw_rect(Rect2(4, -10, 3, 3), DARK)
	ci.draw_rect(Rect2(18, -10, 3, 3), DARK)

static func _shotgun(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-16, -3, 16, 8), WOOD)
	ci.draw_rect(Rect2(-1, -5, 16, 9), METAL)
	ci.draw_rect(Rect2(1, 4, 5, 8), DARK)
	ci.draw_rect(Rect2(15, -4, 24, 4), DARK)
	ci.draw_rect(Rect2(15, 0, 18, 4), STEEL.darkened(0.2))
	ci.draw_rect(Rect2(18, -1, 10, 6), WOOD.lightened(0.1))

static func _sniper(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-18, -3, 16, 7), OLIVE)
	ci.draw_rect(Rect2(-18, 3, 6, 4), OLIVE.darkened(0.3))
	ci.draw_rect(Rect2(-3, -4, 20, 8), OLIVE.darkened(0.2))
	ci.draw_rect(Rect2(1, 4, 5, 8), DARK)
	ci.draw_rect(Rect2(2, -11, 16, 5), DARK)
	ci.draw_circle(Vector2(18, -8.5), 3.0, Color(0.3, 0.6, 0.9))
	ci.draw_rect(Rect2(17, -2, 30, 3), DARK)
	ci.draw_rect(Rect2(44, -3, 4, 5), METAL)
	ci.draw_line(Vector2(24, 1), Vector2(22, 9), DARK, 1.5)
	ci.draw_line(Vector2(28, 1), Vector2(30, 9), DARK, 1.5)

static func _minigun(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-6, -8, 20, 16), METAL)
	ci.draw_rect(Rect2(-4, 8, 8, 6), DARK)
	ci.draw_rect(Rect2(14, -6, 30, 3), DARK)
	ci.draw_rect(Rect2(14, -1, 30, 3), STEEL)
	ci.draw_rect(Rect2(14, 4, 30, 3), DARK)
	ci.draw_rect(Rect2(20, -8, 4, 16), METAL)
	ci.draw_rect(Rect2(38, -8, 4, 16), METAL)
	ci.draw_rect(Rect2(0, -12, 10, 4), Color(0.6, 0.15, 0.1))

static func _rocket(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-18, -6, 60, 11), OLIVE)
	ci.draw_rect(Rect2(-18, -6, 60, 3), OLIVE.lightened(0.15))
	ci.draw_rect(Rect2(-22, -7, 5, 13), DARK)
	ci.draw_rect(Rect2(40, -7, 4, 13), DARK)
	ci.draw_rect(Rect2(2, 5, 5, 8), DARK)
	ci.draw_rect(Rect2(14, 5, 4, 6), DARK)
	ci.draw_rect(Rect2(6, -12, 8, 6), METAL)
	ci.draw_rect(Rect2(-10, -3, 4, 5), Color(0.8, 0.2, 0.15))

static func _launcher(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-16, -3, 14, 7), OLIVE.darkened(0.1))
	ci.draw_rect(Rect2(-2, -5, 16, 10), METAL)
	ci.draw_circle(Vector2(8, 0), 8.0, DARK)
	ci.draw_circle(Vector2(8, 0), 5.5, METAL)
	for i in 6:
		ci.draw_circle(Vector2(8, 0) + Vector2.from_angle(i * TAU / 6.0) * 4.0, 1.2, DARK)
	ci.draw_rect(Rect2(14, -5, 20, 10), OLIVE)
	ci.draw_rect(Rect2(30, -6, 4, 12), DARK)
	ci.draw_rect(Rect2(0, 5, 5, 8), DARK)

static func _railgun(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-14, -3, 14, 7), Color(0.18, 0.16, 0.24))
	ci.draw_rect(Rect2(0, -6, 18, 12), Color(0.22, 0.2, 0.3))
	ci.draw_rect(Rect2(1, 6, 5, 7), DARK)
	ci.draw_rect(Rect2(18, -5, 24, 3), METAL)
	ci.draw_rect(Rect2(18, 2, 24, 3), METAL)
	ci.draw_rect(Rect2(18, -2, 24, 4), Color(0.7, 0.35, 1.0, 0.9))
	for i in 3:
		ci.draw_rect(Rect2(22 + i * 7, -6, 3, 12), STEEL)
