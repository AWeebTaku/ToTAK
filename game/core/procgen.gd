class_name Procgen
## Dungeon generation: random rooms joined by L-shaped tunnels, weighted spawns by floor.

const MAX_ROOMS := 30
const ROOM_MIN := 6
const ROOM_MAX := 10


class Room:
	var x1: int
	var y1: int
	var x2: int
	var y2: int

	func _init(x: int, y: int, w: int, h: int) -> void:
		x1 = x
		y1 = y
		x2 = x + w
		y2 = y + h

	func center() -> Vector2i:
		return Vector2i((x1 + x2) / 2, (y1 + y2) / 2)

	func intersects(o: Room) -> bool:
		return x1 <= o.x2 and x2 >= o.x1 and y1 <= o.y2 and y2 >= o.y1


## Generates a map and places `player` in the first room. Needs >= 2 rooms (retries otherwise).
static func generate(player: Actor, floor_no: int, rng: RandomNumberGenerator, w := 80, h := 43) -> GameMap:
	while true:
		var m := _attempt(player, floor_no, rng, w, h)
		if m != null:
			return m
	return null


static func _attempt(player: Actor, floor_no: int, rng: RandomNumberGenerator, w: int, h: int) -> GameMap:
	var map := GameMap.new(w, h)
	map.entities.append(player)
	var rooms: Array[Room] = []
	for _i in MAX_ROOMS:
		var rw := rng.randi_range(ROOM_MIN, ROOM_MAX)
		var rh := rng.randi_range(ROOM_MIN, ROOM_MAX)
		var room := Room.new(rng.randi_range(0, w - rw - 1), rng.randi_range(0, h - rh - 1), rw, rh)
		var clash := false
		for o in rooms:
			if room.intersects(o):
				clash = true
				break
		if clash:
			continue
		for yy in range(room.y1 + 1, room.y2):
			for xx in range(room.x1 + 1, room.x2):
				map.set_tile(xx, yy, GameMap.Tile.FLOOR)
		if rooms.is_empty():
			player.x = room.center().x
			player.y = room.center().y
		else:
			for p in _tunnel(rooms[-1].center(), room.center(), rng):
				map.set_tile(p.x, p.y, GameMap.Tile.FLOOR)
			map.downstairs = room.center()
		_place_entities(room, map, floor_no, rng)
		rooms.append(room)
	if rooms.size() < 2:
		return null
	map.set_tile(map.downstairs.x, map.downstairs.y, GameMap.Tile.STAIRS)
	return map


static func _tunnel(a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var corner := Vector2i(b.x, a.y) if rng.randf() < 0.5 else Vector2i(a.x, b.y)
	var out: Array[Vector2i] = []
	for seg in [[a, corner], [corner, b]]:
		var p: Vector2i = seg[0]
		var q: Vector2i = seg[1]
		var step := Vector2i(signi(q.x - p.x), signi(q.y - p.y))
		out.append(p)
		while p != q:
			p += step
			out.append(p)
	return out


static func max_for_floor(table: Array, floor_no: int) -> int:
	var cur := 0
	for e in table:
		if e[0] > floor_no:
			break
		cur = int(e[1])
	return cur


## Weights accumulate over floors; later floors override a kind's weight (same as the Python original).
static func pick(table: Array, count: int, floor_no: int, rng: RandomNumberGenerator) -> Array[String]:
	var weights := {}
	for e in table:
		if e[0] > floor_no:
			break
		for k in e[1]:
			weights[k] = e[1][k]
	var out: Array[String] = []
	var total := 0.0
	for k in weights:
		total += weights[k]
	for _i in count:
		var roll := rng.randf() * total
		for k in weights:
			roll -= weights[k]
			if roll <= 0.0:
				out.append(k)
				break
	return out


static func _place_entities(room: Room, map: GameMap, floor_no: int, rng: RandomNumberGenerator) -> void:
	var sp := Data.spawns()
	var n_mon := rng.randi_range(0, max_for_floor(sp.max_monsters, floor_no))
	var n_item := rng.randi_range(0, max_for_floor(sp.max_items, floor_no))
	var spawned: Array[Entity] = []
	for k in pick(sp.monsters, n_mon, floor_no, rng):
		spawned.append(Actor.make_monster(k))
	for k in pick(sp.items, n_item, floor_no, rng):
		spawned.append(Item.make(k))
	for e in spawned:
		e.x = rng.randi_range(room.x1 + 1, room.x2 - 1)
		e.y = rng.randi_range(room.y1 + 1, room.y2 - 1)
		if not map.occupied(e.x, e.y):  # also skips the player's tile
			map.entities.append(e)
