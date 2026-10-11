class_name Fov
## Recursive shadowcasting (8 octants). Fills map.visible and merges into map.explored.

const MULT := [
	[1, 0, 0, -1, -1, 0, 0, 1],
	[0, 1, -1, 0, 0, -1, 1, 0],
	[0, 1, 1, 0, 0, -1, -1, 0],
	[1, 0, 0, 1, -1, 0, 0, -1],
]


static func compute(map: GameMap, ox: int, oy: int, radius: int) -> void:
	map.visible.fill(0)
	map.visible[map.idx(ox, oy)] = 1
	for oct in 8:
		_cast(map, ox, oy, radius, 1, 1.0, 0.0, oct)
	for i in map.visible.size():
		if map.visible[i] == 1:
			map.explored[i] = 1


static func _cast(map: GameMap, cx: int, cy: int, radius: int, row: int, start: float, end: float, oct: int) -> void:
	if start < end:
		return
	var r2 := radius * radius
	var new_start := start
	for j in range(row, radius + 1):
		var dx := -j - 1
		var dy := -j
		var blocked := false
		while dx <= 0:
			dx += 1
			var X: int = cx + dx * MULT[0][oct] + dy * MULT[1][oct]
			var Y: int = cy + dx * MULT[2][oct] + dy * MULT[3][oct]
			var l_slope := (dx - 0.5) / (dy + 0.5)
			var r_slope := (dx + 0.5) / (dy - 0.5)
			if start < r_slope:
				continue
			elif end > l_slope:
				break
			if map.in_bounds(X, Y) and dx * dx + dy * dy <= r2:
				map.visible[map.idx(X, Y)] = 1
			var opaque := not map.transparent(X, Y)
			if blocked:
				if opaque:
					new_start = r_slope
					continue
				blocked = false
				start = new_start
			elif opaque and j < radius:
				blocked = true
				_cast(map, cx, cy, radius, j + 1, start, l_slope, oct)
				new_start = r_slope
		if blocked:
			break
