extends Node2D

const RADIUS   = 90.0
const DURATION = 0.45

var shooter_id := 0
var damage     := 80.0
var elapsed    := 0.0
var did_damage := false

func _ready() -> void:
	_apply_damage()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= DURATION:
		queue_free()

func _draw() -> void:
	var t       := elapsed / DURATION
	var radius  := RADIUS * (0.3 + 0.7 * t)
	var alpha   := 1.0 - t
	draw_circle(Vector2.ZERO, radius,       Color(1.0, 0.5, 0.1, alpha * 0.6))
	draw_circle(Vector2.ZERO, radius * 0.6, Color(1.0, 0.85, 0.3, alpha * 0.8))
	draw_circle(Vector2.ZERO, radius * 0.3, Color(1.0, 1.0, 0.9, alpha))

func _apply_damage() -> void:
	if did_damage:
		return
	did_damage = true
	var space := get_world_2d().direct_space_state
	var shape  := CircleShape2D.new()
	shape.radius = RADIUS
	var query                   := PhysicsShapeQueryParameters2D.new()
	query.shape                 = shape
	query.transform             = Transform2D(0.0, global_position)
	query.collision_mask        = 1
	for result in space.intersect_shape(query, 8):
		var body: Object = result["collider"]
		if body.has_method("take_damage") and body.get("player_id") != shooter_id:
			var dist    := global_position.distance_to(body.global_position)
			var falloff := 1.0 - clampf(dist / RADIUS, 0.0, 1.0)
			body.take_damage(damage * maxf(falloff, 0.2), global_position)
