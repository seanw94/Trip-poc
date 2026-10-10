extends Node2D
## Night background, paper lanterns, the lacquered table and the top's shadow.

const TITLE_FONT = preload("res://fonts/DelaGothicOne-Regular.ttf")

const NIGHT := Color("#1a1430")
const GOLD := Color("#e8b04b")
const INK := Color("#1d1416")

var view := Vector2(720, 1280)
var center := Vector2(360, 590)
var radius := 250.0
var show_table := true


func _draw() -> void:
	# oversized so screen shake never shows an edge
	draw_rect(Rect2(Vector2(-60, -60), view + Vector2(120, 120)), NIGHT)
	for i in 6:
		draw_circle(center, (radius + 260) * (1.0 - i / 6.0) + 40, Color(1.0, 0.55, 0.2, 0.035))
	_lantern(Vector2(70, 0))
	_lantern(Vector2(view.x - 70, 0))
	if not show_table:
		return
	draw_circle(center + Vector2(0, 18), radius + 14, Color(0, 0, 0, 0.45))
	draw_circle(center, radius + 14, Color("#5a1015"))
	draw_circle(center, radius, Color("#8f1d22"))
	draw_arc(center, radius - 18, 0, TAU, 96, Color(GOLD, 0.8), 4, true)
	draw_arc(center, radius - 30, 0, TAU, 96, Color(GOLD, 0.35), 2, true)
	draw_circle(center + Vector2(8, 14), 104, Color(0, 0, 0, 0.35))


func _lantern(top: Vector2) -> void:
	var c := top + Vector2(0, 150)
	draw_line(top, c - Vector2(0, 60), INK, 3)
	for i in 5:
		draw_circle(c, 70 + i * 14, Color(1.0, 0.45, 0.2, 0.05))
	var body := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		body.append(c + Vector2(cos(a) * 46, sin(a) * 58))
	draw_colored_polygon(body, Color("#d43a2f"))
	for y in [-36, -12, 12, 36]:
		var half := 46.0 * sqrt(1.0 - pow(y / 58.0, 2))
		draw_line(c + Vector2(-half, y), c + Vector2(half, y), Color(0, 0, 0, 0.18), 2)
	draw_rect(Rect2(c + Vector2(-26, -64), Vector2(52, 12)), INK)
	draw_rect(Rect2(c + Vector2(-26, 52), Vector2(52, 12)), INK)
	draw_string(TITLE_FONT, c + Vector2(-40, 16), "酒", HORIZONTAL_ALIGNMENT_CENTER, 80, 44, INK)
