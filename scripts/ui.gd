extends RefCounted
## Shared palette, fonts and widget builders for the code-built UI.

const TITLE_FONT = preload("res://fonts/DelaGothicOne-Regular.ttf")
const BODY_FONT = preload("res://fonts/ZenMaruGothic-Bold.ttf")

const GOLD := Color("#e8b04b")
const LACQUER := Color("#b3202a")
const CREAM := Color("#fff8ec")
const INK := Color("#1d1416")
const NIGHT := Color("#1a1430")
const PLAYER_COLORS := [
	Color("#7b4fa8"), Color("#2f6db5"), Color("#c0392b"), Color("#2e8b57"),
	Color("#d4781c"), Color("#b0417a"), Color("#3a8f9e"), Color("#8a6d1f"),
]


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = BODY_FONT
	t.default_font_size = 32
	var states := {
		"normal": box(LACQUER, GOLD, 4, 28),
		"hover": box(LACQUER.lightened(0.1), GOLD, 4, 28),
		"pressed": box(LACQUER.darkened(0.3), GOLD, 4, 28),
		"disabled": box(Color(0.3, 0.27, 0.32), Color(0.5, 0.47, 0.5), 4, 28),
	}
	for key: String in states:
		var s: StyleBoxFlat = states[key]
		s.content_margin_left = 36
		s.content_margin_right = 36
		s.content_margin_top = 12
		s.content_margin_bottom = 16
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 4)
		t.set_stylebox(key, "Button", s)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for key: String in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(key, "Button", CREAM)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(CREAM, 0.4))
	t.set_stylebox("normal", "LineEdit", box(Color("#2a2140"), GOLD, 3, 16))
	t.set_stylebox("focus", "LineEdit", box(Color("#352a52"), CREAM, 3, 16))
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("font_placeholder_color", "LineEdit", Color(CREAM, 0.4))
	t.set_color("font_color", "Label", CREAM)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(key, "CheckButton", CREAM)
	t.set_font_size("font_size", "CheckButton", 28)
	return t


static func box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(16)
	s.corner_detail = 10
	return s


static func label(text: String, font: Font, font_size: int, color: Color, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", INK)
	return l


static func button(text: String, font_size: int, min_width := 320) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", TITLE_FONT)
	b.add_theme_font_size_override("font_size", font_size)
	return b


static func spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func expand() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func full_rect(parent: Node) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


static func vbox(parent: Control, margin: int, separation := 12) -> VBoxContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, margin)
	parent.add_child(m)
	var b := VBoxContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_constant_override("separation", separation)
	m.add_child(b)
	return b


static func hbox(separation := 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", separation)
	return h


## A dimmed full-screen layer with a centred card; returns [layer, card, style, content].
static func overlay(parent: Node, bg: Color, min_width := 600) -> Array:
	var layer := full_rect(parent)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var card := PanelContainer.new()
	var style := box(bg, GOLD, 6, 40)
	style.set_content_margin_all(36)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 18
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(min_width, 0)
	card.resized.connect(func(): card.pivot_offset = card.size / 2)
	center.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)
	layer.visible = false
	return [layer, card, style, content]
