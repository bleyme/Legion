extends Node
## Title screen. A bot-only match runs behind the UI as an attract mode.
## Players pick who controls each slot (keyboard+mouse, second keyboard,
## gamepads, or bots of four skill levels), the arena and the match rules.

const MainScene := preload("res://scenes/main/main.tscn")

const SLOT_CHOICES := [
	{"label": "—", "type": "off"},
	{"label": "Clavier + souris", "type": "kbm"},
	{"label": "Clavier (flèches)", "type": "kb2"},
	{"label": "Manette 1", "type": "pad", "device": 0},
	{"label": "Manette 2", "type": "pad", "device": 1},
	{"label": "Manette 3", "type": "pad", "device": 2},
	{"label": "Manette 4", "type": "pad", "device": 3},
	{"label": "Bot · Recrue", "type": "bot", "level": 0},
	{"label": "Bot · Soldat", "type": "bot", "level": 1},
	{"label": "Bot · Vétéran", "type": "bot", "level": 2},
	{"label": "Bot · Légion", "type": "bot", "level": 3},
]
const FRAG_CHOICES := [5, 10, 15, 20, 30, 0]
const TIME_CHOICES := [120.0, 180.0, 300.0, 600.0, 0.0]

var _slot_buttons: Array[OptionButton] = []
var _team_buttons: Array[Button] = []
var _slot_teams: Array[int] = []
var _mode_button: OptionButton
var _swatches: Array[ColorRect] = []
var _map_button: OptionButton
var _arsenal_button: OptionButton
var _map_desc: Label
var _frag_button: OptionButton
var _time_button: OptionButton
var _error: Label
var _controls: PanelContainer
var _start: Button

func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.load_settings()
	Game.demo = true
	Music.set_enabled(Game.music_on)
	Music.play("menu")
	add_child(MainScene.instantiate())
	_build_ui()
	_start.grab_focus()
	Input.joy_connection_changed.connect(func(_d, _c): _apply())

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.make()
	layer.add_child(root)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.01, 0.03, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	root.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 40)
	margin.add_child(hbox)

	# ---- left: title + main buttons ---------------------------------------
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 14)
	hbox.add_child(left)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var title := UITheme.label("LÉGION", 110, UITheme.ACCENT)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	left.add_child(title)
	left.add_child(UITheme.label("Arène de combat 2D · jetpacks, roquettes et mauvaise foi", 18, UITheme.DIM))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	left.add_child(gap)

	_start = UITheme.button("COMBAT !", 28)
	_start.custom_minimum_size = Vector2(300, 62)
	_start.pressed.connect(_on_start)
	left.add_child(_start)
	var controls := UITheme.button("Commandes")
	controls.custom_minimum_size = Vector2(300, 44)
	controls.pressed.connect(func(): _controls.visible = not _controls.visible)
	left.add_child(controls)
	var quit := UITheme.button("Quitter")
	quit.custom_minimum_size = Vector2(300, 44)
	quit.pressed.connect(func(): get_tree().quit())
	left.add_child(quit)
	for b in [_start, controls, quit]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_error = UITheme.label("", 16, Color(1.0, 0.45, 0.35))
	left.add_child(_error)
	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer2)
	left.add_child(UITheme.label("F11 plein écran · Échap pause", 13, UITheme.DIM))

	# ---- right: match setup ---------------------------------------------------
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(430, 0)
	hbox.add_child(panel)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	panel.add_child(right)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 10)
	var mode_lbl := UITheme.label("MODE", 20, UITheme.ACCENT)
	mode_lbl.custom_minimum_size = Vector2(90, 0)
	mode_row.add_child(mode_lbl)
	_mode_button = OptionButton.new()
	_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_button.add_item("Chacun pour soi")
	_mode_button.add_item("Équipes (rouge vs bleue)")
	_mode_button.add_item("Survie (vagues de bots)")
	_mode_button.select({Game.MODE_FFA: 0, Game.MODE_TDM: 1, Game.MODE_SURVIVAL: 2}.get(Game.mode, 0))
	_mode_button.item_selected.connect(func(_i): _apply())
	mode_row.add_child(_mode_button)
	right.add_child(mode_row)
	right.add_child(_sep())
	right.add_child(UITheme.label("JOUEURS", 20, UITheme.ACCENT))
	for i in Game.MAX_SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var swatch := ColorRect.new()
		swatch.color = Game.PLAYER_COLORS[i]
		_swatches.append(swatch)
		swatch.custom_minimum_size = Vector2(8, 30)
		row.add_child(swatch)
		var lbl := UITheme.label("Slot %d" % (i + 1), 16)
		lbl.custom_minimum_size = Vector2(64, 0)
		row.add_child(lbl)
		var ob := OptionButton.new()
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.add_theme_font_size_override("font_size", 16)
		for c in SLOT_CHOICES:
			ob.add_item(c["label"])
		ob.select(_choice_index(Game.slots[i]))
		ob.item_selected.connect(func(_idx): _apply())
		row.add_child(ob)
		var tb := Button.new()
		tb.custom_minimum_size = Vector2(86, 0)
		tb.add_theme_font_size_override("font_size", 15)
		tb.pressed.connect(func(): _toggle_team(i))
		row.add_child(tb)
		right.add_child(row)
		_slot_buttons.append(ob)
		_team_buttons.append(tb)
		_slot_teams.append(int(Game.slots[i].get("team", i % 2)))

	right.add_child(_sep())
	right.add_child(UITheme.label("ARÈNE & ARSENAL", 20, UITheme.ACCENT))
	_map_button = OptionButton.new()
	for m in MapData.all():
		_map_button.add_item(m["name"])
	_map_button.select(clampi(Game.map_index, 0, MapData.all().size() - 1))
	_map_button.item_selected.connect(func(_i): _apply())
	_map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 10)
	map_row.add_child(_map_button)
	_arsenal_button = OptionButton.new()
	_arsenal_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for a in Game.ARSENALS:
		_arsenal_button.add_item("Armes : " + a["name"])
	_arsenal_button.select(maxi(0, Game.ARSENALS.map(func(a): return a["id"]).find(Game.arsenal)))
	_arsenal_button.item_selected.connect(func(_i): _apply())
	map_row.add_child(_arsenal_button)
	right.add_child(map_row)
	_map_desc = UITheme.label("", 14, UITheme.DIM)
	_map_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(_map_desc)

	right.add_child(_sep())
	var rules := HBoxContainer.new()
	rules.add_theme_constant_override("separation", 10)
	right.add_child(rules)
	var fcol := VBoxContainer.new()
	fcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fcol.add_child(UITheme.label("FRAGS", 16, UITheme.ACCENT))
	_frag_button = OptionButton.new()
	for f in FRAG_CHOICES:
		_frag_button.add_item("Illimité" if f == 0 else "%d frags" % f)
	_frag_button.select(maxi(0, FRAG_CHOICES.find(Game.frag_limit)))
	_frag_button.item_selected.connect(func(_i): _apply())
	fcol.add_child(_frag_button)
	rules.add_child(fcol)
	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.add_child(UITheme.label("DURÉE", 16, UITheme.ACCENT))
	_time_button = OptionButton.new()
	for t in TIME_CHOICES:
		_time_button.add_item("Illimitée" if t == 0.0 else "%d min" % int(t / 60.0))
	_time_button.select(maxi(0, TIME_CHOICES.find(Game.time_limit)))
	_time_button.item_selected.connect(func(_i): _apply())
	tcol.add_child(_time_button)
	rules.add_child(tcol)

	right.add_child(_sep())
	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 10)
	right.add_child(opts)
	opts.add_child(UITheme.label("VOLUME", 16, UITheme.ACCENT))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Game.volume
	vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol.value_changed.connect(_on_volume)
	opts.add_child(vol)
	var shake := CheckButton.new()
	shake.text = "Secousses"
	shake.button_pressed = Game.screen_shake
	shake.add_theme_font_size_override("font_size", 15)
	shake.toggled.connect(func(on): Game.screen_shake = on; Game.save_settings())
	opts.add_child(shake)
	var music := CheckButton.new()
	music.text = "Musique"
	music.button_pressed = Game.music_on
	music.add_theme_font_size_override("font_size", 15)
	music.toggled.connect(_on_music)
	opts.add_child(music)

	# ---- controls overlay ---------------------------------------------------------
	_controls = PanelContainer.new()
	_controls.visible = false
	_controls.set_anchors_preset(Control.PRESET_CENTER)
	_controls.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_controls.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_controls)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	_controls.add_child(cv)
	cv.add_child(UITheme.label("COMMANDES", 26, UITheme.ACCENT))
	var k := func(c: Key) -> String: return Game.key_label(c)
	var help := [
		["Clavier + souris", "%s%s%s%s : se déplacer   ·   Espace ou %s : sauter, maintenir en l'air = jetpack\n" % [k.call(KEY_W), k.call(KEY_A), k.call(KEY_S), k.call(KEY_D), k.call(KEY_W)]
			+ "%s : s'accroupir (plus précis)   ·   %s + saut : traverser une passerelle\n" % [k.call(KEY_S), k.call(KEY_S)]
			+ "Souris : viser   ·   Clic gauche : tirer   ·   Clic droit ou %s : grenade\n" % k.call(KEY_G)
			+ "%s : recharger   ·   %s ou %s : changer d'arme, ramasser l'arme au sol" % [k.call(KEY_R), k.call(KEY_Q), k.call(KEY_E)]],
		["Clavier (flèches)", "Flèches : se déplacer / sauter / jetpack   ·   Visée assistée automatique\nEntrée, Ctrl droit ou Pavé 0 : tirer   ·   Maj droit ou Pavé 1 : grenade\nRetour arrière ou Pavé 3 : recharger   ·   Pavé 2 ou « . » : changer d'arme"],
		["Manette", "Stick gauche : bouger   ·   Stick droit : viser (aide à la visée)\nRT/R1 : tirer   ·   LT/L1 : grenade   ·   A : saut/jetpack\nX : recharger   ·   Y : changer d'arme / ramasser   ·   Start : pause"],
		["Astuces", "Les roquettes et grenades vous projettent : rocket-jump !\nTir à la tête = dégâts bonus. Les armes des morts restent au sol.\nLe bouclier de réapparition disparaît dès que vous tirez."],
	]
	for h in help:
		cv.add_child(UITheme.label(h[0], 18, UITheme.TEXT))
		cv.add_child(UITheme.label(h[1], 14, UITheme.DIM))
	var close := UITheme.button("Fermer")
	close.pressed.connect(_close_controls)
	cv.add_child(close)
	_apply()

func _on_music(on: bool) -> void:
	Game.music_on = on
	Music.set_enabled(on)
	Game.save_settings()

func _on_volume(v: float) -> void:
	Game.volume = v
	Game.apply_volume()
	SoundManager.play("ui_move", Vector2.INF, -8.0)
	Game.save_settings()

func _toggle_team(i: int) -> void:
	_slot_teams[i] = 1 - _slot_teams[i]
	_apply()

func _close_controls() -> void:
	_controls.visible = false
	_start.grab_focus()

func _sep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", 10)
	return s

func _choice_index(slot: Dictionary) -> int:
	for i in SLOT_CHOICES.size():
		var c: Dictionary = SLOT_CHOICES[i]
		if c["type"] != slot["type"]:
			continue
		if c["type"] == "pad" and int(c["device"]) != int(slot.get("device", 0)):
			continue
		if c["type"] == "bot" and int(c["level"]) != int(slot.get("level", 1)):
			continue
		return i
	return 0

func _apply() -> void:
	for i in _slot_buttons.size():
		var c: Dictionary = SLOT_CHOICES[_slot_buttons[i].selected]
		Game.slots[i] = {"type": c["type"], "device": int(c.get("device", 0)), "level": int(c.get("level", 1)), "team": _slot_teams[i]}
	Game.mode = [Game.MODE_FFA, Game.MODE_TDM, Game.MODE_SURVIVAL][_mode_button.selected]
	var surv := Game.mode == Game.MODE_SURVIVAL
	_frag_button.disabled = surv
	_time_button.disabled = surv
	for i in _team_buttons.size():
		var tb := _team_buttons[i]
		var t := _slot_teams[i]
		tb.visible = Game.mode == Game.MODE_TDM
		_swatches[i].color = Game.TEAM_COLORS[t] if tb.visible else Game.PLAYER_COLORS[i]
		tb.disabled = Game.slots[i]["type"] == "off"
		tb.text = "Rouge" if t == 0 else "Bleue"
		tb.add_theme_color_override("font_color", Game.TEAM_COLORS[t])
		tb.add_theme_color_override("font_hover_color", Game.TEAM_COLORS[t].lightened(0.3))
		tb.add_theme_color_override("font_focus_color", Game.TEAM_COLORS[t].lightened(0.3))
	Game.map_index = _map_button.selected
	Game.arsenal = Game.ARSENALS[_arsenal_button.selected]["id"]
	Game.frag_limit = FRAG_CHOICES[_frag_button.selected]
	Game.time_limit = TIME_CHOICES[_time_button.selected]
	var map: Dictionary = MapData.all()[Game.map_index]
	_map_desc.text = map["desc"]
	if surv:
		var best := int(Game.best_waves.get(map["name"], 0))
		_map_desc.text = "Survie : les bots des slots sont ignorés, ils arrivent par vagues. " \
			+ ("Record : vague %d." % best if best > 0 else "Aucun record pour l'instant.")
	_error.text = _validate()
	_start.disabled = _error.text != ""
	_error.remove_theme_color_override("font_color")
	_error.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	if _error.text == "":
		var pads := Input.get_connected_joypads()
		for s in Game.slots:
			if s["type"] == "pad" and not pads.has(int(s["device"])):
				_error.text = "Attention : manette %d non détectée." % (int(s["device"]) + 1)
				_error.add_theme_color_override("font_color", UITheme.ACCENT)
				break

func _validate() -> String:
	var count := 0
	var seen := {}
	for s in Game.slots:
		if s["type"] == "off":
			continue
		count += 1
		var key: String = s["type"] + (str(s["device"]) if s["type"] == "pad" else "")
		if s["type"] != "bot" and seen.has(key):
			return "Chaque contrôleur ne peut servir qu'à un joueur."
		seen[key] = true
	if Game.mode == Game.MODE_SURVIVAL:
		if not Game.slots.any(func(x): return x["type"] not in ["off", "bot"]):
			return "La survie demande au moins un joueur humain."
		return ""
	if count < 2:
		return "Il faut au moins deux combattants."
	if Game.mode == Game.MODE_TDM:
		var sides := {}
		for s in Game.slots:
			if s["type"] != "off":
				sides[int(s["team"])] = true
		if sides.size() < 2:
			return "Chaque équipe doit avoir au moins un joueur."
	return ""

func _on_start() -> void:
	if _validate() != "":
		return
	Game.save_settings()
	Game.demo = false
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
