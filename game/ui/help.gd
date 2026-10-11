class_name Help
## Builds the controls reference: grouped sections with keycap-style key labels.

const SECTIONS_LEFT := [
	["Movement", [
		[["W", "A", "S", "D"], "or arrows: move, hold to keep walking"],
		[["Y", "U", "B", "N"], "or numpad: diagonals"],
		[[".", "Space"], "Wait a turn"],
	]],
	["Exploring", [
		[[">"], "Take stairs down (stand on >)"],
		[["/", "X"], "Look around"],
		[["G"], "Pick up item underfoot"],
		[["F5"], "Quick save (also saves every turn)"],
	]],
]

const SECTIONS_RIGHT := [
	["Items", [
		[["1", "...", "0"], "Use / equip hotbar slot (or click)"],
		[["Q"], "Quick-drink health potion"],
		[["T"], "then 1-0 to drop (or right-click)"],
		[["Wheel"], "Scroll the hotbar"],
	]],
	["Screens", [
		[["C"], "Character sheet (or click HP bar)"],
		[["V"], "Message history"],
		[["Enter"], "Pin / unpin message log"],
		[["M"], "Show / hide minimap"],
		[["Esc"], "Pause menu / close window"],
	]],
]

const TIP := "Scrolls that need a target: aim with keys or mouse, Enter or click to confirm.   The game saves every turn."


static func build() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 34)
	root.add_child(cols)
	cols.add_child(_column(SECTIONS_LEFT))
	var sep := VSeparator.new()
	cols.add_child(sep)
	cols.add_child(_column(SECTIONS_RIGHT))
	var tip := Label.new()
	tip.text = TIP
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(900, 0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.modulate = UITheme.DIM
	tip.add_theme_font_size_override("font_size", 15)
	root.add_child(tip)
	return root


static func _column(sections: Array) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	for sec in sections:
		if col.get_child_count() > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 10)
			col.add_child(gap)
		var head := Label.new()
		head.text = sec[0]
		head.add_theme_font_size_override("font_size", 22)
		head.add_theme_color_override("font_color", Palette.GOLD)
		col.add_child(head)
		col.add_child(HSeparator.new())
		for row in sec[1]:
			col.add_child(_row(row[0], row[1]))
	return col


static func _row(keys: Array, text: String) -> Control:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	var flow := HFlowContainer.new()
	flow.custom_minimum_size = Vector2(150, 0)
	flow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	for k in keys:
		flow.add_child(_dots() if k == "..." else _keycap(k))
	r.add_child(flow)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(290, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_size_override("font_size", 16)
	r.add_child(l)
	return r


static func _keycap(text: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.18, 0.25)
	sb.border_color = Color(0.4, 0.2, 0.2)
	sb.set_border_width_all(1)
	sb.border_width_bottom = 4          # thick bottom edge reads as a raised key
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 3
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(32, 0)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	p.add_child(l)
	return p


static func _dots() -> Control:
	var l := Label.new()
	l.text = "…"
	l.modulate = UITheme.DIM
	return l
