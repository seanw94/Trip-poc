extends Node
## Renders the main screens to PNGs for visual review in CI:
##   godot --path . res://tests/shots.tscn -- --out <dir>

var game
var out_dir := "user://shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--out")
	if at >= 0 and at + 1 < args.size():
		out_dir = args[at + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	seed(20261010)
	get_window().size = Vector2i(720, 1280)
	game = load("res://main.tscn").instantiate()
	add_child(game)
	game.set_option("declare", false)
	game.set_option("table", false)
	await _settle(0.6)
	await _shot("01_title")

	game.open_setup(4)
	await _settle(0.3)
	await _shot("02_setup")

	game.start_play()
	await _settle(0.4)
	await _shot("03_table")

	game.spin_with(32.0)
	await _settle(0.7)
	await _shot("04_spinning")
	await _until_reveal()
	await _settle(0.8)
	await _shot("05_reveal")

	for i in 3:
		game.drink()
		game.spin_with(30.0)
		await _until_reveal()
	game.drink()
	game.show_banzuke()
	await _settle(0.5)
	await _shot("06_banzuke")
	game.close_overlay()

	game.show_rules()
	await _settle(0.5)
	await _shot("07_rules")
	game.close_overlay()

	game.show_water_break()
	await _settle(0.5)
	await _shot("08_water")
	game.close_overlay()

	game.set_option("declare", true)
	game.open_setup(2, true)
	game.start_play()
	game.declare(1)
	await _settle(0.5)
	await _shot("09_duo_declared")
	game.spin_with(30.0)
	await _until_reveal()
	await _settle(0.8)
	await _shot("10_duo_reveal")
	game.drink()

	game.set_option("declare", false)
	game.set_option("table", false)
	game.open_setup(4)
	game.start_play()
	game.force_bonus = "kanpai"
	game.spin_with(30.0)
	await _until_reveal()
	await _settle(0.8)
	await _shot("12_kanpai")
	game.drink()
	game.force_bonus = "buddy"
	game.spin_with(30.0)
	await _until_reveal()
	await _settle(0.8)
	await _shot("13_buddy")
	game.drink()
	game.force_bonus = ""

	game.set_option("table", true)
	game.open_setup(6)
	game.start_play()
	get_window().size = Vector2i(720, 1600)
	await _settle(0.6)
	await _shot("11_six_table_tall")
	get_tree().quit(0)


func _until_reveal() -> void:
	Engine.time_scale = 6.0
	var deadline := Time.get_ticks_msec() + 30000
	while not game.is_revealing() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	Engine.time_scale = 1.0


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot_name + ".png"))
	print("shot ", shot_name, " ", img.get_size())
