extends RefCounted
## Twin-stick gamepad: left stick moves, right stick aims (with light aim
## assist), RT shoots, LT grenade, LB ninja rope, A jump/jetpack, X reload, Y swap.

var device := 0
var _last_aim := Vector2.ZERO
var _prev := {}

func _init(dev := 0) -> void:
	device = dev

func _edge(key: String, now: bool) -> bool:
	var was: bool = _prev.get(key, false)
	_prev[key] = now
	return now and not was

func update(p: Player, _dt: float, i: PlayerInput) -> void:
	var lx := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	var ly := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	var move := lx if absf(lx) > 0.25 else 0.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
		move = -1.0
	elif Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
		move = 1.0
	i.move = clampf(move * 1.15, -1.0, 1.0)
	var jump := Input.is_joy_button_pressed(device, JOY_BUTTON_A)
	i.jump_pressed = _edge("jump", jump)
	i.jump_held = jump
	i.down = ly > 0.6 or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN)
	i.shoot = Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.35 \
		or Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER)
	var nade := Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > 0.35
	i.rope = Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER)
	i.grenade = _edge("nade", nade)
	i.reload = _edge("reload", Input.is_joy_button_pressed(device, JOY_BUTTON_X))
	i.swap = _edge("swap", Input.is_joy_button_pressed(device, JOY_BUTTON_Y))

	var stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.35:
		_last_aim = stick.normalized()
	elif absf(i.move) > 0.1 and (_last_aim == Vector2.ZERO or signf(_last_aim.x) != signf(i.move)):
		_last_aim = Vector2(signf(i.move), 0)
	var aim := _last_aim if _last_aim != Vector2.ZERO else Vector2(p.facing, 0)
	# Aim assist: bend toward an enemy close to the stick direction.
	var target := AimAssist.best_target(p, 950.0, aim, 0.2)
	if target:
		var to := (target.global_position + Vector2(0, -6) - p.aim_origin()).normalized()
		aim = aim.slerp(to, 0.6)
	i.aim = aim
