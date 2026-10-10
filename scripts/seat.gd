extends Control
## A zabuton cushion at the table: the player's name, cup count, and markers
## for whose turn it is and who has been named (指名).

const UI = preload("res://scripts/ui.gd")
const SIZE := Vector2(156, 96)

var color: Color = UI.LACQUER
var lit := false
var is_turn := false
var declared := false

var _name: Label
var _count: Label


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE / 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = UI.label("", UI.BODY_FONT, 28, UI.CREAM, 6)
	_name.position = Vector2(10, 12)
	_name.size = Vector2(SIZE.x - 20, 40)
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_name)
	_count = UI.label("", UI.BODY_FONT, 22, UI.GOLD, 5)
	_count.position = Vector2(10, 50)
	_count.size = Vector2(SIZE.x - 20, 32)
	add_child(_count)


func set_info(player_name: String, count_text: String) -> void:
	_name.text = player_name
	_count.text = count_text
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, SIZE)
	if lit:
		draw_style_box(_rounded(Color(UI.GOLD, 0.35), 34), rect.grow(14))
	draw_style_box(_rounded(Color(0, 0, 0, 0.4), 22), Rect2(Vector2(4, 8), SIZE))
	var cushion := color.lightened(0.12) if lit else color.darkened(0.2)
	var border := UI.GOLD if lit else color.lightened(0.35)
	draw_style_box(_rounded(cushion, 22, border, 3), rect)
	# tassels on the corners and the stitched tuft in the middle
	for corner: Vector2 in [Vector2(8, 8), Vector2(SIZE.x - 8, 8), Vector2(8, SIZE.y - 8), SIZE - Vector2(8, 8)]:
		draw_circle(corner, 6, UI.GOLD)
		draw_circle(corner, 3, UI.INK)
	if is_turn:
		var c := Vector2(4, 4)
		draw_circle(c, 20, UI.INK)
		draw_circle(c, 17, UI.GOLD)
		draw_string(UI.TITLE_FONT, c + Vector2(-20, 8), "番", HORIZONTAL_ALIGNMENT_CENTER, 40, 22, UI.INK)
	if declared:
		var h := Vector2(SIZE.x - 6, 6)
		draw_circle(h, 26, Color("#c0392b"))
		draw_arc(h, 22, 0, TAU, 32, UI.CREAM, 2.5, true)
		draw_string(UI.TITLE_FONT, h + Vector2(-26, 7), "指名", HORIZONTAL_ALIGNMENT_CENTER, 52, 18, UI.CREAM)


func _rounded(bg: Color, radius: int, border := Color.TRANSPARENT, width := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	if width > 0:
		s.border_color = border
		s.set_border_width_all(width)
	return s
