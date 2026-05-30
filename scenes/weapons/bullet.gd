extends Area2D

const SPEED = 1200.0
const LIFETIME = 2.0
const DAMAGE = 15.0

var direction := Vector2.RIGHT
var shooter_id := 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage") and body.player_id != shooter_id:
		body.take_damage(DAMAGE, global_position)
	queue_free()
