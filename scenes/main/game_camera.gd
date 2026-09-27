extends Camera2D
## Shared camera. With one human it follows them with aim look-ahead; with
## several humans (or none, in the menu demo) it frames everyone. Trauma-based
## screen shake decays smoothly.

const SOLO_VIEW_HEIGHT := 820.0
const FRAME_MARGIN := Vector2(360, 300)

var arena_size := Vector2(1280, 720)
var trauma := 0.0
var _center := Vector2.ZERO
var _zoom := 1.0
var _noise := FastNoiseLite.new()
var _t := 0.0
var _snap := true
var _just_snapped := false

func _ready() -> void:
	_noise.frequency = 0.9
	_noise.seed = randi()
	ignore_rotation = false

func add_trauma(amount: float, at := Vector2.INF) -> void:
	if at != Vector2.INF:
		var d := at.distance_to(get_screen_center_position())
		amount *= clampf(1.2 - d / 1400.0, 0.15, 1.0)
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	_t += delta
	var vs := get_viewport_rect().size
	var players: Array = Game.active_players()
	var humans := players.filter(func(p): return p.is_human)
	var focus: Array = humans if not humans.is_empty() else players
	var alive := focus.filter(func(p): return not p.dead)
	if alive.is_empty():
		alive = focus
	if alive.is_empty():
		return

	var target_center: Vector2
	var solo_zoom := vs.y / SOLO_VIEW_HEIGHT
	var fit_map := minf(vs.x / (arena_size.x + 120.0), vs.y / (arena_size.y + 120.0))
	var target_zoom := solo_zoom
	if alive.size() == 1:
		var p: Player = alive[0]
		target_center = p.global_position + Vector2(0, -40)
		if p.is_mouse_user:
			var m := get_viewport().get_mouse_position() - vs * 0.5
			target_center += (m / _zoom) * 0.3
		else:
			target_center += p.input.aim * 90.0
	else:
		var box := Rect2(alive[0].global_position, Vector2.ZERO)
		for p in alive:
			box = box.expand(p.global_position)
		box = box.grow_individual(FRAME_MARGIN.x * 0.5, FRAME_MARGIN.y * 0.5 + 40, FRAME_MARGIN.x * 0.5, FRAME_MARGIN.y * 0.5)
		target_center = box.get_center()
		target_zoom = minf(vs.x / box.size.x, vs.y / box.size.y)
	target_zoom = clampf(target_zoom, fit_map, solo_zoom)

	if _snap:
		_center = target_center
		_zoom = target_zoom
		_snap = false
		_just_snapped = true
	else:
		_center = _center.lerp(target_center, 1.0 - exp(-delta * 7.0))
		_zoom = lerpf(_zoom, target_zoom, 1.0 - exp(-delta * 2.5))

	# Keep the view inside the arena.
	var half := vs / (2.0 * _zoom)
	var c := _center
	c.x = arena_size.x * 0.5 if half.x * 2.0 >= arena_size.x else clampf(c.x, half.x - 40.0, arena_size.x - half.x + 40.0)
	c.y = arena_size.y * 0.5 if half.y * 2.0 >= arena_size.y else clampf(c.y, half.y - 40.0, arena_size.y - half.y + 40.0)

	trauma = maxf(0.0, trauma - delta * 1.4)
	var s := trauma * trauma
	var shake := Vector2(_noise.get_noise_2d(_t * 60.0, 0.0), _noise.get_noise_2d(0.0, _t * 60.0)) * 26.0 * s
	global_position = c + shake / _zoom
	if _just_snapped:
		reset_physics_interpolation()
		_just_snapped = false
	rotation = _noise.get_noise_2d(_t * 40.0, 100.0) * 0.035 * s
	zoom = Vector2(_zoom, _zoom)

func snap() -> void:
	_snap = true
