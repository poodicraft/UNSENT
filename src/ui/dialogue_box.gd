extends Control
## Bottom-of-screen dialogue box: portrait, name plate, typewriter text,
## tap-anywhere to advance, and large stacked choice buttons for thumbs.

const Kit := preload("res://src/ui/ui_kit.gd")
const Portrait := preload("res://src/ui/portrait.gd")

signal advanced
signal chose(index: int)

var _panel: PanelContainer
var _portrait: Control
var _name: Label
var _text: RichTextLabel
var _cont: Control
var _choices: VBoxContainer
var _catcher: Control
var _typing := false
var _visible_chars := 0.0
var _total := 0
var _waiting := false
var _choosing := false
var _voice := 1.0
var _blip_acc := 0.0
var _who := ""
var _open := false
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	# Full-screen tap catcher (advances text).
	_catcher = Control.new()
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_catcher_input)
	add_child(_catcher)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 14)
	_choices.anchor_left = 0.0
	_choices.anchor_right = 1.0
	_choices.anchor_top = 1.0
	_choices.anchor_bottom = 1.0
	_choices.offset_left = 34
	_choices.offset_right = -34
	_choices.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_choices)

	_panel = PanelContainer.new()
	var sb := Kit.box(Color(0.06, 0.07, 0.14, 0.94), 26, 2, Color(Kit.GOLD, 0.55), 18, 0)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 34
	sb.content_margin_bottom = 30
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 18
	_panel.offset_right = -18
	_panel.offset_bottom = -26
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	_portrait = Portrait.new()
	_portrait.custom_minimum_size = Vector2(128, 128)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	_name = Kit.label("", 25, Kit.GOLD, "display")
	col.add_child(_name)

	_text = Kit.rich(29)
	_text.custom_minimum_size = Vector2(0, 150)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_text)

	_cont = preload("res://src/ui/icon.gd").new()
	_cont.kind = "star"
	_cont.color = Kit.GOLD
	_cont.custom_minimum_size = Vector2(26, 26)
	_cont.anchor_left = 1.0
	_cont.anchor_right = 1.0
	_cont.anchor_top = 1.0
	_cont.anchor_bottom = 1.0
	_cont.offset_left = -64
	_cont.offset_right = -34
	_cont.offset_top = -66
	_cont.offset_bottom = -36
	_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cont)
	_cont.visible = false


func _process(delta: float) -> void:
	if _typing:
		var speed := 46.0 * Settings.text_speed
		if Settings.text_speed >= 2.9:
			speed = 100000.0
		_visible_chars += delta * speed
		var n := int(_visible_chars)
		if n >= _total:
			_finish_typing()
		else:
			_text.visible_characters = n
			_blip_acc += delta * speed
			if _blip_acc > 2.6:
				_blip_acc = 0.0
				Audio.blip(_voice)
	if _cont.visible:
		_cont.offset_top = -66 + sin(Time.get_ticks_msec() / 220.0) * 4.0
		_cont.offset_bottom = _cont.offset_top + 30


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_portrait.set_talking(false)
	_set_world_talking(false)
	_cont.visible = _waiting


func _set_world_talking(on: bool) -> void:
	var w = Story.world
	if w == null:
		return
	var a = w.npc(_who) if _who != "wren" else w.player
	if a:
		a.puppet.talking = on


func _ensure_open() -> void:
	if _open:
		return
	_open = true
	visible = true
	_panel.modulate.a = 0.0
	_panel.position.y += 40
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.22)
	_tween.tween_property(_panel, "position:y", _panel.position.y - 40, 0.28)


func is_open() -> bool:
	return _open


## Shows a line and waits until the player taps past it.
func say(who: String, expr: String, text: String) -> void:
	_ensure_open()
	_clear_choices()
	_who = who
	var narr := who == "n" or who == ""
	_panel.visible = true
	_portrait.visible = not narr
	if narr:
		_name.text = ""
		_name.visible = false
		_text.text = "[i]" + text.replace("[i]", "").replace("[/i]", "") + "[/i]" if not text.begins_with("[i]") else text
		_text.add_theme_color_override("default_color", Color("#d8cfbf"))
		_voice = 0.0
	else:
		_name.visible = true
		_name.text = Data.char_name(who).to_upper() if who != "wren" else "WREN"
		_name.add_theme_color_override("font_color", Data.char_color(who))
		_text.text = text
		_text.add_theme_color_override("default_color", Kit.CREAM)
		_portrait.show_char(who, expr, true)
		_voice = float(Data.characters.get(who, {}).get("voice", 1.0))
	for k in ["normal_font_size", "italics_font_size", "bold_font_size"]:
		_text.add_theme_font_size_override(k, Settings.font(29))
	_total = _text.get_total_character_count()
	_visible_chars = 0.0
	_text.visible_characters = 0
	_typing = true
	_waiting = true
	_cont.visible = false
	await advanced
	_waiting = false
	_cont.visible = false


## Shows choice buttons above the box; returns the chosen index.
func choose(options: Array, hub := false) -> int:
	_ensure_open()
	if _typing:
		_finish_typing()
	_clear_choices()
	_choosing = true
	_cont.visible = false
	_choices.offset_bottom = -26 - _panel.size.y - 18
	for i in options.size():
		var b: Button = Kit.dark_button(options[i], 82) if hub and options[i] == "Goodbye" else Kit.button(options[i], 82)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var idx := i
		b.pressed.connect(func(): _on_choice(idx))
		_choices.add_child(b)
		b.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.04 * i)
		t.tween_property(b, "modulate:a", 1.0, 0.18)
	var r: int = await chose
	_choosing = false
	_clear_choices()
	return r


func _on_choice(i: int) -> void:
	chose.emit(i)


func _clear_choices() -> void:
	for c in _choices.get_children():
		c.queue_free()


func close() -> void:
	if not _open:
		return
	_open = false
	_typing = false
	_clear_choices()
	_set_world_talking(false)
	var t := create_tween()
	t.tween_property(_panel, "modulate:a", 0.0, 0.15)
	t.tween_callback(func():
		if not _open:
			visible = false)


func _on_catcher_input(event: InputEvent) -> void:
	if _choosing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _typing:
			_finish_typing()
		elif _waiting:
			advanced.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _choosing:
		return
	if event.is_pressed() and (event as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER]:
		if _typing:
			_finish_typing()
		elif _waiting:
			advanced.emit()
