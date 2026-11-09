extends Control
## Full-screen letter reader. The letter is shown in its writer's hand on its
## own paper. Underlined phrases hide clues — tap them to note them. The
## envelope can be turned over for physical evidence (postmarks, ink, paper).
## Below, the "Who is it for?" board shows what the evidence points to.

const Kit := preload("res://src/ui/ui_kit.gd")
const Icon := preload("res://src/ui/icon.gd")
const TapCard := preload("res://src/ui/tap_card.gd")

signal closed

const PAPER_COLORS := {
	"hotel": "#f3ead8", "fine": "#f5ecdc", "airmail": "#edf2f6", "logbook": "#efe6d0",
	"ticket": "#f1e0c0", "typed": "#f6f3ec", "kraft": "#cfae80", "silver": "#e8edf4",
}

## The paper textures are drawn for this width (see tools/art/ui_art.py).
const PAPER_MAX_W := 660.0

var letter_id := ""
var L: Dictionary = {}
var _backdrop: ColorRect
var _scroll: ScrollContainer
var _content: VBoxContainer
var _sheet: PanelContainer
var _front: VBoxContainer
var _back: VBoxContainer
var _body: RichTextLabel
var _sig: RichTextLabel
var _flip_btn: Button
var _close_btn: Button
var _x_btn: Button
var _counter: Label
var _origin: Label
var _leads_box: VBoxContainer
var _frame: MarginContainer
var _showing_back := false
var _flipping := false
var _closing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Closing must work no matter what else is going on.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_apply_safe_area)


func on_back() -> void:
	_close()


func open(id: String) -> void:
	letter_id = id
	L = Data.letter(id)
	GameState.mark_read(id)
	Audio.sfx("letter_open")

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.03, 0.03, 0.07, 0.88)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	# Everything lives in one column inside the safe area: header, the
	# scrolling letter, and a bottom bar with big thumb-sized buttons.
	_frame = MarginContainer.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(88, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(titles)
	var title := Kit.label(L.get("title", ""), 29, Kit.CREAM, "display", HORIZONTAL_ALIGNMENT_CENTER)
	titles.add_child(title)
	_origin = Kit.label("", 21, Kit.MUTED, "italic", HORIZONTAL_ALIGNMENT_CENTER)
	titles.add_child(_origin)
	_counter = Kit.label("", 20, Kit.GOLD, "serif_bold", HORIZONTAL_ALIGNMENT_CENTER)
	titles.add_child(_counter)
	_x_btn = Kit.icon_button("close", 88)
	_x_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_x_btn.pressed.connect(_close)
	head.add_child(_x_btn)

	_scroll = Kit.scroller()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 26)
	_scroll.add_child(_content)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(margin)
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", _paper_style())
	# Never wider than the paper itself: on wide screens the sheet is centred
	# instead of stretched (which would distort the printed letterheads).
	_sheet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sheet.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(_sheet)

	_build_front()
	_build_back()
	_back.visible = false

	var lm := MarginContainer.new()
	lm.add_theme_constant_override("margin_left", 26)
	lm.add_theme_constant_override("margin_right", 26)
	_content.add_child(lm)
	_leads_box = VBoxContainer.new()
	_leads_box.add_theme_constant_override("separation", 10)
	lm.add_child(_leads_box)
	var pad := Control.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.custom_minimum_size = Vector2(0, 24)
	_content.add_child(pad)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_left", 22)
	bm.add_theme_constant_override("margin_right", 22)
	bm.add_child(bottom)
	col.add_child(bm)
	_flip_btn = Kit.dark_button("Turn over", 92)
	_flip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flip_btn.size_flags_stretch_ratio = 1.0
	_flip_btn.pressed.connect(_flip)
	bottom.add_child(_flip_btn)
	_close_btn = Kit.button("Close", 92)
	_close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_btn.size_flags_stretch_ratio = 1.0
	_close_btn.pressed.connect(_close)
	bottom.add_child(_close_btn)

	_apply_safe_area()
	_refresh()
	modulate.a = 0.0
	_sheet.scale = Vector2(0.96, 0.96)
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.22)
	t.tween_property(_sheet, "scale", Vector2.ONE, 0.32)
	await get_tree().process_frame
	if is_instance_valid(_sheet):
		_sheet.pivot_offset = _sheet.size * 0.5


func _apply_safe_area() -> void:
	if _frame == null or _sheet == null or not is_inside_tree():
		return
	var vw := get_viewport_rect().size.x
	_sheet.custom_minimum_size.x = minf(vw - 24.0 - 44.0, PAPER_MAX_W)
	var ins := Kit.safe_insets(self)
	_frame.add_theme_constant_override("margin_top", int(ins.x) + 10)
	_frame.add_theme_constant_override("margin_bottom", int(ins.y) + 18)
	_frame.add_theme_constant_override("margin_left", 12)
	_frame.add_theme_constant_override("margin_right", 12)


func _paper_style() -> StyleBox:
	var paper: String = L.get("paper", "fine")
	var p := "res://assets/art/ui/paper_%s.png" % paper
	if ResourceLoader.exists(p):
		var s := StyleBoxTexture.new()
		s.texture = load(p)
		var header: bool = paper in ["hotel", "logbook", "ticket"]
		s.texture_margin_left = 60
		s.texture_margin_right = 60
		s.texture_margin_top = 130 if header else 90
		s.texture_margin_bottom = 60
		s.content_margin_left = 46
		s.content_margin_right = 42
		s.content_margin_top = 118 if header else (64 if paper == "airmail" else 44)
		s.content_margin_bottom = 44
		return s
	var b := Kit.box(Color(PAPER_COLORS.get(paper, "#f3ead8")), 6, 0, Kit.GOLD, 14, 40)
	return b


func _ink() -> Color:
	return Color(L.get("ink", "#26314d"))


func _hand() -> String:
	return L.get("font", "caveat")


func _build_front() -> void:
	_front = VBoxContainer.new()
	_front.add_theme_constant_override("separation", 18)
	_sheet.add_child(_front)
	var hand := _hand()
	var hsize: int = Kit.HAND_SIZE.get(hand, 30)
	if L.get("date", "") != "":
		var d := Kit.label(L.date, int(hsize * 0.8), _ink(), hand, HORIZONTAL_ALIGNMENT_RIGHT)
		_front.add_child(d)
	_body = _hand_rich(hsize)
	_body.meta_clicked.connect(_on_meta)
	_front.add_child(_body)
	_sig = _hand_rich(hsize)
	_sig.meta_clicked.connect(_on_meta)
	_front.add_child(_sig)
	var state := GameState.letter_state(letter_id)
	if state == "faded":
		_front.modulate.a = 0.22
	if state in ["delivered", "kept"] or state == "faded":
		var stamp := Kit.label(_stamp_text(), 26, Kit.WAX, "display", HORIZONTAL_ALIGNMENT_CENTER)
		stamp.rotation = -0.08
		_front.add_child(stamp)


func _stamp_text() -> String:
	var state := GameState.letter_state(letter_id)
	match state:
		"delivered":
			return "— DELIVERED TO %s —" % Data.char_name(GameState.letter_to(letter_id)).to_upper()
		"kept":
			return "— KEPT —"
		"faded":
			return "— THIS FUTURE NO LONGER EXISTS —"
	return ""


func _hand_rich(size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.selection_enabled = false
	r.meta_underlined = true
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	var f := Kit.font(_hand())
	for k in ["normal_font", "italics_font", "bold_font", "bold_italics_font"]:
		r.add_theme_font_override(k, f)
	for k in ["normal_font_size", "italics_font_size", "bold_font_size", "bold_italics_font_size"]:
		r.add_theme_font_size_override(k, Settings.font(size))
	r.add_theme_color_override("default_color", _ink())
	r.add_theme_constant_override("line_separation", 4)
	return r


func _build_back() -> void:
	_back = VBoxContainer.new()
	_back.add_theme_constant_override("separation", 18)
	_sheet.add_child(_back)
	var env: Dictionary = L.get("envelope", {})
	var head := Kit.label("THE ENVELOPE", 22, Color(_ink(), 0.7), "display", HORIZONTAL_ALIGNMENT_CENTER)
	_back.add_child(head)
	var front := Kit.label(env.get("front", ""), 27, _ink(), "italic", HORIZONTAL_ALIGNMENT_CENTER)
	_back.add_child(front)
	var sep := ColorRect.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.color = Color(_ink(), 0.25)
	sep.custom_minimum_size = Vector2(0, 2)
	_back.add_child(sep)
	for d in env.get("details", []):
		_back.add_child(_detail_chip(d))
	var hint := Kit.label("Tap anything that might matter.", 21, Color(_ink(), 0.55), "italic", HORIZONTAL_ALIGNMENT_CENTER)
	_back.add_child(hint)


func _detail_chip(d: Dictionary) -> Control:
	var cid: String = d.get("clue", "")
	var found := cid != "" and GameState.has_clue(cid)
	var card := TapCard.new()
	var sb := Kit.box(Color(1, 1, 1, 0.35) if not found else Color("#f0d68a"), 14, 2, Color(_ink(), 0.35), 0, 14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	var sd := sb.duplicate()
	sd.bg_color = Color(1, 1, 1, 0.55) if not found else Color("#f5e0a0")
	card.set_styles(sb, sd)
	card.custom_minimum_size = Vector2(0, 88)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	v.add_child(Kit.label(String(d.get("label", "")).to_upper(), 18, Color(_ink(), 0.6), "display"))
	v.add_child(Kit.label(d.get("text", ""), 25, _ink(), "serif"))
	card.pressed.connect(func():
		if cid != "" and not GameState.has_clue(cid):
			Story._give_clue(cid)
			_refresh()
			_rebuild_back()
		else:
			Audio.sfx("paper", -6.0))
	return card


func _rebuild_back() -> void:
	var was := _back.visible
	_back.queue_free()
	_build_back()
	_back.visible = was


func _markup(text: String) -> String:
	var out := ""
	var i := 0
	while i < text.length():
		var s := text.find("[[", i)
		if s < 0:
			out += text.substr(i)
			break
		out += text.substr(i, s - i)
		var e := text.find("]]", s)
		if e < 0:
			out += text.substr(s)
			break
		var inner := text.substr(s + 2, e - s - 2)
		var bar := inner.rfind("|")
		var phrase := inner.substr(0, bar) if bar >= 0 else inner
		var cid := inner.substr(bar + 1) if bar >= 0 else ""
		if cid != "" and GameState.has_clue(cid):
			out += "[bgcolor=#e9c25e66]%s[/bgcolor]" % phrase
		elif cid != "":
			out += "[url=%s]%s[/url]" % [cid, phrase]
		else:
			out += phrase
		i = e + 2
	return out


func _refresh() -> void:
	_body.text = _markup(L.get("body", ""))
	_sig.text = "[right]" + _markup(L.get("signature", "")).replace("\n", "\n") + "[/right]"
	var origin := Story.letter_origin_known(letter_id)
	_origin.text = Kit.origin_label(origin)
	_origin.add_theme_color_override("font_color", Kit.origin_color(origin))
	var all := Data.clues_for_letter(letter_id)
	var found := 0
	for c in all:
		if GameState.has_clue(c):
			found += 1
	_counter.text = "Clues  %d / %d" % [found, all.size()] if all.size() > 0 else "No clues"
	_refresh_leads()


func _refresh_leads() -> void:
	for c in _leads_box.get_children():
		c.queue_free()
	if L.get("auto_keep", false):
		return
	var state := GameState.letter_state(letter_id)
	var head := Kit.label("WHO IS IT FOR?", 22, Kit.GOLD, "display")
	_leads_box.add_child(head)
	if state != "held":
		_leads_box.add_child(Kit.label(_resolved_text(state), 24, Kit.MUTED, "italic"))
		return
	var leads := Story.leads(letter_id)
	if leads.is_empty():
		_leads_box.add_child(Kit.label("No leads yet. Tap underlined words, turn the envelope over, then ask around town.", 24, Kit.MUTED, "italic"))
		return
	var need := int(L.get("min_evidence", 2))
	for ld in leads:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", Kit.box(Color(0.1, 0.12, 0.21, 0.92), 16, 1, Color(Kit.GOLD, 0.3), 0, 14))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var nm := Kit.label("You" if ld.who == "wren" else Data.char_name(ld.who), 25, Data.char_color(ld.who) if ld.who != "memorial" else Kit.CREAM, "serif_bold")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		var marks := HBoxContainer.new()
		marks.add_theme_constant_override("separation", 6)
		marks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(marks)
		for i in maxi(need, ld.support):
			marks.add_child(Kit.mark("dot" if i < ld.support else "ring", Kit.GOLD, 20))
		if ld.refute > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(6, 0)
			marks.add_child(gap)
			marks.add_child(Kit.mark("cross", Kit.BAD, 20))
			var n := Kit.label(str(ld.refute), 22, Kit.BAD, "serif_bold")
			n.autowrap_mode = TextServer.AUTOWRAP_OFF
			n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			marks.add_child(n)
		if ld.ready:
			marks.add_child(Kit.mark("check", Kit.GOOD, 26))
		_leads_box.add_child(row)
	# Legend, as a flowing row: it wraps instead of running off the edge.
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 18)
	legend.add_theme_constant_override("v_separation", 4)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for it in [["dot", Kit.GOLD, "supporting clue"], ["cross", Kit.BAD, "contradicting clue"], ["check", Kit.GOOD, "enough to deliver"]]:
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 6)
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_child(Kit.mark(it[0], it[1], 18))
		var tl := Kit.label(it[2], 19, Kit.MUTED, "italic")
		tl.autowrap_mode = TextServer.AUTOWRAP_OFF
		pair.add_child(tl)
		legend.add_child(pair)
	_leads_box.add_child(legend)
	_leads_box.add_child(Kit.label("To deliver, find the person and choose \"Deliver a letter…\" when you talk to them.", 20, Kit.MUTED, "italic"))
	if "wren" in L.get("candidates", []) and Story.can_deliver(letter_id, "wren") and not Story.busy:
		var keep := Kit.dark_button("Keep it — I think this one is mine", 80)
		Kit.in_list(keep)
		keep.pressed.connect(func():
			set_meta("action", "keep")
			_close())
		_leads_box.add_child(keep)


func _resolved_text(state: String) -> String:
	match state:
		"delivered":
			return "Delivered to %s." % Data.char_name(GameState.letter_to(letter_id))
		"kept":
			return "You kept this one."
		"faded":
			return "The ink has faded away. The future that wrote it will never happen now."
	return ""


func _on_meta(meta: Variant) -> void:
	var cid := str(meta)
	if GameState.has_clue(cid):
		return
	var scroll := _scroll.scroll_vertical
	Story._give_clue(cid)
	_refresh()
	await get_tree().process_frame
	_scroll.scroll_vertical = scroll


func _flip() -> void:
	if _flipping:
		return
	_flipping = true
	Audio.sfx("paper")
	_sheet.pivot_offset = Vector2(_sheet.size.x * 0.5, 0)
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(_sheet, "scale:x", 0.0, 0.16)
	await t.finished
	_showing_back = not _showing_back
	_front.visible = not _showing_back
	_back.visible = _showing_back
	_flip_btn.text = "Read the letter" if _showing_back else "Turn over"
	var t2 := create_tween().set_trans(Tween.TRANS_SINE)
	t2.tween_property(_sheet, "scale:x", 1.0, 0.18)
	await t2.finished
	_flipping = false


func _close() -> void:
	if _closing:
		return
	_closing = true
	Audio.sfx("letter_fold", -2.0)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.16)
	# A timer that runs even if the tree were paused: the letter ALWAYS closes.
	await get_tree().create_timer(0.17, true, false, true).timeout
	closed.emit()
