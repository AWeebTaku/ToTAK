extends SceneTree
## Headless checks. Run: godot --headless -s tests/run.gd   (exit code 1 on failure)

var failures := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", msg)


func _init() -> void:
	test_procgen()
	test_fov()
	test_combat_and_xp()
	test_items()
	test_stacking()
	test_ai_chases()
	test_save_roundtrip()
	test_migration()
	print("tests done, failures: %d" % failures)
	quit(1 if failures else 0)


func test_procgen() -> void:
	for s in range(1, 21):
		var gs := GameState.new_game(s)
		var m := gs.map
		check(m.walkable(gs.player.x, gs.player.y), "seed %d: player on floor" % s)
		check(m.tile(m.downstairs.x, m.downstairs.y) == GameMap.Tile.STAIRS, "seed %d: stairs exist" % s)
		check(m.downstairs != gs.player.pos(), "seed %d: stairs not under player" % s)
		# stairs reachable from the player
		var grid := gs.astar()
		check(grid.get_id_path(gs.player.pos(), m.downstairs).size() > 0, "seed %d: stairs reachable" % s)


func test_fov() -> void:
	var m := GameMap.new(20, 20)
	for x in range(1, 19):
		for y in range(1, 19):
			m.set_tile(x, y, GameMap.Tile.FLOOR)
	for y in range(1, 19):
		m.set_tile(10, y, GameMap.Tile.WALL)
	Fov.compute(m, 5, 10, 8)
	check(m.is_visible(5, 10), "fov: origin visible")
	check(m.is_visible(8, 10), "fov: open floor visible")
	check(m.is_visible(10, 10), "fov: wall face visible")
	check(not m.is_visible(12, 10), "fov: behind wall hidden")
	check(not m.is_visible(5, 1), "fov: radius respected (distance 9)")


func _arena() -> GameState:
	var gs := GameState.new()
	gs.rng.seed = 1
	gs.player = Actor.make_player()
	gs.map = GameMap.new(20, 20)
	for x in range(1, 19):
		for y in range(1, 19):
			gs.map.set_tile(x, y, GameMap.Tile.FLOOR)
	gs.player.x = 5
	gs.player.y = 5
	gs.map.entities.append(gs.player)
	gs.update_fov()
	return gs


func _spawn(gs: GameState, kind: String, x: int, y: int) -> Actor:
	var a := Actor.make_monster(kind)
	a.x = x
	a.y = y
	gs.map.entities.append(a)
	return a


func test_combat_and_xp() -> void:
	var gs := _arena()
	var orc := _spawn(gs, "orc", 6, 5)
	check(gs.player.power() == 2, "unarmed arena player power is base 2")
	gs.player.base_power = 12
	check(Actions.bump(gs, gs.player, 1, 0) == "", "melee ok")
	check(not orc.alive, "orc dies from 12-0 damage")
	check(gs.player.xp == 35, "xp awarded on kill (got %d)" % gs.player.xp)
	check(orc.blocks == false and orc.sprite == "corpse", "corpse state")
	# level up
	gs.player.xp = 350
	check(not gs.player.requires_level_up(), "no level up at exactly 350")
	gs.player.xp = 351
	check(gs.player.requires_level_up(), "level up needed")
	gs.player.level_up(0)
	check(gs.player.level == 2 and gs.player.max_hp == 50, "level up +20 hp")
	# player death
	var troll := _spawn(gs, "troll", 5, 6)
	gs.player.hp = 1
	gs.player.base_defense = 0
	troll.base_power = 50
	AI.act(gs, troll)
	check(gs.game_over and not gs.player.alive, "player dies")


func test_items() -> void:
	var gs := _arena()
	var p := gs.player
	p.hp = 10
	var potion := Item.make("health_potion")
	p.inventory.append(potion)
	check(Actions.use_item(gs, p, potion) == "", "potion used")
	check(p.hp == 20 and not p.inventory.has(potion), "potion heals 10 and is consumed")
	var p2 := Item.make("health_potion")
	p.hp = p.max_hp
	p.inventory.append(p2)
	check(Actions.use_item(gs, p, p2) != "", "full health refuses potion")
	var orc := _spawn(gs, "orc", 8, 5)
	var conf := Item.make("confusion_scroll")
	p.inventory.append(conf)
	check(Actions.use_item(gs, p, conf, orc.pos()) == "" and orc.ai == "confused", "confusion applied")
	check(Actions.use_item(gs, p, Item.make("confusion_scroll"), p.pos()) != "", "cannot confuse self")
	var bolt := Item.make("lightning_scroll")
	p.inventory.append(bolt)
	check(Actions.use_item(gs, p, bolt) == "" and not orc.alive, "lightning kills orc")
	var troll := _spawn(gs, "troll", 7, 5)
	var fb := Item.make("fireball_scroll")
	p.inventory.append(fb)
	check(Actions.use_item(gs, p, fb, Vector2i(7, 5)) == "" and troll.hp == 4, "fireball deals 12 to troll")
	# equipment
	var sword := Item.make("sword")
	p.inventory.append(sword)
	Actions.equip(gs, p, sword)
	check(p.weapon == sword and p.power() == p.base_power + 4, "sword equipped")
	Actions.drop(gs, p, sword)
	check(p.weapon == null and gs.map.items_at(p.x, p.y).has(sword), "drop unequips and places item")
	check(Actions.pickup(gs, p) == "", "pickup works")


func test_stacking() -> void:
	var gs := _arena()
	var p := gs.player
	p.capacity = 3
	p.inventory.clear()
	var weapon := Item.make("dagger")
	var armor := Item.make("leather_armor")
	p.inventory.append(weapon)
	p.inventory.append(armor)
	for i in 3:
		var potion := Item.make("health_potion")
		potion.x = p.x
		potion.y = p.y
		gs.map.entities.append(potion)
		check(Actions.pickup(gs, p) == "", "pickup potion #%d (inventory has 1 free slot, stack must merge)" % (i + 1))
	check(p.inventory.size() == 3, "potions share one slot (got %d slots)" % p.inventory.size())
	check(p.inventory[2].count == 3, "stack count is 3 (got %d)" % p.inventory[2].count)
	# a different item no longer fits, but another potion still does
	var sword := Item.make("sword")
	sword.x = p.x
	sword.y = p.y
	gs.map.entities.append(sword)
	check(Actions.pickup(gs, p) == "Your inventory is full.", "full inventory refuses a new item type")
	gs.map.entities.erase(sword)
	# equipment does not stack
	check(not Item.make("dagger").stackable(), "weapons do not stack")
	# using consumes one at a time
	p.hp = 1
	var stack: Item = p.inventory[2]
	check(Actions.use_item(gs, p, stack) == "", "use one potion")
	check(stack.count == 2 and p.inventory.has(stack), "stack drops to 2, entry stays")
	p.hp = 1
	Actions.use_item(gs, p, stack)
	p.hp = 1
	Actions.use_item(gs, p, stack)
	check(not p.inventory.has(stack), "last potion removes the entry")
	# full-health refusal must not consume
	var keep := Item.make("health_potion")
	keep.count = 2
	p.inventory.append(keep)
	p.hp = p.max_hp
	check(Actions.use_item(gs, p, keep) != "" and keep.count == 2, "refused use keeps the stack intact")


func test_ai_chases() -> void:
	var gs := _arena()
	var orc := _spawn(gs, "orc", 15, 5)
	gs.update_fov()
	check(gs.map.is_visible(orc.x, orc.y) == false, "orc starts outside FOV")
	orc.x = 10
	gs.update_fov()
	check(gs.map.is_visible(orc.x, orc.y), "orc in FOV")
	var before := orc.distance(5, 5)
	AI.act(gs, orc)
	check(orc.distance(5, 5) < before, "orc approaches player")


func test_save_roundtrip() -> void:
	var gs := GameState.new_game(42)
	gs.player.xp = 77
	gs.player_act(Actions.wait(gs, gs.player))
	var path := "user://test_save.json"
	check(Save.write(gs, path), "save written")
	var back := Save.read(path)
	check(back != null, "save readable")
	if back == null:
		return
	check(back.floor_no == gs.floor_no and back.player.xp == 77, "player fields kept")
	check(back.player.weapon != null and back.player.weapon.kind == "dagger", "equipment kept")
	var q := Item.make("health_potion")
	q.count = 4
	gs.player.inventory.append(q)
	Save.write(gs, path)
	var back2 := Save.read(path)
	check(back2.player.inventory[-1].count == 4, "stack counts survive save/load")
	check(back.map.entities.size() == gs.map.entities.size(), "entities kept")
	check(back.map.tiles == gs.map.tiles and back.map.downstairs == gs.map.downstairs, "map kept")
	check(back.rng.state == gs.rng.state, "rng state kept")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_migration() -> void:
	var table := {1: func(d): d["new_field"] = 7; return d, 2: func(d): d["renamed"] = d["new_field"]; return d}
	var out: Dictionary = Save.migrate({"save_version": 1}, table)
	check(out.save_version == 3 and out.renamed == 7, "migrations chain in order")
	check(Save.migrate({"save_version": Save.SAVE_VERSION + 1}) == null, "newer save rejected")
