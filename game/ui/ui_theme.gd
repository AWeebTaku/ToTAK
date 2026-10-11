class_name UITheme
## Builds the shared dark-stone / gold UI theme in code.

const BG := Color(0.05, 0.04, 0.06, 0.95)
const BORDER := Color(0.5, 0.1, 0.12)
const TEXT := Color(0.84, 0.8, 0.74)
const DIM := Color(0.5, 0.46, 0.5)


static func box(bg := BG, border := BORDER, bw := 2, radius := 6, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "PanelContainer", box())
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var bg := Color(0.1, 0.08, 0.11)
		var border := Color(0.28, 0.12, 0.12)
		match state:
			"hover", "focus":
				bg = Color(0.2, 0.08, 0.09)
				border = BORDER
			"pressed":
				bg = Color(0.28, 0.07, 0.08)
				border = BORDER
			"disabled":
				bg = Color(0.11, 0.1, 0.13)
				border = Color(0.25, 0.23, 0.25)
		t.set_stylebox(state, "Button", box(bg, border, 2, 5, 10))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.38, 0.42))
	t.set_stylebox("background", "ProgressBar", box(Color(0.12, 0.03, 0.04), Color(0.03, 0.02, 0.03), 2, 4, 0))
	t.set_stylebox("fill", "ProgressBar", box(Color(0.6, 0.08, 0.1), Color(0, 0, 0, 0), 0, 4, 0))
	for cls in ["CheckBox", "CheckButton"]:
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			t.set_stylebox(state, cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, TEXT)
		t.set_color("font_hover_pressed_color", cls, Color.WHITE)
	return t


## Small red X button for closing a menu.
static func close_button(cb: Callable) -> Button:
	var b := Button.new()
	b.text = "X"
	b.tooltip_text = "Close (Esc)"
	b.focus_mode = Control.FOCUS_NONE        # keep Space/Enter free for game keys
	b.custom_minimum_size = Vector2(32, 32)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", box(Color(0.68, 0.12, 0.14), Color(0.35, 0.04, 0.05), 2, 5, 0))
	b.add_theme_stylebox_override("hover", box(Color(0.9, 0.2, 0.22), Color(1, 0.6, 0.6), 2, 5, 0))
	b.add_theme_stylebox_override("pressed", box(Color(0.5, 0.08, 0.1), Color(0.35, 0.04, 0.05), 2, 5, 0))
	b.pressed.connect(cb)
	return b


## Title row with the title centered and a red X on the right. The X is child 2 of the returned row.
static func with_close(title: Label, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(32, 32)    # balances the X so the title stays centered
	row.add_child(spacer)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(title)
	row.add_child(close_button(cb))
	return row
