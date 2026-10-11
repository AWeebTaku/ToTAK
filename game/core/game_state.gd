class_name GameState
extends RefCounted
## The whole run: player, current map, floor number, message log, turn loop.

signal message(text: String, color: Color)
signal fx(kind: String, data: Dictionary)   # animation/sound cues for the view
signal changed                              # map/FOV/entities changed

const FOV_RADIUS := 8
const MAX_LOG := 500

var player: Actor
var map: GameMap
var floor_no := 0
var log: Array = []                # [{text, color}]
var game_over := false
var rng := RandomNumberGenerator.new()
var _astar: AStarGrid2D


static func new_game(seed_value := 0) -> GameState:
	var gs := GameState.new()
	if seed_value == 0:
		gs.rng.randomize()
	else:
		gs.rng.seed = seed_value
	gs.player = Actor.make_player()
	gs.descend()
	gs.say("Hello and welcome, adventurer, to yet another dungeon!", Palette.WELCOME)
	for k in ["dagger", "leather_armor"]:
		var it := Item.make(k)
		gs.player.inventory.append(it)
		gs.player.toggle_equip(it)
	return gs


func say(text: String, color := Color.WHITE) -> void:
	log.append({"text": text, "color": color})
	if log.size() > MAX_LOG:
		log.pop_front()
	message.emit(text, color)


func descend() -> void:
	floor_no += 1
	map = Procgen.generate(player, floor_no, rng)
	_astar = null
	update_fov()


func update_fov() -> void:
	Fov.compute(map, player.x, player.y, FOV_RADIUS)


func astar() -> AStarGrid2D:
	if _astar == null:
		_astar = AStarGrid2D.new()
		_astar.region = Rect2i(0, 0, map.width, map.height)
		_astar.cell_size = Vector2.ONE
		_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
		_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_astar.update()
		for y in map.height:
			for x in map.width:
				if not map.walkable(x, y):
					_astar.set_point_solid(Vector2i(x, y))
	return _astar


## Applies damage from `source`, handling death, XP and the game-over flag.
func damage(target: Actor, amount: int, source: Actor) -> void:
	fx.emit("hit", {"entity": target, "amount": amount})
	if not target.take_damage(amount):
		return
	fx.emit("died", {"entity": target})
	if target.is_player:
		game_over = true
		say("You died!", Palette.PLAYER_DIE)
		return
	say("%s is dead!" % target.display_name.replace("remains of ", "").capitalize(), Palette.ENEMY_DIE)
	if source != null and source.is_player and target.xp_given > 0:
		player.add_xp(target.xp_given)
		say("You gain %d experience points." % target.xp_given)
		if player.requires_level_up():
			say("You advance to level %d!" % (player.level + 1))
			fx.emit("levelup", {})


## Runs a player action. On success, monsters act and FOV updates. Returns true if a turn passed.
func player_act(error: String) -> bool:
	if error != "":
		say(error, Palette.IMPOSSIBLE)
		return false
	end_player_turn()
	return true


func end_player_turn() -> void:
	if not game_over:
		for a in map.actors():
			if a != player and a.alive and not game_over:
				AI.act(self, a)
	update_fov()
	changed.emit()
