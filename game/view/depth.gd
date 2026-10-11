class_name Depth
## The deeper you go, the darker and eerier the tomb. Used for tile tint, ambient light and names.

const NAMES := ["The Antechamber", "The Burial Halls", "The Moss Crypts", "The Ossuary",
		"The Sunken Vaults", "The Blood Catacombs", "The Forgotten Deep", "The Abyssal Tomb"]
const TINTS := [Color(0.9, 0.88, 0.85), Color(0.85, 0.8, 0.75), Color(0.72, 0.86, 0.72), Color(0.78, 0.8, 0.92),
		Color(0.65, 0.78, 0.9), Color(0.95, 0.6, 0.6), Color(0.78, 0.65, 0.9), Color(0.62, 0.62, 0.72)]


static func name_of(floor_no: int) -> String:
	return NAMES[mini(floor_no - 1, NAMES.size() - 1)]


static func tint(floor_no: int) -> Color:
	return TINTS[(floor_no - 1) % TINTS.size()]


## Ambient light: starts dim and drops steadily, never fully black.
static func ambient(floor_no: int) -> Color:
	var v := maxf(0.05, 0.17 - 0.02 * (floor_no - 1))
	return Color(v, v * 0.9, v * 1.15)
