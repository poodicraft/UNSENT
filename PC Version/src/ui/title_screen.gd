extends Control
## Title screen, drawn over a live, slowly drifting harbour diorama.
## PC layout: the logo and the menu in a column on the left; the menu can
## be used with the mouse or the arrow keys and Enter.

const Kit := preload("res://src/ui/ui_kit.gd")

signal action(name: String)

var _envelopes: Array = []
var _t := 0.0
var _buttons: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.03, 0.08, 0.86))
	grad.set_color(1, Color(0.03, 0.03, 0.08, 0.0))
	grad.add_point(0.3, Color(0.03, 0.03, 0.08, 0.62))
	g.gradient = grad
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(0.75, 0)
	var tr := TextureRect.new()
	tr.texture = g
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

	for i in 9:
		_envelopes.append({"x": randf(), "y": randf_range(0.2, 1.2), "s": randf_range(0.6, 1.2),
			"r": randf_range(-0.6, 0.6), "v": randf_range(0.012, 0.03), "ph": randf() * TAU})

	# Left column: logo above the menu, centred vertically.
	var column := VBoxContainer.new()
	column.anchor_left = 0.0
	column.anchor_right = 0.0
	column.anchor_top = 0.5
	column.anchor_bottom = 0.5
	column.offset_left = 120
	column.offset_right = 120 + 600
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 56)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", 10)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(logo)
	var title := Kit.label("UNSENT", 96, Kit.CREAM, "display", HORIZONTAL_ALIGNMENT_CENTER)
	var fv := FontVariation.new()
	fv.base_font = Kit.font("display")
	fv.spacing_glyph = 14
	title.add_theme_font_override("font", fv)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_constant_override("shadow_outline_size", 10)
	logo.add_child(title)
	var line := ColorRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = Color(Kit.GOLD, 0.8)
	line.custom_minimum_size = Vector2(220, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.add_child(line)
	var sub := Kit.label("CHAPTER ONE · THE LONG DUSK", 24, Kit.GOLD, "display", HORIZONTAL_ALIGNMENT_CENTER)
	logo.add_child(sub)
	var tag := Kit.label("Some letters were never sent.\nSome haven't been written yet.", 25, Color("#e8dcc6"), "italic", HORIZONTAL_ALIGNMENT_CENTER)
	tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	tag.add_theme_constant_override("shadow_offset_y", 2)
	logo.add_child(tag)

	_buttons = VBoxContainer.new()
	_buttons.custom_minimum_size = Vector2(440, 0)
	_buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_buttons.add_theme_constant_override("separation", 14)
	column.add_child(_buttons)
	var recent := GameState.most_recent_slot()
	if recent != "":
		_add("Continue", "continue", true)
	_add("New Game", "new", recent == "")
	if recent != "":
		_add("Load Game", "load", false)
	_add("Settings", "settings", false)
	_add("Credits", "credits", false)
	_add("Quit", "quit", false)
	if not GameState.endings_seen.is_empty():
		var e := Kit.label("Endings discovered: %d / 3" % GameState.endings_seen.size(), 21, Kit.MUTED, "italic", HORIZONTAL_ALIGNMENT_CENTER)
		_buttons.add_child(e)

	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 1.4)


func _add(text: String, id: String, primary: bool) -> void:
	var b := Kit.button(text, 88) if primary else Kit.dark_button(text, 82)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("focus", Kit.focus_ring())
	b.pressed.connect(func(): action.emit(id))
	_buttons.add_child(b)


## Up / Down (or W / S) start keyboard navigation of the menu; after that
## Godot's focus handling moves between buttons and Enter / Space press.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if not k.pressed or k.echo or Story.main == null or Story.main.ui.modal_open():
		return
	if not k.keycode in [KEY_UP, KEY_DOWN, KEY_W, KEY_S]:
		return
	var btns: Array = []
	for c in _buttons.get_children():
		if c is Button:
			btns.append(c)
	if btns.is_empty():
		return
	get_viewport().set_input_as_handled()
	var cur := -1
	for i in btns.size():
		if btns[i].has_focus():
			cur = i
	var up: bool = k.keycode in [KEY_UP, KEY_W]
	var nxt := (btns.size() - 1 if up else 0) if cur < 0 else wrapi(cur + (-1 if up else 1), 0, btns.size())
	btns[nxt].grab_focus()


func _process(delta: float) -> void:
	_t += delta
	for e in _envelopes:
		e.y -= e.v * delta
		e.r += sin(_t * 0.5 + e.ph) * 0.002
		if e.y < -0.1:
			e.y = 1.1
			e.x = randf()
	queue_redraw()


func _draw() -> void:
	var vs := size
	for e in _envelopes:
		var p := Vector2(e.x * vs.x + sin(_t * 0.4 + e.ph) * 30.0, e.y * vs.y)
		var s: float = e.s * 30.0
		draw_set_transform(p, e.r + sin(_t * 0.7 + e.ph) * 0.15, Vector2.ONE)
		var a := 0.22 + 0.12 * sin(_t + e.ph)
		draw_rect(Rect2(-s, -s * 0.66, s * 2, s * 1.32), Color(0.96, 0.9, 0.78, a), true)
		draw_polyline(PackedVector2Array([Vector2(-s, -s * 0.66), Vector2(0, s * 0.1), Vector2(s, -s * 0.66)]), Color(0.5, 0.42, 0.35, a * 1.4), 1.6, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func show_credits() -> void:
	await Story.main.ui.open_credits()
