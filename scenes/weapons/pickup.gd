extends Node2D
## Weapon / health / grenade pickup. Map pickups respawn; weapons dropped by
## dead players fall to the floor and vanish after a while.
## Walking over a weapon takes it if your primary slot is empty (or tops up
## ammo for the same gun); otherwise press "swap" to exchange weapons.

const RESPAWN := {"weapon": 10.0, "health": 16.0, "frag": 14.0}
const DROP_LIFETIME := 14.0
const REACH := Vector2(26, 40)

var kind := "weapon"
var weapon_id := "rifle"
var fixed := ""             # weapon id that always spawns here, "" = random
var dropped := false
var mag := -1
var reserve := -1
var active := true
var respawn_left := 0.0
var life := DROP_LIFETIME
var vel := Vector2.ZERO
var resting := false
var _t := 0.0
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	_t = randf() * TAU
	if kind == "weapon" and not dropped:
		weapon_id = fixed if fixed != "" else WeaponData.random_pickup_id()

func _physics_process(delta: float) -> void:
	_t += delta
	if dropped:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		if not resting:
			vel.y = minf(vel.y + 1400.0 * delta, 900.0)
			var next := position + vel * delta
			var floor_y: float = Game.arena.floor_below(position + Vector2(0, -4)) - 16.0
			if next.y >= floor_y:
				next.y = floor_y
				resting = true
			if Game.arena.is_solid(Vector2(next.x, position.y)):
				vel.x = -vel.x * 0.3
				next.x = position.x
			next.x = clampf(next.x, 24.0, Game.arena.size.x - 24.0)   # stay reachable
			position = next
	if not active:
		respawn_left -= delta
		if respawn_left <= 0.0:
			active = true
			if kind == "weapon" and fixed == "":
				weapon_id = WeaponData.random_pickup_id()
			Game.fx.pickup_burst(global_position, _color())
		queue_redraw()
		return

	var frame := Engine.get_physics_frames()
	for p in Game.active_players():
		if p.dead:
			continue
		var d: Vector2 = (p.global_position - global_position).abs()
		if d.x > REACH.x or d.y > REACH.y:
			continue
		match kind:
			"health":
				if p.give_health(50.0):
					_consume()
					return
			"frag":
				if p.give_grenades(2):
					_consume()
					return
			_:
				if p.primary.is_empty() or p.primary["id"] == weapon_id:
					if p.give_weapon(weapon_id, mag, reserve):
						_consume()
						return
				else:
					p.nearby_pickup = self
					p.nearby_frame = frame
	queue_redraw()

## Called when a player presses swap while standing on this pickup.
func try_take(p: Player, force: bool) -> bool:
	if not active or kind != "weapon":
		return false
	if p.give_weapon(weapon_id, mag, reserve, force):
		_consume()
		return true
	return false

func _consume() -> void:
	Game.fx.pickup_burst(global_position, _color())
	if dropped:
		queue_free()
		return
	active = false
	respawn_left = RESPAWN[kind]
	queue_redraw()

func _color() -> Color:
	match kind:
		"health": return Color(0.35, 1.0, 0.45)
		"frag":   return Color(1.0, 0.75, 0.25)
	return WeaponArt.accent(weapon_id)

func _draw() -> void:
	var c := _color()
	if not active:
		# faint marker with respawn progress
		var total: float = RESPAWN[kind]
		var p := 1.0 - respawn_left / total
		draw_arc(Vector2.ZERO, 14, -PI * 0.5, -PI * 0.5 + TAU * p, 24, Color(c.r, c.g, c.b, 0.35), 2.0)
		return
	if dropped and life < 3.0 and fmod(life, 0.3) < 0.15:
		return
	var bob := 0.0 if dropped else sin(_t * 3.0) * 3.0
	var pulse := 0.6 + 0.4 * sin(_t * 5.0)
	if not dropped:
		draw_circle(Vector2(0, 14), 18.0, Color(c.r, c.g, c.b, 0.08 + 0.06 * pulse))
		draw_line(Vector2(-16, 16), Vector2(16, 16), Color(c.r, c.g, c.b, 0.6), 2.0)
	draw_set_transform(Vector2(0, bob))
	match kind:
		"health":
			draw_rect(Rect2(-11, -9, 22, 18), Color(0.92, 0.94, 0.92))
			draw_rect(Rect2(-11, -9, 22, 18), Color(0.2, 0.5, 0.25), false, 2.0)
			draw_rect(Rect2(-3, -6, 6, 12), Color(0.85, 0.12, 0.12))
			draw_rect(Rect2(-6, -3, 12, 6), Color(0.85, 0.12, 0.12))
		"frag":
			for i in 2:
				var o := Vector2(-6 + i * 12, 0)
				draw_circle(o, 6.0, Color(0.25, 0.32, 0.18))
				draw_rect(Rect2(o + Vector2(-2, -9), Vector2(4, 4)), Color(0.55, 0.55, 0.55))
		_:
			draw_set_transform(Vector2(-12, bob), 0.0, Vector2(0.9, 0.9))
			WeaponArt.draw_weapon(self, weapon_id)
			draw_set_transform(Vector2(0, bob))
			var label: String = WeaponData.get_def(weapon_id)["name"]
			var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string_outline(_font, Vector2(-w * 0.5, -18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.7))
			draw_string(_font, Vector2(-w * 0.5, -18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(c.r, c.g, c.b, 0.9))
	draw_set_transform(Vector2.ZERO)
	# swap prompt for humans standing on it
	var frame := Engine.get_physics_frames()
	for p in Game.active_players():
		if p.is_human and p.nearby_pickup == self and frame - p.nearby_frame <= 1:
			var hint := "%s : prendre" % p.swap_hint
			var hw := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string_outline(_font, Vector2(-hw * 0.5, -34), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.8))
			draw_string(_font, Vector2(-hw * 0.5, -34), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
			break
