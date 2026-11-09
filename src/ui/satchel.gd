extends Control
## The satchel: your letters, clue notebook, people you've met, and items.

const Kit := preload("res://src/ui/ui_kit.gd")
const Icon := preload("res://src/ui/icon.gd")
const Portrait := preload("res://src/ui/portrait.gd")
const TapCard := preload("res://src/ui/tap_card.gd")

signal closed

const TABS := [["letters", "Letters", "letter"], ["clues", "Clues", "clue"], ["people", "People", "people"], ["items", "Items", "key"]]

var _tab := "letters"
var _tab_btns: Dictionary = {}
var _list: VBoxContainer
var _scroll: ScrollContainer
var _objective: Label
var _sheet: PanelContainer
var _busy := false
var _closing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func on_back() -> void:
	if not _busy:
		_close()


func open(tab: String) -> void:
	var bd := ColorRect.new()
	bd.color = Color(0.03, 0.03, 0.07, 0.9)
	bd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bd)

	var ins := Kit.safe_insets(self)
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", Kit.box(Color("#161b30"), 28, 2, Color(Kit.GOLD, 0.45), 20, 0))
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet.offset_left = 14
	_sheet.offset_right = -14
	_sheet.offset_top = ins.x + 6
	_sheet.offset_bottom = -(ins.y + 10)
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(v)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 26)
	hm.add_theme_constant_override("margin_right", 12)
	hm.add_theme_constant_override("margin_top", 12)
	hm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hm.add_child(head)
	v.add_child(hm)
	var title := Kit.label("SATCHEL", 34, Kit.CREAM, "display")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	var close := Kit.icon_button("close", 84)
	close.pressed.connect(_close)
	head.add_child(close)

	_objective = Kit.label("", 22, Color("#e6d9bf"), "italic")
	var om := MarginContainer.new()
	om.add_theme_constant_override("margin_left", 28)
	om.add_theme_constant_override("margin_right", 28)
	om.mouse_filter = Control.MOUSE_FILTER_IGNORE
	om.add_child(_objective)
	v.add_child(om)
	_objective.text = ("Now: " + GameState.objective) if GameState.objective != "" else ""
	om.visible = _objective.text != ""

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tm := MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 16)
	tm.add_theme_constant_override("margin_right", 16)
	tm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tm.add_child(tabs)
	v.add_child(tm)
	for t in TABS:
		var b := TapCard.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 100)
		var key: String = t[0]
		b.pressed.connect(func():
			Audio.sfx("paper", -8.0)
			_show(key))
		var tv := VBoxContainer.new()
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", 2)
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tv)
		var ic := Icon.new()
		ic.kind = t[2]
		ic.color = Kit.CREAM
		ic.custom_minimum_size = Vector2(0, 48)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(ic)
		var lb := Kit.label(t[1], 20, Kit.CREAM, "serif_bold", HORIZONTAL_ALIGNMENT_CENTER)
		lb.autowrap_mode = TextServer.AUTOWRAP_OFF
		lb.clip_text = false
		tv.add_child(lb)
		tabs.add_child(b)
		_tab_btns[key] = b

	_scroll = Kit.scroller()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_left", 18)
	sm.add_theme_constant_override("margin_right", 18)
	sm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sm.add_child(_scroll)
	v.add_child(sm)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	_scroll.add_child(_list)

	# A big Close button where the thumb is.
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_left", 18)
	cm.add_theme_constant_override("margin_right", 18)
	cm.add_theme_constant_override("margin_bottom", 16)
	cm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cm)
	var cb := Kit.button("Close", 88)
	cb.pressed.connect(_close)
	cm.add_child(cb)

	_show(tab)
	modulate.a = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.22)


func _show(tab: String) -> void:
	_tab = tab
	for k in _tab_btns:
		var sel: bool = k == tab
		var sb := Kit.box(Color("#2b3253") if sel else Color("#1b2038"), 18, 2, Color(Kit.GOLD, 0.8 if sel else 0.25), 0, 6)
		var sd := sb.duplicate()
		sd.bg_color = Color("#343c62")
		_tab_btns[k].set_styles(sb, sd)
	for c in _list.get_children():
		c.queue_free()
	_scroll.scroll_vertical = 0
	match tab:
		"letters": _build_letters()
		"clues": _build_clues()
		"people": _build_people()
		"items": _build_items()


func _card(min_h := 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.box(Color("#20263f"), 18, 1, Color(Kit.GOLD, 0.25), 0, 18))
	p.custom_minimum_size = Vector2(0, min_h)
	return p


func _empty(text: String) -> void:
	var l := Kit.label(text, 25, Kit.MUTED, "italic", HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size = Vector2(0, 200)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_list.add_child(l)


# ─── Letters ─────────────────────────────────────────────────────────

func _build_letters() -> void:
	var ids := GameState.collected_letters()
	if ids.is_empty():
		_empty("No letters yet. The Chute will provide.")
		return
	var order := {"held": 0, "kept": 1, "delivered": 2, "faded": 3}
	ids.sort_custom(func(a, b): return order.get(GameState.letter_state(a), 9) < order.get(GameState.letter_state(b), 9))
	for id in ids:
		_list.add_child(_letter_card(id))


func _letter_card(id: String) -> Control:
	var Ld := Data.letter(id)
	var state := GameState.letter_state(id)
	var b := TapCard.new()
	b.set_meta("letter_id", id)
	b.custom_minimum_size = Vector2(0, 120)
	var bg := Color("#262d4a") if state == "held" else Color("#1d2238")
	var sb := Kit.box(bg, 18, 2, Color(Kit.GOLD, 0.55 if state == "held" else 0.2), 0, 16)
	var sp := sb.duplicate()
	sp.bg_color = bg.lightened(0.08)
	b.set_styles(sb, sp)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var origin := Story.letter_origin_known(id)
	var ic := Icon.new()
	ic.kind = "letter"
	ic.color = Kit.origin_color(origin) if state != "faded" else Color(Kit.MUTED, 0.5)
	ic.custom_minimum_size = Vector2(80, 80)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	var t := Kit.label(Ld.get("title", id), 26, Kit.CREAM if state != "faded" else Kit.MUTED, "serif_bold")
	v.add_child(t)
	var status := ""
	var sc := Kit.MUTED
	match state:
		"held":
			var all := Data.clues_for_letter(id)
			var n := 0
			for c in all:
				if GameState.has_clue(c):
					n += 1
			status = "Undelivered · %d of %d clues · %s" % [n, all.size(), Kit.origin_label(origin).to_lower()]
			if not GameState.is_read(id):
				status = "New — not read yet · " + status
			sc = Kit.GOLD
		"delivered":
			status = "Delivered to " + Data.char_name(GameState.letter_to(id))
			sc = Kit.GOOD
		"kept":
			status = "Kept — addressed to you" if Ld.get("auto_keep", false) else "Kept"
			sc = Kit.FUTURE
		"faded":
			status = "Faded — that future is gone"
	v.add_child(Kit.label(status, 21, sc, "italic"))
	b.pressed.connect(func(): _read(id))
	return b


func _read(id: String) -> void:
	if _busy or _closing:
		return
	_busy = true
	Audio.sfx("paper", -4.0)
	var ui = Story.main.ui
	var r := preload("res://src/ui/letter_reader.gd").new()
	ui.push_modal(r)
	r.open(id)
	Audio.duck(true)
	await r.closed
	Audio.duck(false)
	ui.pop_modal(r)
	var action: String = r.get_meta("action", "")
	_busy = false
	# If the story is about to react (a letter addressed to you, the first
	# night's lesson, or keeping a letter), get out of the way first so the
	# scene that follows is visible and can be tapped.
	if action == "keep" or Story.letter_has_hooks(id):
		# The satchel is freed as soon as it closes, so hand the follow-up to
		# the Story director (an autoload) before that happens.
		Story.after_satchel_read(id, action == "keep", self)
		_close()
		return
	Story.letter_closed(id)
	if is_inside_tree():
		_show(_tab)


# ─── Clues ───────────────────────────────────────────────────────────

func _build_clues() -> void:
	if GameState.clues.is_empty():
		_empty("No clues noted yet.\nTap underlined words in letters, examine things, and ask people questions.")
		return
	var letters := GameState.collected_letters()
	letters.sort_custom(func(a, b): return int(GameState.letter_state(a) != "held") < int(GameState.letter_state(b) != "held"))
	for lid in letters:
		var found: Array = []
		for c in GameState.clues:
			if lid in Data.clue(c).get("letters", []):
				found.append(c)
		if found.is_empty():
			continue
		var held := GameState.letter_state(lid) == "held"
		var hdr := Kit.label(Data.letter(lid).get("title", lid).to_upper(), 21, Kit.GOLD if held else Kit.MUTED, "display")
		_list.add_child(hdr)
		for c in found:
			var card := _card()
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 4)
			card.add_child(v)
			v.add_child(Kit.label(Data.clue(c).get("title", c), 25, Kit.CREAM, "serif_bold"))
			v.add_child(Kit.label(Data.clue(c).get("note", ""), 22, Color("#cfc5b2"), "serif"))
			if not held:
				card.modulate.a = 0.6
			_list.add_child(card)


# ─── People ──────────────────────────────────────────────────────────

func _build_people() -> void:
	var any := false
	for id in ["odile", "mari", "felix", "bram", "june", "tobias", "theo"]:
		if not Story.f("met_" + id) and not (id == "theo" and Story.f("theo_home")):
			continue
		any = true
		var C: Dictionary = Data.characters[id]
		var card := _card(150)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		card.add_child(h)
		var p := Portrait.new()
		p.custom_minimum_size = Vector2(112, 112)
		p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(p)
		p.ready.connect(func(): p.show_char(id, "neutral", false))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 4)
		h.add_child(v)
		v.add_child(Kit.label(C.name, 27, Data.char_color(id), "serif_bold"))
		v.add_child(Kit.label(C.role, 21, Kit.MUTED, "italic"))
		v.add_child(Kit.label(C.get("bio", ""), 22, Color("#d7cdb9")))
		for n in C.get("notes", []):
			if Story.eval(n.get("if", "")):
				v.add_child(Kit.label("• " + n.text, 22, Kit.CREAM))
		_list.add_child(card)
	if not any:
		_empty("You haven't met anyone yet.")


# ─── Items ───────────────────────────────────────────────────────────

func _build_items() -> void:
	if GameState.items.is_empty():
		_empty("Your pockets are empty, apart from a pencil stub and some dusk.")
		return
	for iid in GameState.items:
		var I: Dictionary = Data.items.get(iid, {})
		var card := _card(120)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		card.add_child(h)
		var ic := Icon.new()
		ic.kind = I.get("icon", "item")
		ic.color = Kit.GOLD
		ic.custom_minimum_size = Vector2(84, 84)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(ic)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(Kit.label(I.get("name", iid), 26, Kit.CREAM, "serif_bold"))
		v.add_child(Kit.label(I.get("text", ""), 22, Color("#d7cdb9")))
		_list.add_child(card)


func _close() -> void:
	if _closing:
		return
	_closing = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.16)
	await get_tree().create_timer(0.17, true, false, true).timeout
	closed.emit()
