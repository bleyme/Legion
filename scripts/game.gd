extends Node
## Global game state: match settings, input bindings, shared references.

const PLAYER_COLORS := [
	Color(0.36, 0.78, 0.32),
	Color(0.98, 0.50, 0.14),
	Color(0.30, 0.62, 1.00),
	Color(0.92, 0.30, 0.62),
	Color(0.96, 0.84, 0.22),
	Color(0.30, 0.92, 0.86),
]
const BOT_NAMES := [
	"Viper", "Raptor", "Ghost", "Brutus", "Nova", "Spectre",
	"Hyène", "Cobra", "Titan", "Faucon", "Loup", "Orage",
]
const BOT_LEVEL_NAMES := ["Recrue", "Soldat", "Vétéran", "Légion"]
const MAX_SLOTS := 6

# Slot types
const SLOT_OFF := "off"
const SLOT_KBM := "kbm"
const SLOT_KB2 := "kb2"
const SLOT_PAD := "pad"
const SLOT_BOT := "bot"

var slots: Array = [
	{"type": SLOT_KBM, "device": 0, "level": 1, "team": 0},
	{"type": SLOT_BOT, "device": 0, "level": 1, "team": 1},
	{"type": SLOT_BOT, "device": 0, "level": 1, "team": 1},
	{"type": SLOT_OFF, "device": 0, "level": 1, "team": 0},
	{"type": SLOT_OFF, "device": 0, "level": 1, "team": 0},
	{"type": SLOT_OFF, "device": 0, "level": 1, "team": 1},
]
const MODE_FFA := "ffa"
const MODE_TDM := "tdm"
const TEAM_COLORS := [Color(1.0, 0.38, 0.3), Color(0.32, 0.62, 1.0)]
const TEAM_NAMES := ["ROUGE", "BLEUE"]

var mode := MODE_FFA
## Weapon mutator: "all" or a single weapon id everyone spawns with.
const ARSENALS := [
	{"id": "all", "name": "Complet"},
	{"id": "rocket", "name": "Roquettes"},
	{"id": "railgun", "name": "Railgun instagib"},
	{"id": "shotgun", "name": "Fusils à pompe"},
	{"id": "sniper", "name": "Snipers"},
]
var arsenal := "all"
var volume := 0.8          # master volume, 0..1
var screen_shake := true
var map_index  := 0
var frag_limit := 15
var time_limit := 300.0   # seconds, 0 = unlimited

## Set while a match scene is alive.
var world: Node = null
var arena: Node = null
var fx: Node = null
var projectiles: Node = null
var camera: Node = null
var hud: Node = null
var demo := false

## Soft radial sprite shared by glows, smoke and flashes.
var soft_tex: GradientTexture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	load_settings()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	soft_tex = GradientTexture2D.new()
	soft_tex.gradient = g
	soft_tex.fill = GradientTexture2D.FILL_RADIAL
	soft_tex.fill_from = Vector2(0.5, 0.5)
	soft_tex.fill_to = Vector2(1.0, 0.5)
	soft_tex.width = 64
	soft_tex.height = 64

## Set by a mouse-wheel notch, consumed by the keyboard+mouse controller.
var wheel_swap := false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and \
			(event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		wheel_swap = true
		return
	if event.is_action_pressed("pause") and world and world.has_method("toggle_pause"):
		world.toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_fullscreen"):
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)

## Name of the key at a physical position on the user's own layout
## (e.g. physical Q shows as "A" on AZERTY).
func key_label(physical: Key) -> String:
	if DisplayServer.get_name() == "headless":
		return OS.get_keycode_string(physical)
	return OS.get_keycode_string(DisplayServer.keyboard_get_label_from_physical(physical))

## Single-weapon mutator active? (never in the menu demo)
func arsenal_weapon() -> String:
	return "" if arsenal == "all" or demo else arsenal

func instagib() -> bool:
	return arsenal_weapon() == "railgun"

func teams() -> bool:
	return mode == MODE_TDM and not demo

## True if `b` is someone `a` should shoot at.
func is_enemy(a: Node, b: Node) -> bool:
	if a == b or a == null or b == null:
		return false
	return a.team < 0 or a.team != b.team

func active_players() -> Array:
	if world and world.has_method("get_players"):
		return world.get_players()
	return []

func shake(amount: float, at := Vector2.INF) -> void:
	if camera and screen_shake:
		camera.add_trauma(amount, at)

# --------------------------------------------------------------------------
# Input map (registered at runtime so bindings live in one readable place).
# Physical keycodes are layout independent: WASD == ZQSD on AZERTY.
# --------------------------------------------------------------------------

func _register_inputs() -> void:
	_bind("p1_left",    [_key(KEY_A)])
	_bind("p1_right",   [_key(KEY_D)])
	_bind("p1_jump",    [_key(KEY_W), _key(KEY_SPACE)])
	_bind("p1_down",    [_key(KEY_S)])
	_bind("p1_shoot",   [_mouse(MOUSE_BUTTON_LEFT)])
	_bind("p1_grenade", [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_G)])
	_bind("p1_reload",  [_key(KEY_R)])
	_bind("p1_swap",    [_key(KEY_Q), _key(KEY_E), _mouse(MOUSE_BUTTON_MIDDLE)])

	_bind("p2_left",    [_key(KEY_LEFT)])
	_bind("p2_right",   [_key(KEY_RIGHT)])
	_bind("p2_jump",    [_key(KEY_UP)])
	_bind("p2_down",    [_key(KEY_DOWN)])
	_bind("p2_shoot",   [_key(KEY_ENTER), _key(KEY_KP_0), _key(KEY_CTRL, KEY_LOCATION_RIGHT)])
	_bind("p2_grenade", [_key(KEY_SHIFT, KEY_LOCATION_RIGHT), _key(KEY_KP_1)])
	_bind("p2_reload",  [_key(KEY_BACKSPACE), _key(KEY_KP_3)])
	_bind("p2_swap",    [_key(KEY_KP_2), _key(KEY_PERIOD)])

	_bind("pause",             [_key(KEY_ESCAPE), _key(KEY_P), _joy(JOY_BUTTON_START)])
	_bind("toggle_fullscreen", [_key(KEY_F11)])

func _bind(action: String, events: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.5)
	for e in events:
		InputMap.action_add_event(action, e)

func _key(code: Key, location := KEY_LOCATION_UNSPECIFIED) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.location = location
	return e

func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e

func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = -1
	return e

# --------------------------------------------------------------------------
# Settings persistence
# --------------------------------------------------------------------------

const SETTINGS_PATH := "user://legion.cfg"

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("match", "slots", slots)
	cfg.set_value("match", "map_index", map_index)
	cfg.set_value("match", "frag_limit", frag_limit)
	cfg.set_value("match", "time_limit", time_limit)
	cfg.set_value("match", "mode", mode)
	cfg.set_value("match", "arsenal", arsenal)
	cfg.set_value("options", "volume", volume)
	cfg.set_value("options", "screen_shake", screen_shake)
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var s = cfg.get_value("match", "slots", slots)
	if s is Array and s.size() == MAX_SLOTS:
		slots = s
	map_index = int(cfg.get_value("match", "map_index", map_index))
	frag_limit = int(cfg.get_value("match", "frag_limit", frag_limit))
	time_limit = float(cfg.get_value("match", "time_limit", time_limit))
	mode = str(cfg.get_value("match", "mode", mode))
	arsenal = str(cfg.get_value("match", "arsenal", arsenal))
	volume = float(cfg.get_value("options", "volume", volume))
	screen_shake = bool(cfg.get_value("options", "screen_shake", screen_shake))
	apply_volume()
	for i in slots.size():
		if not slots[i].has("team"):
			slots[i]["team"] = i % 2
