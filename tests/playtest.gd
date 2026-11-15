extends SceneTree
## Real-input playtest: random keys, clicks and wheel through every screen, forced deaths and level-ups,
## menu round trips. Run via tests/playtest.sh, which fails on any "SCRIPT ERROR" / "ERROR:" line in the output.

const KEYS := [KEY_RIGHT, KEY_LEFT, KEY_UP, KEY_DOWN, KEY_W, KEY_A, KEY_S, KEY_D, KEY_Y, KEY_U, KEY_B, KEY_N,
		KEY_KP_1, KEY_KP_3, KEY_KP_7, KEY_KP_9, KEY_PERIOD, KEY_SPACE, KEY_G, KEY_T, KEY_Q, KEY_C, KEY_V, KEY_M,
		KEY_ENTER, KEY_ESCAPE, KEY_SLASH, KEY_X, KEY_F1, KEY_F5, KEY_R, KEY_H, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5,
		KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_A, KEY_B, KEY_C, KEY_PERIOD, KEY_PERIOD]
var rng := RandomNumberGenerator.new()
var menu_trips := 0
var deaths := 0


func key(code: int, unicode := 0, shift := false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.unicode = unicode
		e.shift_pressed = shift
		e.pressed = pressed
		Input.parse_input_event(e)
	await process_frame


func mouse(button: int, pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = button
		e.pressed = pressed
		Input.parse_input_event(e)
	await process_frame


func in_game() -> bool:
	return current_scene != null and current_scene.name == "Game" and current_scene.get("gs") != null


func _initialize() -> void:
	rng.seed = int(OS.get_environment("SEED") if OS.get_environment("SEED") != "" else "7")
	var app: Node = root.get_node("App")
	Save.delete()
	change_scene_to_file("res://game/ui/menu.tscn")
	for i in 3:
		await process_frame
	# menu pages by keyboard
	await key(KEY_ESCAPE)
	app.start_new_game()
	for i in 4:
		await process_frame

	var steps := int(OS.get_environment("STEPS") if OS.get_environment("STEPS") != "" else "6000")
	for n in steps:
		if not in_game():
			# back at the menu (or mid-load): restart or continue like a player would
			menu_trips += 1
			for i in 3:
				await process_frame
			if current_scene != null and current_scene.name == "Menu":
				await key(KEY_ESCAPE)
				if Save.exists() and rng.randf() < .5:
					app.continue_game()
				else:
					app.start_new_game()
				for i in 4:
					await process_frame
			continue
		var g = current_scene
		var r := rng.randf()
		if r < .006:     # die
			g.gs.player.hp = 1
			g.gs.damage(g.gs.player, 9, null)
			g._open_dead() if g.gs.game_over and g.mode != g.Mode.DEAD else null
			deaths += 1
		elif r < .012 and g.mode == g.Mode.PLAY:    # level up
			g.gs.player.xp += 100000
			g._act("")
		elif r < .02 and g.mode == g.Mode.PLAY:     # items to exercise targeting and drops
			for k in ["lightning_scroll", "fireball_scroll", "confusion_scroll", "health_potion", "sword", "chain_mail", "dagger", "leather_armor"]:
				g.gs.player.inventory.append(Item.make(k))
			g._sync()
		elif r < .03 and g.mode == g.Mode.PLAY:     # stairs
			g.gs.player.x = g.gs.map.downstairs.x
			g.gs.player.y = g.gs.map.downstairs.y
			await key(KEY_PERIOD, ">".unicode_at(0), true)
			for i in 80:
				await process_frame
		elif r < .06:    # mouse: clicks anywhere, right-click, wheel
			var pos := Vector2(rng.randf() * 1280, rng.randf() * 720)
			await mouse([MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN][rng.randi() % 4], pos)
		elif r < .065:
			await key(KEY_SLASH, "?".unicode_at(0), true)
		else:
			var k: int = KEYS[rng.randi() % KEYS.size()]
			if k == KEY_Q and g.mode == g.Mode.PAUSE:
				continue    # Q in the pause menu quits the program, by design
			await key(k, 0, rng.randf() < .1)
	print("playtest ok: steps=%d deaths=%d menu_trips=%d" % [steps, deaths, menu_trips])
	quit(0)
