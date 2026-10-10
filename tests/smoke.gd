extends Node
## CI smoke test, run headless: plays group, 指名 and two-player rounds and
## opens every overlay, failing on a stall or a wrong tally.

var game


func _ready() -> void:
	Engine.time_scale = 8.0
	game = load("res://main.tscn").instantiate()
	add_child(game)
	if not game.has_method("start_play"):
		_fail("main.gd failed to load")
		return
	await get_tree().process_frame

	game.set_option("declare", false)
	game.set_option("table", false)
	game.open_setup(4)
	game.start_play()
	for i in 4:
		var ok: bool = await _round(-1)
		if not ok:
			return
	if game.total_drinks() < 4:
		_fail("group: expected at least 4 drinks, got %d" % game.total_drinks())
		return

	game.set_option("declare", true)
	game.open_setup(2, true)
	game.start_play()
	for i in 3:
		var ok: bool = await _round(1)
		if not ok:
			return
	if game.total_drinks() < 3:
		_fail("duo: expected at least 3 drinks, got %d" % game.total_drinks())
		return

	game.show_rules()
	game.show_banzuke()
	game.show_water_break()
	game.close_overlay()
	print("SMOKE OK")
	get_tree().quit(0)


## One spin → reveal → drink. declare_index >= 0 names that player first.
func _round(declare_index: int) -> bool:
	game.close_overlay()
	if declare_index >= 0:
		game.declare(declare_index)
	game.spin_with(30.0)
	var deadline := Time.get_ticks_msec() + 30000
	while not game.is_revealing():
		if Time.get_ticks_msec() > deadline:
			_fail("a round never reached the reveal")
			return false
		await get_tree().process_frame
	game.drink()
	return true


func _fail(reason: String) -> void:
	printerr("SMOKE FAIL: " + reason)
	get_tree().quit(1)
