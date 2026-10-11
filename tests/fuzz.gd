extends SceneTree
## Random-bot soak test: plays many seeded runs with random actions, saving/loading along the way.
## Fails on any script error (headless exits non-zero) or broken invariant. godot --headless -s tests/fuzz.gd

const SEEDS := 40
const TURNS := 500

var failures := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", msg)


func _init() -> void:
	var deaths := 0
	var deepest := 0
	var turns_played := 0
	for s in range(1, SEEDS + 1):
		var gs := GameState.new_game(s)
		gs.player.max_hp = 400      # sturdy bot, so runs last long enough to reach deep floors
		gs.player.hp = 400
		var rng := RandomNumberGenerator.new()
		rng.seed = s * 977
		for t in TURNS:
			if gs.game_over:
				deaths += 1
				break
			_random_turn(gs, rng)
			turns_played += 1
			_invariants(gs, s, t)
			if t % 97 == 0:
				gs = _roundtrip(gs, s)
		deepest = maxi(deepest, gs.floor_no)
	print("fuzz: %d seeds, %d turns, %d deaths, deepest floor %d, failures %d" % [SEEDS, turns_played, deaths, deepest, failures])
	quit(1 if failures else 0)


func _random_turn(gs: GameState, rng: RandomNumberGenerator) -> void:
	var p := gs.player
	if p.requires_level_up():
		p.level_up(rng.randi() % 3)
	var roll := rng.randi() % 100
	var err := ""
	if roll < 55:
		var d: Vector2i = AI.DIRS[rng.randi() % 8]
		err = Actions.bump(gs, p, d.x, d.y)
	elif roll < 62:
		err = Actions.wait(gs, p)
	elif roll < 70:
		err = Actions.pickup(gs, p)
	elif roll < 82 and not p.inventory.is_empty():
		var it := p.inventory[rng.randi() % p.inventory.size()]
		var target := p.pos() + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4))
		err = Actions.use_item(gs, p, it, target)
	elif roll < 86 and not p.inventory.is_empty():
		err = Actions.drop(gs, p, p.inventory[rng.randi() % p.inventory.size()])
	elif roll < 90:
		p.x = gs.map.downstairs.x      # jump to the stairs now and then so deeper floors get exercised
		p.y = gs.map.downstairs.y
		err = Actions.take_stairs(gs, p)
	else:
		err = Actions.take_stairs(gs, p)
	gs.player_act(err)


func _invariants(gs: GameState, s: int, t: int) -> void:
	var p := gs.player
	var tag := "seed %d turn %d" % [s, t]
	check(gs.map.in_bounds(p.x, p.y) and gs.map.walkable(p.x, p.y), tag + ": player on a walkable tile")
	check(p.hp >= 0 and p.hp <= p.max_hp, tag + ": hp in range")
	check(p.alive == (p.hp > 0), tag + ": alive flag matches hp")
	check(p.inventory.size() <= p.capacity, tag + ": inventory within capacity")
	for it in p.inventory:
		check(it.count >= 1, tag + ": stack count positive")
		check(it.count == 1 or it.stackable(), tag + ": only consumables stack")
	check(p.weapon == null or p.inventory.has(p.weapon), tag + ": equipped weapon is in the inventory")
	check(p.armor == null or p.inventory.has(p.armor), tag + ": equipped armor is in the inventory")
	var seen := {}
	for e in gs.map.entities:
		if e is Actor and e.alive:
			check(gs.map.walkable(e.x, e.y), tag + ": actor on a wall")
			var key := e.pos()
			check(not seen.has(key), tag + ": two living actors share a tile")
			seen[key] = true


func _roundtrip(gs: GameState, s: int) -> GameState:
	var path := "user://fuzz_save.json"
	check(Save.write(gs, path), "seed %d: save written" % s)
	var back := Save.read(path)
	check(back != null, "seed %d: save readable" % s)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if back == null:
		return gs
	check(back.floor_no == gs.floor_no and back.player.hp == gs.player.hp and back.player.pos() == gs.player.pos(), "seed %d: state survives save/load" % s)
	check(back.player.inventory.size() == gs.player.inventory.size(), "seed %d: inventory survives save/load" % s)
	return back
