extends Node2D
## Match controller: builds the arena and players from Game settings, runs the
## deathmatch rules (frags, timer, respawns, streaks, announcer), and owns the
## pause and end-of-match screens. Also runs the bot-only demo behind the menu.

const RESPAWN_DELAY := 2.4
const COUNTDOWN := 2.4
const PlayerScene := preload("res://scenes/player/player.tscn")
const ArenaScript := preload("res://scenes/map/arena.gd")
const BackgroundScript := preload("res://scenes/fx/background_visual.gd")
const FxScript := preload("res://scenes/fx/fx.gd")
const ProjectilesScript := preload("res://scenes/weapons/projectiles.gd")
const PickupScript := preload("res://scenes/weapons/pickup.gd")
const CameraScript := preload("res://scenes/main/game_camera.gd")
const HudScript := preload("res://scenes/main/hud.gd")
const KbmController := preload("res://scenes/player/controllers/keyboard_mouse_controller.gd")
const KbController := preload("res://scenes/player/controllers/keyboard_controller.gd")
const PadController := preload("res://scenes/player/controllers/gamepad_controller.gd")
const BotController := preload("res://scenes/player/controllers/bot_controller.gd")

var arena: Node2D
var players: Array = []
var pickups: Array = []
var time_left := -1.0
var team_scores := [0, 0]
var teams := false
var survival := false
var wave := 0
var wave_break := 0.0
var wave_pending := 0
var _spawn_cd := 0.0
var _map_name := ""
const SURVIVAL_LIVES := 3
const ENEMY_COLOR := Color(0.85, 0.22, 0.18)
var match_over := false
var first_blood := false
var _demo := false
var _pickup_root: Node2D
var _player_root: Node2D
var _hud_layer: CanvasLayer
var _hud: Control
var _pause_layer: CanvasLayer
var _end_layer: CanvasLayer
var _recent_spawns := {}
var _hitstop := 0.0
var _slowmo := 0.0
## Seconds left in the 3-2-1 intro; players are frozen while > 0.
var countdown := 0.0
var _intro_sub := ""
var _last_count := -1
var _prev_best := 0

func _ready() -> void:
	_demo = Game.demo
	teams = Game.teams()
	survival = Game.survival()
	Game.world = self
	Engine.time_scale = 1.0
	var maps := MapData.all()
	var map: Dictionary = maps[clampi(Game.map_index, 0, maps.size() - 1)]
	if _demo:
		map = maps[randi() % maps.size()]
	_map_name = map["name"]

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var bg := Node2D.new()
	bg.set_script(BackgroundScript)
	bg_layer.add_child(bg)
	bg.setup(map["theme"])

	arena = Node2D.new()
	arena.set_script(ArenaScript)
	add_child(arena)
	arena.setup(map)
	Game.arena = arena

	_pickup_root = Node2D.new()
	add_child(_pickup_root)
	for spot in map["pickups"]:
		var pk := Node2D.new()
		pk.set_script(PickupScript)
		pk.kind = spot["kind"]
		pk.fixed = spot.get("fixed", "")
		pk.position = spot["pos"]
		_pickup_root.add_child(pk)
		pickups.append(pk)

	_player_root = Node2D.new()
	add_child(_player_root)

	var projectiles := Node2D.new()
	projectiles.set_script(ProjectilesScript)
	add_child(projectiles)
	Game.projectiles = projectiles

	var fx := Node2D.new()
	fx.set_script(FxScript)
	add_child(fx)
	Game.fx = fx

	var cam := Camera2D.new()
	cam.set_script(CameraScript)
	cam.arena_size = arena.size
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS   # required by physics interpolation
	add_child(cam)
	cam.make_current()
	Game.camera = cam

	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)
	_hud = Control.new()
	_hud.set_script(HudScript)
	_hud_layer.add_child(_hud)
	Game.hud = _hud
	_hud_layer.visible = not _demo

	_spawn_players()
	if Game.time_limit > 0.0 and not _demo and not survival:
		time_left = Game.time_limit
	_build_pause()
	_build_end()
	if not _demo:
		var sub: String = map["name"]
		if Game.arsenal_weapon() != "":
			for a in Game.ARSENALS:
				if a["id"] == Game.arsenal:
					sub += " · " + a["name"]
		_intro_sub = sub
		countdown = COUNTDOWN
		Music.play("combat")
		_hud.show_hints(players)
		var has_mouse := players.any(func(p): return p.is_mouse_user)
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if has_mouse else Input.MOUSE_MODE_VISIBLE

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if Game.world == self:
		Game.world = null
		Game.arena = null
		Game.fx = null
		Game.projectiles = null
		Game.camera = null
		Game.hud = null

func get_players() -> Array:
	return players

func frozen() -> bool:
	return countdown > 0.0

# --------------------------------------------------------------------------
# Setup
# --------------------------------------------------------------------------

func _spawn_players() -> void:
	var slots: Array = Game.slots
	if _demo:
		slots = [
			{"type": Game.SLOT_BOT, "level": 2}, {"type": Game.SLOT_BOT, "level": 3},
			{"type": Game.SLOT_BOT, "level": 1}, {"type": Game.SLOT_BOT, "level": 2},
		]
	var names := Game.BOT_NAMES.duplicate()
	names.shuffle()
	var human_n := 0
	var idx := 0
	for s in slots:
		if s["type"] == Game.SLOT_OFF:
			continue
		if survival and s["type"] == Game.SLOT_BOT:
			continue   # survival: bots come in waves instead
		var p: Player = PlayerScene.instantiate()
		var ctrl: RefCounted
		var human := true
		var mouse := false
		var nm := ""
		var hint := "Q"
		match s["type"]:
			Game.SLOT_KBM:
				ctrl = KbmController.new()
				mouse = true
				hint = "%s/%s" % [Game.key_label(KEY_Q), Game.key_label(KEY_E)]
			Game.SLOT_KB2:
				ctrl = KbController.new()
				hint = "Pavé2"
			Game.SLOT_PAD:
				ctrl = PadController.new(int(s.get("device", 0)))
				hint = "Y"
			_:
				ctrl = BotController.new(int(s.get("level", 1)))
				human = false
		if human:
			human_n += 1
			nm = "J%d" % human_n
		else:
			nm = names[idx % names.size()]
		var col: Color = Game.PLAYER_COLORS[idx % Game.PLAYER_COLORS.size()]
		if survival:
			p.team = 0
			p.lives = SURVIVAL_LIVES
		elif teams:
			p.team = int(s.get("team", idx % 2))
			var mates := players.filter(func(o): return o.team == p.team).size()
			col = Game.TEAM_COLORS[p.team].lightened(mates * 0.12)
		p.setup(idx + 1, nm, col, ctrl, human, mouse)
		p.swap_hint = hint
		if s["type"] == Game.SLOT_PAD:
			p.pad_device = int(s.get("device", 0))
		_player_root.add_child(p)
		p.died.connect(_on_player_died)
		players.append(p)
		p.respawn(_pick_spawn(p))
		idx += 1

func _pick_spawn(p: Player) -> Vector2:
	var now := Time.get_ticks_msec()
	var scored := []
	for sp in arena.spawns:
		var min_d := 99999.0
		for other in players:
			if other.dead or not Game.is_enemy(p, other):
				continue
			min_d = minf(min_d, other.global_position.distance_to(sp))
		if now - int(_recent_spawns.get(sp, -10000)) < 1500:
			min_d *= 0.2
		scored.append([min_d + randf() * 250.0, sp])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var choice: Vector2 = scored[0][1]
	_recent_spawns[choice] = now
	return choice + Vector2(0, -30)

func drop_weapon(w: Dictionary, at: Vector2, vel: Vector2) -> void:
	var pk := Node2D.new()
	pk.set_script(PickupScript)
	pk.kind = "weapon"
	pk.dropped = true
	pk.weapon_id = w["id"]
	pk.mag = int(w["mag"])
	pk.reserve = int(w["reserve"])
	pk.vel = vel
	pk.position = at
	_pickup_root.add_child.call_deferred(pk)
	pickups.append(pk)
	pk.tree_exited.connect(func(): pickups.erase(pk))

# --------------------------------------------------------------------------
# Rules
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.001)
	if _hitstop > 0.0:
		_hitstop -= real_dt
		if _hitstop <= 0.0 and _slowmo <= 0.0:
			Engine.time_scale = 1.0
	if _slowmo > 0.0:
		_slowmo -= real_dt
		Engine.time_scale = lerpf(1.0, 0.25, clampf(_slowmo / 1.0, 0.0, 1.0))
		if _slowmo <= 0.0:
			Engine.time_scale = 1.0
			if match_over and not _demo:
				_show_end()

	if match_over:
		return
	if countdown > 0.0:
		countdown -= delta
		var n := int(ceil(countdown / (COUNTDOWN / 3.0)))
		if n != _last_count and n > 0:
			_last_count = n
			_hud.announce(str(n), Color.WHITE, _intro_sub, COUNTDOWN / 3.0 - 0.02)
			SoundManager.play("ui_move", Vector2.INF, -2.0, 0.8)
		if countdown <= 0.0:
			_hud.announce("COMBAT !", UITheme.ACCENT, _intro_sub, 1.4)
			SoundManager.play("announce", Vector2.INF, -6.0)
		return
	if time_left > 0.0:
		var before := time_left
		time_left = maxf(0.0, time_left - delta)
		if before > 60.0 and time_left <= 60.0:
			_hud.announce("DERNIÈRE MINUTE", Color(1.0, 0.5, 0.3))
		if before > 10.0 and time_left <= 10.0:
			_hud.announce("10 SECONDES", Color(1.0, 0.4, 0.3))
		if time_left <= 0.0:
			_end_match()

	if survival:
		_survival_tick(delta)

	for p in players:
		if p.dead and not p.retired:
			p.respawn_left -= delta
			if p.respawn_left <= 0.0:
				p.respawn(_pick_spawn(p))

func _on_player_died(victim: Player, killer: Node, weapon_id: String, headshot: bool) -> void:
	victim.deaths += 1
	victim.respawn_left = RESPAWN_DELAY
	victim.killed_by = ""
	var k := killer as Player
	_hud.add_kill(killer, victim, weapon_id, headshot)
	if match_over:
		return
	if survival:
		_survival_death(victim, k, headshot)
		return
	if k and k != victim:
		victim.killed_by = k.display_name
		k.kills += 1
		if teams:
			team_scores[k.team] += 1
		k.streak += 1
		k.best_streak = maxi(k.best_streak, k.streak)
		k.multi_kills = k.multi_kills + 1 if k.multi_timer > 0.0 else 1
		k.multi_timer = 3.0
		if k.is_human:
			SoundManager.play("kill", Vector2.INF, -6.0)
		_announce_kill(k, victim, headshot)
		if k.is_human or victim.is_human:
			_hitstop_now(0.06)
		var score: int = team_scores[k.team] if teams else k.kills
		if Game.frag_limit > 0 and score >= Game.frag_limit and not _demo:
			_end_match()
		elif _demo and k.kills >= 25:
			for p in players:
				p.kills = 0
	else:
		victim.kills = maxi(0, victim.kills - 1)
		if teams:
			team_scores[victim.team] = maxi(0, team_scores[victim.team] - 1)
		if victim.is_human:
			_hud.announce("SUICIDE", Color(0.8, 0.8, 0.8), "-1 frag", 1.4)

# --------------------------------------------------------------------------
# Survival: endless waves of bots against the humans
# --------------------------------------------------------------------------

func enemies_left() -> int:
	var n := wave_pending
	for p in players:
		if not p.is_human and not p.dead:
			n += 1
	return n

func _survival_tick(delta: float) -> void:
	if wave_break > 0.0:
		wave_break -= delta
		if wave_break <= 0.0:
			_start_wave()
		return
	if wave == 0:
		wave_break = 1.0
		return
	# Trickle enemies in, never too many alive at once.
	_spawn_cd -= delta
	var alive := 0
	for p in players:
		if not p.is_human and not p.dead:
			alive += 1
	var cap := mini(2 + wave / 3, 7)
	if wave_pending > 0 and alive < cap and _spawn_cd <= 0.0:
		_spawn_cd = maxf(0.35, 1.2 - wave * 0.06)
		wave_pending -= 1
		_spawn_enemy()
	if wave_pending == 0 and alive == 0:
		_wave_cleared()

func _start_wave() -> void:
	wave += 1
	wave_pending = mini(3 + wave + wave / 2, 30)
	_spawn_cd = 0.5
	var sub := "%d ennemis" % wave_pending
	if wave % 5 == 0:
		sub += " · vague d'élite"
	_hud.announce("VAGUE %d" % wave, ENEMY_COLOR.lightened(0.3), sub, 2.0)
	SoundManager.play("announce", Vector2.INF, -4.0)

func _wave_cleared() -> void:
	wave_break = 5.0
	var bonus := ""
	for p in players:
		if not p.is_human:
			continue
		if p.retired or p.dead:
			continue
		p.health = Player.MAX_HEALTH
		p.grenades = maxi(p.grenades, Player.START_GRENADES)
	if wave % 3 == 0:
		for p in players:
			if p.is_human and p.lives >= 0:
				p.lives += 1
				if p.retired:
					p.retired = false
					p.respawn(_pick_spawn(p))
		bonus = " · +1 vie"
	_hud.announce("VAGUE %d NETTOYÉE" % wave, UITheme.ACCENT, "Soins complets" + bonus, 2.2)
	SoundManager.play("health", Vector2.INF, -4.0)

func _spawn_enemy() -> void:
	# Difficulty ramps with the wave number; elite waves are all veterans+.
	var level := clampi((wave - 1) / 4 + (randi() % 2 if wave > 4 else 0), 0, 3)
	if wave % 5 == 0:
		level = mini(level + 1, 3)   # elite wave
	var p: Player = null
	for other in players:
		if not other.is_human and other.retired:
			p = other
			break
	if p == null:
		p = PlayerScene.instantiate()
		var nm: String = Game.BOT_NAMES[players.size() % Game.BOT_NAMES.size()]
		p.setup(players.size() + 1, nm, ENEMY_COLOR.darkened(randf() * 0.35), null, false, false)
		p.team = 1
		_player_root.add_child(p)
		p.died.connect(_on_player_died)
		players.append(p)
	p.controller = BotController.new(level)
	p.retired = false
	p.respawn(_pick_spawn(p))
	p.shield = 0.4
	if randf() < clampf(0.1 * (wave - 2), 0.0, 0.8):
		p.give_weapon(WeaponData.random_pickup_id())

func _survival_death(victim: Player, k: Player, headshot: bool) -> void:
	if not victim.is_human:
		victim.retired = true
		if k and k.is_human:
			k.kills += 1
			k.streak += 1
			k.best_streak = maxi(k.best_streak, k.streak)
			k.multi_kills = k.multi_kills + 1 if k.multi_timer > 0.0 else 1
			k.multi_timer = 3.0
			SoundManager.play("kill", Vector2.INF, -6.0)
			_announce_kill(k, victim, headshot)
			_hitstop_now(0.05)
		return
	if k and k != victim:
		victim.killed_by = k.display_name
	victim.lives -= 1
	if victim.lives <= 0:
		victim.retired = true
		_hud.announce("%s EST TOMBÉ" % victim.display_name, Color(1.0, 0.35, 0.3), "", 1.6)
	if players.all(func(p): return not p.is_human or p.retired):
		_end_match()

func _announce_kill(k: Player, victim: Player, headshot: bool) -> void:
	if _demo:
		return
	var col := k.color.lightened(0.2)
	if not first_blood:
		first_blood = true
		_hud.announce("PREMIER SANG", Color(1.0, 0.3, 0.25), k.display_name)
		SoundManager.play("announce", Vector2.INF, -6.0)
		return
	var multi := ["", "", "DOUBLÉ !", "TRIPLÉ !", "MASSACRE !", "CARNAGE !!"]
	if k.multi_kills >= 2:
		_hud.announce(multi[mini(k.multi_kills, multi.size() - 1)], col, k.display_name)
		SoundManager.play("announce", Vector2.INF, -6.0)
	elif k.streak in [3, 5, 8, 12]:
		var names := {3: "EN SÉRIE", 5: "DÉCHAÎNÉ", 8: "IMPARABLE", 12: "LÉGENDAIRE"}
		_hud.announce(names[k.streak], col, "%s : %d frags d'affilée" % [k.display_name, k.streak])
		SoundManager.play("announce", Vector2.INF, -6.0)
	elif headshot and k.is_human:
		_hud.announce("TIR À LA TÊTE", Color(1.0, 0.45, 0.3), "", 1.0)
	if victim.streak >= 3:
		_hud.announce("SÉRIE STOPPÉE", col, "%s arrête %s" % [k.display_name, victim.display_name], 1.5)

func _hitstop_now(duration: float) -> void:
	if _slowmo > 0.0:
		return
	_hitstop = duration
	Engine.time_scale = 0.08

func _end_match() -> void:
	if match_over:
		return
	match_over = true
	for p in players:
		p.controller = null
		p.input = PlayerInput.new()
	_slowmo = 1.2
	Engine.time_scale = 0.25
	if survival:
		_prev_best = int(Game.best_waves.get(_map_name, 0))
		if wave > _prev_best:
			Game.best_waves[_map_name] = wave
			Game.save_settings()
	_hud.announce("FIN DU MATCH", UITheme.ACCENT, _winner_text(), 2.0)
	SoundManager.play("announce", Vector2.INF, -4.0)

func _winner_text() -> String:
	if survival:
		return "Vague %d atteinte" % wave
	if teams:
		if team_scores[0] == team_scores[1]:
			return "Égalité !"
		return "L'équipe %s l'emporte !" % Game.TEAM_NAMES[0 if team_scores[0] > team_scores[1] else 1].to_lower()
	return "%s l'emporte !" % _ranking()[0].display_name

func _ranking() -> Array:
	var sorted := players.duplicate()
	sorted.sort_custom(func(a, b): return a.kills > b.kills or (a.kills == b.kills and a.deaths < b.deaths))
	return sorted

# --------------------------------------------------------------------------
# Pause & end screens
# --------------------------------------------------------------------------

## Called by the Game autoload (which keeps processing while paused).
func toggle_pause() -> void:
	if _demo or match_over:
		return
	_set_paused(not get_tree().paused)

func _set_paused(on: bool) -> void:
	get_tree().paused = on
	_pause_layer.visible = on
	var has_mouse := players.any(func(p): return p.is_mouse_user)
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		(_pause_layer.get_node("Center/Panel/VBox/Resume") as Button).grab_focus()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if has_mouse else Input.MOUSE_MODE_VISIBLE

func _make_overlay(layer_index: int) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = layer_index
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.visible = false
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = UITheme.make()
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	return layer

func _build_pause() -> void:
	_pause_layer = _make_overlay(30)
	var vbox := _pause_layer.get_node("Center/Panel/VBox")
	var title := UITheme.label("PAUSE", 40, UITheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var resume := UITheme.button("Reprendre")
	resume.name = "Resume"
	resume.pressed.connect(func(): _set_paused(false))
	vbox.add_child(resume)
	var restart := UITheme.button("Recommencer")
	restart.pressed.connect(_restart)
	vbox.add_child(restart)
	var menu := UITheme.button("Menu principal")
	menu.pressed.connect(_to_menu)
	vbox.add_child(menu)
	var help := UITheme.label(_controls_text(), 13, UITheme.DIM)
	vbox.add_child(help)

func _controls_text() -> String:
	var k := func(c: Key) -> String: return Game.key_label(c)
	var move: String = k.call(KEY_W) + k.call(KEY_A) + k.call(KEY_S) + k.call(KEY_D)
	return "J1 : %s bouger · Espace/%s saut + jetpack (maintenir) · %s accroupi (%s+saut : traverser)\n" % [move, k.call(KEY_W), k.call(KEY_S), k.call(KEY_S)] \
		+ "     Souris viser/tirer · Clic droit/%s grenade · %s recharger · %s/%s changer d'arme / ramasser\n" % [k.call(KEY_G), k.call(KEY_R), k.call(KEY_Q), k.call(KEY_E)] \
		+ "J2 : Flèches · Entrée/Ctrl droit tirer · Maj droit grenade · Retour arrière recharger · Pavé 2 changer\n" \
		+ "Manette : stick gauche bouger · stick droit viser · RT tirer · LT grenade · A saut · X recharger · Y changer"

func _build_end() -> void:
	_end_layer = _make_overlay(40)

func _show_end() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var vbox := _end_layer.get_node("Center/Panel/VBox")
	var ranking := _ranking()
	var winner: Player = ranking[0]
	var tie: bool = ranking.size() > 1 and ranking[1].kills == winner.kills and ranking[1].deaths == winner.deaths
	var title_text := "ÉGALITÉ !" if tie else "%s GAGNE !" % winner.display_name.to_upper()
	var title_col := UITheme.ACCENT if tie else winner.color.lightened(0.25)
	if teams:
		tie = team_scores[0] == team_scores[1]
		var wt := 0 if team_scores[0] > team_scores[1] else 1
		title_text = "ÉGALITÉ %d – %d" % team_scores if tie else "ÉQUIPE %s GAGNE %d – %d" % [Game.TEAM_NAMES[wt], team_scores[wt], team_scores[1 - wt]]
		title_col = UITheme.ACCENT if tie else Game.TEAM_COLORS[wt]
	if survival:
		ranking = ranking.filter(func(p): return p.is_human)
		title_text = "VAGUE %d ATTEINTE" % wave
		title_col = ENEMY_COLOR.lightened(0.35)
	var title := UITheme.label(title_text, 44, title_col)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	if survival:
		var rec := "NOUVEAU RECORD !" if wave > _prev_best else "Record sur %s : vague %d" % [_map_name, _prev_best]
		var rl := UITheme.label(rec, 20, UITheme.ACCENT if wave > _prev_best else UITheme.DIM)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(rl)

	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 6)
	for h in ["#", "Joueur", "Frags", "Morts", "Ratio", "Série max", "Précision"]:
		grid.add_child(UITheme.label(h, 15, UITheme.DIM))
	for i in ranking.size():
		var p: Player = ranking[i]
		var acc := "-" if p.shots == 0 else "%d%%" % mini(100, int(100.0 * p.hits / p.shots))
		var ratio := "%.2f" % (float(p.kills) / maxf(1.0, p.deaths))
		var cells := [str(i + 1), p.display_name, str(p.kills), str(p.deaths), ratio, str(p.best_streak), acc]
		for c in cells.size():
			var col := p.color.lightened(0.3) if c == 1 else UITheme.TEXT
			grid.add_child(UITheme.label(cells[c], 18, col))
	vbox.add_child(grid)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var again := UITheme.button("Rejouer")
	again.pressed.connect(_restart)
	row.add_child(again)
	var menu := UITheme.button("Menu principal")
	menu.pressed.connect(_to_menu)
	row.add_child(menu)
	vbox.add_child(row)
	_end_layer.visible = true
	_hud_layer.visible = false
	again.grab_focus()

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")
