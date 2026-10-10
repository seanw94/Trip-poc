extends Control
## べく杯 (bekuhai), Tosa's drinking-game top. Flick it; whoever the spike
## points at drinks from the cup of the face that lands on top. Every screen
## is built in code so the project stays a handful of text files.

enum State { TITLE, SETUP, PLAY, SPINNING, REVEAL }

const Faces = preload("res://scripts/faces.gd")
const Koma = preload("res://scripts/koma.gd")
const Table = preload("res://scripts/table.gd")
const Sfx = preload("res://scripts/sfx.gd")
const FaceView = preload("res://scripts/face_view.gd")
const TITLE_FONT = preload("res://fonts/DelaGothicOne-Regular.ttf")
const BODY_FONT = preload("res://fonts/ZenMaruGothic-Bold.ttf")

const DEFAULT_NAMES := ["龍馬", "慎太郎", "半平太", "以蔵", "弥太郎", "お龍", "容堂", "象二郎"]
const MIN_PLAYERS := 2
const MAX_PLAYERS := 8
const KANPAI_CHANCE := 0.08
const GRAB_RADIUS := 190.0
const SEAT_SIZE := Vector2(156, 84)
const SAVE_PATH := "user://bekuhai.cfg"

const GOLD := Color("#e8b04b")
const LACQUER := Color("#b3202a")
const CREAM := Color("#fff8ec")
const INK := Color("#1d1416")
const CARD_COLORS := [Color("#c2456b"), Color("#2f5ea8"), Color("#a3172b")]
const KANPAI_COLOR := Color("#9a6b12")

var state := State.TITLE
var player_count := 4
var saved_names: Array[String] = []
var names: Array[String] = []
var drinks: Array[int] = []
var chosen := 0
var chosen_face := 0
var kanpai := false
var next_hint := ""

var world: Node2D
var table
var koma
var sfx
var confetti: CPUParticles2D
var seats: Array[PanelContainer] = []
var seat_styles: Array[StyleBoxFlat] = []
var seat_names: Array[Label] = []
var seat_counts: Array[Label] = []

var title_screen: Control
var setup_screen: Control
var play_hud: Control
var reveal: Control
var count_label: Label
var name_edits: Array[LineEdit] = []
var hint_label: Label
var spin_button: Button
var card: PanelContainer
var card_style: StyleBoxFlat
var face_view
var reveal_name: Label
var reveal_cup: Label
var reveal_rule: Label

var _shake := 0.0
var _touch := -1
var _grab_angle := 0.0
var _spin_samples: Array[Vector2] = []  # (time, angular velocity)
var _drag_speed := 0.0
var _last_drag := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# names with kanji the display font lacks fall back to the body font
	var title_font: FontFile = TITLE_FONT
	var fallbacks: Array[Font] = [BODY_FONT]
	title_font.fallbacks = fallbacks
	theme = _make_theme()
	DisplayServer.screen_set_keep_on(true)
	_load()

	sfx = Sfx.new()
	add_child(sfx)

	world = Node2D.new()
	add_child(world)
	table = Table.new()
	world.add_child(table)
	for i in MAX_PLAYERS:
		_make_seat()
	koma = Koma.new()
	world.add_child(koma)
	koma.connect("ticked", _on_tick)
	koma.connect("stopped", _on_stopped)

	title_screen = _build_title()
	setup_screen = _build_setup()
	play_hud = _build_hud()
	reveal = _build_reveal()
	confetti = _build_confetti()
	add_child(confetti)

	get_viewport().size_changed.connect(_layout)
	_layout()
	_enter(State.TITLE)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, 70.0 * delta)
		world.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	elif world.position != Vector2.ZERO:
		world.position = Vector2.ZERO


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	match state:
		State.TITLE:
			get_tree().quit()
		State.SETUP:
			_enter(State.TITLE)
		State.PLAY:
			show_setup()


# --- public API (also driven by tests/smoke.gd) ---

func show_setup() -> void:
	set_player_count(player_count)
	_enter(State.SETUP)


func set_player_count(n: int) -> void:
	player_count = clampi(n, MIN_PLAYERS, MAX_PLAYERS)
	count_label.text = str(player_count)
	for i in name_edits.size():
		name_edits[i].visible = i < player_count


func start_play() -> void:
	names.clear()
	drinks.clear()
	for i in player_count:
		var n := name_edits[i].text.strip_edges()
		if n.is_empty():
			n = DEFAULT_NAMES[i]
		names.append(n)
		drinks.append(0)
		saved_names[i] = n
	_save()
	next_hint = "コマをつかんで、シュッと回せ！"
	_refresh_seats()
	_highlight(-1)
	_layout()
	_enter(State.PLAY)


func spin_random() -> void:
	if state == State.PLAY:
		_start_spin(randf_range(16.0, 34.0) * (1.0 if randf() < 0.5 else -1.0))


func is_revealing() -> bool:
	return state == State.REVEAL


func drink() -> void:
	if state != State.REVEAL:
		return
	if kanpai:
		for i in drinks.size():
			drinks[i] += 1
	else:
		drinks[chosen] += 1
	sfx.clink()
	_finish_round("次は%sが回す番！" % names[chosen])


func pass_water() -> void:
	if state != State.REVEAL:
		return
	sfx.click()
	_finish_round("%sはお水でひと休み。次も%sが回す！" % [names[chosen], names[chosen]])


func total_drinks() -> int:
	var total := 0
	for d in drinks:
		total += d
	return total


# --- game flow ---

func _enter(s: State) -> void:
	state = s
	var playing := s == State.PLAY or s == State.SPINNING or s == State.REVEAL
	title_screen.visible = s == State.TITLE
	setup_screen.visible = s == State.SETUP
	play_hud.visible = playing
	reveal.visible = s == State.REVEAL
	table.show_table = s != State.SETUP
	table.queue_redraw()
	koma.visible = s != State.SETUP
	koma.idle = s == State.TITLE
	for i in seats.size():
		seats[i].visible = playing and i < names.size()
	spin_button.disabled = s != State.PLAY
	if s == State.PLAY:
		hint_label.text = next_hint
	_touch = -1


func _start_spin(speed: float) -> void:
	_enter(State.SPINNING)
	hint_label.text = "回れ回れ〜！"
	_highlight(-1)
	koma.spin(speed)
	sfx.whoosh()
	Input.vibrate_handheld(30)


func _on_tick(speed: float) -> void:
	sfx.tick(speed)


func _on_stopped(face: int) -> void:
	if state != State.SPINNING:
		return
	chosen_face = face
	chosen = _seat_for_angle(koma.rotation)
	kanpai = randf() < KANPAI_CHANCE
	_highlight(chosen)
	hint_label.text = "全員カンパイ！？" if kanpai else "%s！" % names[chosen]
	sfx.don()
	Input.vibrate_handheld(220)
	_shake = 22.0
	await get_tree().create_timer(0.9).timeout
	if state == State.SPINNING:
		_show_reveal()


func _show_reveal() -> void:
	_enter(State.REVEAL)
	if kanpai:
		card_style.bg_color = KANPAI_COLOR
		face_view.face = -1
		reveal_name.text = "全員！"
		reveal_cup.text = "カンパイ！！"
		reveal_rule.text = "みんなで乾杯！\n好きな杯でどうぞ。"
	else:
		card_style.bg_color = CARD_COLORS[chosen_face]
		face_view.face = chosen_face
		reveal_name.text = "%s！" % names[chosen]
		reveal_cup.text = "%sの杯！" % Faces.NAMES[chosen_face]
		reveal_rule.text = Faces.RULES[chosen_face]
	face_view.queue_redraw()

	card.scale = Vector2(0.2, 0.2)
	card.modulate.a = 0.0
	var pop := create_tween().set_parallel()
	pop.tween_property(card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(card, "modulate:a", 1.0, 0.2)
	var wobble := create_tween()
	for angle in [0.18, -0.14, 0.09, -0.05, 0.0]:
		wobble.tween_property(face_view, "rotation", angle, 0.12)
	confetti.restart()
	sfx.fanfare()


func _finish_round(hint: String) -> void:
	next_hint = hint
	_refresh_seats()
	_enter(State.PLAY)


func _seat_for_angle(angle: float) -> int:
	var best := 0
	var best_gap := INF
	for i in names.size():
		var gap := absf(wrapf(angle - _seat_angle(i), -PI, PI))
		if gap < best_gap:
			best_gap = gap
			best = i
	return best


func _seat_angle(i: int) -> float:
	return -PI / 2 + TAU * i / maxi(names.size(), 1)


func _refresh_seats() -> void:
	var top := 0
	for d in drinks:
		top = maxi(top, d)
	for i in names.size():
		seat_names[i].text = names[i]
		var boss := " 酒豪!" if top > 0 and drinks[i] == top else ""
		seat_counts[i].text = "%d杯%s" % [drinks[i], boss]


func _highlight(index: int) -> void:
	for i in seats.size():
		var on := i == index
		seat_styles[i].bg_color = LACQUER if on else Color(INK, 0.88)
		seat_styles[i].border_color = CREAM if on else GOLD
		var tw := seats[i].create_tween()
		if on:
			tw.tween_property(seats[i], "scale", Vector2(1.3, 1.3), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		else:
			tw.tween_property(seats[i], "scale", Vector2.ONE, 0.15)


func _layout() -> void:
	var view := get_viewport_rect().size
	var center := Vector2(view.x * 0.5, view.y * 0.46)
	var seat_r := minf(view.x * 0.5 - 90.0, view.y * 0.3)
	table.view = view
	table.center = center
	table.radius = seat_r - 24.0
	table.queue_redraw()
	koma.position = center
	for i in names.size():
		seats[i].position = center + Vector2.from_angle(_seat_angle(i)) * seat_r - SEAT_SIZE / 2
	confetti.position = Vector2(view.x * 0.5, view.y * 0.4)


# --- flick to spin ---

func _input(event: InputEvent) -> void:
	if state != State.PLAY:
		return
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)


func _on_touch(t: InputEventScreenTouch) -> void:
	var rel: Vector2 = t.position - koma.global_position
	if t.pressed:
		if _touch == -1 and rel.length() < GRAB_RADIUS:
			_touch = t.index
			_grab_angle = rel.angle()
			_spin_samples.clear()
			_drag_speed = 0.0
			_last_drag = _now()
	elif t.index == _touch:
		_touch = -1
		_fling()


func _on_drag(d: InputEventScreenDrag) -> void:
	if d.index != _touch:
		return
	var rel: Vector2 = d.position - koma.global_position
	var now := _now()
	_drag_speed = d.velocity.length()
	if rel.length() > 30.0:  # too close to the middle, the angle is noise
		var a := rel.angle()
		var da := wrapf(a - _grab_angle, -PI, PI)
		_grab_angle = a
		koma.rotation += da
		_spin_samples.append(Vector2(now, da / maxf(now - _last_drag, 0.004)))
	_last_drag = now


func _fling() -> void:
	var now := _now()
	var w := 0.0
	var n := 0
	for s in _spin_samples:
		if now - s.x < 0.15:
			w += s.y
			n += 1
	if n > 0:
		w /= n
	# a straight flick through the middle has little angular speed; use its pace
	var linear := _drag_speed / 120.0 if now - _last_drag < 0.15 else 0.0
	var mag := maxf(absf(w), linear)
	if mag < 5.0:
		hint_label.text = "もっと勢いよく！"
		return
	var dir := signf(w) if absf(w) > 1.0 else (1.0 if randf() < 0.5 else -1.0)
	_start_spin(dir * clampf(mag * 1.2, 14.0, 44.0))


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


# --- persistence ---

func _load() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # a missing file just leaves the defaults
	player_count = clampi(int(cfg.get_value("game", "players", 4)), MIN_PLAYERS, MAX_PLAYERS)
	var stored: Array = cfg.get_value("game", "names", [])
	saved_names.clear()
	for i in MAX_PLAYERS:
		saved_names.append(str(stored[i]) if i < stored.size() else str(DEFAULT_NAMES[i]))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "players", player_count)
	cfg.set_value("game", "names", saved_names)
	cfg.save(SAVE_PATH)


# --- screens ---

func _build_title() -> Control:
	var root := _screen()
	var box := _vbox(root, 32)
	box.add_child(_spacer(70))
	box.add_child(_label("べく杯", TITLE_FONT, 150, GOLD, 20))
	box.add_child(_label("土佐のお座敷あそび", BODY_FONT, 36, CREAM, 8))
	box.add_child(_expand())
	box.add_child(_label("コマが止まったら、軸が指した人が\n上を向いた顔の杯で飲む！", BODY_FONT, 28, CREAM, 8))
	box.add_child(_spacer(20))
	var start := _button("はじめる", 52)
	start.pressed.connect(show_setup)
	box.add_child(start)
	box.add_child(_spacer(20))
	box.add_child(_label("お酒は20歳になってから。飲みすぎ注意、お水もどうぞ。", BODY_FONT, 22, Color(CREAM, 0.65)))
	box.add_child(_spacer(24))
	return root


func _build_setup() -> Control:
	var root := _screen()
	var box := _vbox(root, 40)
	box.add_child(_spacer(40))
	box.add_child(_label("何人で飲む？", TITLE_FONT, 60, GOLD, 14))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var minus := _button("－", 56)
	minus.custom_minimum_size = Vector2(110, 110)
	minus.pressed.connect(func(): set_player_count(player_count - 1))
	count_label = _label("", TITLE_FONT, 84, CREAM, 14)
	count_label.custom_minimum_size = Vector2(140, 0)
	var plus := _button("＋", 56)
	plus.custom_minimum_size = Vector2(110, 110)
	plus.pressed.connect(func(): set_player_count(player_count + 1))
	row.add_child(minus)
	row.add_child(count_label)
	row.add_child(plus)
	box.add_child(row)
	box.add_child(_spacer(10))
	box.add_child(_label("名前（タップで変更）", BODY_FONT, 26, Color(CREAM, 0.7)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in MAX_PLAYERS:
		var e := LineEdit.new()
		e.custom_minimum_size = Vector2(300, 76)
		e.max_length = 6
		e.alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.placeholder_text = DEFAULT_NAMES[i]
		e.text = saved_names[i]
		e.select_all_on_focus = true
		e.add_theme_font_size_override("font_size", 32)
		grid.add_child(e)
		name_edits.append(e)
	box.add_child(grid)
	box.add_child(_expand())
	var go := _button("席につく！", 52)
	go.pressed.connect(start_play)
	box.add_child(go)
	box.add_child(_spacer(6))
	var back := _button("もどる", 28)
	back.pressed.connect(func(): _enter(State.TITLE))
	box.add_child(back)
	box.add_child(_spacer(24))
	set_player_count(player_count)
	return root


func _build_hud() -> Control:
	var root := _screen()
	var box := _vbox(root, 28)
	var members := _button("メンバー", 26)
	members.custom_minimum_size = Vector2.ZERO
	members.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	members.pressed.connect(show_setup)
	box.add_child(members)
	box.add_child(_expand())
	hint_label = _label("", BODY_FONT, 30, CREAM, 8)
	box.add_child(hint_label)
	box.add_child(_spacer(8))
	spin_button = _button("回す！", 52)
	spin_button.pressed.connect(spin_random)
	box.add_child(spin_button)
	box.add_child(_spacer(24))
	var pulse := hint_label.create_tween().set_loops()
	pulse.tween_property(hint_label, "modulate:a", 0.4, 0.8)
	pulse.tween_property(hint_label, "modulate:a", 1.0, 0.8)
	return root


func _build_reveal() -> Control:
	var root := _screen()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	card = PanelContainer.new()
	card_style = _box(CARD_COLORS[0], GOLD, 6, 40)
	card_style.set_content_margin_all(36)
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(600, 0)
	card.resized.connect(func(): card.pivot_offset = card.size / 2)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	face_view = FaceView.new()
	face_view.custom_minimum_size = Vector2(300, 300)
	face_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face_view.resized.connect(func(): face_view.pivot_offset = face_view.size / 2)
	box.add_child(face_view)
	reveal_name = _label("", TITLE_FONT, 80, CREAM, 16)
	box.add_child(reveal_name)
	reveal_cup = _label("", TITLE_FONT, 54, GOLD, 12)
	box.add_child(reveal_cup)
	reveal_rule = _label("", BODY_FONT, 30, CREAM, 6)
	box.add_child(reveal_rule)
	box.add_child(_spacer(16))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var drank := _button("飲んだ！", 44)
	drank.custom_minimum_size = Vector2(250, 0)
	drank.pressed.connect(drink)
	var water := _button("お水でパス", 30)
	water.custom_minimum_size = Vector2(220, 0)
	water.pressed.connect(pass_water)
	row.add_child(drank)
	row.add_child(water)
	box.add_child(row)
	return root


func _build_confetti() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 160
	p.lifetime = 2.2
	p.explosiveness = 0.95
	p.direction = Vector2(0, -1)
	p.spread = 75.0
	p.initial_velocity_min = 500.0
	p.initial_velocity_max = 1100.0
	p.gravity = Vector2(0, 1400)
	p.damping_min = 80.0
	p.damping_max = 160.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.scale_amount_min = 8.0
	p.scale_amount_max = 16.0
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	g.colors = PackedColorArray([LACQUER, GOLD, CREAM, Color("#f28aa5"), Color("#5b8fd6")])
	p.color_initial_ramp = g
	return p


func _make_seat() -> void:
	var panel := PanelContainer.new()
	var style := _box(Color(INK, 0.88), GOLD, 3, 18)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = SEAT_SIZE
	panel.size = SEAT_SIZE
	panel.pivot_offset = SEAT_SIZE / 2
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var name_label := _label("", BODY_FONT, 28, CREAM, 4)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(SEAT_SIZE.x - 16, 0)
	var count := _label("", BODY_FONT, 22, GOLD)
	box.add_child(name_label)
	box.add_child(count)
	world.add_child(panel)
	seats.append(panel)
	seat_styles.append(style)
	seat_names.append(name_label)
	seat_counts.append(count)


# --- widget helpers ---

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = BODY_FONT
	t.default_font_size = 32
	var states := {
		"normal": _box(LACQUER, GOLD, 4, 28),
		"hover": _box(LACQUER.lightened(0.1), GOLD, 4, 28),
		"pressed": _box(LACQUER.darkened(0.3), GOLD, 4, 28),
		"disabled": _box(Color(0.3, 0.27, 0.32), Color(0.5, 0.47, 0.5), 4, 28),
	}
	for key: String in states:
		var s: StyleBoxFlat = states[key]
		s.content_margin_left = 36
		s.content_margin_right = 36
		s.content_margin_top = 12
		s.content_margin_bottom = 16
		t.set_stylebox(key, "Button", s)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for key: String in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(key, "Button", CREAM)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(CREAM, 0.4))
	t.set_stylebox("normal", "LineEdit", _box(Color("#2a2140"), GOLD, 3, 16))
	t.set_stylebox("focus", "LineEdit", _box(Color("#352a52"), CREAM, 3, 16))
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("font_placeholder_color", "LineEdit", Color(CREAM, 0.4))
	t.set_color("font_color", "Label", CREAM)
	return t


func _box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(16)
	s.corner_detail = 10
	return s


func _screen() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _vbox(parent: Control, margin: int) -> VBoxContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, margin)
	parent.add_child(m)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12)
	m.add_child(box)
	return box


func _label(text: String, font: Font, font_size: int, color: Color, outline := 0) -> Label:
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


func _button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", TITLE_FONT)
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(Callable(sfx, "click"))
	return b


func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _expand() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
