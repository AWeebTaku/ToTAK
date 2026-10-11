class_name GameMap
extends RefCounted

enum Tile { WALL, FLOOR, STAIRS }

var width: int
var height: int
var tiles := PackedByteArray()
var visible := PackedByteArray()
var explored := PackedByteArray()
var entities: Array[Entity] = []
var downstairs := Vector2i.ZERO


func _init(w: int, h: int) -> void:
	width = w
	height = h
	tiles.resize(w * h)
	visible.resize(w * h)
	explored.resize(w * h)


func idx(x: int, y: int) -> int:
	return y * width + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func tile(x: int, y: int) -> int:
	return tiles[idx(x, y)] if in_bounds(x, y) else Tile.WALL


func set_tile(x: int, y: int, t: int) -> void:
	tiles[idx(x, y)] = t


func walkable(x: int, y: int) -> bool:
	return tile(x, y) != Tile.WALL


func transparent(x: int, y: int) -> bool:
	return tile(x, y) != Tile.WALL


func is_visible(x: int, y: int) -> bool:
	return in_bounds(x, y) and visible[idx(x, y)] == 1


func is_explored(x: int, y: int) -> bool:
	return in_bounds(x, y) and explored[idx(x, y)] == 1


func actors() -> Array[Actor]:
	var out: Array[Actor] = []
	for e in entities:
		if e is Actor and e.alive:
			out.append(e)
	return out


func items_at(x: int, y: int) -> Array[Item]:
	var out: Array[Item] = []
	for e in entities:
		if e is Item and e.x == x and e.y == y:
			out.append(e)
	return out


func blocker_at(x: int, y: int) -> Entity:
	for e in entities:
		if e.blocks and e.x == x and e.y == y:
			return e
	return null


func actor_at(x: int, y: int) -> Actor:
	for e in entities:
		if e is Actor and e.alive and e.x == x and e.y == y:
			return e
	return null


func occupied(x: int, y: int) -> bool:
	for e in entities:
		if e.x == x and e.y == y:
			return true
	return false
