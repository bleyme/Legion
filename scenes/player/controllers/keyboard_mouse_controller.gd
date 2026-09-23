extends RefCounted
## Player 1: move with WASD/ZQSD, aim with the mouse.

const P := "p1_"

func update(p: Player, _dt: float, i: PlayerInput) -> void:
	i.move = Input.get_axis(P + "left", P + "right")
	i.jump_pressed = Input.is_action_just_pressed(P + "jump")
	i.jump_held = Input.is_action_pressed(P + "jump")
	i.down = Input.is_action_pressed(P + "down")
	i.shoot = Input.is_action_pressed(P + "shoot")
	i.grenade = Input.is_action_just_pressed(P + "grenade")
	i.reload = Input.is_action_just_pressed(P + "reload")
	i.swap = Input.is_action_just_pressed(P + "swap") or Game.wheel_swap
	Game.wheel_swap = false
	var to_mouse := p.get_global_mouse_position() - p.aim_origin()
	if to_mouse.length() > 4.0:
		i.aim = to_mouse.normalized()
