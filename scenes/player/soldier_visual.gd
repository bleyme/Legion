extends Node2D
## Procedural soldier: team-coloured armour, jetpack, walk cycle, crouch,
## airborne tuck and hit flash. Origin is the body centre, feet at y = 29.

const C_SKIN   := Color(0.78, 0.58, 0.42)
const C_BOOT   := Color(0.09, 0.07, 0.05)
const C_PACK   := Color(0.22, 0.23, 0.26)
const C_VISOR  := Color(0.10, 0.14, 0.20)
const C_STRAP  := Color(0.12, 0.10, 0.08)

var walk_time := 0.0
var bob := 0.0

@onready var player: Player = get_parent()

func _process(delta: float) -> void:
	if player == null or player.dead:
		return
	var vx := player.velocity.x
	if player.is_on_floor() and absf(vx) > 10.0:
		walk_time += delta * absf(vx) * 0.045
	else:
		walk_time = lerpf(walk_time, roundf(walk_time / PI) * PI, delta * 8.0)
	scale.x = player.facing
	if player.hurt_flash > 0.0:
		modulate = Color(3.0, 3.0, 3.0)
	elif player.shield > 0.0:
		modulate = Color(0.75, 0.9, 1.3, 0.85)
	else:
		modulate = Color.WHITE
	queue_redraw()

func _draw() -> void:
	if player == null:
		return
	var team := player.color
	var armour := team.darkened(0.35).lerp(Color(0.25, 0.3, 0.2), 0.35)
	var cloth := armour.darkened(0.35)
	var crouch := player.crouching
	var airborne := not player.is_on_floor()
	var drop := 9.0 if crouch else 0.0
	var run_phase := sin(walk_time)
	bob = absf(run_phase) * -1.5 if not airborne and not crouch else 0.0

	# ---- legs --------------------------------------------------------------
	var hip := Vector2(0, 8 + drop + bob)
	if crouch:
		_leg_bent(hip + Vector2(-3, 0), cloth.darkened(0.15), -1)
		_leg_bent(hip + Vector2(3, 0), cloth, 1)
	elif airborne:
		var tuck := clampf(-player.velocity.y / 600.0, -0.4, 0.8)
		_leg(hip + Vector2(-3, 0), 0.35 + tuck * 0.3, cloth.darkened(0.15), 0.9)
		_leg(hip + Vector2(3, 0), -0.25 + tuck * 0.5, cloth, 0.85)
	else:
		_leg(hip + Vector2(-2, 0), -run_phase * 0.55, cloth.darkened(0.15), 1.0)
		_leg(hip + Vector2(2, 0), run_phase * 0.55, cloth, 1.0)

	var o := Vector2(0, drop + bob)
	# ---- jetpack -------------------------------------------------------------
	draw_rect(Rect2(o + Vector2(-16, -12), Vector2(7, 19)), C_PACK)
	draw_rect(Rect2(o + Vector2(-16, -12), Vector2(7, 3)), C_PACK.lightened(0.2))
	draw_rect(Rect2(o + Vector2(-15, 7), Vector2(5, 4)), Color(0.12, 0.12, 0.13))
	var fuel_frac := player.fuel / Player.FUEL_MAX
	draw_rect(Rect2(o + Vector2(-14, -8 + 12 * (1.0 - fuel_frac)), Vector2(3, 12 * fuel_frac)), Color(0.3, 0.7, 1.0, 0.9))

	# ---- torso ----------------------------------------------------------------
	draw_rect(Rect2(o + Vector2(-9, -13), Vector2(18, 22)), armour)
	draw_rect(Rect2(o + Vector2(-8, -11), Vector2(16, 12)), armour.lightened(0.12))
	draw_rect(Rect2(o + Vector2(-9, 5), Vector2(18, 4)), C_STRAP)
	draw_rect(Rect2(o + Vector2(2, 5), Vector2(4, 4)), Color(0.55, 0.45, 0.2))
	draw_line(o + Vector2(-7, -12), o + Vector2(5, 4), C_STRAP, 2.0)
	draw_rect(Rect2(o + Vector2(3, -9), Vector2(4, 6)), team.lightened(0.1))   # shoulder badge

	# ---- head -------------------------------------------------------------------
	var head := o + Vector2(1, -21)
	draw_rect(Rect2(head + Vector2(-3, 5), Vector2(6, 4)), C_SKIN.darkened(0.15))   # neck
	draw_circle(head, 7.5, C_SKIN)
	# helmet
	draw_circle(head + Vector2(-1, -3), 8.5, team.darkened(0.15))
	draw_rect(Rect2(head + Vector2(-10, -4), Vector2(19, 4)), team.darkened(0.35))
	draw_rect(Rect2(head + Vector2(-8, -10), Vector2(8, 3)), team.lightened(0.15))
	# visor
	draw_rect(Rect2(head + Vector2(1, -1), Vector2(7, 4)), C_VISOR)
	draw_rect(Rect2(head + Vector2(5, -1), Vector2(2, 2)), Color(0.6, 0.85, 1.0, 0.9))
	# chin
	draw_rect(Rect2(head + Vector2(2, 4), Vector2(4, 2)), C_SKIN.darkened(0.1))

func _leg(hip: Vector2, angle: float, col: Color, length_scale: float) -> void:
	draw_set_transform(hip, angle)
	draw_rect(Rect2(-3, 0, 7, 16 * length_scale), col)
	draw_rect(Rect2(-3, 16 * length_scale, 9, 5), C_BOOT)
	draw_set_transform(Vector2.ZERO, 0.0)

func _leg_bent(hip: Vector2, col: Color, side: int) -> void:
	# thigh forward, shin down
	var knee := hip + Vector2(8 if side > 0 else 5, 2)
	draw_line(hip, knee, col, 7.0)
	draw_rect(Rect2(knee + Vector2(-3, 0), Vector2(7, 6)), col)
	draw_rect(Rect2(knee + Vector2(-3, 6), Vector2(9, 4)), C_BOOT)
