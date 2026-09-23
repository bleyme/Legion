extends RefCounted
## Player 2 on the same keyboard: arrows to move, automatic aim at the closest
## visible enemy (otherwise straight ahead).

const P := "p2_"

var facing := 1.0

func update(p: Player, _dt: float, i: PlayerInput) -> void:
	i.move = Input.get_axis(P + "left", P + "right")
	i.jump_pressed = Input.is_action_just_pressed(P + "jump")
	i.jump_held = Input.is_action_pressed(P + "jump")
	i.down = Input.is_action_pressed(P + "down")
	i.shoot = Input.is_action_pressed(P + "shoot")
	i.grenade = Input.is_action_just_pressed(P + "grenade")
	i.reload = Input.is_action_just_pressed(P + "reload")
	i.swap = Input.is_action_just_pressed(P + "swap")
	if absf(i.move) > 0.1:
		facing = signf(i.move)
	var target := AimAssist.best_target(p, 1000.0)
	if target:
		var chest := target.global_position + Vector2(0, -6)
		i.aim = (chest - p.aim_origin()).normalized()
	else:
		var tilt := -0.25 if i.jump_held else 0.0
		i.aim = Vector2(facing, tilt).normalized()
