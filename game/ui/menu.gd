extends Control
## Main menu: torch-lit dungeon backdrop (light follows the mouse), buttons, settings, update banner.

var _torch: PointLight2D
var _banner: Label
var _title: Label
var _main: VBoxContainer
var _options: VBoxContainer
var _controls: VBoxContainer
var _main_focus: Control
var _options_focus: Control
var _controls_focus: Control
var _update_btn: Button
var _update_status: Label
var _t := 0.0


func _ready() -> void:
	theme = UITheme.build()
	_build_backdrop()
	_build_ui()
	App.update_found.connect(_on_update)
	if App.latest_version != "":
		_on_update(App.latest_version, App.latest_url)


func _build_backdrop() -> void:
	var bg := Node2D.new()
	bg.draw.connect(func():
		var T := Sprites.TILE * 4
		var vp := get_viewport_rect().size
		for y in int(vp.y / T) + 2:
			for x in int(vp.x / T) + 2:
				var n := "wall_face" if y % 5 == 0 else ("wall" if y % 5 == 4 else ("floor_a" if (x * 7 + y * 13) % 5 < 3 else "floor_b"))
				bg.draw_texture_rect_region(Sprites.atlas(), Rect2(x * T, y * T, T, T), Sprites.region(n)))
	add_child(bg)
	var mod := CanvasModulate.new()
	mod.color = Color(0.05, 0.04, 0.08)
	add_child(mod)
	_torch = PointLight2D.new()
	_torch.texture = Sprites.light_texture()
	_torch.texture_scale = 2.6
	_torch.color = Color(1.0, 0.6, 0.35)
	_torch.energy = 1.1
	add_child(_torch)
	get_viewport().size_changed.connect(bg.queue_redraw)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	layer.add_child(root)

	var title := Label.new()
	title.text = "TOMBS OF THE\nANCIENT KINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color("#b01c1c"))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 8)
	_title = title
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.offset_top = 90
	root.add_child(title)

	# Clicking outside the Options / Controls panels goes back to the main page.
	var backdrop := Control.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not _main.get_parent().visible:
			_show(_main))
	root.add_child(backdrop)

	# Main page
	_main = _page(root, false)
	var new_btn := _button(_main, "New Game", App.start_new_game)
	var cont := _button(_main, "Continue", func(): if not App.continue_game(): cont_fail())
	cont.disabled = not Save.exists()
	_button(_main, "Options", func(): _show(_options))
	_button(_main, "Controls", func(): _show(_controls))
	_button(_main, "Quit", func(): get_tree().quit())
	_main_focus = cont if Save.exists() else new_btn

	# Options page
	_options = _page(root)
	_options.add_child(UITheme.with_close(_heading("Options"), func(): _show(_main)))
	var snd := _toggle(_options, "Sound effects", App.sound_on, App.set_sound)
	_options.add_child(HSeparator.new())
	_options.add_child(_heading("About"))
	var ver := Label.new()
	ver.text = "Tombs of the Ancient Kings  v%s" % Version.VERSION
	_options.add_child(ver)
	_toggle(_options, "Check for updates on startup", App.check_updates, App.set_check_updates)
	_update_status = Label.new()
	_update_status.modulate = UITheme.DIM
	_update_btn = _button(_options, "Check for updates now", _check_now)
	_options.add_child(_update_status)
	_button(_options, "Back", func(): _show(_main))
	_options_focus = snd

	# Controls page
	_controls = _page(root)
	_controls.add_child(UITheme.with_close(_heading("Controls"), func(): _show(_main)))
	_controls.add_child(Help.build())
	_button(_controls, "Back", func(): _show(_main))
	_controls_focus = _controls.get_child(2)

	var ver_label := Label.new()
	ver_label.text = "v%s" % Version.VERSION
	ver_label.modulate = UITheme.DIM
	ver_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver_label.offset_right = -12
	ver_label.offset_bottom = -8
	root.add_child(ver_label)

	_banner = Label.new()
	_banner.visible = false
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 14
	_banner.add_theme_color_override("font_color", Palette.HEAL)
	_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_banner)

	_show(_main)


## A centered column that holds one page of the menu. Sub-pages sit on a panel for readability.
func _page(root: Control, boxed := true) -> VBoxContainer:
	var wrap := PanelContainer.new()
	wrap.set_anchors_preset(Control.PRESET_CENTER)
	wrap.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wrap.grow_vertical = Control.GROW_DIRECTION_BOTH
	if not boxed:
		wrap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		wrap.offset_top = 70
	root.add_child(wrap)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(380, 0)
	wrap.add_child(col)
	return col


func _show(page: Control) -> void:
	for p in [_main, _options, _controls]:
		p.get_parent().visible = p == page
	_title.visible = page == _main
	var focus: Control = {_main: _main_focus, _options: _options_focus, _controls: _controls_focus}[page]
	focus.grab_focus.call_deferred()


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Palette.GOLD)
	return l


## Toggle styled as a button so hover/focus never swaps the page background.
func _toggle(parent: Control, text: String, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = on
	b.custom_minimum_size = Vector2(0, 44)
	var refresh := func(v: bool): b.text = "%s:  %s" % [text, "On" if v else "Off"]
	refresh.call(on)
	b.toggled.connect(func(v: bool):
		refresh.call(v)
		cb.call(v))
	parent.add_child(b)
	return b


func _check_now() -> void:
	if Version.VERSION.ends_with("-dev"):
		_update_status.text = "Development build: update checks are disabled."
		return
	_update_status.text = "Checking..."
	_update_btn.disabled = true
	App.update_checked.connect(func(status: String):
		_update_btn.disabled = false
		_update_status.text = "You are up to date." if status == "latest" else "Could not reach GitHub.",
		CONNECT_ONE_SHOT)
	App.check_for_updates()


func cont_fail() -> void:
	_banner.text = "That save could not be loaded."
	_banner.visible = true


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _on_update(version: String, url: String) -> void:
	if _update_status:
		_update_status.text = "Update v%s is available." % version
		_update_btn.disabled = false
	_banner.text = "Update v%s available — click to download" % version
	_banner.visible = true
	_banner.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			OS.shell_open(url))


func _process(delta: float) -> void:
	_t += delta
	var target := get_viewport().get_mouse_position()
	_torch.position = _torch.position.lerp(target, 1.0 - exp(-8.0 * delta))
	_torch.energy = 1.0 + sin(_t * 9.0) * 0.08 + sin(_t * 23.0) * 0.07 - (0.35 if fmod(_t, 7.3) < 0.12 else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _main.get_parent().visible:
		_show(_main)
		get_viewport().set_input_as_handled()
