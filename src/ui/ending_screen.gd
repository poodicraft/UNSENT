extends Control
## The ending: one card per life the letters touched, then the end card.

const Kit := preload("res://src/ui/ui_kit.gd")
const Portrait := preload("res://src/ui/portrait.gd")

signal finished

var ending_id := ""
var _tap := false
var _bg: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_tap = true


func play(id: String) -> void:
	ending_id = id
	var E: Dictionary = Data.endings.get(id, {})
	var dawn: bool = E.get("dawn", false)
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.03, 0.03, 0.07, 0.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	var t := create_tween()
	t.tween_property(_bg, "color:a", 0.55 if dawn else 0.7, 1.5)
	await t.finished

	for fate in Story.fates():
		await _fate_card(fate)

	var t2 := create_tween()
	t2.tween_property(_bg, "color:a", 0.92, 1.2)
	await t2.finished
	await _end_card(E)
	finished.emit()


func _wait(secs: float) -> void:
	_tap = false
	var left := secs
	while left > 0.0 and not _tap:
		await get_tree().process_frame
		left -= get_process_delta_time()
	_tap = false


func _fate_card(fate: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = 50
	box.offset_right = -50
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 24)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var p := Portrait.new()
	p.custom_minimum_size = Vector2(190, 190)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(p)
	var who: String = fate.who
	p.show_char(who, fate.get("mood", "happy"), false)
	var name := Kit.label(Data.char_name(who).to_upper(), 26, Data.char_color(who), "display", HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(name)
	var txt := Kit.label(fate.text, 30, Kit.CREAM, "italic", HORIZONTAL_ALIGNMENT_CENTER)
	txt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	txt.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(txt)
	box.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(box, "modulate:a", 1.0, 0.9)
	await t.finished
	await _wait(6.0)
	var t2 := create_tween()
	t2.tween_property(box, "modulate:a", 0.0, 0.7)
	await t2.finished
	box.queue_free()


func _end_card(E: Dictionary) -> void:
	var v := VBoxContainer.new()
	v.anchor_left = 0.0
	v.anchor_right = 1.0
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = 44
	v.offset_right = -44
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.add_theme_constant_override("separation", 20)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	v.add_child(Kit.label("END OF CHAPTER ONE", 22, Kit.MUTED, "display", HORIZONTAL_ALIGNMENT_CENTER))
	var title := Kit.label(E.get("title", "The End"), 54, Kit.CREAM, "display", HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(title)
	var line := ColorRect.new()
	line.color = Color(Kit.GOLD, 0.8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(200, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(line)
	v.add_child(Kit.label(E.get("subtitle", ""), 27, Color("#e3d6bd"), "italic", HORIZONTAL_ALIGNMENT_CENTER))
	var delivered := 0
	var futures := 0
	for id in GameState.letters:
		var st := GameState.letter_state(id)
		if st in ["delivered", "kept"] and not Data.letter(id).get("auto_keep", false):
			delivered += 1
		if st == "faded":
			futures += 1
	for f in ["clock_running", "bakery_lamp_lit", "tobias_knows", "lamp_lit"]:
		if Story.f(f):
			futures += 1
	var stats := "Letters delivered: %d\nClues found: %d of %d\nThings changed for good: %d\nEndings discovered: %d of 3" % [
		delivered, GameState.clues.size(), Data.clues.size(), futures, GameState.endings_seen.size()]
	v.add_child(Kit.label(stats, 25, Kit.CREAM, "serif", HORIZONTAL_ALIGNMENT_CENTER))
	var hint := ""
	if ending_id == "long_dusk":
		hint = "The dawn needs the lighthouse lit on Lantern Night — and enough hearts mended. Read more closely. Ask one more question."
	elif ending_id == "first_light" and not GameState.endings_seen.has("morning_ferry"):
		hint = "Another road leads out of Hushwater, for someone holding a ferry ticket."
	if hint != "":
		v.add_child(Kit.label(hint, 22, Kit.GOLD, "italic", HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.label("Thank you for playing.", 26, Kit.CREAM, "italic", HORIZONTAL_ALIGNMENT_CENTER))
	var b := Kit.button("Return to Title", 88)
	v.add_child(b)
	v.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(v, "modulate:a", 1.0, 1.2)
	await b.pressed
