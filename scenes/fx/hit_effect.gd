extends Node2D

func _ready() -> void:
	for i in range(6):
		var particle := ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.color = Color(1.0, randf_range(0.1, 0.4), 0.0, 1.0)
		add_child(particle)
		var dir := Vector2.from_angle(randf() * TAU)
		var speed := randf_range(80.0, 200.0)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", dir * speed * 0.3, 0.3)
		tween.tween_property(particle, "modulate:a", 0.0, 0.3)
	await get_tree().create_timer(0.35).timeout
	queue_free()
