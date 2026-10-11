class_name Hud
extends CanvasLayer
## On-screen UI: stats, message log, hover text, and a reusable modal panel.

signal pause_action(id: String)   # resume | help | menu | quit
signal slot_clicked(index: int, button: int)   # absolute inventory index; MOUSE_BUTTON_LEFT / RIGHT
signal stats_clicked
signal pause_clicked
signal close_clicked      # red X on any closable menu

const MINI_W := 80
const MINI_H := 43
const MINI_SCALE := 3
const LOG_SHOW_SECONDS := 4.0
const PLAYER_SCALE := 12      # the 16x16 in-game sprite, enlarged for the character screen
const INV_VISIBLE := 10      # hotbar slots, bound to keys 1-9 and 0
const SLOT := 50

var _hp_bar: ProgressBar
var _hp_label: Label
var _info: Label
var _log: RichTextLabel
var _hover: Label
var _modal: PanelContainer
var _modal_title: Label
var _modal_x: Button
var _modal_custom: VBoxContainer   # holds a prebuilt control (e.g. the controls reference) instead of text
var _modal_body: RichTextLabel
var _modal_footer: Label
var _toast: Label
var _logp: PanelContainer
var _log_timer := 0.0
var _log_pinned := false
var _log_tween: Tween
var _mini_tex: ImageTexture
var _mini_img: Image
var _mini_panel: PanelContainer
var _depth_label: Label
var _fade: ColorRect
var _char: Control
var _inv_slots: Array[Button] = []
var _inv_counts: Array[Label] = []
var _inv_prompt: Label
var _inv_range: Label
var _inv_offset := 0
var _inv_count := 0
var _pause: Control
var _pause_first: Button
var _save_icon: TextureRect
var _save_tween: Tween


func _ready() -> void:
	layer = 2     # above the vignette layer (1) so the UI stays readable
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.build()
	add_child(root)

	_logp = PanelContainer.new()
	_logp.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_logp.offset_left = 12
	_logp.offset_top = 12
	_logp.custom_minimum_size = Vector2(640, 140)
	_logp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logp.add_theme_stylebox_override("panel", UITheme.box(Color(0.05, 0.04, 0.07, 0.55), Color(0, 0, 0, 0), 0, 8, 10))
	_logp.modulate.a = 0.0
	root.add_child(_logp)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.scroll_active = false
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_size_override("normal_font_size", 16)
	_log.add_theme_color_override("font_outline_color", Color.BLACK)
	_log.add_theme_constant_override("outline_size", 4)
	_logp.add_child(_log)

	_mini_panel = PanelContainer.new()
	_mini_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mini_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_mini_panel.offset_right = -12
	_mini_panel.offset_top = 12
	_mini_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.03, 0.06, 0.7), Color(0.5, 0.1, 0.12, 0.8), 1, 4, 4))
	root.add_child(_mini_panel)
	var mv2 := VBoxContainer.new()
	mv2.add_theme_constant_override("separation", 2)
	_mini_panel.add_child(mv2)
	_depth_label = Label.new()
	_depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_depth_label.add_theme_font_size_override("font_size", 14)
	_depth_label.add_theme_color_override("font_color", Palette.GOLD)
	mv2.add_child(_depth_label)
	var mr := TextureRect.new()
	mr.custom_minimum_size = Vector2(MINI_W * MINI_SCALE, MINI_H * MINI_SCALE)
	mr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mv2.add_child(mr)
	_mini_img = Image.create(MINI_W, MINI_H, false, Image.FORMAT_RGBA8)
	_mini_tex = ImageTexture.create_from_image(_mini_img)
	mr.texture = _mini_tex

	_build_inventory(root)

	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.tooltip_text = "Pause (Esc)"
	pause_btn.focus_mode = Control.FOCUS_NONE        # keep Space/Enter free for game keys
	pause_btn.custom_minimum_size = Vector2(46, 46)
	pause_btn.add_theme_font_size_override("font_size", 20)
	pause_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pause_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pause_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pause_btn.offset_right = -12
	pause_btn.offset_bottom = -12
	pause_btn.pressed.connect(func(): pause_clicked.emit())
	root.add_child(pause_btn)

	# Save indicator: invisible until F5 is pressed, then appears briefly.
	_save_icon = TextureRect.new()
	_save_icon.texture = load("res://assets/save_icon.png")
	_save_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_save_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_save_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_save_icon.custom_minimum_size = Vector2(36, 36)
	_save_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_save_icon.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_save_icon.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_save_icon.offset_right = -70
	_save_icon.offset_bottom = -17
	_save_icon.modulate.a = 0.0
	root.add_child(_save_icon)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 70
	_toast.add_theme_font_size_override("font_size", 28)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	root.add_child(_fade)

	_build_pause(root)
	_char = Control.new()
	_char.set_anchors_preset(Control.PRESET_FULL_RECT)
	_char.visible = false
	root.add_child(_char)

	_modal = PanelContainer.new()
	_modal.visible = false
	_modal.set_anchors_preset(Control.PRESET_CENTER)
	_modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_modal.grow_vertical = Control.GROW_DIRECTION_BOTH
	_modal.custom_minimum_size = Vector2(460, 0)
	root.add_child(_modal)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	_modal.add_child(mv)
	_modal_title = Label.new()
	_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_title.add_theme_font_size_override("font_size", 26)
	_modal_title.add_theme_color_override("font_color", Palette.GOLD)
	var mrow := UITheme.with_close(_modal_title, func(): close_clicked.emit())
	_modal_x = mrow.get_child(2)
	mv.add_child(mrow)
	_modal_body = RichTextLabel.new()
	_modal_body.bbcode_enabled = true
	_modal_body.fit_content = true
	_modal_body.custom_minimum_size = Vector2(440, 0)
	mv.add_child(_modal_body)
	_modal_custom = VBoxContainer.new()
	_modal_custom.visible = false
	mv.add_child(_modal_custom)
	_modal_footer = Label.new()
	_modal_footer.modulate = UITheme.DIM
	_modal_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(_modal_footer)


## Bottom-center dock: hover name, clickable HP/stats bar, and a 10-slot hotbar (keys 1-9, 0; mouse wheel scrolls).
func _build_inventory(root: Control) -> void:
	var dock := VBoxContainer.new()
	dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dock.offset_bottom = -10
	dock.add_theme_constant_override("separation", 6)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dock)

	_hover = Label.new()
	_hover.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hover.add_theme_color_override("font_outline_color", Color.BLACK)
	_hover.add_theme_constant_override("outline_size", 6)
	dock.add_child(_hover)

	# HP + stats strip: click for the full character sheet
	var stats := PanelContainer.new()
	stats.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	stats.tooltip_text = "Click for the full character sheet (C)"
	stats.add_theme_stylebox_override("panel", UITheme.box(Color(0.07, 0.06, 0.09, 0.88), Color(0.5, 0.1, 0.12, 0.85), 2, 6, 8))
	stats.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			stats_clicked.emit())
	dock.add_child(stats)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_child(row)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(240, 26)
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_hp_bar)
	_hp_label = Label.new()
	_hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_bar.add_child(_hp_label)
	_info = Label.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_info)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.07, 0.06, 0.09, 0.88), Color(0.5, 0.1, 0.12, 0.85), 2, 6, 8))
	dock.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Label.new()
	t.text = "Inventory"
	t.add_theme_color_override("font_color", Palette.GOLD)
	t.add_theme_font_size_override("font_size", 15)
	head.add_child(t)
	_inv_range = Label.new()
	_inv_range.modulate = UITheme.DIM
	_inv_range.add_theme_font_size_override("font_size", 13)
	head.add_child(_inv_range)
	_inv_prompt = Label.new()
	_inv_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_inv_prompt.add_theme_font_size_override("font_size", 14)
	_inv_prompt.add_theme_color_override("font_color", Palette.HEAL)
	head.add_child(_inv_prompt)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 3)
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(grid)
	for i in INV_VISIBLE:
		var b := Button.new()
		b.custom_minimum_size = Vector2(SLOT, SLOT)
		b.focus_mode = Control.FOCUS_NONE        # keep Space/Enter free for game keys
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", SLOT - 14)
		var key := Label.new()
		key.text = str((i + 1) % 10)             # 1..9, then 0
		key.position = Vector2(4, 0)
		key.add_theme_font_size_override("font_size", 13)
		key.modulate = Color(1, 1, 1, 0.7)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(key)
		var cnt := Label.new()                   # stack size, bottom-right of the slot
		cnt.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		cnt.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		cnt.grow_vertical = Control.GROW_DIRECTION_BEGIN
		cnt.offset_right = -4
		cnt.offset_bottom = -1
		cnt.add_theme_font_size_override("font_size", 14)
		cnt.add_theme_color_override("font_outline_color", Color.BLACK)
		cnt.add_theme_constant_override("outline_size", 5)
		cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cnt)
		_inv_counts.append(cnt)
		b.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				if e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and _inv_offset + i < _inv_count:
					slot_clicked.emit(_inv_offset + i, e.button_index)
				elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
					scroll_inventory(-1)
				elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					scroll_inventory(1))
		grid.add_child(b)
		_inv_slots.append(b)
	var hint := Label.new()
	hint.text = "1-0 use   Click: use   Right-click / T: drop   Wheel: scroll   Q: heal   C: character"
	hint.modulate = UITheme.DIM
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)


## Scroll the hotbar window over the inventory by `dir` slots (wheel notch).
func scroll_inventory(dir: int) -> void:
	var before := _inv_offset
	_inv_offset = clampi(_inv_offset + dir, 0, maxi(0, _inv_count - INV_VISIBLE))
	if _inv_offset != before:
		_redraw_inventory()


func inventory_offset() -> int:
	return _inv_offset


func _slot_style(border: Color, bg: Color) -> StyleBoxFlat:
	return UITheme.box(bg, border, 2, 4, 0)


var _last_player: Actor


func refresh_inventory(p: Actor) -> void:
	_last_player = p
	_inv_count = p.inventory.size()
	_inv_offset = clampi(_inv_offset, 0, maxi(0, _inv_count - INV_VISIBLE))
	_redraw_inventory()


func _redraw_inventory() -> void:
	var p := _last_player
	for i in INV_VISIBLE:
		var b := _inv_slots[i]
		var idx := _inv_offset + i
		if idx < p.inventory.size():
			var it := p.inventory[idx]
			b.icon = Sprites.texture(it.sprite)
			for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
				b.add_theme_color_override(c, it.tint)   # scrolls share one sprite, so tint tells them apart
			b.tooltip_text = it.label() + ("  (equipped)" if p.is_equipped(it) else "")
			_inv_counts[i].text = "x%d" % it.count if it.count > 1 else ""
			var edge := Palette.GOLD if p.is_equipped(it) else Color(0.3, 0.16, 0.16)
			b.add_theme_stylebox_override("normal", _slot_style(edge, Color(0.17, 0.15, 0.21)))
			b.add_theme_stylebox_override("hover", _slot_style(Color.WHITE, Color(0.28, 0.24, 0.33)))
			b.add_theme_stylebox_override("pressed", _slot_style(Palette.GOLD, Color(0.34, 0.28, 0.22)))
		else:
			b.icon = null
			b.tooltip_text = ""
			_inv_counts[i].text = ""
			var empty := _slot_style(Color(0.22, 0.2, 0.25), Color(0.1, 0.09, 0.13))
			for st in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(st, empty)
	_inv_range.text = "   items %d-%d of %d  (scroll)" % [_inv_offset + 1, mini(_inv_offset + INV_VISIBLE, _inv_count), _inv_count] \
			if _inv_count > INV_VISIBLE else ""


func set_inventory_prompt(text: String) -> void:
	_inv_prompt.text = text


func _click_outside(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		close_clicked.emit()


## Pause menu in the same style as the main menu: gold title, stacked buttons, dimmed dungeon behind.
func _build_pause(root: Control) -> void:
	_pause = Control.new()
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	root.add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_click_outside)
	_pause.add_child(dim)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(340, 0)
	col.mouse_filter = Control.MOUSE_FILTER_STOP   # gaps between buttons are not "outside"
	_pause.add_child(col)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color("#b01c1c"))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 8)
	col.add_child(UITheme.with_close(title, func(): close_clicked.emit()))
	col.add_child(Control.new())
	_pause_first = _pause_button(col, "Resume", "resume")
	_pause_button(col, "Controls", "help")
	var snd := Button.new()
	snd.toggle_mode = true
	snd.button_pressed = App.sound_on
	snd.custom_minimum_size = Vector2(0, 44)
	var label := func(v: bool): snd.text = "Sound effects:  %s" % ("On" if v else "Off")
	label.call(App.sound_on)
	snd.toggled.connect(func(v: bool):
		label.call(v)
		App.set_sound(v))
	col.add_child(snd)
	_pause_button(col, "Save and Main Menu", "menu")
	_pause_button(col, "Save and Quit", "quit")


func _pause_button(parent: Control, text: String, id: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(func(): pause_action.emit(id))
	parent.add_child(b)
	return b


## Character sheet: the player sprite, enlarged, beside stats and equipment.
func show_character(p: Actor) -> void:
	for c in _char.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_click_outside)
	_char.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_char.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Character"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Palette.GOLD)
	box.add_child(UITheme.with_close(title, func(): close_clicked.emit()))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	box.add_child(row)

	# player sprite on a dim torch-lit backdrop
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UITheme.box(Color(0.1, 0.09, 0.13), Color(0.28, 0.12, 0.12), 2, 6, 0))
	row.add_child(stage)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(Sprites.TILE, Sprites.TILE) * PLAYER_SCALE
	holder.clip_contents = true
	stage.add_child(holder)
	var glow := TextureRect.new()
	glow.texture = Sprites.light_texture()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.modulate = Color(0.9, 0.42, 0.22, 0.35)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	holder.add_child(glow)
	var tr := TextureRect.new()
	tr.texture = Sprites.texture("player")
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # never stretch the sprite
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(tr)

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.custom_minimum_size = Vector2(300, 0)
	var gold := "#" + Palette.GOLD.to_html(false)
	info.text = "[b][color=%s]Wandering Adventurer[/color][/b]\nLost, hunted, and running out of light.\n\n" % gold \
			+ "[b]Level[/b]  %d\n[b]XP[/b]  %d / %d\n[b]HP[/b]  %d / %d\n\n" % [p.level, p.xp, p.xp_to_next(), p.hp, p.max_hp] \
			+ "[b]Attack[/b]  %d\n[b]Defense[/b]  %d\n\n" % [p.power(), p.defense()] \
			+ "[b][color=%s]Equipment[/color][/b]\n[b]Weapon[/b]  %s\n[b]Armor[/b]  %s" % [
				gold, p.weapon.display_name if p.weapon else "none", p.armor.display_name if p.armor else "none"]
	row.add_child(info)
	_char.visible = true


func hide_character() -> void:
	_char.visible = false


func show_pause() -> void:
	_pause.visible = true
	_pause_first.grab_focus.call_deferred()


func hide_pause() -> void:
	_pause.visible = false


func update_stats(gs: GameState) -> void:
	var p := gs.player
	refresh_inventory(p)
	_hp_bar.max_value = p.max_hp
	_hp_bar.value = p.hp
	_hp_label.text = "HP %d / %d" % [p.hp, p.max_hp]
	_info.text = "Depth %d   Level %d   XP %d / %d" % [gs.floor_no, p.level, p.xp, p.xp_to_next()]
	_depth_label.text = Depth.name_of(gs.floor_no)


func add_log(text: String, color: Color, reveal := true) -> void:
	_log.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text.replace("[", "[lb]")])
	if reveal:
		show_log()


func reset_log(entries: Array) -> void:
	_log.clear()
	for e in entries.slice(-30):
		add_log(e.text, e.color, false)


## Fade the message log in; it fades out again after a few seconds unless pinned.
func show_log() -> void:
	_log_timer = LOG_SHOW_SECONDS
	_fade_log(1.0, 0.12)


func toggle_log_pin() -> void:
	_log_pinned = not _log_pinned
	if _log_pinned:
		_fade_log(1.0, 0.12)
	else:
		_log_timer = LOG_SHOW_SECONDS


func toggle_minimap() -> void:
	_mini_panel.visible = not _mini_panel.visible


func _fade_log(to: float, time: float) -> void:
	if _log_tween:
		_log_tween.kill()
	_log_tween = create_tween()
	_log_tween.tween_property(_logp, "modulate:a", to, time)


func _process(delta: float) -> void:
	if _log_timer > 0.0 and not _log_pinned:
		_log_timer -= delta
		if _log_timer <= 0.0:
			_fade_log(0.0, 0.6)


## Redraws the minimap: only explored tiles show; visible tiles are brighter.
func update_minimap(gs: GameState) -> void:
	var m := gs.map
	var img := _mini_img
	img.fill(Color(0, 0, 0, 0))
	for y in m.height:
		for x in m.width:
			if not m.is_explored(x, y):
				continue
			var vis := m.is_visible(x, y)
			var c: Color
			match m.tile(x, y):
				GameMap.Tile.WALL:
					# only draw walls that touch a floor so the outline stays crisp
					c = Color(0.36, 0.33, 0.42) if _touches_floor(m, x, y) else Color(0, 0, 0, 0)
				GameMap.Tile.STAIRS:
					c = Palette.GOLD
				_:
					c = Color(0.62, 0.52, 0.34) if vis else Color(0.36, 0.3, 0.22)
			if vis and c.a > 0.0 and m.tile(x, y) == GameMap.Tile.WALL:
				c = c.lightened(0.25)
			img.set_pixel(x, y, c)
	for e in m.entities:
		if e is Item and m.is_visible(e.x, e.y):
			img.set_pixel(e.x, e.y, Color(0.4, 0.8, 1.0))
		elif e is Actor and e.alive and not e.is_player and m.is_visible(e.x, e.y):
			img.set_pixel(e.x, e.y, Color(1.0, 0.25, 0.2))
	img.set_pixel(gs.player.x, gs.player.y, Color.WHITE)
	_mini_tex.update(img)


func _touches_floor(m: GameMap, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if m.walkable(x + dx, y + dy):
				return true
	return false


## Black fade out/in used when taking stairs. `mid` runs while the screen is black.
func descend_transition(mid: Callable, title: String) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.35)
	tw.tween_callback(mid)
	tw.tween_interval(0.25)
	tw.tween_callback(toast.bind(title))
	tw.tween_property(_fade, "modulate:a", 0.0, 0.6)


## Shows the floppy-disk icon for a moment (only called on a manual F5 save), then fades it out.
func flash_save() -> void:
	if _save_tween:
		_save_tween.kill()
	_save_icon.modulate = Color(1, 1, 1, 1)
	_save_tween = create_tween()
	_save_tween.tween_interval(0.9)
	_save_tween.tween_property(_save_icon, "modulate:a", 0.0, 0.6)


func set_hover(text: String) -> void:
	_hover.text = text


func show_modal_control(title: String, content: Control) -> void:
	show_modal(title, "")
	_modal_body.visible = false
	_modal_footer.visible = false
	for c in _modal_custom.get_children():
		c.queue_free()
	_modal_custom.add_child(content)
	_modal_custom.visible = true


func show_modal(title: String, body: String, footer := "", closable := true) -> void:
	_modal_custom.visible = false
	_modal_body.visible = true
	_modal_footer.visible = footer != ""
	_modal_x.visible = closable
	_modal_title.text = title
	_modal_body.text = body
	_modal_footer.text = footer
	_modal.visible = true


func hide_modal() -> void:
	_modal.visible = false


func toast(text: String, color := Palette.GOLD) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	create_tween().tween_property(_toast, "modulate:a", 0.0, 2.0).set_delay(0.8)
