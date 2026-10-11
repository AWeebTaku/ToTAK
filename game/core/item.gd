class_name Item
extends Entity
## A pickup: consumable (has an `effect`) or equippable (has a `slot`).

var def := {}
var count := 1          # stack size; only consumables stack


static func make(kind_id: String) -> Item:
	var it := Item.new()
	it.kind = kind_id
	it.def = Data.item(kind_id)
	it.display_name = it.def.name
	it.sprite = it.def.sprite
	it.tint = Color(it.def.tint)
	it.order = Entity.Order.ITEM
	return it


func stackable() -> bool:
	return is_consumable()


func label() -> String:
	return display_name if count <= 1 else "%s x%d" % [display_name, count]


func is_consumable() -> bool:
	return def.has("effect")


func is_equippable() -> bool:
	return def.has("slot")


func slot() -> String:
	return def.get("slot", "")


func power_bonus() -> int:
	return int(def.get("power", 0))


func defense_bonus() -> int:
	return int(def.get("defense", 0))
