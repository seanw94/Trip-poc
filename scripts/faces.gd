extends RefCounted
## The three bekuhai faces, drawn with primitives so the game ships no images.
## Call these from inside a CanvasItem's _draw().

const OKAME := 0
const HYOTTOKO := 1
const TENGU := 2

const NAMES := ["おかめ", "ひょっとこ", "天狗"]
const RULES := [
	"いちばん小さい杯。\nただひとつ、テーブルに置ける杯。",
	"口に穴があいた杯！\n指でふさいで、飲み干すまで置けない。",
	"いちばん大きい杯！\n鼻が長くて、飲み干すまで置けない。",
]

const INK := Color("#1d1416")
const WHITE := Color("#fff3e6")
const SKIN := Color("#f2c894")
const TENGU_RED := Color("#d7263d")
const BANDANA := Color("#2a4f9a")


static func draw_face(ci: CanvasItem, face: int, c: Vector2, r: float) -> void:
	match face:
		OKAME:
			_okame(ci, c, r)
		HYOTTOKO:
			_hyottoko(ci, c, r)
		_:
			_tengu(ci, c, r)


static func oval(c: Vector2, rx: float, ry: float, points := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * i / points
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _okame(ci: CanvasItem, c: Vector2, r: float) -> void:
	var line := maxf(2.0, r * 0.06)
	ci.draw_circle(c, r, INK)  # hair, left showing around the top
	ci.draw_colored_polygon(oval(c + Vector2(0, 0.12) * r, r * 0.9, r * 0.86), WHITE)
	for s: float in [-1.0, 1.0]:
		# high painted eyebrows
		ci.draw_colored_polygon(oval(c + Vector2(s * 0.3, -0.4) * r, r * 0.1, r * 0.055), INK)
		# closed, smiling eyes
		ci.draw_arc(c + Vector2(s * 0.3, -0.02) * r, r * 0.14, PI * 1.15, PI * 1.85, 12, INK, line, true)
		# puffy pink cheeks
		ci.draw_colored_polygon(oval(c + Vector2(s * 0.52, 0.3) * r, r * 0.2, r * 0.14), Color(1.0, 0.45, 0.55, 0.55))
	ci.draw_arc(c + Vector2(0, 0.18) * r, r * 0.07, PI * 0.2, PI * 0.8, 8, Color(INK, 0.5), line * 0.7, true)
	ci.draw_colored_polygon(oval(c + Vector2(0, 0.52) * r, r * 0.09, r * 0.065), Color("#d62839"))


static func _hyottoko(ci: CanvasItem, c: Vector2, r: float) -> void:
	var line := maxf(2.0, r * 0.06)
	ci.draw_circle(c, r, INK)
	ci.draw_circle(c, r * 0.95, SKIN)
	# dotted headband over the top of the head
	var cap := PackedVector2Array()
	for i in 17:
		cap.append(c + Vector2.from_angle(lerpf(PI + 0.42, TAU - 0.42, i / 16.0)) * r * 0.95)
	ci.draw_colored_polygon(cap, BANDANA)
	for p: Vector2 in [Vector2(-0.7, -0.5), Vector2(-0.45, -0.66), Vector2(-0.15, -0.8), Vector2(0.15, -0.8),
			Vector2(0.45, -0.66), Vector2(0.7, -0.5), Vector2(-0.2, -0.52), Vector2(0.2, -0.52)]:
		ci.draw_circle(c + p * r, r * 0.05, WHITE)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.78, -0.48) * r, c + Vector2(1.12, -0.74) * r,
			c + Vector2(1.06, -0.36) * r]), BANDANA)
	# lopsided eyes: one wide open, one squinting
	ci.draw_colored_polygon(oval(c + Vector2(-0.3, -0.12) * r, r * 0.16, r * 0.14), WHITE)
	ci.draw_circle(c + Vector2(-0.27, -0.1) * r, r * 0.07, INK)
	ci.draw_colored_polygon(oval(c + Vector2(0.32, -0.14) * r, r * 0.11, r * 0.06), WHITE)
	ci.draw_circle(c + Vector2(0.33, -0.14) * r, r * 0.045, INK)
	ci.draw_arc(c + Vector2(-0.3, -0.2) * r, r * 0.2, PI * 1.2, PI * 1.8, 10, INK, line, true)
	ci.draw_line(c + Vector2(0.18, -0.3) * r, c + Vector2(0.48, -0.24) * r, INK, line, true)
	ci.draw_colored_polygon(oval(c + Vector2(-0.5, 0.25) * r, r * 0.13, r * 0.09), Color(1.0, 0.45, 0.45, 0.45))
	# puckered mouth pushed out to one side
	var lips := Color("#d98a5f")
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.02, 0.3) * r, c + Vector2(0.42, 0.3) * r,
			c + Vector2(0.42, 0.56) * r, c + Vector2(0.02, 0.48) * r]), lips)
	ci.draw_circle(c + Vector2(0.45, 0.43) * r, r * 0.15, lips)
	ci.draw_circle(c + Vector2(0.47, 0.43) * r, r * 0.065, INK)


static func _tengu(ci: CanvasItem, c: Vector2, r: float) -> void:
	var line := maxf(2.0, r * 0.06)
	var beard := Color("#f2efe9")
	ci.draw_circle(c, r, INK)
	ci.draw_circle(c, r * 0.95, TENGU_RED)
	for i in 7:
		var a := lerpf(PI * 0.18, PI * 0.82, i / 6.0)
		ci.draw_circle(c + Vector2.from_angle(a) * r * 0.86, r * 0.2, beard)
	# fierce golden eyes under bushy white brows
	for s: float in [-1.0, 1.0]:
		var eye := c + Vector2(s * 0.33, -0.12) * r
		ci.draw_colored_polygon(oval(eye, r * 0.15, r * 0.1), Color("#fff2c0"))
		ci.draw_circle(eye, r * 0.075, Color("#e3a81b"))
		ci.draw_circle(eye, r * 0.035, INK)
		ci.draw_line(c + Vector2(s * 0.62, -0.42) * r, c + Vector2(s * 0.12, -0.24) * r, beard, r * 0.13, true)
	# the famous long nose
	var nose := PackedVector2Array()
	for p: Vector2 in [Vector2(-0.12, -0.2), Vector2(0.12, -0.2), Vector2(0.17, 0.25), Vector2(0.12, 0.8),
			Vector2(0.04, 1.08), Vector2(-0.06, 0.84), Vector2(-0.15, 0.25)]:
		nose.append(c + p * r)
	ci.draw_colored_polygon(nose, Color("#b51d31"))
	var outline := nose.duplicate()
	outline.append(nose[0])
	ci.draw_polyline(outline, INK, line * 0.6, true)
	ci.draw_line(c + Vector2(0.02, -0.1) * r, c + Vector2(0.04, 0.75) * r, Color(1, 1, 1, 0.35), r * 0.04, true)
