extends Node2D
## The bekuhai top seen from above. Its rotation is where the spike (軸) points;
## the face on top cycles while it spins, and whichever is up when it stops
## decides the cup.

signal ticked(speed: float)
signal stopped(face: int)

const Faces = preload("res://scripts/faces.gd")

const RADIUS := 100.0
const FACE_STEP := 2.2  # radians turned per face change
const FRICTION := 1.2  # constant slowdown, rad/s²
const DRAG := 0.35  # extra slowdown proportional to speed

const GOLD := Color("#e8b04b")
const RED := Color("#9e1b26")
const RED_LIGHT := Color("#c8303c")
const CREAM := Color("#fff8ec")

var face := 0
var speed := 0.0
var spinning := false
var idle := false  # slow decorative turn on the title screen
var _turned := 0.0


func spin(initial_speed: float) -> void:
	speed = initial_speed * randf_range(0.9, 1.1)
	spinning = true
	_turned = 0.0
	scale = Vector2.ONE


func _process(delta: float) -> void:
	if spinning:
		var step := speed * delta
		rotation += step
		_turned += absf(step)
		while _turned >= FACE_STEP:
			_turned -= FACE_STEP
			face = (face + 1) % 3
			ticked.emit(absf(speed))
		var dir := signf(speed)
		speed -= dir * (FRICTION + DRAG * absf(speed)) * delta
		if signf(speed) != dir or absf(speed) < 0.15:
			speed = 0.0
			spinning = false
			rotation = wrapf(rotation, -PI, PI)
			_settle()
		queue_redraw()
	elif idle:
		rotation += 0.5 * delta


func _settle() -> void:
	var tw := create_tween()
	tw.tween_method(_wobble, 0.0, 1.0, 0.6)
	tw.tween_callback(func(): stopped.emit(face))


func _wobble(t: float) -> void:
	scale = Vector2.ONE * (1.0 + sin(t * PI * 5.0) * (1.0 - t) * 0.08)


func _draw() -> void:
	var r := RADIUS
	# spike first so the body covers its base
	var spike := PackedVector2Array([Vector2(r * 0.6, -22), Vector2(r + 78, 0), Vector2(r * 0.6, 22)])
	draw_colored_polygon(spike, GOLD)
	var spike_outline := spike.duplicate()
	spike_outline.append(spike[0])
	draw_polyline(spike_outline, Faces.INK, 4.0, true)
	draw_circle(Vector2(r + 78, 0), 10, Faces.INK)
	draw_circle(Vector2(r + 78, 0), 7, GOLD)

	draw_circle(Vector2.ZERO, r + 6, Faces.INK)
	draw_circle(Vector2.ZERO, r, GOLD)
	draw_circle(Vector2.ZERO, r - 8, RED)
	# alternating wedges so the spin is easy to see
	for i in 12:
		if i % 2 == 0:
			continue
		var wedge := PackedVector2Array([Vector2.ZERO])
		for k in 5:
			var a := lerpf(TAU * i / 12.0, TAU * (i + 1) / 12.0, k / 4.0)
			wedge.append(Vector2.from_angle(a) * (r - 8))
		draw_colored_polygon(wedge, RED_LIGHT)
	draw_circle(Vector2.ZERO, r * 0.66, Faces.INK)
	draw_circle(Vector2.ZERO, r * 0.62, CREAM)
	Faces.draw_face(self, face, Vector2.ZERO, r * 0.54)

	if absf(speed) > 2.0:
		var alpha := clampf(absf(speed) / 30.0, 0.0, 0.7)
		for i in 3:
			var a0 := TAU * i / 3.0
			draw_arc(Vector2.ZERO, r + 18, a0, a0 + 1.3, 24, Color(GOLD, alpha), 6.0, true)
