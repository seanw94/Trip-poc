extends Node
## CI smoke test: plays three full rounds headless (setup → spin → reveal →
## drink) and exits non-zero if anything stalls or the tally is wrong.

const ROUNDS := 3


func _ready() -> void:
	Engine.time_scale = 8.0
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.show_setup()
	game.set_player_count(3)
	game.start_play()
	var deadline := Time.get_ticks_msec() + 60000
	for round_i in ROUNDS:
		game.spin_random()
		while not game.is_revealing():
			if Time.get_ticks_msec() > deadline:
				_fail("round %d never reached the reveal" % round_i)
				return
			await get_tree().process_frame
		game.drink()
	var total: int = game.total_drinks()
	if total < ROUNDS:
		_fail("expected at least %d drinks, got %d" % [ROUNDS, total])
		return
	print("SMOKE OK: %d drinks over %d rounds" % [total, ROUNDS])
	get_tree().quit(0)


func _fail(reason: String) -> void:
	printerr("SMOKE FAIL: " + reason)
	get_tree().quit(1)
