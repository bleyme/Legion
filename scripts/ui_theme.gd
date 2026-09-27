## Shared look for menus: dark translucent panels, amber accent.

const ACCENT := Color(1.0, 0.72, 0.2)
const TEXT := Color(0.92, 0.93, 0.95)
const DIM := Color(0.62, 0.66, 0.72)

static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18

	var normal := _box(Color(0.10, 0.12, 0.16, 0.92), Color(0.28, 0.32, 0.4), 2)
	var hover := _box(Color(0.16, 0.19, 0.25, 0.95), ACCENT, 2)
	var pressed := _box(Color(0.28, 0.2, 0.06, 0.95), ACCENT, 2)
	var focus := _box(Color(0, 0, 0, 0), ACCENT, 3)
	var disabled := _box(Color(0.08, 0.08, 0.1, 0.8), Color(0.2, 0.2, 0.24), 2)
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("hover_pressed", cls, pressed)
		t.set_stylebox("focus", cls, focus)
		t.set_stylebox("disabled", cls, disabled)
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_focus_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, ACCENT)
		t.set_color("font_disabled_color", cls, DIM)
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.05, 0.06, 0.09, 0.86), Color(0.22, 0.25, 0.32), 2, 14))
	t.set_stylebox("panel", "PopupMenu", _box(Color(0.07, 0.08, 0.11, 0.98), ACCENT, 2, 6))
	t.set_stylebox("hover", "PopupMenu", _box(Color(0.3, 0.22, 0.08, 1.0), Color(0, 0, 0, 0), 0, 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_color", "Label", TEXT)
	return t

static func _box(bg: Color, border: Color, width: int, margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(4)
	s.content_margin_left = margin + 4
	s.content_margin_right = margin + 4
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	return s

static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func button(text: String, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(240, 44)
	b.focus_entered.connect(func(): SoundManager.play("ui_move", Vector2.INF, -14.0))
	b.pressed.connect(func(): SoundManager.play("ui_ok", Vector2.INF, -10.0))
	return b
