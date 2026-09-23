class_name AimAssist
## Target finding shared by keyboard/gamepad aim assist and bots.

static func has_los(from: Node2D, a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	return from.get_world_2d().direct_space_state.intersect_ray(q).is_empty()

## Closest living enemy in line of sight. If `dir` is given, only enemies
## within `cone` radians of it are considered.
static func best_target(p: Player, max_dist: float, dir := Vector2.ZERO, cone := PI) -> Player:
	var origin := p.aim_origin()
	var best: Player = null
	var best_score := INF
	for other in Game.active_players():
		if other == p or other.dead:
			continue
		var to: Vector2 = other.global_position - origin
		var d := to.length()
		if d > max_dist:
			continue
		var score := d
		if dir != Vector2.ZERO:
			var ang := absf(dir.angle_to(to))
			if ang > cone:
				continue
			score = ang * 1000.0 + d * 0.2
		if score < best_score and has_los(p, origin, other.global_position):
			best = other
			best_score = score
	return best
