class_name Entity
extends RefCounted
## Anything on the map. Actors and items extend this.

enum Order { CORPSE, ITEM, ACTOR }

var kind := ""
var display_name := ""
var sprite := ""
var tint := Color.WHITE
var x := 0
var y := 0
var blocks := false
var order := Order.CORPSE


func pos() -> Vector2i:
	return Vector2i(x, y)


func distance(px: int, py: int) -> float:
	return Vector2(x, y).distance_to(Vector2(px, py))
