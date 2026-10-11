class_name AI
## Monster behaviour: hostile (chase/attack) and confused (stumble randomly).

const DIRS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
		Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]


static func act(gs: GameState, a: Actor) -> void:
	match a.ai:
		"hostile":
			_hostile(gs, a)
		"confused":
			_confused(gs, a)


static func _hostile(gs: GameState, a: Actor) -> void:
	var p := gs.player
	var dx := p.x - a.x
	var dy := p.y - a.y
	if gs.map.is_visible(a.x, a.y):
		if maxi(absi(dx), absi(dy)) <= 1:
			Actions.melee(gs, a, p)
			return
		a.path = _path(gs, a.pos(), p.pos())
	if not a.path.is_empty():
		var step: Vector2i = a.path.pop_front()
		Actions.move(gs, a, step.x - a.x, step.y - a.y)


static func _confused(gs: GameState, a: Actor) -> void:
	if a.confused_turns <= 0:
		gs.say("The %s is no longer confused." % a.display_name)
		a.ai = "hostile"
		return
	a.confused_turns -= 1
	var d: Vector2i = DIRS[gs.rng.randi() % DIRS.size()]
	Actions.bump(gs, a, d.x, d.y)


## A* path (excluding start). Other blockers cost extra so monsters queue up in corridors.
static func _path(gs: GameState, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var grid := gs.astar()
	var weighted: Array[Vector2i] = []
	for e in gs.map.entities:
		if e.blocks and e.pos() != from and e.pos() != to:
			grid.set_point_weight_scale(e.pos(), 11.0)
			weighted.append(e.pos())
	var ids := grid.get_id_path(from, to)
	for w in weighted:
		grid.set_point_weight_scale(w, 1.0)
	var out: Array[Vector2i] = []
	for i in range(1, ids.size()):
		out.append(ids[i])
	return out
