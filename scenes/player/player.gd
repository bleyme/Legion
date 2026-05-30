extends CharacterBody2D

signal died(player_node)

const SPEED            = 200.0
const JUMP_VELOCITY    = -400.0
const JETPACK_FORCE    = -600.0
const JETPACK_FUEL_MAX = 100.0
const JETPACK_FUEL_DRAIN = 30.0
const JETPACK_FUEL_REGEN = 15.0
const MAX_HEALTH       = 100.0

var jetpack_fuel  := JETPACK_FUEL_MAX
var is_jetpacking := false
var fire_timer    := 0.0
var health        := MAX_HEALTH
var dead          := false
var is_reloading  := false
var reload_timer  := 0.0
var ammo_mag      := 0
var ammo_reserve  := 0

var current_weapon: Dictionary

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
@onready var gun_sprite   := $GunPivot/GunSprite
@onready var health_bar   := $HUD/HealthBar
@onready var fuel_bar     := $HUD/FuelBar
@onready var ammo_label   := $HUD/AmmoLabel
@onready var weapon_label := $HUD/WeaponLabel

var bullet_scene     := preload("res://scenes/weapons/bullet.tscn")
var grenade_scene    := preload("res://scenes/weapons/grenade.tscn")
var hit_effect_scene := preload("res://scenes/fx/hit_effect.tscn")
var gravity: float    = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	equip_weapon(WeaponData.assault_rifle())

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
		velocity.y    = JETPACK_FORCE * delta * 10
		jetpack_fuel  = max(0, jetpack_fuel - JETPACK_FUEL_DRAIN * delta)
	else:
		jetpack_fuel  = min(JETPACK_FUEL_MAX, jetpack_fuel + JETPACK_FUEL_REGEN * delta)

func _handle_movement() -> void:
	if Input.is_action_just_pressed(jump_action) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var direction := Input.get_axis(move_left_action, move_right_action)
	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.2)

func _handle_aim() -> void:
	var aim_dir       := (get_global_mouse_position() - global_position).normalized()
	gun_pivot.rotation = aim_dir.angle()

func _handle_shoot(delta: float) -> void:
	fire_timer -= delta
	if is_reloading or current_weapon.is_empty():
		return
	if Input.is_action_pressed(shoot_action) and fire_timer <= 0.0:
		if ammo_mag <= 0:
			_start_reload()
			return
		fire_timer  = current_weapon["fire_rate"]
		ammo_mag   -= 1
		SoundManager.play_shoot()
		if current_weapon["is_grenade"]:
			_spawn_grenade()
		else:
			for i in range(current_weapon.pellets):
				_spawn_bullet()

func _spawn_bullet() -> void:
	var aim:    Vector2 = (get_global_mouse_position() - muzzle.global_position).normalized()
	var spread: float   = current_weapon["spread"]
	var angle:  float   = aim.angle() + randf_range(-spread, spread)
	var dir:    Vector2 = Vector2.from_angle(angle)
	var bullet: Node    = bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.set("direction",  dir)
	bullet.set("rotation",   angle)
	bullet.set("shooter_id", player_id)
	bullet.set("speed",      current_weapon["bullet_speed"])
	bullet.set("damage",     current_weapon["damage"])
	get_tree().root.add_child(bullet)

func _spawn_grenade() -> void:
	var aim:     Vector2 = (get_global_mouse_position() - muzzle.global_position).normalized()
	var grenade: Node    = grenade_scene.instantiate()
	grenade.global_position = muzzle.global_position
	grenade.set("velocity",    aim * float(current_weapon["bullet_speed"]))
	grenade.set("shooter_id",  player_id)
	grenade.set("damage",      current_weapon["damage"])
	get_tree().root.add_child(grenade)

func _handle_reload(delta: float) -> void:
	if Input.is_action_just_pressed(reload_action) and not is_reloading and not current_weapon.is_empty():
		if ammo_mag < int(current_weapon["mag_size"]) and ammo_reserve > 0:
			_start_reload()
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()

func _start_reload() -> void:
	if current_weapon.is_empty() or ammo_reserve <= 0 or ammo_mag == int(current_weapon["mag_size"]):
		return
	is_reloading = true
	reload_timer = current_weapon["reload_time"]
	SoundManager.play_reload()

func _finish_reload() -> void:
	var needed: int  = int(current_weapon["mag_size"]) - ammo_mag
	var refill: int  = mini(needed, ammo_reserve)
	ammo_mag        += refill
	ammo_reserve    -= refill
	is_reloading     = false

func equip_weapon(w: Dictionary) -> void:
	current_weapon   = w
	ammo_mag         = w["mag_size"]
	ammo_reserve     = w["ammo_reserve"]
	is_reloading     = false
	gun_sprite.weapon_type = w["weapon_type"]
	gun_sprite.queue_redraw()

func _update_hud() -> void:
	health_bar.value = health
	fuel_bar.value   = jetpack_fuel
	if current_weapon.is_empty():
		return
	weapon_label.text = current_weapon["weapon_name"]
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
	if health <= 0.0:
		die()

func die() -> void:
	dead = true
	body.modulate       = Color(1.0, 0.2, 0.2, 0.5)
	gun_pivot.visible   = false
	SoundManager.play_death()
	emit_signal("died", self)
	await get_tree().create_timer(2.0).timeout
	respawn()

func respawn() -> void:
	health     = MAX_HEALTH
	dead       = false
	gun_pivot.visible = true
	body.modulate     = Color(1.0, 1.0, 1.0, 1.0) if player_id == 1 else Color(1.0, 0.4, 0.1, 1.0)
	global_position   = Vector2(400, 400) if player_id == 1 else Vector2(880, 400)
	equip_weapon(WeaponData.assault_rifle())
