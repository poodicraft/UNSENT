extends RefCounted
## Modal panels and cinematic cards, as inner classes.

const Kit := preload("res://src/ui/ui_kit.gd")
const Icon := preload("res://src/ui/icon.gd")


## Base for dimmed full-screen modals.
class Modal extends Control:
	var backdrop: ColorRect

	func _init() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		backdrop = ColorRect.new()
		backdrop.color = Color(0.03, 0.03, 0.07, 0.78)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(backdrop)

	func appear(node: Control) -> void:
		modulate.a = 0.0
		var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "modulate:a", 1.0, 0.2)
		var y0 := node.position.y
		node.position.y += 50
		t.tween_property(node, "position:y", y0, 0.28)

	func sheet(bottom := true, max_frac := 0.78) -> PanelContainer:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Kit.box(Color("#171c32"), 28, 2, Color(Kit.GOLD, 0.5), 20, 22))
		p.anchor_left = 0.0
		p.anchor_right = 1.0
		p.offset_left = 14
		p.offset_right = -14
		if bottom:
			p.anchor_top = 1.0 - max_frac
			p.anchor_bottom = 1.0
			p.offset_bottom = -18
		else:
			p.anchor_top = 0.5
			p.anchor_bottom = 0.5
			p.grow_vertical = Control.GROW_DIRECTION_BOTH
		add_child(p)
		return p

	func header(parent: Control, text: String, on_close: Callable) -> void:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		parent.add_child(h)
		var t := Kit.label(text, 29, Kit.CREAM, "display")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(t)
		var c := Kit.icon_button("close", 78)
		c.pressed.connect(on_close)
		h.add_child(c)

	func scroll_list(parent: Control) -> VBoxContainer:
		var s := ScrollContainer.new()
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
		s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		parent.add_child(s)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 12)
		s.add_child(v)
		return v


# ═══════════════════════════════════════════════════════════════════
#  Cinematic cards
# ═══════════════════════════════════════════════════════════════════

class TitleCard extends Control:
	signal done
	var _ready_to_close := false

	func setup(title: String, subtitle: String, on_black: bool) -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var bg := ColorRect.new()
		bg.color = Color(0.02, 0.02, 0.05, 1.0 if on_black else 0.82)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		v.anchor_left = 0.0
		v.anchor_right = 1.0
		v.offset_left = 40
		v.offset_right = -40
		v.grow_vertical = Control.GROW_DIRECTION_BOTH
		v.add_theme_constant_override("separation", 22)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(v)
		var line1 := ColorRect.new()
		line1.color = Color(Kit.GOLD, 0.7)
		line1.custom_minimum_size = Vector2(160, 2)
		line1.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(line1)
		var t := Kit.label(title, 56, Kit.CREAM, "display", HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(t)
		var s := Kit.label(subtitle, 28, Color("#cbbfa8"), "italic", HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(s)
		var line2 := line1.duplicate()
		v.add_child(line2)
		modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.9)
		tw.tween_callback(func(): _ready_to_close = true)
		tw.tween_interval(2.6)
		tw.tween_callback(_finish)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and _ready_to_close:
			_finish()

	func _finish() -> void:
		if not _ready_to_close:
			return
		_ready_to_close = false
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.7)
		tw.tween_callback(func(): done.emit())


class ConsequenceCard extends Control:
	signal done
	var _can := false

	func setup(title: String, subtitle: String) -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var bg := ColorRect.new()
		bg.color = Color(0.02, 0.02, 0.06, 0.55)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", Kit.paper_box(10, 40))
		card.anchor_left = 0.0
		card.anchor_right = 1.0
		card.anchor_top = 0.5
		card.anchor_bottom = 0.5
		card.offset_left = 44
		card.offset_right = -44
		card.grow_vertical = Control.GROW_DIRECTION_BOTH
		add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 16)
		card.add_child(v)
		var seal := Icon.new()
		seal.kind = "star"
		seal.color = Kit.WAX
		seal.custom_minimum_size = Vector2(70, 70)
		seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(seal)
		v.add_child(Kit.label("THE WORLD HAS CHANGED", 20, Color(Kit.INK, 0.6), "display", HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(Kit.label(title, 31, Kit.INK, "serif_bold", HORIZONTAL_ALIGNMENT_CENTER))
		if subtitle != "":
			v.add_child(Kit.label(subtitle, 25, Kit.INK_SOFT, "italic", HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(Kit.label("tap to continue", 19, Color(Kit.INK, 0.4), "italic", HORIZONTAL_ALIGNMENT_CENTER))
		modulate.a = 0.0
		card.pivot_offset = Vector2(300, 150)
		card.scale = Vector2(0.9, 0.9)
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 1.0, 0.35)
		tw.tween_property(card, "scale", Vector2.ONE, 0.45)
		tw.chain().tween_interval(0.5)
		tw.chain().tween_callback(func(): _can = true)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and _can:
			_can = false
			Audio.sfx("paper", -6.0)
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.3)
			tw.tween_callback(func(): done.emit())


class DeliveredStamp extends Control:
	signal done

	func setup(letter_id: String, who: String) -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var v := VBoxContainer.new()
		v.anchor_left = 0.0
		v.anchor_right = 1.0
		v.anchor_top = 0.38
		v.anchor_bottom = 0.38
		v.add_theme_constant_override("separation", 6)
		add_child(v)
		var word := "KEPT" if who == "wren" else "DELIVERED"
		var stamp := Kit.label(word, 64, Kit.WAX, "display", HORIZONTAL_ALIGNMENT_CENTER)
		stamp.add_theme_color_override("font_outline_color", Color("#f5e3c8"))
		stamp.add_theme_constant_override("outline_size", 8)
		v.add_child(stamp)
		var to := "" if who == "wren" else "to " + Data.char_name(who)
		var sub := Kit.label(to, 30, Kit.CREAM, "italic", HORIZONTAL_ALIGNMENT_CENTER)
		sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		sub.add_theme_constant_override("outline_size", 6)
		v.add_child(sub)
		v.pivot_offset = Vector2(360, 50)
		v.rotation = -0.1
		v.scale = Vector2(1.8, 1.8)
		modulate.a = 0.0
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.12)
		tw.tween_property(v, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(func(): Audio.sfx("stamp"))
		tw.chain().tween_interval(0.9)
		tw.chain().tween_property(self, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(func(): done.emit())


# ═══════════════════════════════════════════════════════════════════
#  Conversation panels
# ═══════════════════════════════════════════════════════════════════

class AskPanel extends Modal:
	signal picked(clue_id: String)
	var npc := ""

	func on_back() -> void:
		picked.emit("")

	func open(npc_id: String) -> void:
		npc = npc_id
		var p := sheet(true, 0.74)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		p.add_child(v)
		header(v, "Ask %s about…" % Data.char_first_name(npc_id), func(): picked.emit(""))
		v.add_child(Kit.label("Your notes, grouped by letter. Faded entries have already been asked.", 21, Kit.MUTED, "italic"))
		var list := scroll_list(v)
		var letters := GameState.collected_letters()
		letters.sort_custom(func(a, b): return int(GameState.letter_state(a) != "held") < int(GameState.letter_state(b) != "held"))
		var shown := {}
		for lid in letters:
			var group: Array = []
			for c in GameState.clues:
				if lid in Data.clue(c).get("letters", []) and not shown.has(c):
					group.append(c)
			if group.is_empty():
				continue
			list.add_child(Kit.label(Data.letter(lid).get("title", lid).to_upper(), 20, Kit.GOLD, "display"))
			for c in group:
				shown[c] = true
				var asked := GameState.was_asked(npc_id, c)
				var b := Kit.dark_button(("✓  " if asked else "") + Data.clue(c).get("title", c), 76)
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				if asked:
					b.modulate.a = 0.55
				var cid: String = c
				b.pressed.connect(func(): picked.emit(cid))
				list.add_child(b)
		appear(p)


class LetterPicker extends Modal:
	signal picked(letter_id: String)

	func on_back() -> void:
		picked.emit("")

	func open(npc_id: String) -> void:
		var p := sheet(true, 0.62)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		p.add_child(v)
		header(v, "Deliver to %s…" % Data.char_first_name(npc_id), func(): picked.emit(""))
		v.add_child(Kit.label("Which letter? You'll need at least two good reasons.", 21, Kit.MUTED, "italic"))
		var list := scroll_list(v)
		for lid in Story.deliverable_letters():
			var ev := Story.evidence(lid, npc_id)
			var ready := Story.can_deliver(lid, npc_id)
			var n: int = ev.support.size()
			var txt: String = Data.letter(lid).get("title", lid)
			var hint := "  ·  %d reason%s" % [n, "" if n == 1 else "s"] if n > 0 else "  ·  no reason yet"
			var b := Kit.button(txt + hint, 84) if ready else Kit.dark_button(txt + hint, 84)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var id: String = lid
			b.pressed.connect(func(): picked.emit(id))
			list.add_child(b)
		appear(p)


class ConfirmDelivery extends Modal:
	signal answered(yes: bool)

	func on_back() -> void:
		answered.emit(false)

	func open(letter_id: String, who: String) -> void:
		var L := Data.letter(letter_id)
		var ev := Story.evidence(letter_id, who)
		var need := int(L.get("min_evidence", 2))
		var ready := Story.can_deliver(letter_id, who)
		var p := sheet(false)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		p.add_child(v)
		var whom := "yourself" if who == "wren" else Data.char_name(who)
		v.add_child(Kit.label("Keep this letter?" if who == "wren" else "Deliver to %s?" % whom, 30, Kit.CREAM, "display", HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(Kit.label("“%s”" % L.get("title", ""), 26, Kit.GOLD, "italic", HORIZONTAL_ALIGNMENT_CENTER))
		var sep := ColorRect.new()
		sep.color = Color(Kit.GOLD, 0.3)
		sep.custom_minimum_size = Vector2(0, 2)
		v.add_child(sep)
		if ev.support.is_empty() and ev.refute.is_empty():
			v.add_child(Kit.label("Nothing you've found connects this letter to %s." % whom, 24, Kit.MUTED, "italic"))
		for c in ev.support:
			v.add_child(_row("✓", Data.clue(c).get("title", c), Kit.GOOD))
		for c in ev.refute:
			v.add_child(_row("✗", Data.clue(c).get("title", c), Kit.BAD))
		var thought := ""
		if not ready:
			thought = "I don't have enough reason to think this is theirs yet. I need at least %d good clues pointing to them." % need if who != "wren" else "I'm not sure this is mine. I need more reason."
		elif not ev.refute.is_empty():
			thought = "Some of what I've found doesn't fit. Am I sure?"
		else:
			thought = "Once it's delivered, it can't be undelivered."
		v.add_child(Kit.label(thought, 23, Color("#d8cdb6"), "italic", HORIZONTAL_ALIGNMENT_CENTER))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		v.add_child(h)
		var no := Kit.dark_button("Not yet", 88)
		no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		no.pressed.connect(func(): answered.emit(false))
		h.add_child(no)
		var yes := Kit.wax_button("Keep it" if who == "wren" else "Deliver", 88)
		yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		yes.disabled = not ready
		yes.pressed.connect(func(): answered.emit(true))
		h.add_child(yes)
		appear(p)

	func _row(mark: String, text: String, c: Color) -> Control:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var m := Kit.label(mark, 28, c, "serif_bold")
		m.custom_minimum_size = Vector2(34, 0)
		h.add_child(m)
		var t := Kit.label(text, 24, Kit.CREAM)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		return h


class ConfirmBox extends Modal:
	signal answered(yes: bool)

	func on_back() -> void:
		answered.emit(false)

	func open(question: String, yes_text: String, no_text: String) -> void:
		var p := sheet(false)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 22)
		p.add_child(v)
		v.add_child(Kit.label(question, 27, Kit.CREAM, "serif", HORIZONTAL_ALIGNMENT_CENTER))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		v.add_child(h)
		var no := Kit.dark_button(no_text, 86)
		no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		no.pressed.connect(func(): answered.emit(false))
		h.add_child(no)
		var yes := Kit.button(yes_text, 86)
		yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		yes.pressed.connect(func(): answered.emit(true))
		h.add_child(yes)
		appear(p)


# ═══════════════════════════════════════════════════════════════════
#  Menus
# ═══════════════════════════════════════════════════════════════════

class PauseMenu extends Modal:
	signal closed

	func on_back() -> void:
		closed.emit()

	func open() -> void:
		get_tree().paused = false
		var p := sheet(false)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 16)
		p.add_child(v)
		v.add_child(Kit.label("PAUSED", 38, Kit.CREAM, "display", HORIZONTAL_ALIGNMENT_CENTER))
		var night := int(Story.f("night"))
		var sub := "Lantern Night" if Story.f("lantern_night") else "Night %d" % night
		var loc: String = Data.locations.get(GameState.location, {}).get("name", "")
		v.add_child(Kit.label("%s · %s" % [sub, loc], 22, Kit.MUTED, "italic", HORIZONTAL_ALIGNMENT_CENTER))
		if GameState.objective != "":
			v.add_child(Kit.label(GameState.objective, 23, Color("#e6d9bf"), "italic", HORIZONTAL_ALIGNMENT_CENTER))
		var items := [
			["Resume", func(): closed.emit()],
			["Satchel", func(): _satchel()],
			["Save Game", func(): _save()],
			["Load Game", func(): _load()],
			["Settings", func(): _settings()],
			["Return to Title", func(): _title()],
		]
		for it in items:
			var b := Kit.button(it[0], 84) if it[0] == "Resume" else Kit.dark_button(it[0], 80)
			b.pressed.connect(it[1])
			v.add_child(b)
		appear(p)

	func _satchel() -> void:
		visible = false
		await Story.main.ui.open_satchel("letters")
		visible = true

	func _save() -> void:
		visible = false
		await Story.main.ui.open_saves("save")
		visible = true

	func _load() -> void:
		visible = false
		var slot: String = await Story.main.ui.open_saves("load")
		visible = true
		if slot != "":
			closed.emit()
			Story.main.load_slot(slot)

	func _settings() -> void:
		visible = false
		await Story.main.ui.open_settings()
		visible = true

	func _title() -> void:
		visible = false
		var ok: bool = await Story.main.ui.confirm("Return to the title screen? Your progress is autosaved at every door and delivery.", "Return", "Stay")
		visible = true
		if ok:
			GameState.autosave()
			closed.emit()
			Story.main.go_title()


class SettingsPanel extends Modal:
	signal closed

	func on_back() -> void:
		Settings.save_settings()
		closed.emit()

	func open() -> void:
		var p := sheet(true, 0.86)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 12)
		p.add_child(v)
		header(v, "SETTINGS", func(): on_back())
		var list := scroll_list(v)
		list.add_theme_constant_override("separation", 18)
		_slider(list, "Music", Settings.music_volume, func(x): Settings.music_volume = x; Audio.apply_volumes())
		_slider(list, "Ambience", Settings.ambience_volume, func(x): Settings.ambience_volume = x; Audio.apply_volumes())
		_slider(list, "Sound effects", Settings.sfx_volume, func(x):
			Settings.sfx_volume = x
			Audio.apply_volumes()
			Audio.sfx("ui_tap"))
		_slider(list, "Text speed", (Settings.text_speed - 0.5) / 2.5, func(x): Settings.text_speed = 0.5 + x * 2.5)
		list.add_child(Kit.label("Text size", 25, Kit.CREAM, "serif_bold"))
		var sizes := HBoxContainer.new()
		sizes.add_theme_constant_override("separation", 10)
		list.add_child(sizes)
		var names := ["Small", "Medium", "Large"]
		var btns: Array = []
		for i in 3:
			var b := Kit.button(names[i], 76) if Settings.text_size == i else Kit.dark_button(names[i], 76)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var idx := i
			b.pressed.connect(func():
				Settings.text_size = idx
				Settings.save_settings()
				closed.emit()
				Story.main.ui.open_settings())
			sizes.add_child(b)
			btns.append(b)
		_toggle(list, "Reduce motion (no shake, flashes or ripples)", Settings.reduce_motion, func(on): Settings.reduce_motion = on)
		_toggle(list, "Show sparkles on things worth examining", Settings.show_hints, func(on):
			Settings.show_hints = on
			if Story.world:
				Story.world.refresh())
		var sep := ColorRect.new()
		sep.color = Color(Kit.GOLD, 0.25)
		sep.custom_minimum_size = Vector2(0, 2)
		list.add_child(sep)
		var wipe := Kit.dark_button("Erase all saved games", 78)
		wipe.add_theme_color_override("font_color", Kit.BAD)
		wipe.pressed.connect(_wipe)
		list.add_child(wipe)
		list.add_child(Kit.label("UNSENT v1.0 · Made with Godot Engine. Fonts under the SIL Open Font License / Apache 2.0. All art, music and sound generated for this game.", 19, Kit.MUTED, "italic", HORIZONTAL_ALIGNMENT_CENTER))
		appear(p)

	func _slider(parent: Control, name: String, value: float, cb: Callable) -> void:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		parent.add_child(h)
		var l := Kit.label(name, 25, Kit.CREAM, "serif_bold")
		l.custom_minimum_size = Vector2(220, 0)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.01
		s.value = clampf(value, 0.0, 1.0)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.custom_minimum_size = Vector2(0, 64)
		s.focus_mode = Control.FOCUS_NONE
		var grabber := _grabber_tex()
		if grabber:
			s.add_theme_icon_override("grabber", grabber)
			s.add_theme_icon_override("grabber_highlight", grabber)
		s.value_changed.connect(cb)
		h.add_child(s)

	func _grabber_tex() -> Texture2D:
		var img := Image.create(44, 44, false, Image.FORMAT_RGBA8)
		for y in 44:
			for x in 44:
				var d := Vector2(x - 21.5, y - 21.5).length()
				var a := clampf(20.0 - d, 0.0, 1.0)
				var c := Kit.CREAM if d < 15.0 else Kit.GOLD
				img.set_pixel(x, y, Color(c, a))
		return ImageTexture.create_from_image(img)

	func _toggle(parent: Control, name: String, value: bool, cb: Callable) -> void:
		var c := CheckButton.new()
		c.text = name
		c.button_pressed = value
		c.focus_mode = Control.FOCUS_NONE
		c.custom_minimum_size = Vector2(0, 72)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_theme_font_size_override("font_size", Settings.font(24))
		var sb := Kit.box(Color("#232944"), 20, 1, Color(Kit.GOLD, 0.35), 0, 14)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			c.add_theme_stylebox_override(st, sb)
		c.add_theme_color_override("font_color", Kit.CREAM)
		c.add_theme_color_override("font_pressed_color", Kit.CREAM)
		c.add_theme_color_override("font_hover_color", Kit.CREAM)
		c.add_theme_color_override("font_hover_pressed_color", Kit.CREAM)
		c.toggled.connect(cb)
		parent.add_child(c)

	func _wipe() -> void:
		visible = false
		var ok: bool = await Story.main.ui.confirm("Erase every saved game and discovered ending? This can't be undone.", "Erase", "Keep")
		visible = true
		if ok:
			GameState.wipe_all()
			Story.main.ui.toast("All saved games erased.", "fade")


class SavePanel extends Modal:
	signal picked(slot: String)
	var mode := "save"

	func on_back() -> void:
		picked.emit("")

	func open(m: String) -> void:
		mode = m
		var p := sheet(true, 0.7)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		p.add_child(v)
		header(v, "SAVE GAME" if mode == "save" else "LOAD GAME", func(): picked.emit(""))
		var list := scroll_list(v)
		for slot in GameState.SLOTS:
			if slot == "auto" and mode == "save":
				continue
			list.add_child(_slot_button(slot))
		appear(p)

	func _slot_button(slot: String) -> Control:
		var info := GameState.slot_info(slot)
		var title := "Autosave" if slot == "auto" else "Slot %s" % slot
		var line := "Empty"
		if not info.is_empty():
			var night := "Lantern Night" if info.lantern else "Night %d" % info.night
			var loc: String = Data.locations.get(info.location, {}).get("name", "")
			var when := Time.get_datetime_string_from_unix_time(int(info.saved_at)).replace("T", " ").substr(0, 16)
			line = "%s · %s\n%d letters delivered · %s · %s" % [night, loc, info.delivered, Kit.fmt_time(float(info.play_time)), when]
		var b := Kit.dark_button("", 120)
		var vb := VBoxContainer.new()
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vb.offset_left = 26
		vb.offset_top = 14
		vb.offset_right = -20
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(vb)
		vb.add_child(Kit.label(title, 26, Kit.GOLD, "serif_bold"))
		vb.add_child(Kit.label(line, 21, Kit.CREAM, "serif"))
		if mode == "load" and info.is_empty():
			b.disabled = true
			b.modulate.a = 0.5
		b.pressed.connect(func(): _pick(slot, info.is_empty()))
		return b

	func _pick(slot: String, empty: bool) -> void:
		if mode == "save":
			if not empty:
				visible = false
				var ok: bool = await Story.main.ui.confirm("Overwrite this save?", "Overwrite", "Cancel")
				visible = true
				if not ok:
					return
			GameState.save_game(slot)
			Audio.sfx("stamp", -4.0)
			Story.main.ui.toast("Game saved.", "letter")
			picked.emit(slot)
		else:
			picked.emit(slot)
