extends Control
## べく杯 (bekuhai), Tosa's drinking-game top. Flick it while everyone sings
## 「べろべろの神様」; whoever the shaft points at drinks from the cup of the
## face that comes up. Every screen is built in code.

enum State { TITLE, SETUP, PLAY, SPINNING, REVEAL }

const UI = preload("res://scripts/ui.gd")
const Faces = preload("res://scripts/faces.gd")
const Koma = preload("res://scripts/koma.gd")
const Table = preload("res://scripts/table.gd")
const Lantern = preload("res://scripts/lantern.gd")
const Seat = preload("res://scripts/seat.gd")
const Sfx = preload("res://scripts/sfx.gd")
const FaceView = preload("res://scripts/face_view.gd")

const DEFAULT_NAMES := ["龍馬", "慎太郎", "半平太", "以蔵", "弥太郎", "お龍", "容堂", "象二郎"]
const MIN_PLAYERS := 2
const MAX_PLAYERS := 8
const KANPAI_CHANCE := 0.06
const BUDDY_CHANCE := 0.07
const WATER_EVERY := 8  # drinks between お水タイム reminders
const GRAB_RADIUS := 190.0
const SEAT_TAP_RADIUS := 90.0
const SAVE_PATH := "user://bekuhai.cfg"
const CHANT := ["べろべろの神様は", "正直の神様よ", "%sの方へと", "おむきゃれ　おむきゃれ♪"]
const CHANT_WORDS := ["おささ", "男前", "べっぴんさん", "のんべえ", "すけべえ", "さみしがり屋", "今夜の幹事", "いちばん若い人"]
const RANKS := ["横綱", "大関", "関脇", "小結", "前頭筆頭", "前頭二枚目", "前頭三枚目", "前頭四枚目"]
const CARD_COLORS := [Color("#c2456b"), Color("#2f5ea8"), Color("#a3172b")]
const KANPAI_COLOR := Color("#9a6b12")
const WATER_COLOR := Color("#1f6f8b")
const RULES_COLOR := Color("#3b2a55")
const TOGGLE_LABELS := {"declare": "指名モード", "table": "向かい合わせ", "sound": "効果音", "vibe": "バイブ"}

var state := State.TITLE
var player_count := 4
var declare_mode := false
var table_mode := false
var sound_on := true
var vibe_on := true
var saved_names: Array[String] = []

var names: Array[String] = []
var drinks: Array[int] = []
var waters: Array[int] = []
var cups: Array = []  # per player: [おかめ, ひょっとこ, 天狗]
var spinner := 0
var declared := -1
var pointed := 0
var drinkers: Array[int] = []
var chosen_face := 0
var verdict := ""  # "", "hit", "miss"
var bonus := ""  # "", "kanpai", "buddy"
var last_result := ""
var _since_water := 0

var world: Node2D
var table
var koma
var koma_root: Node2D
var sfx
var seats: Array = []
var seat_centers: Array[Vector2] = []
var confetti: CPUParticles2D
var beat_timer: Timer

var title_screen: Control
var setup_screen: Control
var play_hud: Control
var count_label: Label
var name_edits: Array[LineEdit] = []
var toggles := {}
var hint_label: Label
var chant_label: Label
var spin_button: Button
var version_label: Label

var reveal: Control
var reveal_card: Control
var reveal_style: StyleBoxFlat
var reveal_banner: Label
var face_view
var reveal_name: Label
var reveal_cup: Label
var reveal_rule: Label

var overlay: Control = null
var rules_layer: Control
var rules_scroll: ScrollContainer
var banzuke_layer: Control
var banzuke_rows: VBoxContainer
var water_layer: Control

var _shake := 0.0
var _touch := -1
var _grab_angle := 0.0
var _spin_samples: Array[Vector2] = []  # (time, angular velocity)
var _drag_speed := 0.0
var _last_drag := 0.0
var _beat := 0
var _chant_word := ""
var force_bonus := ""  # tests/shots.gd sets this to capture the rare events


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# names with kanji the display font lacks fall back to the body font
	var title_font: FontFile = UI.TITLE_FONT
	var fallbacks: Array[Font] = [UI.BODY_FONT]
	title_font.fallbacks = fallbacks
	theme = UI.make_theme()
	DisplayServer.screen_set_keep_on(true)
	_load()

	sfx = Sfx.new()
	add_child(sfx)
	sfx.enabled = sound_on
	beat_timer = Timer.new()
	beat_timer.wait_time = 0.36
	beat_timer.timeout.connect(_on_beat)
	add_child(beat_timer)

	world = Node2D.new()
	add_child(world)
	table = Table.new()
	world.add_child(table)
	for i in MAX_PLAYERS:
		var seat = Seat.new()
		seat.color = UI.PLAYER_COLORS[i]
		world.add_child(seat)
		seats.append(seat)
		seat_centers.append(Vector2.ZERO)
	koma_root = Node2D.new()
	world.add_child(koma_root)
	koma = Koma.new()
	koma_root.add_child(koma)
	koma.connect("ticked", _on_tick)
	koma.connect("landed", _on_landed)
	koma.connect("rolled", _on_rolled)
	koma.connect("stopped", _on_stopped)
	for i in 2:
		var lantern = Lantern.new()
		lantern.phase = i * 2.1
		world.add_child(lantern)

	title_screen = _build_title()
	setup_screen = _build_setup()
	play_hud = _build_hud()
	_build_reveal()
	_build_rules()
	_build_banzuke()
	_build_water()
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
	if overlay != null:
		close_overlay()
		return
	match state:
		State.TITLE:
			get_tree().quit()
		State.SETUP:
			_enter(State.TITLE)
		State.PLAY:
			open_setup(player_count)


# --- public API (the UI uses it, and so do tests/smoke.gd and tests/shots.gd) ---

func open_setup(count: int, duo := false) -> void:
	if duo:
		_set_option("table", true)
	_set_count(count)
	_enter(State.SETUP)


func set_option(key: String, on: bool) -> void:
	_set_option(key, on)


func start_play() -> void:
	names.clear()
	drinks.clear()
	waters.clear()
	cups.clear()
	for i in player_count:
		var n := name_edits[i].text.strip_edges()
		if n.is_empty():
			n = DEFAULT_NAMES[i]
		names.append(n)
		drinks.append(0)
		waters.append(0)
		cups.append([0, 0, 0])
		saved_names[i] = n
	_save()
	spinner = 0
	declared = -1
	last_result = ""
	_since_water = 0
	koma.reset_pose()
	_highlight(-1)
	_layout()
	_enter(State.PLAY)
	_refresh_seats()


func spin_with(speed: float) -> void:
	if _can_spin():
		_start_spin(speed)


func declare(index: int) -> void:
	if state != State.PLAY or not declare_mode or index < 0 or index >= names.size():
		return
	declared = index
	sfx.click()
	_vibrate(20)
	_refresh_seats()
	var s = seats[index]
	var tw: Tween = s.create_tween()
	tw.tween_property(s, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(s, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_revealing() -> bool:
	return state == State.REVEAL


func drink() -> void:
	if state != State.REVEAL:
		return
	for d in drinkers:
		drinks[d] += 1
		if bonus != "kanpai":
			cups[d][chosen_face] += 1
	_since_water += drinkers.size()
	if bonus == "kanpai":
		for i in 3:
			get_tree().create_timer(0.09 * i).timeout.connect(Callable(sfx, "clink"))
		last_result = "みんなで乾杯！"
	else:
		sfx.clink()
		last_result = "%sが%sの杯をぐいっと！" % [_drinker_names(), Faces.NAMES[chosen_face]]
	_next_round()
	if _since_water >= WATER_EVERY:
		_since_water = 0
		show_water_break()


func pass_water() -> void:
	if state != State.REVEAL:
		return
	for d in drinkers:
		waters[d] += 1
	sfx.click()
	last_result = "%sはお水でひと休み。" % _drinker_names()
	_next_round()


func total_drinks() -> int:
	var total := 0
	for d in drinks:
		total += d
	return total


func show_rules() -> void:
	rules_scroll.scroll_vertical = 0
	_open_overlay(rules_layer)


func show_banzuke() -> void:
	_fill_banzuke()
	_open_overlay(banzuke_layer)


func show_water_break() -> void:
	_open_overlay(water_layer)


func close_overlay() -> void:
	if overlay == null:
		return
	overlay.visible = false
	overlay = null
	_update_hint()


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
	chant_label.visible = s == State.SPINNING
	if s != State.SPINNING:
		beat_timer.stop()
	_touch = -1
	_layout()
	_update_hint()


func _can_spin() -> bool:
	return state == State.PLAY and overlay == null and (not declare_mode or declared >= 0)


func _update_hint() -> void:
	if state != State.PLAY or names.is_empty():
		return
	var who := names[spinner]
	var turn := ""
	if declare_mode and declared < 0:
		turn = "%sの番。飲ませたい人をタップして指名！" % who
	elif declare_mode:
		turn = "%sが%sを指名！ シュッと回せ！" % [who, names[declared]]
	else:
		turn = "%sの番。コマをシュッと回せ！" % who
	hint_label.text = turn if last_result.is_empty() else last_result + "\n" + turn


func _flash_hint(text: String) -> void:
	hint_label.text = text
	var tw := hint_label.create_tween()
	tw.tween_property(hint_label, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(hint_label, "scale", Vector2.ONE, 0.15)
	get_tree().create_timer(1.6).timeout.connect(_update_hint)


func _start_spin(speed: float) -> void:
	_enter(State.SPINNING)
	hint_label.text = "回れ回れ〜！"
	_highlight(-1)
	koma.spin(speed)
	sfx.whoosh()
	_vibrate(30)
	_chant_word = CHANT_WORDS[randi() % CHANT_WORDS.size()]
	_beat = 0
	_show_chant_line(0)
	beat_timer.start()


func _on_beat() -> void:
	_beat += 1
	if _beat % 2 == 0:
		sfx.beat_don()
		_show_chant_line(int(_beat / 2.0) % CHANT.size())
	else:
		sfx.clap()


func _show_chant_line(i: int) -> void:
	var line: String = CHANT[i]
	chant_label.text = line % _chant_word if line.contains("%s") else line
	chant_label.scale = Vector2(1.15, 1.15)
	var tw := chant_label.create_tween()
	tw.tween_property(chant_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_tick(speed: float) -> void:
	sfx.tick(speed)


func _on_landed() -> void:
	beat_timer.stop()
	chant_label.visible = false
	pointed = _seat_for_angle(koma.rotation)
	_highlight(pointed)
	hint_label.text = "%sの方へ…！" % names[pointed]
	sfx.thud()
	_vibrate(120)
	_shake = 16.0


func _on_rolled() -> void:
	sfx.roll()


func _on_stopped(face: int) -> void:
	if state != State.SPINNING:
		return
	_resolve(face)
	sfx.don()
	_vibrate(220)
	_shake = 22.0
	await get_tree().create_timer(0.55).timeout
	if state == State.SPINNING:
		_show_reveal()


func _resolve(face: int) -> void:
	chosen_face = face
	verdict = ""
	bonus = ""
	drinkers.clear()
	if declare_mode and declared >= 0:
		verdict = "hit" if pointed == declared else "miss"
		drinkers.append(declared if verdict == "hit" else spinner)
	else:
		drinkers.append(pointed)
	var roll := randf()
	if force_bonus == "kanpai":
		roll = 0.0
	elif force_bonus == "buddy":
		roll = KANPAI_CHANCE
	if roll < KANPAI_CHANCE:
		bonus = "kanpai"
		drinkers.clear()
		for i in names.size():
			drinkers.append(i)
	elif roll < KANPAI_CHANCE + BUDDY_CHANCE and names.size() >= 3:
		bonus = "buddy"
		var others: Array[int] = []
		for i in names.size():
			if i != drinkers[0]:
				others.append(i)
		drinkers.append(others[randi() % others.size()])


func _show_reveal() -> void:
	_enter(State.REVEAL)
	var banner := "神様のお告げ"
	if bonus == "kanpai":
		banner = "大当たり！"
	elif bonus == "buddy":
		banner = "道連れ発動！"
	elif verdict == "hit":
		banner = "指名的中！"
	elif verdict == "miss":
		banner = "ハズレ！言い出しっぺが飲む"
	reveal_banner.text = banner

	if bonus == "kanpai":
		reveal_style.bg_color = KANPAI_COLOR
		face_view.face = -1
		_set_reveal_name("全員！")
		reveal_cup.text = "カンパイ！！"
		reveal_rule.text = "みんなで乾杯！\n好きな杯でどうぞ。"
	else:
		reveal_style.bg_color = CARD_COLORS[chosen_face]
		face_view.face = chosen_face
		_set_reveal_name(_drinker_names("＆") + "！")
		reveal_cup.text = "%sの杯！" % Faces.NAMES[chosen_face]
		reveal_rule.text = Faces.RULES[chosen_face]
	face_view.queue_redraw()

	# on a table, turn the card to face whoever has to drink
	var flip: bool = table_mode and seat_centers[drinkers[0]].y < koma_root.position.y - 1.0
	reveal_card.rotation = PI if flip else 0.0
	reveal_card.scale = Vector2(0.2, 0.2)
	reveal_card.modulate.a = 0.0
	var pop := create_tween().set_parallel()
	pop.tween_property(reveal_card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(reveal_card, "modulate:a", 1.0, 0.2)
	var wobble := create_tween()
	for angle: float in [0.18, -0.14, 0.09, -0.05, 0.0]:
		wobble.tween_property(face_view, "rotation", angle, 0.12)
	confetti.restart()
	sfx.fanfare()


func _set_reveal_name(text: String) -> void:
	reveal_name.text = text
	reveal_name.add_theme_font_size_override("font_size", clampi(int(540.0 / maxf(text.length(), 1.0)), 44, 84))


func _drinker_names(sep := "と") -> String:
	var parts := PackedStringArray()
	for d in drinkers:
		parts.append(names[d])
	return sep.join(parts)


func _next_round() -> void:
	# the one who drank spins next; after a kanpai the turn just moves on
	spinner = (spinner + 1) % names.size() if bonus == "kanpai" else drinkers[0]
	declared = -1
	_enter(State.PLAY)
	_refresh_seats()
	_highlight(-1)


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
		var boss := " 酒豪" if top > 0 and drinks[i] == top else ""
		seats[i].set_info(names[i], "%d杯%s" % [drinks[i], boss])
		seats[i].is_turn = i == spinner and state != State.REVEAL
		seats[i].declared = i == declared
		seats[i].queue_redraw()


func _highlight(index: int) -> void:
	for i in seats.size():
		var s = seats[i]
		var on: bool = i == index
		if s.lit == on:
			continue
		s.lit = on
		s.queue_redraw()
		var tw: Tween = s.create_tween()
		if on:
			tw.tween_property(s, "scale", Vector2(1.3, 1.3), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		else:
			tw.tween_property(s, "scale", Vector2.ONE, 0.15)


func _layout() -> void:
	var view := get_viewport_rect().size
	var center := Vector2(view.x * 0.5, view.y * 0.47)
	var seat_r := minf(view.x * 0.5 - 90.0, view.y * 0.3)
	if names.size() == 2:
		seat_r = minf(view.y * 0.26, 330.0)  # face to face, a little further apart
	var table_r := minf(view.x * 0.5 - 90.0, view.y * 0.3) - 24.0
	var koma_scale := 1.0
	if state == State.TITLE:
		# a smaller table between the title and the buttons
		center = Vector2(view.x * 0.5, view.y * 0.5)
		table_r = minf(view.x * 0.24, view.y * 0.14)
		koma_scale = table_r / 230.0
	table.view = view
	table.center = center
	table.radius = table_r
	table.koma_shadow = 110.0 * koma_scale
	table.queue_redraw()
	koma_root.position = center
	koma_root.scale = Vector2.ONE * koma_scale
	for i in names.size():
		var a := _seat_angle(i)
		seat_centers[i] = center + Vector2.from_angle(a) * seat_r
		seats[i].position = seat_centers[i] - Seat.SIZE / 2
		# on a table, each cushion reads from its own side
		seats[i].rotation = a - PI / 2 if table_mode else 0.0
	var lanterns := world.get_children().filter(func(n): return n is Lantern)
	if lanterns.size() == 2:
		lanterns[0].position = Vector2(70, 0)
		lanterns[1].position = Vector2(view.x - 70, 0)
	confetti.position = Vector2(view.x * 0.5, view.y * 0.42)
	rules_scroll.custom_minimum_size.y = maxf(view.y - 420.0, 400.0)


func _vibrate(ms: int) -> void:
	if vibe_on:
		Input.vibrate_handheld(ms)


# --- touch: flick the top, tap a cushion to name someone ---

func _input(event: InputEvent) -> void:
	if state != State.PLAY or overlay != null:
		return
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)


func _on_touch(t: InputEventScreenTouch) -> void:
	var rel: Vector2 = t.position - koma.global_position
	if t.pressed:
		if _touch != -1:
			return
		if rel.length() < GRAB_RADIUS:
			if not _can_spin():
				_flash_hint("先に、飲ませたい人をタップ！")
				return
			_touch = t.index
			_grab_angle = rel.angle()
			_spin_samples.clear()
			_drag_speed = 0.0
			_last_drag = _now()
		elif declare_mode:
			var local: Vector2 = t.position - world.position
			for i in names.size():
				if local.distance_to(seat_centers[i]) < SEAT_TAP_RADIUS:
					declare(i)
					return
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
		_flash_hint("もっと勢いよく、シュッと！")
		return
	var dir := signf(w) if absf(w) > 1.0 else (1.0 if randf() < 0.5 else -1.0)
	_start_spin(dir * clampf(mag * 1.2, 14.0, 44.0))


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


# --- settings & persistence ---

func _set_count(n: int) -> void:
	player_count = clampi(n, MIN_PLAYERS, MAX_PLAYERS)
	count_label.text = "%d人" % player_count
	for i in name_edits.size():
		name_edits[i].visible = i < player_count


func _on_toggle(key: String, on: bool) -> void:
	sfx.click()
	_set_option(key, on)


func _set_option(key: String, on: bool) -> void:
	match key:
		"declare":
			declare_mode = on
		"table":
			table_mode = on
		"sound":
			sound_on = on
			sfx.enabled = on
		"vibe":
			vibe_on = on
	if toggles.has(key):
		var t: Button = toggles[key]
		t.set_pressed_no_signal(on)
		t.text = ("● " if on else "○ ") + str(TOGGLE_LABELS[key])
	_save()


func _load() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # a missing file just leaves the defaults
	player_count = clampi(int(cfg.get_value("game", "players", 4)), MIN_PLAYERS, MAX_PLAYERS)
	declare_mode = bool(cfg.get_value("game", "declare", false))
	table_mode = bool(cfg.get_value("game", "table", false))
	sound_on = bool(cfg.get_value("game", "sound", true))
	vibe_on = bool(cfg.get_value("game", "vibe", true))
	var stored: Array = cfg.get_value("game", "names", [])
	saved_names.clear()
	for i in MAX_PLAYERS:
		saved_names.append(str(stored[i]) if i < stored.size() else str(DEFAULT_NAMES[i]))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "players", player_count)
	cfg.set_value("game", "names", saved_names)
	cfg.set_value("game", "declare", declare_mode)
	cfg.set_value("game", "table", table_mode)
	cfg.set_value("game", "sound", sound_on)
	cfg.set_value("game", "vibe", vibe_on)
	cfg.save(SAVE_PATH)


# --- screens ---

func _btn(text: String, font_size: int, action: Callable, min_width := 320) -> Button:
	var b := UI.button(text, font_size, min_width)
	b.pressed.connect(func(): sfx.click())
	b.pressed.connect(action)
	return b


func _build_title() -> Control:
	var root := UI.full_rect(self)
	var box := UI.vbox(root, 32)
	box.add_child(UI.spacer(80))
	box.add_child(UI.label("べく杯", UI.TITLE_FONT, 150, UI.GOLD, 20))
	box.add_child(UI.label("土佐のお座敷あそび", UI.BODY_FONT, 36, UI.CREAM, 8))
	box.add_child(UI.label("〜 べろべろの神様 〜", UI.BODY_FONT, 26, Color(UI.GOLD, 0.85), 6))
	box.add_child(UI.expand())
	box.add_child(_btn("みんなで遊ぶ", 46, func(): open_setup(maxi(player_count, 3)), 440))
	box.add_child(UI.spacer(6))
	box.add_child(_btn("ふたりで差し向かい", 40, func(): open_setup(2, true), 440))
	box.add_child(UI.spacer(6))
	box.add_child(_btn("遊び方 / Rules", 28, show_rules, 320))
	box.add_child(UI.spacer(14))
	box.add_child(UI.label("お酒は20歳になってから。飲みすぎ注意、お水もどうぞ。", UI.BODY_FONT, 22, Color(UI.CREAM, 0.65)))
	version_label = UI.label("v" + str(ProjectSettings.get_setting("application/config/version", "dev")),
			UI.BODY_FONT, 18, Color(UI.CREAM, 0.35))
	box.add_child(version_label)
	box.add_child(UI.spacer(16))
	return root


func _build_setup() -> Control:
	var root := UI.full_rect(self)
	var box := UI.vbox(root, 36, 10)
	box.add_child(UI.expand())
	box.add_child(UI.label("何人で飲む？", UI.TITLE_FONT, 58, UI.GOLD, 14))
	var row := UI.hbox(24)
	var minus := _btn("－", 56, func(): _set_count(player_count - 1), 110)
	minus.custom_minimum_size = Vector2(110, 104)
	count_label = UI.label("", UI.TITLE_FONT, 72, UI.CREAM, 14)
	count_label.custom_minimum_size = Vector2(180, 0)
	var plus := _btn("＋", 56, func(): _set_count(player_count + 1), 110)
	plus.custom_minimum_size = Vector2(110, 104)
	row.add_child(minus)
	row.add_child(count_label)
	row.add_child(plus)
	box.add_child(row)
	box.add_child(UI.label("名前（タップで変更）", UI.BODY_FONT, 24, Color(UI.CREAM, 0.7)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in MAX_PLAYERS:
		var e := LineEdit.new()
		e.custom_minimum_size = Vector2(300, 72)
		e.max_length = 6
		e.alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.placeholder_text = DEFAULT_NAMES[i]
		e.text = saved_names[i]
		e.select_all_on_focus = true
		e.add_theme_font_size_override("font_size", 30)
		e.add_theme_color_override("font_color", UI.PLAYER_COLORS[i].lightened(0.55))
		grid.add_child(e)
		name_edits.append(e)
	box.add_child(grid)
	box.add_child(UI.spacer(6))
	var opts := GridContainer.new()
	opts.columns = 2
	opts.add_theme_constant_override("h_separation", 16)
	opts.add_theme_constant_override("v_separation", 12)
	opts.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var values := {"declare": declare_mode, "table": table_mode, "sound": sound_on, "vibe": vibe_on}
	for key: String in TOGGLE_LABELS:
		var c := UI.toggle(TOGGLE_LABELS[key], values[key])
		c.toggled.connect(func(on: bool): _on_toggle(key, on))
		opts.add_child(c)
		toggles[key] = c
	box.add_child(opts)
	box.add_child(UI.label("指名モード：回す前に飲ませたい人を指名。外れたら自分が飲む！\n向かい合わせ：スマホを卓に置いて囲む用。", UI.BODY_FONT, 20, Color(UI.CREAM, 0.6)))
	box.add_child(UI.expand())
	box.add_child(_btn("席につく！", 52, start_play))
	box.add_child(_btn("もどる", 26, func(): _enter(State.TITLE), 200))
	box.add_child(UI.spacer(16))
	_set_count(player_count)
	return root


func _build_hud() -> Control:
	var root := UI.full_rect(self)
	var box := UI.vbox(root, 26)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var members := _btn("メンバー", 24, func(): open_setup(player_count), 0)
	members.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top.add_child(members)
	top.add_child(UI.expand())
	top.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_btn("遊び方 / Rules", 22, show_rules, 0))
	var spacer := UI.expand()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var ranking := _btn("番付", 24, show_banzuke, 0)
	top.add_child(ranking)
	box.add_child(top)
	chant_label = UI.label("", UI.TITLE_FONT, 44, UI.GOLD, 12)
	chant_label.custom_minimum_size = Vector2(0, 80)
	chant_label.resized.connect(func(): chant_label.pivot_offset = chant_label.size / 2)
	box.add_child(chant_label)
	box.add_child(UI.expand())
	hint_label = UI.label("", UI.BODY_FONT, 28, UI.CREAM, 8)
	hint_label.custom_minimum_size = Vector2(0, 84)
	hint_label.resized.connect(func(): hint_label.pivot_offset = hint_label.size / 2)
	box.add_child(hint_label)
	spin_button = _btn("回す！", 52, _on_spin_button)
	box.add_child(spin_button)
	box.add_child(UI.spacer(18))
	return root


func _build_reveal() -> void:
	var parts := UI.overlay(self, CARD_COLORS[0])
	reveal = parts[0]
	reveal_card = parts[1]
	reveal_style = parts[2]
	var box: VBoxContainer = parts[3]
	reveal_banner = UI.label("", UI.BODY_FONT, 26, UI.CREAM, 6)
	box.add_child(reveal_banner)
	face_view = FaceView.new()
	face_view.custom_minimum_size = Vector2(280, 280)
	face_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face_view.resized.connect(func(): face_view.pivot_offset = face_view.size / 2)
	box.add_child(face_view)
	reveal_name = UI.label("", UI.TITLE_FONT, 80, UI.CREAM, 16)
	box.add_child(reveal_name)
	reveal_cup = UI.label("", UI.TITLE_FONT, 54, UI.GOLD, 12)
	box.add_child(reveal_cup)
	reveal_rule = UI.label("", UI.BODY_FONT, 28, UI.CREAM, 6)
	box.add_child(reveal_rule)
	box.add_child(UI.spacer(14))
	var row := UI.hbox(18)
	row.add_child(_btn("飲んだ！", 44, drink, 250))
	row.add_child(_btn("お水でパス", 28, pass_water, 210))
	box.add_child(row)


func _build_rules() -> void:
	var parts := UI.overlay(self, RULES_COLOR, 660)
	rules_layer = parts[0]
	var box: VBoxContainer = parts[3]
	box.add_child(UI.label("遊び方 / Rules", UI.TITLE_FONT, 52, UI.GOLD, 12))
	rules_scroll = ScrollContainer.new()
	rules_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rules_scroll.custom_minimum_size = Vector2(0, 760)
	box.add_child(rules_scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	rules_scroll.add_child(page)

	_rules_heading(page, "日本語")
	_rules_text(page, "スマホを真ん中に置いて、みんなで輪になって座ろう。")
	_rules_steps(page, [
		"番の人が、コマを指でシュッと回す。（「回す！」ボタンでもOK）",
		"回っている間、みんなで「べろべろの神様」を歌う。歌詞は画面に出るよ。",
		"コマが倒れたら、軸（長い棒）の先にいる人が飲む。",
		"真ん中に出た顔で、どの杯かが決まる。",
		"飲んだら「飲んだ！」。飲めない時は「お水でパス」でOK。",
		"飲んだ人が、次にコマを回す。",
	])
	_rules_cups(page, ["おかめ", "ひょっとこ", "天狗"], [
		"いちばん小さい。唯一テーブルに置ける杯。",
		"口に穴あり。指でふさいで、飲み干すまで置けない。",
		"いちばん大きい。鼻が長くて、飲み干すまで置けない。",
	])
	_rules_text(page, "本物の杯がなければ、小・中・大のグラスでOK。", 24, 0.75)
	_rules_subheading(page, "オプション")
	_rules_text(page, "・指名モード：回す前に「この人に当たる！」と思う人をタップ。当たればその人が、外れたら自分が飲む。\n・向かい合わせ：スマホを卓に置く用。名前と結果がそれぞれの席の向きに表示される。")
	_rules_subheading(page, "サプライズ")
	_rules_text(page, "・全員カンパイ：みんなで飲む！\n・道連れ：もう一人、ランダムに一緒に飲む。")
	_rules_text(page, "「番付」で今夜のランキング、「メンバー」で人数・名前を変更できます。", 24, 0.75)
	_rules_text(page, "お酒は20歳になってから。無理に飲ませない、飲まない。お水もはさんでね。", 24, 0.75)

	page.add_child(UI.spacer(10))
	_rules_heading(page, "English")
	_rules_text(page, "Put the phone in the middle and sit around it in a circle.")
	_rules_steps(page, [
		"On your turn (番), flick the top with your finger — or tap 回す！ (Spin).",
		"While it spins, everyone sings the 「べろべろの神様」 chant. The words appear on screen.",
		"When the top falls over, whoever the long stick points at drinks.",
		"The face that shows in the middle decides which cup.",
		"Tap 飲んだ！ (Drank!) when done. Can't drink? Tap お水でパス (Pass with water) — that's fine.",
		"Whoever drank spins next.",
	])
	_rules_cups(page, ["Okame", "Hyottoko", "Tengu"], [
		"Smallest. The only cup you can put down.",
		"Hole in the mouth. Cover it with a finger; you can't put it down until it's empty.",
		"Biggest. Its long nose means you can't put it down until it's empty.",
	])
	_rules_text(page, "No real bekuhai cups? Use a small, medium and large glass.", 24, 0.75)
	_rules_subheading(page, "Options")
	_rules_text(page, "• 指名モード (Call it): before spinning, tap the person you think it will point at. Right — they drink. Wrong — you drink.\n• 向かい合わせ (Face to face): for a phone lying on the table. Names and results turn to face each player.")
	_rules_subheading(page, "Surprises")
	_rules_text(page, "• 全員カンパイ (Everyone drinks!)\n• 道連れ (Buddy): a random second player drinks too.")
	_rules_text(page, "番付 shows tonight's ranking; メンバー changes players and names.", 24, 0.75)
	_rules_text(page, "Drinking age in Japan is 20. Never pressure anyone to drink, and have water in between.", 24, 0.75)

	box.add_child(UI.label("上下にスクロール / Scroll for more", UI.BODY_FONT, 20, Color(UI.CREAM, 0.5)))
	box.add_child(_btn("閉じる / Close", 30, close_overlay, 320))


func _rules_heading(page: VBoxContainer, text: String) -> void:
	var l := UI.label(text, UI.TITLE_FONT, 40, UI.CREAM, 10)
	page.add_child(l)
	var line := ColorRect.new()
	line.color = Color(UI.GOLD, 0.6)
	line.custom_minimum_size = Vector2(0, 3)
	page.add_child(line)


func _rules_subheading(page: VBoxContainer, text: String) -> void:
	var l := UI.label(text, UI.TITLE_FONT, 28, UI.GOLD, 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	page.add_child(l)


func _rules_text(page: VBoxContainer, text: String, font_size := 26, alpha := 1.0) -> void:
	var l := UI.label(text, UI.BODY_FONT, font_size, Color(UI.CREAM, alpha))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(l)


func _rules_steps(page: VBoxContainer, steps: Array) -> void:
	for i in steps.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var num := UI.label(str(i + 1), UI.TITLE_FONT, 28, UI.INK)
		num.custom_minimum_size = Vector2(44, 44)
		var badge := PanelContainer.new()
		var style := UI.box(UI.GOLD, UI.GOLD, 0, 22)
		style.set_content_margin_all(0)
		badge.add_theme_stylebox_override("panel", style)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		badge.add_child(num)
		row.add_child(badge)
		var l := UI.label(steps[i], UI.BODY_FONT, 26, UI.CREAM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		page.add_child(row)


func _rules_cups(page: VBoxContainer, cup_names: Array, notes: Array) -> void:
	for f in 3:
		var row := PanelContainer.new()
		var style := UI.box(Color(CARD_COLORS[f], 0.45), Color(CARD_COLORS[f]).lightened(0.3), 2, 18)
		style.set_content_margin_all(10)
		row.add_theme_stylebox_override("panel", style)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		row.add_child(h)
		var fv = FaceView.new()
		fv.face = f
		fv.custom_minimum_size = Vector2(96, 96)
		fv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(fv)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 2)
		var title := UI.label(cup_names[f], UI.TITLE_FONT, 28, UI.GOLD, 6)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text.add_child(title)
		var note := UI.label(notes[f], UI.BODY_FONT, 24, UI.CREAM)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(note)
		h.add_child(text)
		page.add_child(row)


func _build_banzuke() -> void:
	var parts := UI.overlay(self, Color("#2a1416"), 640)
	banzuke_layer = parts[0]
	var box: VBoxContainer = parts[3]
	box.add_child(UI.label("本日の番付", UI.TITLE_FONT, 60, UI.GOLD, 12))
	banzuke_rows = VBoxContainer.new()
	banzuke_rows.add_theme_constant_override("separation", 8)
	box.add_child(banzuke_rows)
	box.add_child(UI.spacer(10))
	box.add_child(_btn("閉じる", 34, close_overlay, 260))


func _fill_banzuke() -> void:
	for child in banzuke_rows.get_children():
		child.queue_free()
	if names.is_empty() or total_drinks() == 0:
		banzuke_rows.add_child(UI.label("まだ誰も飲んでいません。\nさあ、回そう！", UI.BODY_FONT, 30, UI.CREAM))
		return
	var order: Array[int] = []
	for i in names.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int): return drinks[a] > drinks[b])
	var rank := 0
	for pos in order.size():
		var i := order[pos]
		if pos > 0 and drinks[i] < drinks[order[pos - 1]]:
			rank = pos
		var row := PanelContainer.new()
		var style := UI.box(Color(UI.PLAYER_COLORS[i], 0.35), UI.PLAYER_COLORS[i].lightened(0.3), 2, 16)
		style.set_content_margin_all(10)
		row.add_theme_stylebox_override("panel", style)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var title := UI.label(RANKS[rank], UI.TITLE_FONT, 26, UI.GOLD, 6)
		title.custom_minimum_size = Vector2(150, 0)
		h.add_child(title)
		var who := UI.label(names[i], UI.BODY_FONT, 30, UI.CREAM, 6)
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(who)
		var detail := UI.label("お%d ひ%d 天%d 水%d" % [cups[i][0], cups[i][1], cups[i][2], waters[i]],
				UI.BODY_FONT, 18, Color(UI.CREAM, 0.75))
		h.add_child(detail)
		var count := UI.label("%d杯" % drinks[i], UI.TITLE_FONT, 32, UI.CREAM, 8)
		count.custom_minimum_size = Vector2(90, 0)
		h.add_child(count)
		banzuke_rows.add_child(row)


func _build_water() -> void:
	var parts := UI.overlay(self, WATER_COLOR, 560)
	water_layer = parts[0]
	var box: VBoxContainer = parts[3]
	var glass := WaterGlass.new()
	glass.custom_minimum_size = Vector2(160, 190)
	glass.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(glass)
	box.add_child(UI.label("お水タイム", UI.TITLE_FONT, 64, UI.CREAM, 14))
	box.add_child(UI.label("いい飲みっぷり！\nここで みんなでお水を一杯。\n明日の観光のために！", UI.BODY_FONT, 28, UI.CREAM, 6))
	box.add_child(UI.spacer(10))
	box.add_child(_btn("飲んだ！", 40, _water_done, 260))


func _water_done() -> void:
	sfx.clink()
	close_overlay()


func _on_spin_button() -> void:
	if _can_spin():
		_start_spin(randf_range(16.0, 34.0) * (1.0 if randf() < 0.5 else -1.0))
	elif state == State.PLAY:
		_flash_hint("先に、飲ませたい人をタップ！")


func _open_overlay(layer: Control) -> void:
	if overlay != null:
		overlay.visible = false
	overlay = layer
	layer.visible = true
	var card: Control = layer.get_child(1)  # the centring holder, see UI.overlay
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.15)


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
	g.colors = PackedColorArray([UI.LACQUER, UI.GOLD, UI.CREAM, Color("#f28aa5"), Color("#5b8fd6")])
	p.color_initial_ramp = g
	return p


## A glass of water for the お水タイム card.
class WaterGlass extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var glass := PackedVector2Array([Vector2(w * 0.15, h * 0.05), Vector2(w * 0.85, h * 0.05),
				Vector2(w * 0.74, h * 0.95), Vector2(w * 0.26, h * 0.95)])
		var water := PackedVector2Array([Vector2(w * 0.2, h * 0.32), Vector2(w * 0.8, h * 0.32),
				Vector2(w * 0.74, h * 0.95), Vector2(w * 0.26, h * 0.95)])
		draw_colored_polygon(glass, Color(1, 1, 1, 0.18))
		draw_colored_polygon(water, Color("#8fd3f4"))
		var outline := glass.duplicate()
		outline.append(glass[0])
		draw_polyline(outline, Color.WHITE, 5.0, true)
		draw_line(Vector2(w * 0.3, h * 0.42), Vector2(w * 0.34, h * 0.82), Color(1, 1, 1, 0.6), 6.0, true)
		draw_circle(Vector2(w * 0.6, h * 0.55), 7, Color(1, 1, 1, 0.5))
		draw_circle(Vector2(w * 0.5, h * 0.72), 5, Color(1, 1, 1, 0.5))
