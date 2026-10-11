class_name Version
## Overwritten by the release workflow. Single source of truth for the game version.
const VERSION := "0.0.0-dev"
const REPO := "AWeebTaku/ToTAK"


## True if semver string `remote` (optionally "v"-prefixed) is newer than `local`.
static func is_newer(remote: String, local: String) -> bool:
	var a := _parts(remote)
	var b := _parts(local)
	for i in 3:
		if a[i] != b[i]:
			return a[i] > b[i]
	return false


static func _parts(v: String) -> Array[int]:
	var core := v.trim_prefix("v").split("-")[0].split(".")
	var out: Array[int] = [0, 0, 0]
	for i in mini(3, core.size()):
		out[i] = int(core[i])
	return out
