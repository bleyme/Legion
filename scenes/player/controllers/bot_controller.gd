extends RefCounted
## AI soldier. Uses the arena's rectangle layout to navigate (jump, jetpack
## around ceilings, drop through catwalks), keeps a preferred fighting range
## per weapon, strafes, leads its shots, grabs better weapons and health, and
## throws grenades at enemies hiding behind cover.

const PRESETS := [
	# reaction, aim noise (rad), turn speed (rad/s), lead accuracy, grenade chance
	{"reaction": 0.65, "noise": 0.2, "turn": 3.5, "lead": 0.0, "nade": 0.02, "burst": true},
	{"reaction": 0.4, "noise": 0.11, "turn": 6.0, "lead": 0.5, "nade": 0.05, "burst": false},
	{"reaction": 0.24, "noise": 0.06, "turn": 10.0, "lead": 0.85, "nade": 0.08, "burst": false},
	{"reaction": 0.14, "noise": 0.03, "turn": 16.0, "lead": 1.0, "nade": 0.12, "burst": false},
]
const RANK := {
	"pistol": 0, "smg": 2, "rifle": 3, "shotgun": 3, "grenade_launcher": 3,
	"sniper": 3, "minigun": 4, "railgun": 4, "rocket": 5,
}
const PREFERRED_RANGE := {
	"pistol": 380.0, "smg": 300.0, "rifle": 460.0, "shotgun": 170.0, "sniper": 800.0,
	"minigun": 360.0, "rocket": 480.0, "grenade_launcher": 420.0, "railgun": 700.0,
}

var level := 1
var cfg: Dictionary

var target: Player = null
var target_visible := false
var seen_time := 0.0
var last_seen_pos := Vector2.INF
var last_seen_age := 99.0
var goal := Vector2.ZERO
var goal_pickup: Node = null
var think_cd := 0.0
var strafe_dir := 1.0
var strafe_cd := 0.0
var aim_angle := 0.0
var noise := 0.0
var noise_target := 0.0
var noise_cd := 0.0
var stuck_time := 0.0
var last_pos := Vector2.ZERO
var unstick_left := 0.0
var unstick_dir := 1.0
var burst_cd := 0.0
var bursting := true
var nade_cd := 2.0
var hop_cd := 0.0
var detour_dir := 0.0
var wander := Vector2.INF
var _jump_was_held := false

func _init(lvl := 1) -> void:
	level = clampi(lvl, 0, PRESETS.size() - 1)
	cfg = PRESETS[level]
	strafe_dir = 1.0 if randf() < 0.5 else -1.0

func update(p: Player, dt: float, i: PlayerInput) -> void:
	var arena: Node = Game.arena
	if arena == null:
		return
	think_cd -= dt
	if think_cd <= 0.0:
		think_cd = randf_range(0.12, 0.2)
		_think(p)
	last_seen_age += dt
	if target_visible:
		seen_time += dt
	else:
		seen_time = maxf(0.0, seen_time - dt * 2.0)

	_navigate(p, dt, i, arena)
	_aim_and_fire(p, dt, i)

# --------------------------------------------------------------------------
# Decision making
# --------------------------------------------------------------------------

func _think(p: Player) -> void:
	# Target: nearest enemy, visible ones strongly preferred, sticky on current.
	var origin := p.aim_origin()
	var best: Player = null
	var best_score := INF
	var best_vis := false
	for other in Game.active_players():
		if other.dead or not Game.is_enemy(p, other):
			continue
		var d: float = origin.distance_to(other.global_position)
		var vis := AimAssist.has_los(p, origin, other.global_position + Vector2(0, -6))
		var score := d + (0.0 if vis else 700.0) - (200.0 if other == target else 0.0)
		if other.shield > 0.0:
			score += 300.0
		if score < best_score:
			best_score = score
			best = other
			best_vis = vis
	if best != target:
		seen_time = 0.0
	target = best
	target_visible = best_vis
	if target and target_visible:
		last_seen_pos = target.global_position
		last_seen_age = 0.0

	# Goal selection
	goal_pickup = null
	var weapon_id: String = p.current()["id"]
	var want_health := p.health < 50.0
	var want_weapon := p.primary.is_empty() or _ammo_low(p)
	var best_pick: Node = null
	var best_pick_d := INF
	for pk in Game.world.pickups:
		if not pk.active:
			continue
		var d: float = p.global_position.distance_to(pk.global_position)
		var useful := false
		match pk.kind:
			"health":
				useful = want_health or (p.health < 80.0 and d < 250.0)
				d *= 0.6 if want_health else 1.0
			"frag":
				useful = p.grenades < 2 and d < 400.0
			_:
				var rank_new: int = RANK.get(pk.weapon_id, 1)
				var rank_cur: int = RANK.get(weapon_id, 0) if not p.primary.is_empty() else 0
				useful = want_weapon or rank_new > rank_cur or (pk.weapon_id == weapon_id and _ammo_low(p))
				if not useful and d < 200.0 and rank_new >= rank_cur and pk.weapon_id != weapon_id:
					useful = level >= 2
		if useful and d < best_pick_d and d < 1400.0:
			best_pick_d = d
			best_pick = pk
	var fighting := target != null and target_visible and origin.distance_to(target.global_position) < 700.0
	if best_pick and (not fighting or best_pick_d < 220.0 or want_health):
		goal_pickup = best_pick
		goal = best_pick.global_position
	elif target and (target_visible or last_seen_age < 3.0):
		goal = target.global_position if target_visible else last_seen_pos
	elif target:
		goal = target.global_position
	else:
		if wander == Vector2.INF or p.global_position.distance_to(wander) < 80.0:
			var sp: Vector2 = Game.arena.spawns[randi() % Game.arena.spawns.size()]
			wander = sp + Vector2(0, -30)
		goal = wander

func _ammo_low(p: Player) -> bool:
	if p.primary.is_empty():
		return true
	return int(p.primary["mag"]) + int(p.primary["reserve"]) <= int(WeaponData.get_def(p.primary["id"])["mag"]) / 3

# --------------------------------------------------------------------------
# Movement
# --------------------------------------------------------------------------

func _navigate(p: Player, dt: float, i: PlayerInput, arena: Node) -> void:
	i.down = false
	var pos := p.global_position
	var feet := pos + Vector2(0, 29)
	var to_goal := goal - pos
	var move := 0.0
	var want_up := false
	var want_down := false
	var def := p.current_def()
	var pref: float = PREFERRED_RANGE.get(def["id"], 400.0)

	var engaging := target != null and target_visible and goal_pickup == null
	if engaging:
		var d := pos.distance_to(target.global_position)
		var away := -signf(target.global_position.x - pos.x)
		strafe_cd -= dt
		if strafe_cd <= 0.0:
			strafe_cd = randf_range(0.35, 1.1)
			strafe_dir = -strafe_dir if randf() < 0.7 else strafe_dir
		if d > pref * 1.25:
			move = signf(to_goal.x)
		elif d < pref * 0.6:
			move = away
		else:
			move = strafe_dir
		hop_cd -= dt
		if hop_cd <= 0.0 and p.is_on_floor():
			hop_cd = randf_range(0.8, 2.5) / (1.0 + level * 0.3)
			if randf() < 0.35 + level * 0.1:
				want_up = true
		# Stay roughly level with the target, or above it.
		if to_goal.y < -90.0:
			want_up = true
	else:
		if absf(to_goal.x) > 24.0:
			move = signf(to_goal.x)
		if to_goal.y < -60.0:
			want_up = true
		elif to_goal.y > 70.0:
			want_down = true

	var support = arena.support_under(feet, 8.0)

	# Going up: route around a ceiling if one is directly above.
	if want_up and not engaging:
		var ceiling = _ceiling_above(arena, pos, goal.y)
		if ceiling != null:
			var r: Rect2 = ceiling
			if detour_dir == 0.0:
				var left_cost := absf(pos.x - r.position.x) + absf(goal.x - r.position.x)
				var right_cost := absf(r.end.x - pos.x) + absf(r.end.x - goal.x)
				detour_dir = -1.0 if left_cost < right_cost else 1.0
				if r.position.x <= 1.0:
					detour_dir = 1.0
				elif r.end.x >= arena.size.x - 1.0:
					detour_dir = -1.0
			move = detour_dir
			want_up = false
		else:
			detour_dir = 0.0
	else:
		detour_dir = 0.0

	# Going down: drop through catwalks, or walk off the ledge.
	if want_down and support != null:
		if arena.is_platform(support):
			i.down = true
			i.jump_pressed = true
		elif absf(to_goal.x) < 40.0:
			var r: Rect2 = support
			move = -1.0 if (pos.x - r.position.x) < (r.end.x - pos.x) else 1.0

	# Walls in the way: hop / jet over them.
	if absf(move) > 0.0 and p.is_on_wall():
		want_up = true

	# Stuck detection.
	if pos.distance_to(last_pos) < 1.5 and (absf(move) > 0.0 or want_up):
		stuck_time += dt
	else:
		stuck_time = maxf(0.0, stuck_time - dt)
	last_pos = pos
	if stuck_time > 0.7:
		stuck_time = 0.0
		unstick_left = 0.6
		unstick_dir = -move if move != 0.0 else (1.0 if randf() < 0.5 else -1.0)
	if unstick_left > 0.0:
		unstick_left -= dt
		move = unstick_dir
		want_up = true

	i.move = move
	# Jump on the ground, keep holding to jetpack when fuel allows.
	if want_up:
		if p.is_on_floor():
			i.jump_pressed = not _jump_was_held
			i.jump_held = true
		else:
			i.jump_held = p.fuel > 4.0 or p.velocity.y < 0.0
	elif not i.jump_pressed:
		i.jump_held = false
		# Break long falls onto the target level with a touch of jetpack.
		if not p.is_on_floor() and p.velocity.y > 650.0 and p.fuel > 30.0:
			i.jump_held = true
	_jump_was_held = i.jump_held

func _ceiling_above(arena: Node, pos: Vector2, goal_y: float) -> Variant:
	var top := maxf(goal_y, pos.y - 400.0)
	var y := pos.y - 40.0
	while y > top:
		var r = arena.solid_at(Vector2(pos.x, y))
		if r != null:
			return r
		y -= 20.0
	return null

# --------------------------------------------------------------------------
# Aiming & shooting
# --------------------------------------------------------------------------

func _aim_and_fire(p: Player, dt: float, i: PlayerInput) -> void:
	var origin := p.aim_origin()
	var def := p.current_def()
	var desired: float
	var have_shot := false

	noise_cd -= dt
	if noise_cd <= 0.0:
		noise_cd = randf_range(0.15, 0.35)
		noise_target = randf_range(-1.0, 1.0) * float(cfg["noise"])
	noise = lerpf(noise, noise_target, clampf(dt * 8.0, 0.0, 1.0))

	if target and target_visible:
		var tp := target.global_position + Vector2(0, -6)
		if def["kind"] == "hitscan" and level >= 2:
			tp.y -= 12.0   # go for the head
		var dist := origin.distance_to(tp)
		if def["kind"] != "hitscan":
			var t: float = dist / float(def["speed"])
			tp += target.velocity * t * float(cfg["lead"])
		if def["kind"] == "grenade":
			tp.y -= dist * 0.28
		desired = (tp - origin).angle() + noise
		var in_range := dist < float(def["range"]) * 0.9
		if def["id"] == "shotgun":
			in_range = dist < 480.0
		if (def["kind"] == "rocket" or def["kind"] == "grenade") and dist < 110.0:
			in_range = false
		have_shot = in_range and seen_time >= float(cfg["reaction"])
		# Grenade at a close enemy.
		nade_cd -= dt
		if nade_cd <= 0.0 and p.grenades > 0 and dist > 220.0 and dist < 560.0:
			nade_cd = randf_range(1.0, 2.0)
			if randf() < float(cfg["nade"]) * 6.0:
				i.grenade = true
				desired = (tp + Vector2(0, -dist * 0.35) - origin).angle()
	elif target and last_seen_age < 1.6 and last_seen_pos != Vector2.INF:
		# Just lost sight: pre-aim where the enemy was, maybe lob a grenade.
		var lp := last_seen_pos
		desired = (lp - origin).angle()
		nade_cd -= dt
		var dist := origin.distance_to(lp)
		if nade_cd <= 0.0 and p.grenades > 0 and dist < 520.0 and level >= 1:
			nade_cd = randf_range(1.5, 3.0)
			if randf() < float(cfg["nade"]) * 5.0:
				desired = (lp + Vector2(0, -dist * 0.4) - origin).angle()
				i.grenade = true
	else:
		var look := goal - origin
		if absf(look.x) < 1.0:
			look.x = p.facing
		desired = Vector2(signf(look.x), 0.0).angle()
		# Reload during downtime.
		var w := p.current()
		if int(w["mag"]) < int(def["mag"]) / 2 and int(w["reserve"]) != 0:
			i.reload = true

	aim_angle = rotate_toward(aim_angle, desired, float(cfg["turn"]) * dt)
	i.aim = Vector2.from_angle(aim_angle)

	if cfg["burst"]:
		burst_cd -= dt
		if burst_cd <= 0.0:
			bursting = not bursting
			burst_cd = randf_range(0.5, 0.9) if bursting else randf_range(0.3, 0.6)
	var on_target := absf(angle_difference(aim_angle, desired)) < 0.25
	i.shoot = have_shot and on_target and (bursting or not cfg["burst"])

	# Pick up a better weapon lying under us.
	var fresh := Engine.get_physics_frames() - p.nearby_frame <= 1
	if fresh and p.nearby_pickup and is_instance_valid(p.nearby_pickup) and p.nearby_pickup.kind == "weapon":
		var new_rank: int = RANK.get(p.nearby_pickup.weapon_id, 1)
		var cur_rank: int = RANK.get(p.primary.get("id", "pistol"), 0) if not p.primary.is_empty() else -1
		if new_rank > cur_rank or _ammo_low(p):
			i.swap = true
	# Out of primary ammo while fighting close: fall back to pistol instantly.
	if not p.primary.is_empty() and p.slot == 0 and int(p.primary["mag"]) == 0 and p.is_reloading() and target_visible:
		var dist := origin.distance_to(target.global_position) if target else INF
		if dist < 300.0 and level >= 2:
			i.swap = true
