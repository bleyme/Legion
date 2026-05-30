extends Area2D

const RESPAWN_TIME := 8.0

@export var weapon_type: int = 0

var active      := true
var respawn_timer := 0.0

var WEAPON_COLORS := [
	Color(0.8, 0.8, 0.8),
	Color(1.0, 0.5, 0.1),
	Color(0.3, 0.8, 1.0),
	Color(0.4, 1.0, 0.3),
]
var WEAPON_NAMES := ["RIFLE", "SHOTGUN", "SNIPER", "GRENADE"]

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if not active:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			active = true
			queue_redraw()

func _draw() -> void:
	if not active:
		return
	var col: Color = WEAPON_COLORS[weapon_type]
	var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.004)
	draw_circle(Vector2.ZERO, 14, Color(col.r, col.g, col.b, 0.25 * pulse))
	draw_arc(Vector2.ZERO, 14, 0, TAU, 32, Color(col.r, col.g, col.b, 0.8 * pulse), 2.0)
	draw_rect(Rect2(-10, -3, 20, 6), Color(col.r, col.g, col.b, 0.9), true)
	draw_rect(Rect2(-5, 3, 4, 6), Color(col.r * 0.7, col.g * 0.7, col.b * 0.7, 0.9), true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_INTERNAL_PROCESS:
		queue_redraw()

func _on_body_entered(body: Node) -> void:
	if not active:
		return
	if body.has_method("equip_weapon"):
		body.equip_weapon(WeaponData.from_type(weapon_type))
		active        = false
		respawn_timer = RESPAWN_TIME
		queue_redraw()
