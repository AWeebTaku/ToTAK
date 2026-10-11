extends SceneTree
## Headless UI smoke test: boots the menu, starts a game and presses keys. godot --headless -s tests/smoke.gd

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


func click(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = button
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame


func _initialize() -> void:
	var app: Node = root.get_node("App")
	change_scene_to_file("res://game/ui/menu.tscn")
	await process_frame
	await process_frame
	app.start_new_game()
	for i in 3:
		await process_frame
	var game := current_scene
	assert(game.name == "Game", "game scene loaded")
	var start: Vector2i = game.gs.player.pos()
	for k in [KEY_RIGHT, KEY_DOWN, KEY_LEFT, KEY_UP, KEY_PERIOD, KEY_G]:
		await key(k)
	await key(KEY_T)
	assert(game.mode == game.Mode.INV_DROP, "drop mode")
	await key(KEY_ESCAPE)
	assert(game.mode == game.Mode.PLAY, "drop mode cancelled")
	# hotbar: key 1 uses slot 1 (the equipped dagger toggles), wheel scrolls past 10 items
	var weapon_before = game.gs.player.weapon
	await key(KEY_1)
	assert(game.gs.player.weapon != weapon_before, "key 1 toggles the first inventory item")
	await key(KEY_1)
	assert(game.gs.player.weapon == weapon_before, "key 1 again re-equips it")
	for k in ["health_potion", "health_potion", "sword", "chain_mail", "health_potion", "health_potion", "sword", "chain_mail", "sword", "sword"]:
		game.gs.player.inventory.append(Item.make(k))
	game._sync()
	game.hud.scroll_inventory(1)
	assert(game.hud.inventory_offset() == 1, "wheel scrolls hotbar window")
	game.hud.scroll_inventory(-5)
	assert(game.hud.inventory_offset() == 0, "scroll clamps at start")
	game.hud.scroll_inventory(99)
	assert(game.hud.inventory_offset() == game.gs.player.inventory.size() - 10, "scroll clamps at end")
	game.hud.scroll_inventory(-99)
	var hp0: int = game.gs.player.hp
	game.gs.player.hp = 5
	game.gs.player.inventory.append(Item.make("health_potion"))
	var n0: int = game.gs.player.inventory.size()
	await key(KEY_Q)
	assert(game.gs.player.inventory.size() == n0 - 1, "Q drinks a health potion")
	game.gs.player.inventory = game.gs.player.inventory.filter(func(i): return not i.def.has("effect"))
	var n1: int = game.gs.player.inventory.size()
	await key(KEY_Q)
	assert(game.gs.player.inventory.size() == n1, "Q with no potion does nothing")
	game.gs.player.hp = hp0
	var wx: int = game.gs.player.x
	var wy: int = game.gs.player.y
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		await key(k)
	assert(absi(game.gs.player.x - wx) + absi(game.gs.player.y - wy) <= 2, "WASD moves")
	Save.delete()
	assert(game.hud._save_icon.modulate.a == 0.0, "save icon hidden by default")
	await key(KEY_F5)
	assert(Save.exists(), "F5 quick-saves")
	assert(game.hud._save_icon.modulate.a > 0.5, "save icon appears on F5")
	await create_timer(1.8).timeout
	assert(game.hud._save_icon.modulate.a == 0.0, "save icon fades out again")
	await key(KEY_C)
	assert(game.mode == game.Mode.CHARACTER, "character screen")
	game.hud.close_clicked.emit()
	assert(game.mode == game.Mode.PLAY, "red X closes character screen")
	game.hud.pause_clicked.emit()
	game.hud.close_clicked.emit()
	assert(game.mode == game.Mode.PLAY, "red X closes pause menu")
	game._open_levelup()
	game.hud.close_clicked.emit()
	assert(game.mode == game.Mode.LEVELUP, "level-up cannot be dismissed with X")
	game._close_modal()
	await key(KEY_V)
	await key(KEY_ESCAPE)
	await key(KEY_SLASH)
	assert(game.mode == game.Mode.TARGET, "look mode")
	await key(KEY_ESCAPE)
	game.hud.pause_clicked.emit()
	assert(game.mode == game.Mode.PAUSE, "pause button opens pause menu")
	await key(KEY_ESCAPE)
	assert(game.mode == game.Mode.PLAY, "esc resumes")
	await key(KEY_ESCAPE)
	assert(game.mode == game.Mode.PAUSE, "pause open")
	game._open_help()
	await process_frame
	await click(Vector2(5, 300))
	assert(game.mode == game.Mode.PLAY, "click outside closes help (dimmed-overlay menus need a real window for hover, checked by hand)")
	game._open_pause()
	game._on_pause_action("help")
	assert(game.mode == game.Mode.HELP, "help opened from pause")
	await key(KEY_SPACE)
	assert(game.mode == game.Mode.PAUSE, "closing controls returns to pause menu")
	await key(KEY_R)
	assert(game.mode == game.Mode.PLAY, "resumed")
	# stairs: teleport onto them, descend, wait out the fade
	var g: GameState = game.gs
	g.player.x = g.map.downstairs.x
	g.player.y = g.map.downstairs.y
	await key(KEY_PERIOD, ">".unicode_at(0), true)
	assert(g.floor_no == 2, "descended to floor 2")
	for i in 90:
		await process_frame
	assert(game.mode == game.Mode.PLAY, "input restored after fade")
	await key(KEY_ENTER)
	await key(KEY_M)
	await key(KEY_M)
	# hold-to-walk: carve a straight corridor, hold RIGHT for a while, then release
	var gm: GameMap = game.gs.map
	var py: int = game.gs.player.y
	var px: int = game.gs.player.x
	for x in range(px, mini(px + 14, gm.width - 2)):
		gm.set_tile(x, py, GameMap.Tile.FLOOR)
	game.gs.map.entities = game.gs.map.entities.filter(func(e): return e == game.gs.player or e is Item)
	var hold := InputEventKey.new()
	hold.keycode = KEY_RIGHT
	hold.physical_keycode = KEY_RIGHT
	hold.pressed = true
	Input.parse_input_event(hold)
	for i in 70:
		await process_frame
	var walked: int = game.gs.player.x - px
	assert(walked >= 4, "holding a move key keeps walking (walked %d)" % walked)
	var rel := InputEventKey.new()
	rel.keycode = KEY_RIGHT
	rel.physical_keycode = KEY_RIGHT
	rel.pressed = false
	Input.parse_input_event(rel)
	await process_frame
	var stopped_at: int = game.gs.player.x
	for i in 30:
		await process_frame
	assert(game.gs.player.x == stopped_at, "releasing the key stops the walk")
	# walk around randomly for a while, then force a death
	for i in 200:
		await key([KEY_RIGHT, KEY_DOWN, KEY_LEFT, KEY_UP, KEY_KP_7, KEY_KP_3][i % 6])
	game.gs.player.hp = 1
	game.gs.damage(game.gs.player, 5, null)
	game._open_dead()
	await process_frame
	print("smoke ok; start=%s end=%s floor=%d" % [start, game.gs.player.pos(), game.gs.floor_no])
	quit(0)
