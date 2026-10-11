extends Node2D
## Gameplay scene: renders GameState, turns input into actions, plays feedback effects.

enum Mode { BUSY, PLAY, INV_USE, INV_DROP, TARGET, LEVELUP, CHARACTER, HISTORY, HELP, PAUSE, DEAD }

const T := Sprites.TILE
const REPEAT_DELAY := 0.25     # hold a movement key this long before it starts repeating
const REPEAT_INTERVAL := 0.1   # seconds between repeated steps
const MOVE_KEYS := {
	KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0),
	KEY_HOME: Vector2i(-1, -1), KEY_END: Vector2i(-1, 1), KEY_PAGEUP: Vector2i(1, -1), KEY_PAGEDOWN: Vector2i(1, 1),
	KEY_KP_1: Vector2i(-1, 1), KEY_KP_2: Vector2i(0, 1), KEY_KP_3: Vector2i(1, 1), KEY_KP_4: Vector2i(-1, 0),
	KEY_KP_6: Vector2i(1, 0), KEY_KP_7: Vector2i(-1, -1), KEY_KP_8: Vector2i(0, -1), KEY_KP_9: Vector2i(1, -1),
	KEY_W: Vector2i(0, -1), KEY_A: Vector2i(-1, 0), KEY_S: Vector2i(0, 1), KEY_D: Vector2i(1, 0),
	KEY_H: Vector2i(-1, 0), KEY_J: Vector2i(0, 1), KEY_K: Vector2i(0, -1), KEY_L: Vector2i(1, 0),
	KEY_Y: Vector2i(-1, -1), KEY_U: Vector2i(1, -1), KEY_B: Vector2i(-1, 1), KEY_N: Vector2i(1, 1),
}

var gs: GameState
var mode := Mode.PLAY
var hud: Hud
var map_view: MapView
var camera: Camera2D
var torch: PointLight2D
var ambient: CanvasModulate
var vignette: ColorRect
var _flicker := 0.0
var cursor: Node2D
var holders := {}                # Entity -> Node2D (position) with a Sprite2D child
var cursor_pos := Vector2i.ZERO
var target_item: Item = null
var target_radius := 0.0
var look_only := false
var _t := 0.0
var _shake := 0.0
var _help_from_pause := false
var _held_key := 0           # movement key currently auto-repeating (0 = none)
var _repeat_t := 0.0


func _ready() -> void:
	gs = App.current if App.current != null else GameState.new_game()
	map_view = MapView.new()
	add_child(map_view)
	var ents := Node2D.new()
	ents.name = "Entities"
	add_child(ents)
	cursor = Node2D.new()
	cursor.z_index = 50
	cursor.draw.connect(_draw_cursor)
	cursor.visible = false
	add_child(cursor)

	ambient = CanvasModulate.new()
	add_child(ambient)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	add_child(camera)
	get_viewport().size_changed.connect(_fit_zoom)
	_fit_zoom()

	var vlayer := CanvasLayer.new()
	vlayer.layer = 1
	add_child(vlayer)
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.material = ShaderMaterial.new()
	vignette.material.shader = load("res://game/view/vignette.gdshader")
	vlayer.add_child(vignette)

	hud = Hud.new()
	add_child(hud)
	hud.slot_clicked.connect(_on_slot_clicked)
	hud.pause_clicked.connect(func(): if mode == Mode.PLAY: _open_pause())
	hud.stats_clicked.connect(func(): if mode == Mode.PLAY: _open_character())
	hud.pause_action.connect(_on_pause_action)
	hud.close_clicked.connect(_dismiss)

	gs.fx.connect(_on_fx)
	gs.message.connect(hud.add_log)
	gs.changed.connect(_sync)
	hud.reset_log(gs.log)
	_sync(true)
	if gs.player.requires_level_up():
		_open_levelup()
	if App.latest_version != "":
		hud.toast("Update v%s available on the menu" % App.latest_version)


func _fit_zoom() -> void:
	var h := get_viewport_rect().size.y
	camera.zoom = Vector2.ONE * clampf(floorf(h / 240.0), 2.0, 6.0)


# ---------------------------------------------------------------- rendering

func _holder_for(e: Entity) -> Node2D:
	if holders.has(e):
		return holders[e]
	var h := Node2D.new()
	var s := Sprite2D.new()
	s.centered = false
	s.texture = Sprites.texture(e.sprite)
	s.modulate = e.tint
	h.add_child(s)
	h.position = Vector2(e.x, e.y) * T
	$Entities.add_child(h)
	holders[e] = h
	if e == gs.player:
		torch = PointLight2D.new()
		torch.texture = Sprites.light_texture()
		torch.texture_scale = 1.15
		torch.color = Color(1.0, 0.62, 0.36)
		torch.energy = 1.0
		torch.position = Vector2(T, T) / 2.0
		h.add_child(torch)
	return h


func _sync(snap := false) -> void:
	if mode == Mode.BUSY:
		return
	map_view.refresh(gs.map, gs.floor_no)
	ambient.color = Depth.ambient(gs.floor_no)
	hud.update_minimap(gs)
	var alive := {}
	for e in gs.map.entities:
		alive[e] = true
		var h := _holder_for(e)
		var s: Sprite2D = h.get_child(0)
		s.texture = Sprites.texture(e.sprite)
		h.z_index = e.order
		h.visible = e == gs.player or gs.map.is_visible(e.x, e.y)
		var target := Vector2(e.x, e.y) * T
		if h.position != target:
			if snap or not h.visible:
				h.position = target
			else:
				var tw := h.create_tween()
				tw.tween_property(h, "position", target, 0.09)
	for e in holders.keys():
		if not alive.has(e):
			holders[e].queue_free()
			holders.erase(e)
	camera.position = Vector2(gs.player.x, gs.player.y) * T + Vector2(T, T) / 2.0
	if snap:
		camera.reset_smoothing()
	hud.update_stats(gs)
	var ratio := float(gs.player.hp) / gs.player.max_hp
	(vignette.material as ShaderMaterial).set_shader_parameter("hurt", clampf((0.4 - ratio) / 0.4, 0.0, 1.0))
	if not snap and ratio < 0.3 and gs.player.alive:
		App.play("heartbeat")     # low health: your pulse is in your ears
	_update_hover()


func _process(delta: float) -> void:
	_t += delta
	if torch:
		# Guttering flame: steady wobble plus the odd sudden dip, as if something breathed on it.
		if randf() < delta * 0.5:
			_flicker = 0.45
		_flicker = move_toward(_flicker, 0.0, delta * 1.8)
		torch.energy = 0.95 + sin(_t * 8.0) * 0.07 + sin(_t * 21.0) * 0.06 - _flicker
		torch.texture_scale = 1.15 + sin(_t * 5.0) * 0.03 - _flicker * 0.15
	var mat := vignette.material as ShaderMaterial
	mat.set_shader_parameter("time", _t)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 20.0
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO
	if mode == Mode.PLAY or mode == Mode.TARGET:
		_update_hover()
	_repeat_held_move(delta)


## Holding a movement key keeps walking. Stops on a blocked step, when hurt, or when any menu opens.
func _repeat_held_move(delta: float) -> void:
	if _held_key == 0:
		return
	if mode != Mode.PLAY or not Input.is_key_pressed(_held_key as Key):
		_held_key = 0
		return
	_repeat_t -= delta
	if _repeat_t > 0.0:
		return
	_repeat_t = REPEAT_INTERVAL
	var d: Vector2i = MOVE_KEYS[_held_key]
	var hp_before := gs.player.hp
	if not _act(Actions.bump(gs, gs.player, d.x, d.y)) or gs.player.hp < hp_before:
		_held_key = 0


func _mouse_tile() -> Vector2i:
	var p := get_global_mouse_position()
	return Vector2i(floori(p.x / T), floori(p.y / T))


func _update_hover() -> void:
	var t := cursor_pos if mode == Mode.TARGET else _mouse_tile()
	var names := []
	if gs.map.is_visible(t.x, t.y):
		for e in gs.map.entities:
			if e.x == t.x and e.y == t.y:
				names.append(e.display_name)
	hud.set_hover(", ".join(names).capitalize())


func _draw_cursor() -> void:
	var p := Vector2(cursor_pos) * T
	cursor.draw_rect(Rect2(p, Vector2(T, T)), Color(1, 1, 1, 0.9), false, 1.0)
	if target_radius > 0.0:
		cursor.draw_arc(p + Vector2(T, T) / 2.0, target_radius * T, 0, TAU, 48, Color(1, 0.3, 0.2, 0.9), 1.0)


# ---------------------------------------------------------------- feedback

func _on_fx(kind: String, d: Dictionary) -> void:
	match kind:
		"moved":
			if d.entity == gs.player:
				App.play("step")
		"lunge":
			var h: Node2D = holders.get(d.entity)
			if h:
				var s: Sprite2D = h.get_child(0)
				var tw := s.create_tween()
				tw.tween_property(s, "position", Vector2(d.dir) * 5.0, 0.05)
				tw.tween_property(s, "position", Vector2.ZERO, 0.08)
		"hit":
			App.play("hit")
			var e: Entity = d.entity
			var h: Node2D = holders.get(e)
			if h:
				var s: Sprite2D = h.get_child(0)
				s.modulate = Color(1, 0.3, 0.3)
				s.create_tween().tween_property(s, "modulate", e.tint, 0.2)
				_float_text(Vector2(e.x, e.y) * T, str(d.amount), Color(1, 0.35, 0.3) if e == gs.player else Color(1, 0.92, 0.5))
			if e == gs.player:
				_shake = 0.18
		"miss":
			App.play("miss")
		"pickup":
			App.play("pickup")
		"heal":
			App.play("use")
			_float_text(Vector2(d.entity.x, d.entity.y) * T, "+%d" % d.amount, Palette.HEAL)
		"used":
			App.play("use")
		"bolt":
			_bolt(d.from, d.to)
		"spell":
			_burst(Vector2(d.at) * T + Vector2(T, T) / 2.0, d.color, 16, 24.0)
		"explosion":
			App.play("hit")
			_shake = 0.25
			_burst(Vector2(d.at) * T + Vector2(T, T) / 2.0, Color(1, 0.5, 0.15), 60, d.radius * T)
		"died":
			App.play("die")
		"levelup":
			App.play("levelup")
			hud.toast("LEVEL UP!")


func _float_text(at: Vector2, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = at + Vector2(2, -4)
	l.z_index = 60
	l.scale = Vector2(0.4, 0.4)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 14, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _bolt(a: Vector2i, b: Vector2i) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(1, 0.95, 0.4)
	line.z_index = 55
	var pa := Vector2(a) * T + Vector2(T, T) / 2.0
	var pb := Vector2(b) * T + Vector2(T, T) / 2.0
	line.add_point(pa)
	for i in range(1, 5):
		line.add_point(pa.lerp(pb, i / 5.0) + Vector2(randf_range(-3, 3), randf_range(-3, 3)))
	line.add_point(pb)
	add_child(line)
	line.create_tween().tween_property(line, "modulate:a", 0.0, 0.25).finished.connect(line.queue_free)
	_burst(pb, Color(1, 0.95, 0.4), 14, 16.0)


func _burst(at: Vector2, col: Color, n: int, spread: float) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.z_index = 55
	p.amount = n
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.5
	p.spread = 180.0
	p.initial_velocity_min = spread * 0.5
	p.initial_velocity_max = spread * 1.6
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color = col
	p.emitting = true
	add_child(p)
	p.create_tween().tween_interval(1.0).finished.connect(p.queue_free)


# ---------------------------------------------------------------- turns

## Runs a player action. Returns true if a turn passed.
func _act(error: String) -> bool:
	var ok := gs.player_act(error)
	if not ok:
		return false
	if gs.game_over:
		_open_dead()
		return true
	Save.write(gs)
	if gs.player.requires_level_up():
		_open_levelup()
	return true


## Manual save (F5). The game also autosaves after every turn.
func _quick_save() -> void:
	if gs.game_over or mode in [Mode.BUSY, Mode.DEAD]:
		return
	if Save.write(gs):
		hud.flash_save()
		hud.toast("Game saved", Palette.HEAL)
	else:
		hud.toast("Could not save the game", Palette.ERROR)


func _on_stairs_taken() -> void:
	App.play("stairs")
	hud.descend_transition(func():
		for h in holders.values():
			h.queue_free()
		holders.clear()
		torch = null
		mode = Mode.PLAY
		_sync(true),
		"Depth %d: %s" % [gs.floor_no, Depth.name_of(gs.floor_no)])


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mode == Mode.TARGET:
		var t := _mouse_tile()
		if gs.map.in_bounds(t.x, t.y):
			cursor_pos = t
			cursor.queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		hud.scroll_inventory(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and mode in [Mode.HELP, Mode.HISTORY]:
		_dismiss()   # clicked outside the help / history window
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mode == Mode.TARGET:
			var t := _mouse_tile()
			if gs.map.in_bounds(t.x, t.y):
				cursor_pos = t
				_confirm_target()
		return
	if event is InputEventKey and not event.pressed and event.keycode == _held_key:
		_held_key = 0
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match mode:
		Mode.BUSY:
			pass
		Mode.PLAY:
			_key_play(event)
		Mode.INV_USE, Mode.INV_DROP:
			_key_inventory(event)
		Mode.TARGET:
			_key_target(event)
		Mode.LEVELUP:
			_key_levelup(event)
		Mode.PAUSE:
			_key_pause(event)
		Mode.DEAD:
			_key_dead(event)
		_:
			_dismiss()   # help / character / history: any key closes
	get_viewport().set_input_as_handled()


func _key_play(e: InputEventKey) -> void:
	var p := gs.player
	var k := e.keycode
	if e.unicode == ">".unicode_at(0):
		var before := gs.floor_no
		var on_stairs := p.pos() == gs.map.downstairs
		if on_stairs:
			mode = Mode.BUSY   # input and view updates pause until the fade finishes
		_act(Actions.take_stairs(gs, p))
		if gs.floor_no != before:
			_on_stairs_taken()
		else:
			mode = Mode.PLAY
	elif MOVE_KEYS.has(k):
		var d: Vector2i = MOVE_KEYS[k]
		if _act(Actions.bump(gs, p, d.x, d.y)):
			_held_key = k            # keep walking while the key stays down
			_repeat_t = REPEAT_DELAY
	elif k in [KEY_PERIOD, KEY_KP_5, KEY_SPACE, KEY_CLEAR]:
		_act(Actions.wait(gs, p))
	elif k == KEY_G:
		_act(Actions.pickup(gs, p))
	elif _hotbar_slot(k) >= 0:
		_use_hotbar(_hotbar_slot(k))
	elif k == KEY_F5:
		_quick_save()
	elif k == KEY_T:
		_start_inventory(Mode.INV_DROP)
	elif k == KEY_Q:
		_quick_heal()
	elif k == KEY_C:
		_open_character()
	elif k == KEY_V:
		_open_history()
	elif k in [KEY_ENTER, KEY_KP_ENTER]:
		hud.toggle_log_pin()
	elif k == KEY_M:
		hud.toggle_minimap()
	elif k == KEY_SLASH or k == KEY_X:
		if e.unicode == "?".unicode_at(0):
			_open_help()
		else:
			_start_target(null, 0.0, true)
	elif k == KEY_F1:
		_open_help()
	elif k == KEY_ESCAPE:
		_open_pause()


func _key_inventory(e: InputEventKey) -> void:
	if e.keycode == KEY_ESCAPE:
		_close_modal()
	elif _hotbar_slot(e.keycode) >= 0:
		_use_hotbar(_hotbar_slot(e.keycode))


func _pick_item(it: Item) -> void:
	var drop := mode == Mode.INV_DROP
	_close_modal()
	if drop:
		_act(Actions.drop(gs, gs.player, it))
	elif Actions.needs_target(it):
		gs.say("Select a target location.", Palette.NEEDS_TARGET)
		_start_target(it, float(it.def.get("radius", 0)), false)
	else:
		_act(Actions.use_item(gs, gs.player, it))


func _start_target(it: Item, radius: float, look: bool) -> void:
	mode = Mode.TARGET
	target_item = it
	target_radius = radius
	look_only = look
	cursor_pos = gs.player.pos()
	cursor.visible = true
	cursor.queue_redraw()


func _key_target(e: InputEventKey) -> void:
	var k := e.keycode
	if MOVE_KEYS.has(k):
		var step := 1
		if e.shift_pressed:
			step = 5
		var d: Vector2i = MOVE_KEYS[k] * step
		cursor_pos = Vector2i(clampi(cursor_pos.x + d.x, 0, gs.map.width - 1), clampi(cursor_pos.y + d.y, 0, gs.map.height - 1))
		cursor.queue_redraw()
	elif k in [KEY_ENTER, KEY_KP_ENTER]:
		_confirm_target()
	elif k == KEY_ESCAPE:
		_end_target()


func _confirm_target() -> void:
	var it := target_item
	var at := cursor_pos
	_end_target()
	if it != null and not look_only:
		_act(Actions.use_item(gs, gs.player, it, at))


func _end_target() -> void:
	mode = Mode.PLAY
	cursor.visible = false
	target_item = null
	target_radius = 0.0


func _key_levelup(e: InputEventKey) -> void:
	var i := e.keycode - KEY_A
	if i >= 0 and i <= 2:
		gs.player.level_up(i)
		gs.say(["Your health improves!", "You feel stronger!", "Your movements are getting swifter!"][i])
		hud.update_stats(gs)
		Save.write(gs)
		_close_modal()
		if gs.player.requires_level_up():
			_open_levelup()


## Red X / Esc on a menu. Level-up and death screens have no X: you must choose.
func _dismiss() -> void:
	match mode:
		Mode.HELP:
			if _help_from_pause:   # controls opened from the pause menu: go back to it
				_help_from_pause = false
				hud.hide_modal()
				_open_pause()
			else:
				_close_modal()
		Mode.CHARACTER, Mode.HISTORY, Mode.PAUSE, Mode.INV_DROP:
			_close_modal()
		Mode.TARGET:
			_end_target()


func _on_pause_action(id: String) -> void:
	match id:
		"resume":
			_close_modal()
		"help":
			hud.hide_pause()
			_open_help()
			_help_from_pause = true
		"menu":
			Save.write(gs)
			App.to_menu()
		"quit":
			Save.write(gs)
			get_tree().quit()


func _key_pause(e: InputEventKey) -> void:
	match e.keycode:
		KEY_R, KEY_ESCAPE:
			_close_modal()
		KEY_S, KEY_M:
			Save.write(gs)
			App.to_menu()
		KEY_Q:
			Save.write(gs)
			get_tree().quit()
		KEY_H:
			_on_pause_action("help")


func _key_dead(e: InputEventKey) -> void:
	if e.keycode == KEY_R:
		App.start_new_game()
	elif e.keycode in [KEY_M, KEY_ESCAPE]:
		App.to_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and gs != null and not gs.game_over:
		Save.write(gs)


# ---------------------------------------------------------------- modals

func _close_modal() -> void:
	hud.hide_modal()
	hud.hide_pause()
	hud.hide_character()
	hud.set_inventory_prompt("")
	mode = Mode.PLAY


func _start_inventory(m: Mode) -> void:
	if gs.player.inventory.is_empty():
		gs.say("Your inventory is empty.", Palette.IMPOSSIBLE)
		return
	mode = m
	hud.set_inventory_prompt("Press 1-0 (or click) to DROP, Esc to cancel")


## Top-row number key -> hotbar slot 0..9 (1..9, then 0 is slot 10); -1 if not a number key.
func _hotbar_slot(keycode: int) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_1
	return 9 if keycode == KEY_0 else -1


func _use_hotbar(slot: int) -> void:
	var i := hud.inventory_offset() + slot
	if i >= gs.player.inventory.size():
		return
	_on_slot_clicked(i, MOUSE_BUTTON_LEFT)


func _on_slot_clicked(i: int, button: int) -> void:
	if not mode in [Mode.PLAY, Mode.INV_USE, Mode.INV_DROP] or i >= gs.player.inventory.size():
		return
	var it := gs.player.inventory[i]
	if button == MOUSE_BUTTON_RIGHT:
		mode = Mode.INV_DROP
	elif mode == Mode.PLAY:
		mode = Mode.INV_USE
	_pick_item(it)


func _quick_heal() -> void:
	for it in gs.player.inventory:
		if it.def.get("effect", "") == "heal":
			_act(Actions.use_item(gs, gs.player, it))
			return
	gs.say("You have no healing potions.", Palette.IMPOSSIBLE)


func _open_character() -> void:
	mode = Mode.CHARACTER
	hud.show_character(gs.player)


func _open_levelup() -> void:
	mode = Mode.LEVELUP
	var p := gs.player
	hud.show_modal("Level Up", "Congratulations! Select an attribute to increase.\n\n[b]a)[/b] Constitution (+20 HP, from %d)\n[b]b)[/b] Strength (+1 attack, from %d)\n[b]c)[/b] Agility (+1 defense, from %d)" % [
			p.max_hp, p.power(), p.defense()], "Press A, B or C.", false)


func _open_history() -> void:
	mode = Mode.HISTORY
	var lines := PackedStringArray()
	for l in gs.log.slice(-18):
		lines.append("[color=#%s]%s[/color]" % [l.color.to_html(false), String(l.text).replace("[", "[lb]")])
	hud.show_modal("Message history", "\n".join(lines))


func _open_help() -> void:
	_help_from_pause = false
	mode = Mode.HELP
	hud.show_modal_control("Controls", Help.build())


func _open_pause() -> void:
	mode = Mode.PAUSE
	hud.show_pause()


func _open_dead() -> void:
	mode = Mode.DEAD
	Save.delete()
	hud.show_modal("You died", "You perished on dungeon level %d, at character level %d.\n\n[b]R[/b]  Start a new game\n[b]M[/b]  Main menu" % [
			gs.floor_no, gs.player.level], "", false)
