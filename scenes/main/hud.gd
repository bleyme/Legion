extends Control
## Everything drawn on screen during a match: player cards, crosshair,
## scoreboard, kill feed, announcer, timer, damage vignette and off-screen
## enemy arrows. Drawn immediately each frame (no per-widget nodes).

const FEED_TIME := 5.0
const CARD_SIZE := Vector2(300, 92)

var _font: Font
var _feed: Array = []        # {killer, kcol, weapon, victim, vcol, head, t}
var _announce: Array = []    # {text, sub, color, t, dur}
var _vignette := 0.0
var _time := 0.0

func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	_vignette = maxf(0.0, _vignette - delta * 1.6)
	for f in _feed:
		f["t"] += delta
	_feed = _feed.filter(func(f): return f["t"] < FEED_TIME)
	if not _announce.is_empty():
		_announce[0]["t"] += delta
		if _announce[0]["t"] >= _announce[0]["dur"]:
			_announce.pop_front()
	queue_redraw()

# --------------------------------------------------------------------------
# API
# --------------------------------------------------------------------------

func add_kill(killer: Node, victim: Player, weapon_id: String, headshot: bool) -> void:
	var entry := {
		"victim": victim.display_name, "vcol": victim.color, "head": headshot, "t": 0.0,
		"weapon": WeaponData.get_def(weapon_id)["name"] if weapon_id != "" else "",
	}
	if killer is Player and killer != victim:
		entry["killer"] = killer.display_name
		entry["kcol"] = killer.color
	else:
		entry["killer"] = ""
		entry["kcol"] = Color.WHITE
	_feed.push_front(entry)
	if _feed.size() > 6:
		_feed.pop_back()

func announce(text: String, color := UITheme.ACCENT, sub := "", dur := 1.8) -> void:
	# Replace a pending announcement of the same text instead of queueing.
	for a in _announce:
		if a["text"] == text:
			return
	_announce.append({"text": text, "sub": sub, "color": color, "t": 0.0, "dur": dur})
	if _announce.size() > 3:
		_announce.remove_at(1)

func damage_flash(p: Player) -> void:
	_vignette = minf(1.0, _vignette + 0.45)

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
	var world: Node = Game.world
	if world == null:
		return
	var vs := get_viewport_rect().size
	var players: Array = world.get_players()
	var humans := players.filter(func(p): return p.is_human)

	_draw_offscreen(players, humans, vs)
	if _vignette > 0.0 or (humans.size() == 1 and humans[0].health < 35.0 and not humans[0].dead):
		_draw_vignette(humans, vs)

	# Human cards along the bottom.
	var n := humans.size()
	for idx in n:
		var x: float
		if n == 1:
			x = 16.0
		elif n == 2:
			x = 16.0 if idx == 0 else vs.x - CARD_SIZE.x - 16.0
		else:
			var gap := (vs.x - n * CARD_SIZE.x) / float(n + 1)
			x = gap + idx * (CARD_SIZE.x + gap)
		_draw_card(humans[idx], Vector2(x, vs.y - CARD_SIZE.y - 14.0))

	_draw_timer(world, vs)
	_draw_scoreboard(players, vs)
	_draw_feed(vs)
	_draw_announce(vs)
	for p in humans:
		if p.dead:
			_draw_death(p, vs, humans.size())
		elif p.is_mouse_user:
			_draw_crosshair(p)

func _text(pos: Vector2, text: String, fsize: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 4) -> void:
	if outline > 0:
		draw_string_outline(_font, pos, text, align, width, fsize, outline, Color(0, 0, 0, 0.75 * color.a))
	draw_string(_font, pos, text, align, width, fsize, color)

func _draw_card(p: Player, at: Vector2) -> void:
	var r := Rect2(at, CARD_SIZE)
	draw_rect(r, Color(0.03, 0.04, 0.07, 0.78))
	draw_rect(Rect2(at, Vector2(5, CARD_SIZE.y)), p.color)
	draw_rect(r, Color(1, 1, 1, 0.08), false, 1.0)
	var x := at.x + 16
	_text(Vector2(x, at.y + 20), p.display_name, 16, p.color.lightened(0.25))
	_text(Vector2(at.x, at.y + 20), "%d frags" % p.kills, 14, UITheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, CARD_SIZE.x - 12, 3)

	# health
	var hb := Rect2(x, at.y + 28, 180, 14)
	draw_rect(hb, Color(0, 0, 0, 0.6))
	var frac := clampf(p.health / Player.MAX_HEALTH, 0.0, 1.0)
	var hc := Color(0.3, 0.9, 0.35).lerp(Color(1.0, 0.2, 0.15), 1.0 - frac)
	if frac < 0.3 and fmod(_time, 0.5) < 0.25:
		hc = hc.lightened(0.4)
	draw_rect(Rect2(hb.position, Vector2(hb.size.x * frac, hb.size.y)), hc)
	_text(Vector2(hb.end.x + 8, hb.end.y - 1), str(int(ceil(p.health))), 16, hc.lightened(0.3))
	# fuel
	var fb := Rect2(x, at.y + 45, 180, 5)
	draw_rect(fb, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(fb.position, Vector2(fb.size.x * p.fuel / Player.FUEL_MAX, fb.size.y)), Color(0.3, 0.65, 1.0))

	# weapon
	var w: Dictionary = p.current()
	var def: Dictionary = p.current_def()
	draw_set_transform(Vector2(x + 18, at.y + 72), 0.0, Vector2(0.85, 0.85))
	WeaponArt.draw_weapon(self, w["id"])
	draw_set_transform(Vector2.ZERO)
	var ammo := ""
	if p.is_reloading():
		ammo = "RECHARGE..."
	else:
		ammo = "%d / %s" % [int(w["mag"]), "∞" if int(w["reserve"]) < 0 else str(int(w["reserve"]))]
	var ammo_col := UITheme.TEXT
	if not p.is_reloading() and int(w["mag"]) <= int(def["mag"]) / 4:
		ammo_col = Color(1.0, 0.4, 0.3)
	_text(Vector2(x + 66, at.y + 70), def["name"], 13, UITheme.DIM)
	_text(Vector2(x + 66, at.y + 86), ammo, 16, ammo_col)
	# grenades
	for g in p.grenades:
		var gp := Vector2(at.x + CARD_SIZE.x - 18 - g * 14, at.y + 78)
		draw_circle(gp, 5, Color(0.35, 0.45, 0.25))
		draw_rect(Rect2(gp + Vector2(-1.5, -8), Vector2(3, 3)), Color(0.7, 0.7, 0.7))
	# secondary slot hint
	if not p.primary.is_empty():
		var other: String = p.sidearm["id"] if p.slot == 0 else p.primary["id"]
		_text(Vector2(at.x, at.y + 62), "%s ▸ %s" % [p.swap_hint, WeaponData.get_def(other)["name"]], 11, UITheme.DIM, HORIZONTAL_ALIGNMENT_RIGHT, CARD_SIZE.x - 12, 0)

func _draw_timer(world: Node, vs: Vector2) -> void:
	var cx := vs.x * 0.5
	var text := "∞"
	if world.time_left >= 0.0:
		var s := int(ceil(world.time_left))
		text = "%d:%02d" % [s / 60, s % 60]
	var col := UITheme.TEXT
	if world.time_left >= 0.0 and world.time_left < 30.0 and fmod(_time, 1.0) < 0.5:
		col = Color(1.0, 0.4, 0.3)
	draw_rect(Rect2(cx - 70, 8, 140, 44), Color(0.03, 0.04, 0.07, 0.7))
	_text(Vector2(cx - 70, 34), text, 24, col, HORIZONTAL_ALIGNMENT_CENTER, 140)
	_text(Vector2(cx - 70, 48), "Objectif : %d frags" % Game.frag_limit if Game.frag_limit > 0 else "Sans limite", 11, UITheme.DIM, HORIZONTAL_ALIGNMENT_CENTER, 140, 0)

func _draw_scoreboard(players: Array, vs: Vector2) -> void:
	var sorted := players.duplicate()
	sorted.sort_custom(func(a, b): return a.kills > b.kills or (a.kills == b.kills and a.deaths < b.deaths))
	var w := 190.0
	var x := vs.x - w - 12
	var y := 12.0
	draw_rect(Rect2(x, y, w, 10 + sorted.size() * 20), Color(0.03, 0.04, 0.07, 0.65))
	for i in sorted.size():
		var p: Player = sorted[i]
		var ry := y + 22 + i * 20
		if p.is_human:
			draw_rect(Rect2(x, ry - 15, w, 20), Color(p.color.r, p.color.g, p.color.b, 0.15))
		draw_rect(Rect2(x + 6, ry - 10, 4, 12), p.color)
		var name_col := p.color.lightened(0.3) if not p.dead else Color(0.5, 0.5, 0.55)
		_text(Vector2(x + 16, ry), "%d. %s" % [i + 1, p.display_name], 14, name_col, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		_text(Vector2(x, ry), str(p.kills), 14, UITheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, w - 10, 3)

func _draw_feed(_vs: Vector2) -> void:
	var y := 26.0
	for f in _feed:
		var a := clampf((FEED_TIME - f["t"]) * 2.0, 0.0, 1.0)
		var x := 14.0
		var parts := []
		if f["killer"] != "":
			parts.append([f["killer"], f["kcol"].lightened(0.2)])
		parts.append(["[" + f["weapon"] + "]" if f["killer"] != "" else "s'est éliminé", UITheme.DIM])
		if f["head"]:
			parts.append(["☠", Color(1.0, 0.4, 0.3)])
		if f["killer"] != "":
			parts.append([f["victim"], f["vcol"].lightened(0.2)])
		else:
			parts.push_front([f["victim"], f["vcol"].lightened(0.2)])
		var total := 0.0
		for part in parts:
			total += _font.get_string_size(part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 8
		draw_rect(Rect2(x - 6, y - 16, total + 8, 22), Color(0.03, 0.04, 0.07, 0.6 * a))
		for part in parts:
			var c: Color = part[1]
			c.a = a
			_text(Vector2(x, y), part[0], 14, c, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
			x += _font.get_string_size(part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 8
		y += 26

func _draw_announce(vs: Vector2) -> void:
	if _announce.is_empty():
		return
	var a: Dictionary = _announce[0]
	var t: float = a["t"]
	var dur: float = a["dur"]
	var appear := clampf(t / 0.12, 0.0, 1.0)
	var fade := clampf((dur - t) / 0.35, 0.0, 1.0)
	var scale := lerpf(1.8, 1.0, ease(appear, 0.4))
	var c: Color = a["color"]
	c.a = fade
	var fsize := int(46 * scale)
	var y := vs.y * 0.3
	_text(Vector2(0, y), a["text"], fsize, c, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 8)
	if a["sub"] != "":
		_text(Vector2(0, y + 34), a["sub"], 20, Color(1, 1, 1, fade), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 5)

func _draw_crosshair(p: Player) -> void:
	var m := get_local_mouse_position()
	var def: Dictionary = p.current_def()
	var spread: float = def["spread"]
	if p.crouching:
		spread *= 0.55
	var gap := 5.0 + spread * 140.0 + p.kick * 0.8
	var col := Color(1, 1, 1, 0.9)
	var outline := Color(0, 0, 0, 0.6)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(m + d * gap, m + d * (gap + 8), outline, 4.0)
		draw_line(m + d * gap, m + d * (gap + 8), col, 2.0)
	draw_circle(m, 1.5, col)
	if p.hit_marker > 0.0:
		var hc := Color(1.0, 0.25, 0.2) if p.hit_marker_kill else Color(1, 1, 1)
		hc.a = p.hit_marker / 0.18
		var k := 6.0 + (1.0 - hc.a) * 4.0
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(m + d * k, m + d * (k + 7), hc, 2.5)
	if p.is_reloading():
		var total: float = def["reload"]
		var prog := 1.0 - p.reload_left / maxf(total, 0.01)
		draw_arc(m, 18, -PI * 0.5, -PI * 0.5 + TAU * prog, 32, Color(1, 1, 1, 0.8), 3.0)
	elif int(p.current()["mag"]) == 0:
		_text(m + Vector2(-60, 34), "RECHARGER (R)", 12, Color(1.0, 0.4, 0.3), HORIZONTAL_ALIGNMENT_CENTER, 120, 3)

func _draw_death(p: Player, vs: Vector2, human_count: int) -> void:
	var t := "Réapparition dans %.1f" % maxf(p.respawn_left, 0.0)
	if human_count == 1:
		draw_rect(Rect2(0, vs.y * 0.55 - 36, vs.x, 70), Color(0, 0, 0, 0.45))
		var who := "ÉLIMINÉ" if p.killed_by == "" else "ÉLIMINÉ PAR %s" % p.killed_by
		_text(Vector2(0, vs.y * 0.55), who, 28, Color(1.0, 0.35, 0.3), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 5)
		_text(Vector2(0, vs.y * 0.55 + 26), t, 16, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 3)
	else:
		var sp := get_viewport().get_canvas_transform() * p.global_position
		_text(sp + Vector2(-100, -20), t, 14, p.color.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER, 200, 3)

func _draw_vignette(humans: Array, vs: Vector2) -> void:
	var a := _vignette * 0.5
	if humans.size() == 1 and not humans[0].dead and humans[0].health < 35.0:
		a = maxf(a, 0.18 + 0.1 * sin(_time * 6.0))
	var c := Color(0.8, 0.0, 0.0, a)
	var clear := Color(0.8, 0.0, 0.0, 0.0)
	var e := minf(vs.x, vs.y) * 0.22
	# four edge gradients
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), Vector2(vs.x, e), Vector2(0, e)]), PackedColorArray([c, c, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, vs.y - e), Vector2(vs.x, vs.y - e), vs, Vector2(0, vs.y)]), PackedColorArray([clear, clear, c, c]))
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(e, 0), Vector2(e, vs.y), Vector2(0, vs.y)]), PackedColorArray([c, clear, clear, c]))
	draw_polygon(PackedVector2Array([Vector2(vs.x - e, 0), Vector2(vs.x, 0), vs, Vector2(vs.x - e, vs.y)]), PackedColorArray([clear, c, c, clear]))

func _draw_offscreen(players: Array, humans: Array, vs: Vector2) -> void:
	if humans.is_empty():
		return
	var xf := get_viewport().get_canvas_transform()
	var screen := Rect2(Vector2.ZERO, vs).grow(-30)
	var center := vs * 0.5
	for p in players:
		if p.dead or (p.is_human and humans.size() > 1):
			continue
		if humans.has(p):
			continue
		var sp: Vector2 = xf * p.global_position
		if screen.grow(20).has_point(sp):
			continue
		var dir := (sp - center).normalized()
		# intersect ray from center with the inset screen rect
		var tx := (screen.size.x * 0.5) / maxf(absf(dir.x), 0.001)
		var ty := (screen.size.y * 0.5) / maxf(absf(dir.y), 0.001)
		var edge := center + dir * minf(tx, ty)
		var c: Color = p.color
		c.a = 0.85
		var tri := PackedVector2Array([edge + dir * 12, edge + dir.rotated(2.4) * 10, edge + dir.rotated(-2.4) * 10])
		draw_colored_polygon(tri, c)
		var d := int(p.global_position.distance_to(humans[0].global_position) / 50.0)
		_text(edge - dir * 22 + Vector2(-30, 5), "%dm" % d, 11, c, HORIZONTAL_ALIGNMENT_CENTER, 60, 3)
