class_name MapView
extends Node2D
## Draws the explored map. Call refresh() whenever tiles/FOV change.

const DIM := Color(0.3, 0.3, 0.4)    # remembered-but-unseen tiles: barely there

var map: GameMap
var floor_tint := Color.WHITE


func refresh(m: GameMap, depth := 1) -> void:
	map = m
	floor_tint = Depth.tint(depth)
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var atlas := Sprites.atlas()
	var T := Sprites.TILE
	for y in map.height:
		for x in map.width:
			if not map.is_explored(x, y):
				continue
			var name := ""
			match map.tile(x, y):
				GameMap.Tile.WALL:
					if map.tile(x, y + 1) == GameMap.Tile.WALL:
						name = "wall"
					else:
						name = "wall_skull" if (x * 31 + y * 17) % 11 == 0 else "wall_face"
				GameMap.Tile.STAIRS:
					name = "stairs"
				_:
					name = "floor_blood" if (x * 13 + y * 29) % 23 == 0 else ("floor_a" if (x * 7 + y * 13) % 5 < 3 else "floor_b")
			draw_texture_rect_region(atlas, Rect2(x * T, y * T, T, T), Sprites.region(name),
					floor_tint if map.is_visible(x, y) else DIM * floor_tint)
