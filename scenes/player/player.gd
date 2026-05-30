extends CharacterBody2D

signal died(player_node)

const SPEED            = 200.0
const JUMP_VELOCITY    = -400.0
const JETPACK_FORCE    = -600.0
const JETPACK_FUEL_MAX = 100.0
const JETPACK_FUEL_DRAIN = 30.0
const JETPACK_FUEL_REGEN = 15.0
const FIRE_RATE        = 0.1
const MAX_HEALTH       = 100.0
const MAG_SIZE         = 30
const AMMO_RESERVE     = 150
const RELOAD_TIME      = 1.8

var jetpack_fuel  := JETPACK_FUEL_MAX
var is_jetpacking := false
var fire_timer    := 0.0
var health        := MAX_HEALTH
var dead          := false
var ammo_mag      := MAG_SIZE
var ammo_reserve  := AMMO_RESERVE
var is_reloading  := false
var reload_timer  := 0.0

var player_id          := 1
var shoot_action       := "shoot"
var move_left_action   := "move_left"
var move_right_action  := "move_right"
var jump_action        := "jump"
var jetpack_action     := "jetpack"
var reload_action      := "reload"

@onready var gun_pivot    := $GunPivot
@onready var muzzle       := $GunPivot/Muzzle
@onready var body: Node2D  = $Body
@onready var health_bar   := $HUD/HealthBar
@onready var fuel_bar     := $HUD/FuelBar
@onready var ammo_label   := $HUD/AmmoLabel

var bullet_scene     := preload("res://scenes/weapons/bullet.tscn")
var hit_effect_scene := preload("res://scenes/fx/hit_effect.tscn")
var gravity: float    = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:
	if dead:
		return
	_handle_gravity(delta)
	_handle_jetpack(delta)
	_handle_movement()
	_handle_aim()
	_handle_shoot(delta)
	_handle_reload(delta)
	_update_hud()
	move_and_slide()

func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func _handle_jetpack(delta: float) -> void:
	is_jetpacking = Input.is_action_pressed(jetpack_action) and not is_on_floor() and jetpack_fuel > 0
	if is_jetpacking:
		velocity.y = JETPACK_FORCE * delta * 10
		jetpack_fuel = max(0, jetpack_fuel - JETPACK_FUEL_DRAIN * delta)
	else:
		jetpack_fuel = min(JETPACK_FUEL_MAX, jetpack_fuel + JETPACK_FUEL_REGEN * delta)

func _handle_movement() -> void:
	if Input.is_action_just_pressed(jump_action) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var direction := Input.get_axis(move_left_action, move_right_action)
	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.2)

func _handle_aim() -> void:
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	gun_pivot.rotation = aim_dir.angle()

func _handle_shoot(delta: float) -> void:
	fire_timer -= delta
	if is_reloading:
		return
	if Input.is_action_pressed(shoot_action) and fire_timer <= 0.0:
		if ammo_mag <= 0:
			_start_reload()
			return
		fire_timer = FIRE_RATE
		ammo_mag -= 1
		SoundManager.play_shoot()
		var bullet := bullet_scene.instantiate()
		bullet.global_position = muzzle.global_position
		bullet.direction = (get_global_mouse_position() - muzzle.global_position).normalized()
		bullet.rotation = bullet.direction.angle()
		bullet.shooter_id = player_id
		get_tree().root.add_child(bullet)

func _handle_reload(delta: float) -> void:
	if Input.is_action_just_pressed(reload_action) and not is_reloading and ammo_mag < MAG_SIZE and ammo_reserve > 0:
		_start_reload()
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()

func _start_reload() -> void:
	if ammo_reserve <= 0 or ammo_mag == MAG_SIZE:
		return
	is_reloading = true
	reload_timer = RELOAD_TIME
	SoundManager.play_reload()

func _finish_reload() -> void:
	var needed: int  = MAG_SIZE - ammo_mag
	var refill: int  = mini(needed, ammo_reserve)
	ammo_mag        += refill
	ammo_reserve    -= refill
	is_reloading     = false

func _update_hud() -> void:
	health_bar.value = health
	fuel_bar.value   = jetpack_fuel
	if is_reloading:
		ammo_label.text = "RELOADING..."
	else:
		ammo_label.text = "%d / %d" % [ammo_mag, ammo_reserve]

func take_damage(amount: float, hit_position: Vector2) -> void:
	if dead:
		return
	health -= amount
	SoundManager.play_hit()
	var effect := hit_effect_scene.instantiate()
	effect.global_position = hit_position
	get_tree().root.add_child(effect)
	if health <= 0:
		die()

func die() -> void:
	dead = true
	body.modulate = Color(1.0, 0.2, 0.2, 0.5)
	gun_pivot.visible = false
	SoundManager.play_death()
	emit_signal("died", self)
	await get_tree().create_timer(2.0).timeout
	respawn()

func respawn() -> void:
	health       = MAX_HEALTH
	ammo_mag     = MAG_SIZE
	ammo_reserve = AMMO_RESERVE
	is_reloading = false
	dead         = false
	gun_pivot.visible = true
	body.modulate = Color(1.0, 1.0, 1.0, 1.0) if player_id == 1 else Color(1.0, 0.4, 0.1, 1.0)
	global_position = Vector2(400, 400) if player_id == 1 else Vector2(880, 400)
