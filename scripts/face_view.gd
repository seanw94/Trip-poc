extends Control
## Big upright face for the reveal card. face = -1 draws all three (kanpai).

const Faces = preload("res://scripts/faces.gd")

var face := 0


func _draw() -> void:
	var c := size / 2
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c, r, Faces.INK)
	draw_circle(c, r * 0.94, Color("#fff8ec"))
	if face < 0:
		for i in 3:
			var p := c + Vector2.from_angle(-PI / 2 + TAU * i / 3.0) * r * 0.45
			Faces.draw_face(self, i, p, r * 0.36)
	else:
		Faces.draw_face(self, face, c, r * 0.78)
