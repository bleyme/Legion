extends CharacterBody2D

var shooter_id  := 0
var damage      := 80.0
var fuse_timer  := 2.5
var exploded    := false

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var explosion_scene := preload("res://scenes/fx/explosion.tscn")

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if exploded:
		return
	velocity.y += gravity * delta
	fuse_timer  -= delta
	if fuse_timer <= 0.0:
		explode()
		return
	var col := move_and_collide(velocity * delta)
	if col:
		velocity = velocity.bounce(col.get_normal()) * 0.55

func explode() -> void:
	if exploded:
		return
	exploded = true
	var exp        := explosion_scene.instantiate()
	exp.global_position = global_position
	exp.shooter_id      = shooter_id
	exp.damage          = damage
	get_tree().root.add_child(exp)
	SoundManager.play_explosion()
	queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage") and body.player_id != shooter_id:
		explode()
