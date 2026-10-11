class_name Sprites
## Tile atlas lookup. NAMES order must match tools/gen_assets.py.

const TILE := 16
const NAMES := ["floor_a", "floor_b", "wall", "stairs", "player", "orc", "troll", "corpse",
		"potion", "scroll", "dagger", "sword", "leather", "chain", "wall_face", "glow", "floor_blood", "wall_skull"]

static var _atlas: Texture2D
static var _cache := {}


static func atlas() -> Texture2D:
	if _atlas == null:
		_atlas = load("res://assets/tiles.png")
	return _atlas


static func region(name: String) -> Rect2:
	return Rect2(NAMES.find(name) * TILE, 0, TILE, TILE)


static func texture(name: String) -> AtlasTexture:
	if not _cache.has(name):
		var t := AtlasTexture.new()
		t.atlas = atlas()
		t.region = region(name)
		_cache[name] = t
	return _cache[name]


## Soft round light texture for PointLight2D.
static func light_texture(size := 256) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.55), Color(0, 0, 0, 1)])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t

