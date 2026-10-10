extends Node2D
## Night background with a faint seigaiha (青海波) wave pattern, a warm glow,
## the lacquered table and the shadow under the top.

const UI = preload("res://scripts/ui.gd")
const WAVE := 56.0  # seigaiha fan radius

var view := Vector2(720, 1280)
var center := Vector2(360, 590)
var radius := 250.0
var show_table := true
var koma_shadow := 110.0


func _draw() -> void:
	# oversized so screen shake never shows an edge
	var area := Rect2(Vector2(-60, -60), view + Vector2(120, 120))
	draw_rect(area, UI.NIGHT)
	_seigaiha(area)
	for i in 6:
		draw_circle(center, (radius + 260) * (1.0 - i / 6.0) + 40, Color(1.0, 0.55, 0.2, 0.035))
	if not show_table:
		return
	draw_circle(center + Vector2(0, 18), radius + 14, Color(0, 0, 0, 0.45))
	draw_circle(center, radius + 14, Color("#5a1015"))
	draw_circle(center, radius, Color("#8f1d22"))
	draw_arc(center, radius - 18, 0, TAU, 96, Color(UI.GOLD, 0.8), 4, true)
	draw_arc(center, radius - 30, 0, TAU, 96, Color(UI.GOLD, 0.35), 2, true)
	for i in 24:
		draw_circle(center + Vector2.from_angle(TAU * i / 24.0) * (radius - 8), 2.5, Color(UI.GOLD, 0.7))
	draw_circle(center + Vector2(8, 16) * koma_shadow / 110.0, koma_shadow, Color(0, 0, 0, 0.35))


func _seigaiha(area: Rect2) -> void:
	# rows top to bottom, each fan masking the one above it
	var line := Color(1, 1, 1, 0.045)
	var half_disc := PackedVector2Array()
	for k in 17:
		half_disc.append(Vector2.from_angle(PI + PI * k / 16.0) * WAVE)
	var row := 0
	var y := area.position.y
	while y < area.end.y + WAVE:
		var x := area.position.x + (WAVE if row % 2 == 1 else 0.0)
		while x < area.end.x + WAVE:
			var c := Vector2(x, y)
			var fan := PackedVector2Array()
			for p in half_disc:
				fan.append(c + p)
			draw_colored_polygon(fan, UI.NIGHT)
			for r: float in [WAVE, WAVE * 0.7, WAVE * 0.4]:
				draw_arc(c, r, PI, TAU, 16, line, 2.0, true)
			x += WAVE * 2.0
		y += WAVE * 0.5
		row += 1
