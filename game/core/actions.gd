class_name Actions
## Every action returns "" on success or a reason string ("Impossible") on failure.
## Failed actions cost no turn.


static func bump(gs: GameState, a: Actor, dx: int, dy: int) -> String:
	var target := gs.map.actor_at(a.x + dx, a.y + dy)
	if target:
		return melee(gs, a, target)
	return move(gs, a, dx, dy)


static func melee(gs: GameState, attacker: Actor, target: Actor) -> String:
	var dmg := attacker.power() - target.defense()
	var who := "You" if attacker.is_player else attacker.display_name
	var verb := "attack" if attacker.is_player else "attacks"
	var col := Palette.PLAYER_ATK if attacker.is_player else Palette.ENEMY_ATK
	gs.fx.emit("lunge", {"entity": attacker, "dir": Vector2i(target.x - attacker.x, target.y - attacker.y)})
	if dmg > 0:
		gs.say("%s %s %s for %d hit points." % [who, verb, target.display_name, dmg], col)
		gs.damage(target, dmg, attacker)
	else:
		gs.say("%s %s %s but does no damage." % [who, verb, target.display_name], col)
		gs.fx.emit("miss", {"entity": target})
	return ""


static func move(gs: GameState, a: Actor, dx: int, dy: int) -> String:
	var nx := a.x + dx
	var ny := a.y + dy
	if not gs.map.in_bounds(nx, ny) or not gs.map.walkable(nx, ny) or gs.map.blocker_at(nx, ny):
		return "That way is blocked."
	a.x = nx
	a.y = ny
	gs.fx.emit("moved", {"entity": a})
	return ""


static func wait(_gs: GameState, _a: Actor) -> String:
	return ""


static func pickup(gs: GameState, a: Actor) -> String:
	var here := gs.map.items_at(a.x, a.y)
	if here.is_empty():
		return "There is nothing here to pick up."
	var it := here[0]
	if not a.can_hold(it):
		return "Your inventory is full."
	gs.map.entities.erase(it)
	a.add_item(it)
	gs.say("You picked up the %s!" % it.label())
	gs.fx.emit("pickup", {"entity": it})
	return ""


static func drop(gs: GameState, a: Actor, it: Item) -> String:
	a.unequip_if_equipped(it)
	a.inventory.erase(it)
	it.x = a.x
	it.y = a.y
	gs.map.entities.append(it)
	gs.say("You dropped the %s." % it.label())
	return ""


static func equip(gs: GameState, a: Actor, it: Item) -> String:
	gs.say(a.toggle_equip(it))
	return ""


static func take_stairs(gs: GameState, a: Actor) -> String:
	if a.pos() != gs.map.downstairs:
		return "There are no stairs here."
	gs.descend()
	gs.say("You descend the staircase.", Palette.DESCEND)
	return ""


## True if this item needs a target tile chosen first.
static func needs_target(it: Item) -> bool:
	return it.def.get("effect", "") in ["confusion", "fireball"]


static func use_item(gs: GameState, a: Actor, it: Item, target := Vector2i(-1, -1)) -> String:
	if it.is_equippable():
		return equip(gs, a, it)
	if not it.is_consumable():
		return "You can't use that."
	if target == Vector2i(-1, -1):
		target = a.pos()
	var d := it.def
	var err := ""
	match d.effect:
		"heal":
			var got := a.heal(int(d.amount))
			if got <= 0:
				return "Your health is already full."
			gs.say("You consume the %s, and recover %d HP!" % [it.display_name, got], Palette.HEAL)
			gs.fx.emit("heal", {"entity": a, "amount": got})
		"lightning":
			err = _lightning(gs, a, d)
		"confusion":
			err = _confusion(gs, a, d, target)
		"fireball":
			err = _fireball(gs, a, d, target)
	if err != "":
		return err
	a.consume_one(it)
	gs.fx.emit("used", {"entity": a, "item": it, "target": target})
	return ""


static func _lightning(gs: GameState, a: Actor, d: Dictionary) -> String:
	var best: Actor = null
	var best_d: float = float(d.range) + 1.0
	for o in gs.map.actors():
		if o != a and gs.map.is_visible(o.x, o.y):
			var dist := a.distance(o.x, o.y)
			if dist < best_d:
				best = o
				best_d = dist
	if best == null:
		return "No enemy is close enough to strike."
	gs.say("A lightning bolt strikes the %s with a loud thunder, for %d damage!" % [best.display_name, int(d.damage)])
	gs.fx.emit("bolt", {"from": a.pos(), "to": best.pos()})
	gs.damage(best, int(d.damage), a)
	return ""


static func _confusion(gs: GameState, a: Actor, d: Dictionary, t: Vector2i) -> String:
	if not gs.map.is_visible(t.x, t.y):
		return "You cannot target an area that you cannot see."
	var target := gs.map.actor_at(t.x, t.y)
	if target == null:
		return "You must select an enemy to target."
	if target == a:
		return "You cannot confuse yourself!"
	gs.say("The eyes of the %s look vacant, as it starts to stumble around!" % target.display_name, Palette.STATUS)
	target.ai = "confused"
	target.confused_turns = int(d.turns)
	gs.fx.emit("spell", {"at": t, "color": Color("#cf3fff")})
	return ""


static func _fireball(gs: GameState, a: Actor, d: Dictionary, t: Vector2i) -> String:
	if not gs.map.is_visible(t.x, t.y):
		return "You cannot target an area that you cannot see."
	var hit := false
	for o in gs.map.actors():
		if o.distance(t.x, t.y) <= float(d.radius):
			gs.say("The %s is engulfed in a fiery explosion, taking %d damage!" % [o.display_name, int(d.damage)])
			gs.damage(o, int(d.damage), a)
			hit = true
	if not hit:
		return "There are no targets in the radius."
	gs.fx.emit("explosion", {"at": t, "radius": float(d.radius)})
	return ""
