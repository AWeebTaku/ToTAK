class_name Data
## Lazy-loaded JSON definitions (monsters, items, spawn tables).

static var _cache := {}


static func load_json(name: String) -> Variant:
	if not _cache.has(name):
		var f := FileAccess.open("res://game/data/%s.json" % name, FileAccess.READ)
		assert(f != null, "missing data file %s" % name)
		_cache[name] = JSON.parse_string(f.get_as_text())
	return _cache[name]


static func monster(kind: String) -> Dictionary:
	return load_json("monsters")[kind]


static func item(kind: String) -> Dictionary:
	return load_json("items")[kind]


static func spawns() -> Dictionary:
	return load_json("spawns")
