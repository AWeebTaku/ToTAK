class_name Save
## JSON save files with a version number and an ordered migration chain.
## To change the format: bump SAVE_VERSION and add MIGRATIONS[old_version] = Callable(dict) -> dict.

const SAVE_VERSION := 1
const PATH := "user://save.json"
const MIGRATIONS := {}   # int -> Callable; e.g. 1: Save._v1_to_v2


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


static func write(gs: GameState, path := PATH) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(gs)))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK


## Returns null if missing/corrupt.
static func read(path := PATH) -> GameState:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return null
	data = migrate(data)
	if data == null:
		return null
	return from_dict(data)


static func migrate(data: Dictionary, table := MIGRATIONS) -> Variant:
	var v := int(data.get("save_version", 1))
	if v > SAVE_VERSION and table == MIGRATIONS:
		return null   # saved by a newer game
	while table.has(v):
		data = table[v].call(data)
		v += 1
		data["save_version"] = v
	return data


static func to_dict(gs: GameState) -> Dictionary:
	var m := gs.map
	var ents: Array = []
	for e in m.entities:
		if e is Actor and not e.is_player:
			ents.append(_actor(e))
		elif e is Item:
			ents.append({"t": "item", "kind": e.kind, "count": e.count, "x": e.x, "y": e.y})
	return {
		"save_version": SAVE_VERSION,
		"game_version": Version.VERSION,
		"floor": gs.floor_no,
		"game_over": gs.game_over,
		"rng_seed": str(gs.rng.seed), "rng_state": str(gs.rng.state),
		"player": _actor(gs.player),
		"map": {
			"w": m.width, "h": m.height,
			"tiles": Marshalls.raw_to_base64(m.tiles),
			"explored": Marshalls.raw_to_base64(m.explored),
			"stairs": [m.downstairs.x, m.downstairs.y],
		},
		"entities": ents,
		"log": gs.log.slice(-100).map(func(l): return {"text": l.text, "color": l.color.to_html()}),
	}


static func _actor(a: Actor) -> Dictionary:
	return {
		"t": "actor", "kind": a.kind, "x": a.x, "y": a.y, "hp": a.hp, "max_hp": a.max_hp,
		"defense": a.base_defense, "power": a.base_power, "alive": a.alive, "ai": a.ai,
		"confused": a.confused_turns, "level": a.level, "xp": a.xp,
		"inventory": a.inventory.map(func(i): return i.kind),
		"counts": a.inventory.map(func(i): return i.count),
		"weapon": a.inventory.find(a.weapon), "armor": a.inventory.find(a.armor),
	}


static func _make_actor(d: Dictionary) -> Actor:
	var a := Actor.make_player() if d.kind == "player" else Actor.make_monster(d.kind)
	a.x = int(d.x)
	a.y = int(d.y)
	a.hp = int(d.hp)
	a.max_hp = int(d.max_hp)
	a.base_defense = int(d.defense)
	a.base_power = int(d.power)
	a.ai = d.ai
	a.confused_turns = int(d.confused)
	a.level = int(d.level)
	a.xp = int(d.xp)
	for n in d.inventory.size():
		var it := Item.make(d.inventory[n])
		it.count = int(d.counts[n]) if d.has("counts") else 1   # saves from before stacking have no counts
		a.inventory.append(it)
	if int(d.weapon) >= 0:
		a.weapon = a.inventory[int(d.weapon)]
	if int(d.armor) >= 0:
		a.armor = a.inventory[int(d.armor)]
	if not d.alive:
		a.become_corpse()
	return a


static func from_dict(d: Dictionary) -> GameState:
	var gs := GameState.new()
	gs.floor_no = int(d.floor)
	gs.game_over = d.game_over
	gs.rng.seed = int(d.rng_seed)
	gs.rng.state = int(d.rng_state)
	gs.player = _make_actor(d.player)
	var md: Dictionary = d.map
	var m := GameMap.new(int(md.w), int(md.h))
	m.tiles = Marshalls.base64_to_raw(md.tiles)
	m.explored = Marshalls.base64_to_raw(md.explored)
	m.downstairs = Vector2i(int(md.stairs[0]), int(md.stairs[1]))
	m.entities.append(gs.player)
	for e in d.entities:
		if e.t == "actor":
			m.entities.append(_make_actor(e))
		else:
			var it := Item.make(e.kind)
			it.count = int(e.get("count", 1))
			it.x = int(e.x)
			it.y = int(e.y)
			m.entities.append(it)
	gs.map = m
	for l in d.log:
		gs.log.append({"text": l.text, "color": Color(l.color)})
	gs.update_fov()
	return gs
