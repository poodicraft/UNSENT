extends RefCounted
## Modal panels and cinematic cards, as inner classes.

const Kit := preload("res://src/ui/ui_kit.gd")
const Icon := preload("res://src/ui/icon.gd")
const TapCard := preload("res://src/ui/tap_card.gd")

## Keys that dismiss a "click to continue" card.
const CONTINUE_KEYS := [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_ESCAPE]


## Base for dimmed full-screen modals.
class Modal extends Control:
	var backdrop: ColorRect
	## Tapping the dimmed area around the panel works like Back / Cancel.
	var dismiss_on_backdrop := true
	var _opened_at := 0

	func _init() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		process_mode = Node.PROCESS_MODE_ALWAYS
		_opened_at = Time.get_ticks_msec()
		backdrop = ColorRect.new()
		backdrop.color = Color(0.03, 0.03, 0.07, 0.78)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		backdrop.gui_input.connect(_on_backdrop_input)
		add_child(backdrop)

	func _on_backdrop_input(e: InputEvent) -> void:
		if not dismiss_on_backdrop or not visible:
			return
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			if Time.get_ticks_msec() - _opened_at > 350 and has_method("on_back"):
				call("on_back")

	## Fades the panel in with a small pop. (It never moves the panel: moving
	## it before its size is known used to leave buttons below the screen.)
	func appear(node: Control) -> void:
		modulate.a = 0.0
		node.scale = Vector2(0.97, 0.97)
		var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "modulate:a", 1.0, 0.2)
		t.tween_property(node, "scale", Vector2.ONE, 0.26)
		await get_tree().process_frame
		if not is_instance_valid(node):
			return
		_fit_on_screen(node)
		node.pivot_offset = node.size * 0.5

	## A centred panel taller than the screen gets its content put in a
	## scrolling list, so nothing can ever end up off screen.
	func _fit_on_screen(node: Control) -> void:
		if node.anchor_top != 0.5 or node.get_child_count() == 0:
			return
		var ins := Kit.safe_insets(self)
		var room := get_viewport_rect().size.y - ins.x - ins.y - 40.0
		if node.size.y <= room:
			return
		var content: Control = node.get_child(0)
		var sb := node.get_theme_stylebox("panel")
		var pad := (sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM)) if sb else 0.0
		var sc := Kit.scroller()
		sc.custom_minimum_size = Vector2(0, room - pad)
		node.remove_child(content)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(content)
		node.add_child(sc)
		node.offset_top = -room * 0.5
		node.offset_bottom = room * 0.5

	## PC: every panel is a card centred on screen, at most `max_w` wide.
	## List panels ("bottom" sheets on the phone) take `max_frac` of the
	## screen height; the others size to their content.
	func sheet(bottom := true, max_frac := 0.78, max_w := 900.0) -> PanelContainer:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Kit.box(Color("#171c32"), 28, 2, Color(Kit.GOLD, 0.5), 20, 26))
		add_child(p)
		Kit.column(p, max_w)
		if bottom:
			var frac := clampf(max_frac, 0.4, 0.9)
			p.anchor_top = 0.5 - frac * 0.5
			p.anchor_bottom = 0.5 + frac * 0.5
		else:
			p.anchor_top = 0.5
			p.anchor_bottom = 0.5
			p.grow_vertical = Control.GROW_DIRECTION_BOTH
		return p

	func header(parent: Control, text: String, on_close: Callable) -> void:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		parent.add_child(h)
		var t := Kit.label(text, 29, Kit.CREAM, "display")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(t)
		var c := Kit.icon_button("close", 84)
		c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		c.pressed.connect(on_close)
		h.add_child(c)

	func scroll_list(parent: Control) -> VBoxContainer:
		var s := Kit.scroller()
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		v.grow_vertical = Control.GROW_DIRECTION_BOTH
		Kit.column(v, 1100)
		v.add_theme_constant_override("separation", 22)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(v)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var line1 := ColorRect.new()
		line1.color = Color(Kit.GOLD, 0.7)
		line1.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	func _unhandled_key_input(e: InputEvent) -> void:
		if e.is_pressed() and not e.is_echo() and _ready_to_close and (e as InputEventKey).keycode in CONTINUE_KEYS:
			get_viewport().set_input_as_handled()
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
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", Kit.paper_box(10, 40))
		card.anchor_top = 0.5
		card.anchor_bottom = 0.5
		card.grow_vertical = Control.GROW_DIRECTION_BOTH
		add_child(card)
		Kit.column(card, 820)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 16)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(v)
		var seal := Icon.new()
		seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seal.kind = "star"
		seal.color = Kit.WAX
		seal.custom_minimum_size = Vector2(70, 70)
		seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(seal)
		v.add_child(Kit.label("THE WORLD HAS CHANGED", 20, Color(Kit.INK, 0.6), "display", HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(Kit.label(title, 31, Kit.INK, "serif_bold", HORIZONTAL_ALIGNMENT_CENTER))
		if subtitle != "":
			v.add_child(Kit.label(subtitle, 25, Kit.INK_SOFT, "italic", HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(Kit.label("click or press Space to continue", 19, Color(Kit.INK, 0.45), "italic", HORIZONTAL_ALIGNMENT_CENTER))
		modulate.a = 0.0
		card.pivot_offset = Vector2(card.offset_right, 150)
		card.scale = Vector2(0.9, 0.9)
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 1.0, 0.35)
		tw.tween_property(card, "scale", Vector2.ONE, 0.45)
		tw.chain().tween_interval(0.5)
		tw.chain().tween_callback(func(): _can = true)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed and _can:
			accept_event()
			_dismiss()

	func _unhandled_key_input(e: InputEvent) -> void:
		if e.is_pressed() and not e.is_echo() and _can and (e as InputEventKey).keycode in CONTINUE_KEYS:
			get_viewport().set_input_as_handled()
			_dismiss()

	func _dismiss() -> void:
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
		Kit.column(v, 900)
		v.anchor_top = 0.38
		v.anchor_bottom = 0.38
		v.add_theme_constant_override("separation", 6)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		v.rotation = -0.1
		v.scale = Vector2(1.8, 1.8)
		modulate.a = 0.0
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.12)
		tw.tween_property(v, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(func(): Audio.sfx("stamp"))
		v.resized.connect(func(): v.pivot_offset = v.size * 0.5)
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
		var p := sheet(true, 0.78, 900)
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
				var b := Kit.dark_button(Data.clue(c).get("title", c), 76)
				Kit.in_list(b)
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				if asked:
					Kit.lead_mark(b, "check", Kit.GOOD)
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
		var p := sheet(true, 0.62, 900)
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
			Kit.in_list(b)
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
		var p := sheet(false, 0.78, 820)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		p.add_child(v)
		var whom := "yourself" if who == "wren" else Data.char_name(who)
		v.add_child(Kit.label("Keep this letter?" if who == "wren" else "Deliver to %s?" % whom, 30, Kit.CREAM, "display", HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(Kit.label("“%s”" % L.get("title", ""), 26, Kit.GOLD, "italic", HORIZONTAL_ALIGNMENT_CENTER))
		var sep := ColorRect.new()
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sep.color = Color(Kit.GOLD, 0.3)
		sep.custom_minimum_size = Vector2(0, 2)
		v.add_child(sep)
		if ev.support.is_empty() and ev.refute.is_empty():
			v.add_child(Kit.label("Nothing you've found connects this letter to %s." % whom, 24, Kit.MUTED, "italic"))
		for c in ev.support:
			v.add_child(_row("check", Data.clue(c).get("title", c), Kit.GOOD))
		for c in ev.refute:
			v.add_child(_row("cross", Data.clue(c).get("title", c), Kit.BAD))
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

	func _row(kind: String, text: String, c: Color) -> Control:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var m := Kit.mark(kind, c, 28)
		m.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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
		var p := sheet(false, 0.78, 720)
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
		var p := sheet(false, 0.78, 600)
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
			["Quit to Desktop", func(): _quit()],
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

	func _quit() -> void:
		visible = false
		await Story.main.ask_quit()
		if is_inside_tree():
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
		var p := sheet(true, 0.88, 960)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 12)
		p.add_child(v)
		header(v, "SETTINGS", func(): on_back())
		var list := scroll_list(v)
		list.add_theme_constant_override("separation", 16)
		_section(list, "Sound")
		_slider(list, "Music", Settings.music_volume, func(x): Settings.music_volume = x; Audio.apply_volumes())
		_slider(list, "Ambience", Settings.ambience_volume, func(x): Settings.ambience_volume = x; Audio.apply_volumes())
		_slider(list, "Sound effects", Settings.sfx_volume, func(x):
			Settings.sfx_volume = x
			Audio.apply_volumes()
			Audio.sfx("ui_tap"))
		_section(list, "Text")
		_slider(list, "Text speed", (Settings.text_speed - 0.5) / 2.5, func(x): Settings.text_speed = 0.5 + x * 2.5)
		list.add_child(Kit.label("Text size", 25, Kit.CREAM, "serif_bold"))
		var sizes := HBoxContainer.new()
		sizes.add_theme_constant_override("separation", 10)
		list.add_child(sizes)
		var names := ["Small", "Medium", "Large"]
		var btns: Array = []
		for i in 3:
			var b := Kit.button(names[i], 76) if Settings.text_size == i else Kit.dark_button(names[i], 76)
			Kit.in_list(b)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var idx := i
			b.pressed.connect(func():
				Settings.text_size = idx
				Settings.save_settings()
				closed.emit()
				Story.main.ui.open_settings())
			sizes.add_child(b)
			btns.append(b)
		_section(list, "Display")
		var fs_toggle := _toggle(list, "Fullscreen  (F11 or Alt+Enter)", Settings.is_fullscreen(), func(on): Settings.set_fullscreen(on))
		_fs_toggle = fs_toggle
		_toggle(list, "V-Sync (smooth, tear-free motion)", Settings.vsync, func(on): Settings.set_vsync(on))
		_section(list, "Accessibility")
		_toggle(list, "Reduce motion (no shake, flashes or ripples)", Settings.reduce_motion, func(on): Settings.reduce_motion = on)
		_toggle(list, "Show sparkles on things worth examining", Settings.show_hints, func(on):
			Settings.show_hints = on
			if Story.world:
				Story.world.refresh())
		_section(list, "Controls")
		_controls(list)
		var sep := ColorRect.new()
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sep.color = Color(Kit.GOLD, 0.25)
		sep.custom_minimum_size = Vector2(0, 2)
		list.add_child(sep)
		var wipe := Kit.dark_button("Erase all saved games", 78)
		Kit.in_list(wipe)
		wipe.add_theme_color_override("font_color", Kit.BAD)
		wipe.pressed.connect(_wipe)
		list.add_child(wipe)
		list.add_child(Kit.label("UNSENT v" + Kit.version() + " for PC · Saves: " + _save_dir() + " · Made with Godot Engine. Fonts under the SIL Open Font License / Apache 2.0. All art, music and sound generated for this game.", 19, Kit.MUTED, "italic", HORIZONTAL_ALIGNMENT_CENTER))
		appear(p)

	var _fs_toggle: CheckButton

	func _process(_delta: float) -> void:
		# F11 can change fullscreen while the panel is open.
		if _fs_toggle and _fs_toggle.button_pressed != Settings.is_fullscreen():
			_fs_toggle.set_pressed_no_signal(Settings.is_fullscreen())

	func _save_dir() -> String:
		var d := ProjectSettings.globalize_path("user://")
		if OS.has_feature("windows"):
			d = d.replace("/", "\\")
		return d

	func _section(parent: Control, title: String) -> void:
		var l := Kit.label(title.to_upper(), 21, Kit.GOLD, "display")
		parent.add_child(l)

	## The keyboard and mouse controls, as a two-column reference.
	func _controls(parent: Control) -> void:
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 24)
		g.add_theme_constant_override("v_separation", 8)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(g)
		for row in [
			["Left click", "Walk · talk to people · examine things"],
			["A / D  or  ← / →", "Walk (W / S or ↑ / ↓ to step nearer or further)"],
			["E", "Talk to / examine whatever is nearest"],
			["Space · Enter · click", "Continue the conversation"],
			["1 – 9  or  ↑ ↓ + Enter", "Choose an answer"],
			["Tab  or  I", "Open / close the satchel"],
			["Mouse wheel", "Scroll letters and lists"],
			["Esc", "Back · close a panel · pause"],
			["F11  or  Alt+Enter", "Fullscreen / windowed"],
		]:
			var k := Kit.label(row[0], 22, Kit.GOLD, "serif_bold")
			k.autowrap_mode = TextServer.AUTOWRAP_OFF
			g.add_child(k)
			var d := Kit.label(row[1], 22, Kit.CREAM)
			d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(d)

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
		s.custom_minimum_size = Vector2(0, 48)
		s.focus_mode = Control.FOCUS_NONE
		s.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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

	func _toggle(parent: Control, name: String, value: bool, cb: Callable) -> CheckButton:
		var c := CheckButton.new()
		c.text = name
		c.button_pressed = value
		c.focus_mode = Control.FOCUS_NONE
		c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		c.custom_minimum_size = Vector2(0, 58)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_theme_font_size_override("font_size", Settings.font(24))
		var sb := Kit.box(Color("#232944"), 20, 1, Color(Kit.GOLD, 0.35), 0, 14)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			c.add_theme_stylebox_override(st, sb)
		c.add_theme_color_override("font_color", Kit.CREAM)
		c.add_theme_color_override("font_pressed_color", Kit.CREAM)
		c.add_theme_color_override("font_hover_color", Kit.CREAM)
		c.add_theme_color_override("font_hover_pressed_color", Kit.CREAM)
		# PC: a larger, clearer switch than the default theme's.
		var on_tex := _switch_tex(true)
		var off_tex := _switch_tex(false)
		for k in ["checked", "checked_mirrored", "checked_disabled", "checked_disabled_mirrored"]:
			c.add_theme_icon_override(k, on_tex)
		for k in ["unchecked", "unchecked_mirrored", "unchecked_disabled", "unchecked_disabled_mirrored"]:
			c.add_theme_icon_override(k, off_tex)
		c.toggled.connect(cb)
		Kit.in_list(c)
		parent.add_child(c)
		return c

	## A pill-shaped on/off switch, drawn with soft (anti-aliased) edges.
	func _switch_tex(on: bool) -> Texture2D:
		var w := 64
		var h := 34
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var track := Kit.GOLD if on else Color("#3a3f5c")
		var knob_x := float(w - h / 2) if on else float(h / 2)
		for y in h:
			for x in w:
				var p := Vector2(x + 0.5, y + 0.5)
				# distance to the pill (a segment with radius h/2)
				var cx := clampf(p.x, h * 0.5, w - h * 0.5)
				var d_track := p.distance_to(Vector2(cx, h * 0.5)) - (h * 0.5 - 1.0)
				var a_track := clampf(0.5 - d_track, 0.0, 1.0)
				var d_knob := p.distance_to(Vector2(knob_x, h * 0.5)) - (h * 0.5 - 5.0)
				var a_knob := clampf(0.5 - d_knob, 0.0, 1.0)
				var c := track.lerp(Kit.CREAM, a_knob)
				img.set_pixel(x, y, Color(c, maxf(a_track, a_knob)))
		return ImageTexture.create_from_image(img)

	func _wipe() -> void:
		visible = false
		var ok: bool = await Story.main.ui.confirm("Erase every saved game and discovered ending? This can't be undone.", "Erase", "Keep")
		visible = true
		if ok:
			GameState.wipe_all()
			Story.main.ui.toast("All saved games erased.", "fade")


class CreditsPanel extends Modal:
	signal closed

	func on_back() -> void:
		closed.emit()

	func open() -> void:
		var p := sheet(false, 0.78, 860)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		p.add_child(v)
		v.add_child(Kit.label("UNSENT", 40, Kit.CREAM, "display", HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(Kit.label("Chapter One · The Long Dusk", 24, Kit.GOLD, "italic", HORIZONTAL_ALIGNMENT_CENTER))
		var txt := "Story, design, code, art direction, music and sound: created for this game.\n\nAll environments, characters, music and sound effects are generated procedurally by the tools in this project — no stock assets.\n\nFonts: Lora, Cinzel, Caveat, Dancing Script, Patrick Hand, Gochi Hand, Kalam, Handlee (SIL Open Font License) and Special Elite (Apache 2.0).\n\nBuilt with the Godot Engine (MIT)."
		v.add_child(Kit.label(txt, 23, Kit.CREAM, "serif", HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(Kit.label("Version " + Kit.version() + " · PC edition", 20, Kit.MUTED, "italic", HORIZONTAL_ALIGNMENT_CENTER))
		var b := Kit.button("Close", 84)
		b.pressed.connect(func(): closed.emit())
		v.add_child(b)
		appear(p)


class SavePanel extends Modal:
	signal picked(slot: String)
	var mode := "save"

	func on_back() -> void:
		picked.emit("")

	func open(m: String) -> void:
		mode = m
		var p := sheet(true, 0.72, 880)
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
		var lines: Array = ["Empty"]
		if not info.is_empty():
			var night := "Lantern Night" if info.lantern else "Night %d" % info.night
			var loc: String = Data.locations.get(info.location, {}).get("name", "")
			lines = ["%s · %s" % [night, loc],
				"%d letter%s delivered · played %s" % [info.delivered, "" if info.delivered == 1 else "s", Kit.fmt_time(float(info.play_time))],
				"Saved " + _local_time(int(info.saved_at))]
		var b := TapCard.new()
		var sb := Kit.box(Color("#262c48"), 24, 2, Color(Kit.GOLD, 0.65), 4, 16)
		sb.content_margin_left = 26
		sb.content_margin_right = 22
		var sd := sb.duplicate()
		sd.bg_color = Color("#343b5e")
		b.set_styles(sb, sd)
		b.custom_minimum_size = Vector2(0, 100)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(vb)
		vb.add_child(Kit.label(title, 26, Kit.GOLD, "serif_bold"))
		for ln in lines:
			vb.add_child(Kit.label(ln, 21, Kit.CREAM, "serif"))
		if mode == "load" and info.is_empty():
			b.disabled = true
		b.pressed.connect(func(): _pick(slot, info.is_empty()))
		return b

	## Save times in the computer's own time zone.
	func _local_time(unix: int) -> String:
		if unix <= 0:
			return "—"
		var bias := int(Time.get_time_zone_from_system().get("bias", 0))
		var d := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
		var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		return "%d %s %d, %02d:%02d" % [d.day, months[clampi(d.month - 1, 0, 11)], d.year, d.hour, d.minute]

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
