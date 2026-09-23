class_name Player
extends CharacterBody2D
## A soldier. Movement is momentum based (so explosions and recoil can push
## you around), with coyote time, jump buffering, variable jump height,
## a jetpack, crouching and dropping through catwalks. Input comes from a
## controller object (keyboard, gamepad or bot) through a PlayerInput.

signal died(victim: Player, killer: Node, weapon_id: String, headshot: bool)

const RUN_SPEED       := 270.0
const CROUCH_SPEED    := 110.0
const GROUND_ACCEL    := 2600.0
const GROUND_FRICTION := 2300.0
const AIR_ACCEL       := 1500.0
const AIR_FRICTION    := 240.0
const GRAVITY         := 1500.0
const MAX_FALL        := 950.0
const JUMP_VELOCITY   := -600.0
const JUMP_CUT        := 0.45
const COYOTE_TIME     := 0.1
const JUMP_BUFFER     := 0.12
const JET_ACCEL       := 2750.0
const JET_MAX_UP      := -420.0
const JET_HOLD_DELAY  := 0.18
const FUEL_MAX        := 100.0
const FUEL_DRAIN      := 40.0
const FUEL_REGEN      := 50.0
const MAX_HEALTH      := 100.0
const SPAWN_SHIELD    := 1.6
const MAX_GRENADES    := 4
const START_GRENADES  := 2

const STAND_HEIGHT  := 58.0
const CROUCH_HEIGHT := 40.0

# identity
var player_id := 0
var team := -1                 # -1 = free for all
var pad_device := -1           # for rumble
var display_name := "J1"
var color := Color.WHITE
var is_human := false
var is_mouse_user := false
var controller: RefCounted
var input := PlayerInput.new()

# state
var health := MAX_HEALTH
var fuel := FUEL_MAX
var dead := false
var facing := 1.0
var crouching := false
var jetting := false
var shield := 0.0
var grenades := START_GRENADES
var coyote := 0.0
var jump_buffer := 0.0
var air_time := 0.0
var jump_hold_time := 0.0
var jet_armed := false
var ground_jump := false
var drop_timer := 0.0
var was_on_floor := true
var fall_speed := 0.0
var hurt_flash := 0.0
var recent_damage := 0.0
var hit_marker := 0.0
var hit_marker_kill := false
var last_hit_by: Node = null
var jet_sound_cd := 0.0
var respawn_left := 0.0
var hurt_dir := Vector2.ZERO    # toward the last attacker, for the HUD indicator
var hurt_dir_time := 0.0
var killed_by := ""

# weapons
var primary := {}                                        # {id, mag, reserve}
var sidearm := {"id": "pistol", "mag": 12, "reserve": -1}
var slot := 0                                            # 0 primary, 1 sidearm
var fire_cd := 0.0
var reload_left := 0.0
var swap_cd := 0.0
var grenade_cd := 0.0
var kick := 0.0

# stats
var kills := 0
var deaths := 0
var streak := 0
var best_streak := 0
var shots := 0
var hits := 0
var multi_kills := 0
var multi_timer := 0.0

@onready var body: Node2D = $Body
@onready var gun_pivot: Node2D = $GunPivot
@onready var gun_sprite: Node2D = $GunPivot/GunSprite
@onready var gun_arm: Node2D = $GunPivot/GunArm
@onready var shape_node: CollisionShape2D = $CollisionShape2D

var _font: Font

func _ready() -> void:
	add_to_group("players")
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 6.0
	shape_node.shape = shape_node.shape.duplicate()   # crouching resizes it per player
	_font = ThemeDB.fallback_font
	_refresh_gun()

func setup(id: int, name_text: String, col: Color, ctrl: RefCounted, human: bool, mouse: bool) -> void:
	player_id = id
	display_name = name_text
	color = col
	controller = ctrl
	is_human = human
	is_mouse_user = mouse

# --------------------------------------------------------------------------
# Main loop
# --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	hurt_flash = maxf(0.0, hurt_flash - delta)
	recent_damage = maxf(0.0, recent_damage - delta)
	hit_marker = maxf(0.0, hit_marker - delta)
	hurt_dir_time = maxf(0.0, hurt_dir_time - delta)
	multi_timer = maxf(0.0, multi_timer - delta)
	if dead:
		return
	input.clear_edges()
	if controller:
		controller.update(self, delta, input)
	shield = maxf(0.0, shield - delta)

	_update_crouch()
	_move(delta)
	_aim()
	_weapons(delta)
	queue_redraw()

func _update_crouch() -> void:
	var want := input.down and is_on_floor() and not input.jump_pressed
	if want == crouching:
		return
	if not want:
		# Make sure there is headroom before standing up.
		var q := PhysicsShapeQueryParameters2D.new()
		var cap := CapsuleShape2D.new()
		cap.radius = 11.0
		cap.height = STAND_HEIGHT
		q.shape = cap
		q.transform = Transform2D(0, global_position + Vector2(0, -1))
		q.collision_mask = 1
		if not get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty():
			return
	crouching = want
	var cap: CapsuleShape2D = shape_node.shape
	cap.height = CROUCH_HEIGHT if crouching else STAND_HEIGHT
	shape_node.position.y = (STAND_HEIGHT - CROUCH_HEIGHT) * 0.5 if crouching else 0.0

func _move(delta: float) -> void:
	var on_floor := is_on_floor()
	var def := current_def()

	if on_floor:
		coyote = COYOTE_TIME
		air_time = 0.0
		jet_armed = false
		fuel = minf(FUEL_MAX, fuel + FUEL_REGEN * delta)
	else:
		coyote -= delta
		air_time += delta

	drop_timer = maxf(0.0, drop_timer - delta)
	set_collision_mask_value(3, drop_timer <= 0.0)

	if input.jump_pressed:
		jump_buffer = JUMP_BUFFER
		if not on_floor and coyote <= 0.0:
			jet_armed = true
	else:
		jump_buffer -= delta

	# Drop through one-way platforms: down + jump.
	if input.down and input.jump_pressed and on_floor and _on_platform():
		drop_timer = 0.25
		jump_buffer = 0.0
		coyote = 0.0
		position.y += 2
	elif jump_buffer > 0.0 and coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		ground_jump = true
		jump_buffer = 0.0
		coyote = 0.0
		jump_hold_time = 0.0
		SoundManager.play("jump", global_position, -12.0)
		Game.fx.dust(global_position + Vector2(0, 28), 4)

	if input.jump_held and not on_floor:
		jump_hold_time += delta
		if jump_hold_time > JET_HOLD_DELAY:
			jet_armed = true
	elif not input.jump_held:
		jump_hold_time = 0.0
		# Variable jump height: releasing early cuts the ground jump once.
		if ground_jump and velocity.y < -150.0:
			velocity.y *= JUMP_CUT
		ground_jump = false
	if on_floor and velocity.y >= 0.0:
		ground_jump = false

	jetting = jet_armed and input.jump_held and fuel > 0.0 and not on_floor
	if jetting:
		fuel = maxf(0.0, fuel - FUEL_DRAIN * delta)
		velocity.y = maxf(JET_MAX_UP, velocity.y - JET_ACCEL * delta)
		jet_sound_cd -= delta
		if jet_sound_cd <= 0.0:
			jet_sound_cd = 0.11
			SoundManager.play("jet", global_position, -14.0)
		Game.fx.jet_flame(global_position + Vector2(-facing * 10, 12), velocity)

	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	var speed := (CROUCH_SPEED if crouching else RUN_SPEED) * float(def["move_mult"])
	var target := input.move * speed
	var accel: float
	if on_floor:
		accel = GROUND_ACCEL if absf(target) > 0.01 else GROUND_FRICTION
	else:
		accel = AIR_ACCEL if absf(target) > 0.01 else AIR_FRICTION
	# Keep momentum from explosions: only accelerate toward target if slower.
	if absf(velocity.x) > speed and signf(velocity.x) == signf(target) and not on_floor:
		accel = AIR_FRICTION
	velocity.x = move_toward(velocity.x, target, accel * delta)

	fall_speed = velocity.y
	move_and_slide()

	if is_on_floor() and not was_on_floor and fall_speed > 420.0:
		SoundManager.play("land", global_position, -10.0)
		Game.fx.dust(global_position + Vector2(0, 28), 8)
	was_on_floor = is_on_floor()

func _on_platform() -> bool:
	if not Game.arena:
		return false
	var feet := global_position + Vector2(0, STAND_HEIGHT * 0.5)
	var r = Game.arena.support_under(feet, 8.0)
	return Game.arena.is_platform(r)

func _aim() -> void:
	var a := input.aim
	if a.length_squared() < 0.01:
		a = Vector2(facing, 0)
	a = a.normalized()
	if absf(a.x) > 0.05:
		facing = signf(a.x)
	gun_pivot.rotation = a.angle()
	gun_pivot.scale.y = -1.0 if facing < 0 else 1.0
	gun_pivot.position = Vector2(0, -10 + (9 if crouching else 0))
	kick = move_toward(kick, 0.0, 60.0 * get_physics_process_delta_time())
	gun_sprite.position.x = -kick
	gun_arm.position.x = -kick

func aim_origin() -> Vector2:
	return gun_pivot.global_position

# --------------------------------------------------------------------------
# Weapons
# --------------------------------------------------------------------------

func current() -> Dictionary:
	return primary if slot == 0 and not primary.is_empty() else sidearm

func current_def() -> Dictionary:
	return WeaponData.get_def(current()["id"])

func is_reloading() -> bool:
	return reload_left > 0.0

func _weapons(delta: float) -> void:
	fire_cd -= delta
	swap_cd -= delta
	grenade_cd -= delta
	var w := current()
	var def := current_def()

	if input.swap and swap_cd <= 0.0:
		if not _try_swap_pickup():
			_swap()

	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			_finish_reload()

	if input.reload and reload_left <= 0.0:
		_start_reload()

	if input.grenade and grenade_cd <= 0.0 and grenades > 0:
		_throw_grenade()

	if input.shoot and fire_cd <= 0.0 and swap_cd <= 0.0 and reload_left <= 0.0:
		if int(w["mag"]) > 0:
			_fire(w, def)
		elif int(w["reserve"]) != 0:
			_start_reload()
		else:
			SoundManager.play("empty", global_position, -6.0)
			fire_cd = 0.3
			if slot == 0 and not primary.is_empty():
				primary = {}
				_swap_to(1)

func _fire(w: Dictionary, def: Dictionary) -> void:
	# Carry the sub-frame remainder so fire rates don't snap to whole frames.
	fire_cd = float(def["fire_rate"]) + maxf(fire_cd, -get_physics_process_delta_time())
	w["mag"] = int(w["mag"]) - 1
	shield = 0.0
	shots += int(def["pellets"])
	var dir := input.aim.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(facing, 0)
	var pivot := aim_origin()
	var origin := pivot + dir * float(def["muzzle"])
	# Never let the muzzle poke through a wall.
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -10), origin, 1)
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		origin = r["position"] - dir * 2.0
	var spread: float = def["spread"]
	if crouching:
		spread *= 0.55
	if not is_on_floor():
		spread *= 1.3
	for i in int(def["pellets"]):
		var d := dir.rotated(randf_range(-spread, spread))
		if int(def["pellets"]) > 1:
			d = d * randf_range(0.9, 1.1)
		Game.projectiles.fire(self, origin, d.normalized() if def["kind"] != "bullet" else d, def,
			velocity * 0.3 if def["kind"] == "grenade" else Vector2.ZERO)
	# recoil and feedback
	velocity -= dir * float(def["recoil"]) * (0.5 if is_on_floor() else 1.0)
	kick = float(def["kick"])
	Game.fx.muzzle_flash(origin, dir, 1.6 if def["pellets"] > 1 or def["kind"] != "bullet" else 1.0)
	if def["kind"] == "bullet" or def["kind"] == "hitscan":
		Game.fx.shell(pivot + dir * 10.0, facing, def["id"] == "shotgun")
	SoundManager.play(def["sound"], origin, -2.0 if is_human else -5.0)
	if is_human:
		Game.shake(float(def["shake"]), global_position)
		rumble(clampf(float(def["shake"]) * 2.0, 0.1, 0.8), 0.08)
	if int(w["mag"]) <= 0 and int(w["reserve"]) != 0:
		_start_reload()

func _throw_grenade() -> void:
	grenades -= 1
	grenade_cd = 0.6
	shield = 0.0
	var dir := input.aim.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(facing, -0.3).normalized()
	var def := WeaponData.get_def("frag")
	var origin := aim_origin() + dir * 14.0
	var q := PhysicsRayQueryParameters2D.create(global_position, origin, 1)
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		origin = global_position
	Game.projectiles.fire(self, origin, dir, def, velocity * 0.5)
	SoundManager.play("throw", origin, -4.0)

func _start_reload() -> void:
	var w := current()
	var def := current_def()
	if reload_left > 0.0 or int(w["reserve"]) == 0 or int(w["mag"]) >= int(def["mag"]):
		return
	reload_left = float(def["reload"])
	SoundManager.play("reload", global_position, -8.0)

func _finish_reload() -> void:
	reload_left = 0.0
	var w := current()
	var def := current_def()
	var need := int(def["mag"]) - int(w["mag"])
	if int(w["reserve"]) < 0:
		w["mag"] = int(def["mag"])
	else:
		var take := mini(need, int(w["reserve"]))
		w["mag"] = int(w["mag"]) + take
		w["reserve"] = int(w["reserve"]) - take
	SoundManager.play("reload_done", global_position, -8.0)

func _swap() -> void:
	if primary.is_empty():
		return
	_swap_to(1 - slot)

func _swap_to(s: int) -> void:
	slot = s
	reload_left = 0.0
	swap_cd = 0.22
	SoundManager.play("swap", global_position, -10.0)
	_refresh_gun()

func _refresh_gun() -> void:
	if gun_sprite:
		gun_sprite.weapon_id = current()["id"]
		gun_sprite.queue_redraw()
		gun_arm.weapon_id = current()["id"]
		gun_arm.color = color
		gun_arm.queue_redraw()

## A pickup overlapping this player that holds a different weapon (set by
## pickups every physics frame, so it goes stale as soon as we walk away).
var nearby_pickup: Node = null
var nearby_frame := -10
var swap_hint := "Q"

func _try_swap_pickup() -> bool:
	if nearby_pickup == null or not is_instance_valid(nearby_pickup):
		return false
	if Engine.get_physics_frames() - nearby_frame > 1:
		return false
	return nearby_pickup.try_take(self, true)

## Gives a weapon. Returns true if the player took it.
func give_weapon(id: String, mag := -1, reserve := -1, force := false) -> bool:
	var def := WeaponData.get_def(id)
	if mag < 0:
		mag = int(def["mag"])
	if reserve < 0:
		reserve = int(def["reserve"])
	if not primary.is_empty() and primary["id"] == id:
		var cap := int(def["reserve"]) * 2
		if int(primary["reserve"]) >= cap:
			return false
		primary["reserve"] = mini(cap, int(primary["reserve"]) + mag + reserve / 2)
		SoundManager.play("pickup", global_position, -6.0)
		return true
	if not primary.is_empty() and not force:
		return false
	if not primary.is_empty():
		Game.world.drop_weapon(primary, global_position + Vector2(0, -6), velocity * 0.5 + Vector2(-facing * 120, -220))
	primary = {"id": id, "mag": mag, "reserve": reserve}
	reload_left = 0.0
	slot = 0
	swap_cd = 0.15
	_refresh_gun()
	SoundManager.play("pickup", global_position, -4.0)
	return true

func give_health(amount: float) -> bool:
	if health >= MAX_HEALTH:
		return false
	health = minf(MAX_HEALTH, health + amount)
	SoundManager.play("health", global_position, -4.0)
	return true

func give_grenades(n: int) -> bool:
	if grenades >= MAX_GRENADES:
		return false
	grenades = mini(MAX_GRENADES, grenades + n)
	SoundManager.play("pickup", global_position, -6.0)
	return true

# --------------------------------------------------------------------------
# Damage & death
# --------------------------------------------------------------------------

func rumble(strength: float, duration: float) -> void:
	if pad_device >= 0:
		Input.start_joy_vibration(pad_device, strength * 0.6, strength, duration)

func is_head_hit(p: Vector2) -> bool:
	# Top ~16px of the body (helmet and face) counts as the head.
	var head_line := global_position.y - 13.0 + (18.0 if crouching else 0.0)
	return p.y < head_line

func take_damage(amount: float, push: Vector2, attacker: Node, weapon_id: String, headshot: bool, at: Vector2) -> void:
	if dead:
		return
	if attacker is Player and attacker != self and not Game.is_enemy(attacker, self):
		return   # no friendly fire
	if shield > 0.0 and attacker != self:
		Game.fx.impact(at, -push.normalized() if push != Vector2.ZERO else Vector2.UP, Color(0.5, 0.8, 1.0))
		return
	velocity += push
	if push.y < -100.0:
		ground_jump = false   # don't let a jump-cut eat a rocket jump
	health -= amount
	hurt_flash = 0.12
	recent_damage = 2.0
	if attacker != self:
		last_hit_by = attacker
		if attacker is Node2D:
			hurt_dir = (attacker.global_position - global_position).normalized()
			hurt_dir_time = 1.2
	var dir := push.normalized() if push != Vector2.ZERO else Vector2.UP
	Game.fx.blood(at, dir, 6 if amount < 30 else 14)
	if attacker is Player and attacker.is_human and attacker != self:
		var popup_col := Color(1.0, 0.9, 0.3) if not headshot else Color(1.0, 0.35, 0.2)
		Game.fx.popup(at + Vector2(0, -16), str(int(round(amount))) + ("!" if headshot else ""), popup_col, 20 if headshot else 15)
	SoundManager.play("hit", at, -6.0)
	if is_human:
		Game.shake(clampf(amount / 120.0, 0.08, 0.4), global_position)
		rumble(clampf(amount / 100.0, 0.2, 1.0), 0.18)
		if Game.hud:
			Game.hud.damage_flash(self)
	var shooter := attacker as Player
	if shooter and shooter != self:
		shooter.hits += 1
		shooter.hit_marker = 0.18
		shooter.hit_marker_kill = false
		if shooter.is_human:
			SoundManager.play("headshot" if headshot else "hitmark", Vector2.INF, -6.0 if headshot else -10.0)
	if health <= 0.0:
		var killer := attacker
		if (killer == self or killer == null) and is_instance_valid(last_hit_by):
			killer = last_hit_by   # finished off by own grenade while fighting → credit the enemy
		if shooter and shooter != self:
			shooter.hit_marker_kill = true
		die(killer, weapon_id, headshot, push)

func die(killer: Node, weapon_id: String, headshot: bool, push := Vector2.ZERO) -> void:
	if dead:
		return
	dead = true
	health = 0.0
	jetting = false
	body.visible = false
	gun_pivot.visible = false
	shape_node.set_deferred("disabled", true)
	Game.fx.gibs(global_position, color, velocity + push)
	SoundManager.play("death", global_position, 0.0)
	if not primary.is_empty() and (int(primary["mag"]) > 0 or int(primary["reserve"]) > 0):
		Game.world.drop_weapon(primary, global_position, velocity * 0.4 + Vector2(randf_range(-80, 80), -260))
	primary = {}
	velocity = Vector2.ZERO
	queue_redraw()
	died.emit(self, killer, weapon_id, headshot)

func respawn(at: Vector2) -> void:
	global_position = at
	reset_physics_interpolation()   # teleport, don't smear across the map
	velocity = Vector2.ZERO
	health = MAX_HEALTH
	fuel = FUEL_MAX
	dead = false
	crouching = false
	var cap: CapsuleShape2D = shape_node.shape
	cap.height = STAND_HEIGHT
	shape_node.position.y = 0
	shape_node.set_deferred("disabled", false)
	primary = {}
	sidearm = {"id": "pistol", "mag": int(WeaponData.get_def("pistol")["mag"]), "reserve": -1}
	slot = 1
	grenades = START_GRENADES
	reload_left = 0.0
	fire_cd = 0.3
	var forced := Game.arsenal_weapon()
	if forced != "":
		var d := WeaponData.get_def(forced)
		primary = {"id": forced, "mag": int(d["mag"]), "reserve": int(d["reserve"]) * 3}
		slot = 0
		if Game.instagib():
			grenades = 0
	shield = SPAWN_SHIELD
	last_hit_by = null
	streak = 0
	body.visible = true
	gun_pivot.visible = true
	_refresh_gun()
	Game.fx.spawn_burst(global_position, color)
	SoundManager.play("spawn", global_position, -8.0)

# --------------------------------------------------------------------------
# Overhead info (name, health, reload)
# --------------------------------------------------------------------------

func _draw() -> void:
	if dead:
		return
	var top := -44.0
	# name tag
	var name_w := _font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var name_pos := Vector2(-name_w * 0.5, top - 8)
	draw_string_outline(_font, name_pos, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.7))
	draw_string(_font, name_pos, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color.lightened(0.2))
	# health bar
	if health < MAX_HEALTH or recent_damage > 0.0:
		var w := 36.0
		draw_rect(Rect2(-w * 0.5 - 1, top - 3, w + 2, 6), Color(0, 0, 0, 0.7))
		var frac := health / MAX_HEALTH
		var hc := Color(0.3, 0.9, 0.3).lerp(Color(1.0, 0.2, 0.1), 1.0 - frac)
		draw_rect(Rect2(-w * 0.5, top - 2, w * frac, 4), hc)
	# reload progress
	if reload_left > 0.0:
		var total: float = current_def()["reload"]
		var p := 1.0 - reload_left / maxf(total, 0.01)
		draw_arc(Vector2(0, top - 22), 7.0, -PI * 0.5, -PI * 0.5 + TAU * p, 20, Color(1, 1, 1, 0.9), 2.5)
	# spawn shield bubble
	if shield > 0.0:
		var a := 0.25 + 0.15 * sin(Time.get_ticks_msec() * 0.02)
		draw_circle(Vector2(0, -2), 36.0, Color(0.5, 0.8, 1.0, a * 0.35))
		draw_arc(Vector2(0, -2), 36.0, 0, TAU, 32, Color(0.6, 0.9, 1.0, a + 0.2), 2.0)
	# laser sight on precision weapons
	var def := current_def()
	if def["kind"] == "hitscan":
		var dir := input.aim.normalized()
		var from := gun_pivot.position + dir * float(def["muzzle"])
		var q := PhysicsRayQueryParameters2D.create(to_global(from), to_global(from + dir * 900.0), 1)
		var r := get_world_2d().direct_space_state.intersect_ray(q)
		var end := from + dir * 900.0
		if not r.is_empty():
			end = to_local(r["position"])
		var lc: Color = def["tracer"]
		lc.a = 0.35
		draw_line(from, end, lc, 1.0)
		draw_circle(end, 2.0, Color(lc.r, lc.g, lc.b, 0.8))
