extends RefCounted
## Player 2 on the same keyboard: arrows to move, automatic aim at the closest
## visible enemy (otherwise straight ahead).

const P := "p2_"

var facing := 1.0
var _rope_was := false
var _wobble := 0.0
var _t := 0.0

func update(p: Player, dt: float, i: PlayerInput) -> void:
	_t += dt
	i.move = Input.get_axis(P + "left", P + "right")
	i.jump_pressed = Input.is_action_just_pressed(P + "jump")
	i.jump_held = Input.is_action_pressed(P + "jump")
	i.down = Input.is_action_pressed(P + "down")
	i.shoot = Input.is_action_pressed(P + "shoot")
	i.grenade = Input.is_action_just_pressed(P + "grenade")
	i.reload = Input.is_action_just_pressed(P + "reload")
	i.rope = Input.is_action_pressed(P + "rope")
	i.swap = Input.is_action_just_pressed(P + "swap")
	if absf(i.move) > 0.1:
		facing = signf(i.move)
	var target := AimAssist.best_target(p, 1000.0)
	if target:
		# Assisted but not perfect: a slow wobble keeps it from being an aimbot.
		var chest := target.global_position + Vector2(0, -4)
		_wobble = sin(_t * 2.3) * 0.035 + sin(_t * 5.1) * 0.02
		i.aim = (chest - p.aim_origin()).normalized().rotated(_wobble)
	else:
		var tilt := -0.25 if i.jump_held else 0.0
		i.aim = Vector2(facing, tilt).normalized()
	# The rope is thrown up and forward, whatever the auto-aim is locked on.
	if i.rope and not _rope_was:
		i.aim = Vector2(facing * 0.55, -1.0).normalized()
	_rope_was = i.rope
