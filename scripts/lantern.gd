extends Node2D
## A paper lantern (提灯) hanging from the node's origin, gently swaying.

const UI = preload("res://scripts/ui.gd")

var phase := 0.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	rotation = sin(_t * 1.3 + phase) * 0.05


func _draw() -> void:
	var c := Vector2(0, 150)
	draw_line(Vector2.ZERO, c - Vector2(0, 60), UI.INK, 3)
	for i in 5:
		draw_circle(c, 70 + i * 14, Color(1.0, 0.45, 0.2, 0.05))
	var body := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		body.append(c + Vector2(cos(a) * 46, sin(a) * 58))
	draw_colored_polygon(body, Color("#d43a2f"))
	for y: float in [-36.0, -12.0, 12.0, 36.0]:
		var half := 46.0 * sqrt(1.0 - pow(y / 58.0, 2))
		draw_line(c + Vector2(-half, y), c + Vector2(half, y), Color(0, 0, 0, 0.18), 2)
	draw_rect(Rect2(c + Vector2(-26, -64), Vector2(52, 12)), UI.INK)
	draw_rect(Rect2(c + Vector2(-26, 52), Vector2(52, 12)), UI.INK)
	draw_string(UI.TITLE_FONT, c + Vector2(-40, 16), "酒", HORIZONTAL_ALIGNMENT_CENTER, 80, 44, UI.INK)
