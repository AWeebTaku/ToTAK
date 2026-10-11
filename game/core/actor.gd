class_name Actor
extends Entity
## Player or monster. Folds the old fighter/inventory/equipment/level components into one class.

var max_hp := 1
var hp := 1
var base_defense := 0
var base_power := 0
var xp_given := 0
var alive := true
var is_player := false
var ai := "hostile"        # hostile | confused | none
var confused_turns := 0
var path: Array[Vector2i] = []
var inventory: Array[Item] = []
var capacity := 0
var weapon: Item = null
var armor: Item = null
# Player progression (level_up_base == 0 means "never levels", like monsters).
var level := 1
var xp := 0
var level_up_base := 0
var level_up_factor := 150


static func make_monster(kind_id: String) -> Actor:
	var d := Data.monster(kind_id)
	var a := Actor.new()
	a.kind = kind_id
	a.display_name = d.name
	a.sprite = d.sprite
	a.max_hp = d.hp
	a.hp = d.hp
	a.base_defense = d.defense
	a.base_power = d.power
	a.xp_given = d.xp
	a.blocks = true
	a.order = Entity.Order.ACTOR
	return a


static func make_player() -> Actor:
	var a := Actor.new()
	a.kind = "player"
	a.display_name = "Player"
	a.sprite = "player"
	a.max_hp = 30
	a.hp = 30
	a.base_defense = 1
	a.base_power = 2
	a.capacity = 26
	a.level_up_base = 200
	a.is_player = true
	a.blocks = true
	a.order = Entity.Order.ACTOR
	return a


func power() -> int:
	return base_power + (weapon.power_bonus() if weapon else 0) + (armor.power_bonus() if armor else 0)


func defense() -> int:
	return base_defense + (weapon.defense_bonus() if weapon else 0) + (armor.defense_bonus() if armor else 0)


## Existing stack this item would merge into, or null.
func stack_for(item: Item) -> Item:
	if item.stackable():
		for it in inventory:
			if it.kind == item.kind:
				return it
	return null


func can_hold(item: Item) -> bool:
	return stack_for(item) != null or inventory.size() < capacity


## Adds an item, merging consumables into an existing stack. Caller checks can_hold() first.
func add_item(item: Item) -> void:
	var stack := stack_for(item)
	if stack:
		stack.count += item.count
	else:
		inventory.append(item)


## Uses up one of a stack; removes the entry when the last one goes.
func consume_one(item: Item) -> void:
	item.count -= 1
	if item.count <= 0:
		inventory.erase(item)


func is_equipped(item: Item) -> bool:
	return item == weapon or item == armor


## Toggle equip state. Returns a log message.
func toggle_equip(item: Item) -> String:
	var slot := item.slot()
	if get(slot) == item:
		set(slot, null)
		return "You remove the %s." % item.display_name
	set(slot, item)
	return "You equip the %s." % item.display_name


func unequip_if_equipped(item: Item) -> void:
	if weapon == item:
		weapon = null
	if armor == item:
		armor = null


## Applies damage; returns true if this killed the actor.
func take_damage(amount: int) -> bool:
	hp = clampi(hp - amount, 0, max_hp)
	if hp == 0 and alive:
		become_corpse()
		return true
	return false


func become_corpse() -> void:
	alive = false
	ai = "none"
	blocks = false
	sprite = "corpse"
	tint = Color.WHITE
	display_name = "remains of %s" % display_name
	order = Entity.Order.CORPSE


func heal(amount: int) -> int:
	var before := hp
	hp = mini(hp + amount, max_hp)
	return hp - before


func xp_to_next() -> int:
	return level_up_base + level * level_up_factor


func requires_level_up() -> bool:
	return xp > xp_to_next()


func add_xp(amount: int) -> void:
	if amount == 0 or level_up_base == 0:
		return
	xp += amount


## choice: 0 = +20 max HP, 1 = +1 power, 2 = +1 defense.
func level_up(choice: int) -> void:
	xp -= xp_to_next()
	level += 1
	match choice:
		0:
			max_hp += 20
			hp += 20
		1:
			base_power += 1
		_:
			base_defense += 1
