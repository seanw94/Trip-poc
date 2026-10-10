extends Node2D
## The bekuhai top (六角独楽) seen from above. Six lacquered panels carry the
## three faces twice; the shaft (軸) points along the node's rotation. When it
## runs out of spin it topples, and the face that lands up is rolled in the hub.

signal ticked(speed: float)
signal landed
signal rolled
signal stopped(face: int)

const Faces = preload("res://scripts/faces.gd")
const UI = preload("res://scripts/ui.gd")

const RADIUS := 104.0
const HUB := 58.0
const FRICTION := 1.2  # constant slowdown, rad/s²
const DRAG := 0.35  # extra slowdown proportional to speed
const PANEL_FACES := [0, 1, 2, 0, 1, 2]
const BLACK_LACQUER := Color("#2a1416")
const WOOD := Color("#4a2c1a")
const SHAFT := Color("#c8963e")

var speed := 0.0
var spinning := false
var idle := false  # slow decorative turn on the title screen
var show_face := false
var face := 0
var _turned := 0.0
var _shown := 0
var _roll_start := 0
var _roll_steps := 0


func spin(initial_speed: float) -> void:
	speed = initial_speed * randf_range(0.9, 1.1)
	spinning = true
	show_face = false
	_turned = 0.0
	scale = Vector2.ONE
	queue_redraw()


func reset_pose() -> void:
	show_face = false
	scale = Vector2.ONE
	queue_redraw()


func _process(delta: float) -> void:
	if spinning:
		var step := speed * delta
		rotation += step
		_turned += absf(step)
		while _turned >= TAU / 6.0:
			_turned -= TAU / 6.0
			ticked.emit(absf(speed))
		var dir := signf(speed)
		speed -= dir * (FRICTION + DRAG * absf(speed)) * delta
		if signf(speed) != dir or absf(speed) < 0.15:
			speed = 0.0
			spinning = false
			rotation = wrapf(rotation, -PI, PI)
			_topple()
		queue_redraw()
	elif idle:
		rotation += 0.5 * delta


func _topple() -> void:
	face = randi() % 3
	_roll_steps = randi_range(7, 10)
	_roll_start = posmod(face - _roll_steps, 3)
	_shown = _roll_start
	var tw := create_tween()
	tw.tween_method(_set_tilt, 0.0, 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): landed.emit())
	tw.tween_method(_set_tilt, 1.0, 0.8, 0.1)
	tw.tween_method(_set_tilt, 0.8, 1.0, 0.1)
	tw.tween_callback(func(): show_face = true)
	tw.tween_method(_roll, 0.0, 1.0, 1.1)
	tw.tween_callback(func(): stopped.emit(face))


func _set_tilt(t: float) -> void:
	# squash across the shaft: the top tipping over onto its side
	scale = Vector2(1.0, 1.0 - 0.28 * t)


func _roll(t: float) -> void:
	var eased := 1.0 - pow(1.0 - t, 2.0)
	var idx := posmod(_roll_start + int(floor(eased * _roll_steps)), 3)
	if idx != _shown:
		_shown = idx
		rolled.emit()
	queue_redraw()


func _draw() -> void:
	_draw_shaft()
	var blur := clampf(absf(speed) / 35.0, 0.0, 1.0)
	_draw_hexagon(Vector2.ZERO, RADIUS + 5, 0.0, UI.INK)
	if blur > 0.1:
		for k in [3, 2, 1]:
			_draw_panels(-signf(speed) * k * 0.13, 0.25 * blur)
	_draw_panels(0.0, 1.0 - 0.45 * blur)
	_draw_hub()
	# a highlight that ignores our rotation, so the light stays top-left
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	draw_arc(Vector2.ZERO, RADIUS * 0.8, PI * 1.05, PI * 1.5, 16, Color(1, 1, 1, 0.16), RADIUS * 0.12, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shaft() -> void:
	var tip := Vector2(RADIUS + 74, 0)
	var shaft := PackedVector2Array([Vector2(0, -9), Vector2(tip.x - 14, -5), tip, Vector2(tip.x - 14, 5), Vector2(0, 9)])
	draw_colored_polygon(shaft, SHAFT)
	var outline := shaft.duplicate()
	outline.append(shaft[0])
	draw_polyline(outline, UI.INK, 3.0, true)
	draw_circle(tip, 10, UI.INK)
	draw_circle(tip, 7, UI.GOLD)


func _draw_hexagon(c: Vector2, r: float, offset: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 6:
		pts.append(c + Vector2.from_angle(offset + TAU * k / 6.0) * r)
	draw_colored_polygon(pts, color)


func _draw_panels(offset: float, alpha: float) -> void:
	for k in 6:
		var a0 := offset + TAU * k / 6.0
		var a1 := offset + TAU * (k + 1) / 6.0
		var quad := PackedVector2Array([
			Vector2.from_angle(a0) * RADIUS, Vector2.from_angle(a1) * RADIUS,
			Vector2.from_angle(a1) * HUB, Vector2.from_angle(a0) * HUB,
		])
		var base: Color = UI.LACQUER if k % 2 == 0 else BLACK_LACQUER
		draw_colored_polygon(quad, Color(base, alpha))
		var edge := quad.duplicate()
		edge.append(quad[0])
		draw_polyline(edge, Color(UI.GOLD, alpha), 3.0, true)
		if alpha < 0.5:
			continue
		var mid := (a0 + a1) / 2.0
		var pos := Vector2.from_angle(mid) * (RADIUS + HUB) * 0.5 * cos(PI / 6.0)
		draw_set_transform(pos, mid + PI / 2.0, Vector2.ONE)
		draw_circle(Vector2.ZERO, 17, UI.CREAM)
		Faces.draw_face(self, PANEL_FACES[k], Vector2.ZERO, 14)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hub() -> void:
	draw_circle(Vector2.ZERO, HUB * 0.98, UI.INK)
	draw_circle(Vector2.ZERO, HUB * 0.9, WOOD)
	draw_arc(Vector2.ZERO, HUB * 0.9, 0, TAU, 40, UI.GOLD, 3, true)
	if show_face:
		draw_circle(Vector2.ZERO, HUB * 0.82, UI.CREAM)
		# keep the rolled face upright so everyone can read it
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
		Faces.draw_face(self, _shown, Vector2.ZERO, HUB * 0.68)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(Vector2.ZERO, 18, SHAFT)
		draw_arc(Vector2.ZERO, 18, 0, TAU, 24, UI.INK, 2, true)
		draw_circle(Vector2(-6, -6), 6, Color(1, 1, 1, 0.35))
