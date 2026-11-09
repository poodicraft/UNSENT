extends Node
## Text-fit audit. Builds every screen of the game with the longest real
## content (all letters, all clues, every consequence and ending text, the
## longest dialogue lines and choices) at every text size and several screen
## shapes (PC: 16:9, 16:10, 21:9, 4:3), and checks mechanically that every
## piece of text:
##   • is entirely on screen (or inside a scrolling list),
##   • lies inside the panel / card / button that frames it,
##   • is not cut off (no hidden lines, nothing wider than its box),
##   • does not overlap another piece of text or a button.
##   xvfb-run -s "-screen 0 2600x1600x24" godot --path . --windowed --resolution 1920x1080 -- --test=ui_audit
## Add --shots to also save screenshots to build/shots/audit_*.png.

const Kit := preload("res://src/ui/ui_kit.gd")
const Panels := preload("res://src/ui/panels.gd")
const LetterReader := preload("res://src/ui/letter_reader.gd")
const Satchel := preload("res://src/ui/satchel.gd")
const EndingScreen := preload("res://src/ui/ending_screen.gd")
const TitleScreen := preload("res://src/ui/title_screen.gd")

## PC screen shapes: 16:9, 16:10, 21:9 ultra-wide and 4:3.
const SIZES := [Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(2560, 1080), Vector2i(1440, 1080)]

var main: Node
var ui: Node
var failures: Array = []
var checked := 0
var screens := 0
var shots := false
var _cfg := ""
var _seen: Dictionary = {}


func _ready() -> void:
	main = get_parent()
	ui = main.ui
	shots = "--shots" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	await get_tree().process_frame
	var only_size := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			only_size = int(a.substr(7))
	for si in SIZES.size():
		if only_size >= 0 and si != only_size:
			continue
		get_window().size = SIZES[si]
		for i in 6:
			await get_tree().process_frame
		for ts in [0, 1, 2]:
			Settings.text_size = ts
			_cfg = "%dx%d text%d" % [SIZES[si].x, SIZES[si].y, ts]
			print("── ", _cfg, " (viewport ", get_viewport().get_visible_rect().size, ")")
			await _all_screens()
	print("UIAUDIT: %d screens, %d text items checked, %d problem(s)" % [screens, checked, failures.size()])
	var shown := 0
	for f in failures:
		if shown < 80:
			print("  PROBLEM: ", f)
		shown += 1
	get_tree().quit(1 if failures.size() > 0 else 0)


func fail(msg: String) -> void:
	var key := msg.get_slice(" @", 0)
	if _seen.has(key):
		return
	_seen[key] = true
	failures.append("[%s] %s" % [_cfg, msg])


# ═══════════════════════════════════════════════════════════════════
#  The checks
# ═══════════════════════════════════════════════════════════════════

func _texty(c: Control) -> bool:
	if c is Label:
		return c.text.strip_edges() != ""
	if c is RichTextLabel:
		return c.get_parsed_text().strip_edges() != ""
	if c is Button:
		return true
	return false


func _collect(n: Node, out: Array) -> void:
	if n is CanvasItem and not n.visible:
		return
	if n is Control:
		var c: Control = n
		if c.modulate.a > 0.02 and (_texty(c) or c is PanelContainer):
			out.append(c)
	for k in n.get_children():
		_collect(k, out)


func _scroller_of(c: Node) -> ScrollContainer:
	var p := c.get_parent()
	while p:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


func _frame_of(c: Control) -> Control:
	var p := c.get_parent()
	while p and p is Control:
		var pc: Control = p
		if pc is ScrollContainer:
			return null
		if pc is Button or pc is PanelContainer or pc is Panel:
			if not pc.get_global_rect().size.is_equal_approx(get_viewport().get_visible_rect().size):
				return pc
		p = p.get_parent()
	return null


func _name(c: Control) -> String:
	var t := ""
	if c is Label or c is Button:
		t = c.text
	elif c is RichTextLabel:
		t = c.get_parsed_text()
	t = t.replace("\n", " ").strip_edges()
	if t.length() > 46:
		t = t.substr(0, 46) + "…"
	return "%s \"%s\"" % [c.get_class(), t]


func _is_ancestor(a: Node, b: Node) -> bool:
	return a.is_ancestor_of(b)


func audit(root: Node, what: String) -> void:
	screens += 1
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var vr := get_viewport().get_visible_rect().grow(1.0)
	var items: Array = []
	_collect(root, items)
	var texts: Array = []
	for c in items:
		var r: Rect2 = c.get_global_rect()
		var sc := _scroller_of(c)
		var where := "%s: %s @%s" % [what, _name(c), r]
		checked += 1
		if sc:
			var sr := sc.get_global_rect().grow(1.0)
			if r.position.x < sr.position.x or r.end.x > sr.end.x:
				fail("%s sticks out of its list sideways" % where)
		elif not vr.encloses(r):
			fail("%s goes off the screen" % where)
		var fr := _frame_of(c)
		if fr and not fr.get_global_rect().grow(1.0).encloses(r):
			fail("%s spills out of its frame %s" % [where, _name(fr)])
		if c is Label:
			var l: Label = c
			if l.get_visible_line_count() < l.get_line_count():
				fail("%s has hidden lines (%d of %d shown)" % [where, l.get_visible_line_count(), l.get_line_count()])
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF and not l.clip_text:
				var f := l.get_theme_font("font")
				var fs := l.get_theme_font_size("font_size")
				for line in l.text.split("\n"):
					var w := f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
					if w > l.size.x + 1.5:
						fail("%s is wider than its box (%d > %d)" % [where, w, l.size.x])
			if l.get_minimum_size().y > l.size.y + 1.5:
				fail("%s is taller than its box" % where)
		elif c is RichTextLabel:
			var rt: RichTextLabel = c
			if rt.get_content_height() > rt.size.y + 2.0:
				fail("%s text is taller than its box (%d > %d)" % [where, rt.get_content_height(), rt.size.y])
			if rt.get_content_width() > rt.size.x + 2.0:
				fail("%s text is wider than its box" % where)
		elif c is Button:
			var b: Button = c
			var ms := b.get_minimum_size()
			if ms.x > b.size.x + 1.5 or ms.y > b.size.y + 1.5:
				fail("%s is too small for its text (%s > %s)" % [where, ms, b.size])
			if b.text != "" and b.autowrap_mode == TextServer.AUTOWRAP_OFF and not b.clip_text:
				var f2 := b.get_theme_font("font")
				var fs2 := b.get_theme_font_size("font_size")
				var w2 := f2.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
				var sb := b.get_theme_stylebox("normal")
				var pad := sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb else 0.0
				if w2 + pad > b.size.x + 1.5:
					fail("%s text is wider than the button" % where)
		if not (c is PanelContainer):
			if sc == null or sc.get_global_rect().intersects(r):
				texts.append(c)
	# Overlaps between texts/buttons that aren't nested in each other.
	for i in texts.size():
		for j in range(i + 1, texts.size()):
			var a: Control = texts[i]
			var b2: Control = texts[j]
			if a.is_ancestor_of(b2) or b2.is_ancestor_of(a):
				continue
			var ra: Rect2 = a.get_global_rect()
			var rb: Rect2 = b2.get_global_rect()
			var sa := _scroller_of(a)
			var sb2 := _scroller_of(b2)
			if sa:
				ra = ra.intersection(sa.get_global_rect())
			if sb2:
				rb = rb.intersection(sb2.get_global_rect())
			var x := ra.intersection(rb)
			if x.size.x > 2.0 and x.size.y > 2.0:
				fail("%s: %s overlaps %s" % [what, _name(a), _name(b2)])
	if shots and Settings.text_size == 2:
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://build/shots/audit_%s_%s.png" % [_cfg.replace(" ", "_"), what.replace(" ", "_").replace("/", "-")])


# ═══════════════════════════════════════════════════════════════════
#  A world full of content
# ═══════════════════════════════════════════════════════════════════

func _rich_state(all_held: bool) -> void:
	GameState.new_game()
	GameState.in_game = true
	for id in Data.letter_order:
		GameState.arrive(id)
	GameState.collect_chute()
	for id in Data.letter_order:
		GameState.mark_read(id)
	if not all_held:
		var states := ["held", "delivered", "kept", "faded"]
		var i := 0
		for id in Data.letter_order:
			var st: String = states[i % 4]
			i += 1
			if st == "delivered":
				var cands: Array = Data.letter(id).get("candidates", ["odile"])
				GameState.mark_delivered(id, cands[cands.size() - 1])
			elif st == "kept":
				GameState.mark_delivered(id, "wren")
			elif st == "faded":
				GameState.fade_letter(id)
	for cid in Data.clues:
		GameState.add_clue(cid)
	for npc in ["odile", "mari", "felix", "bram", "june", "tobias"]:
		GameState.set_flag("met_" + npc, true)
	for f in ["tobias_knows", "theo_home", "reply_posted", "bakery_lamp_lit", "clock_running", "june_mum", "read_ps_1140"]:
		GameState.set_flag(f, true)
	for iid in Data.items:
		GameState.add_item(iid)
	GameState.set_objective("The night's work is done. Return to Odile when you're ready to sleep — or keep exploring.")


func _longest_lines(n: int) -> Array:
	var all: Array = []
	for node in Data.dialogue:
		for ins in Data.dialogue[node]:
			if ins.t == "line":
				all.append([ins.who, ins.get("expr", "neutral"), ins.text])
	all.sort_custom(func(a, b): return a[2].length() > b[2].length())
	var out: Array = all.slice(0, n)
	# also the longest line of each speaker (name plates differ)
	var per: Dictionary = {}
	for l in all:
		if not per.has(l[0]):
			per[l[0]] = l
	for k in per:
		out.append(per[k])
	return out


func _biggest_choices(n: int) -> Array:
	var all: Array = []
	for node in Data.dialogue:
		for ins in Data.dialogue[node]:
			if ins.t == "choice":
				var texts: Array = []
				var total := 0
				for o in ins.options:
					texts.append(o.text)
					total += o.text.length()
				all.append([total, texts])
	all.sort_custom(func(a, b): return a[0] > b[0])
	var out: Array = []
	for x in all.slice(0, n):
		out.append(x[1])
	return out


func _consequences() -> Array:
	var out: Array = []
	for node in Data.dialogue:
		for ins in Data.dialogue[node]:
			if ins.t == "cmd" and ins.cmd in ["consequence", "card"]:
				out.append([ins.cmd, ins.args[0] if ins.args.size() > 0 else "", ins.args[1] if ins.args.size() > 1 else ""])
	return out


# ═══════════════════════════════════════════════════════════════════
#  Screens
# ═══════════════════════════════════════════════════════════════════

func _all_screens() -> void:
	_rich_state(false)
	main.test_mode = true
	await main.goto_location("post_office", "default", false, false)
	ui.set_world_ui(true)
	ui.hud._on_objective(GameState.objective)

	# HUD with a long objective and the location banner
	ui.hud.show_location("Hushwater Harbour")
	await audit(ui.hud, "hud")

	# Title screen (with saves → every button) and credits
	GameState.save_game("1")
	var t := TitleScreen.new()
	ui.screens.add_child(t)
	t.modulate.a = 1.0
	await audit(t, "title")
	var credits := Panels.CreditsPanel.new()
	ui.push_modal(credits)
	credits.open()
	await audit(credits, "credits")
	ui.pop_modal(credits)
	t.queue_free()
	GameState.delete_save("1")

	# Dialogue: the longest lines and the biggest choice sets
	var dlg = ui.dialogue
	for l in _longest_lines(8):
		dlg.say(l[0], l[1], l[2])
		dlg._finish_typing()
		await audit(dlg, "dialogue line (%s)" % l[0])
		dlg.advanced.emit()
	for opts in _biggest_choices(6):
		dlg.say("odile", "neutral", "Well?")
		dlg._finish_typing()
		dlg.advanced.emit()
		dlg.choose(opts)
		await get_tree().process_frame
		await audit(dlg, "dialogue choices")
		dlg.chose.emit(0)
	dlg.choose(["Ask about…", "Deliver a letter…", "Goodbye"], true)
	await audit(dlg, "conversation hub")
	dlg.chose.emit(2)
	dlg.close()
	await get_tree().create_timer(0.3).timeout

	# Letter reader: every letter, front and back, with every clue found,
	# and once more with none found (underlined links instead).
	for pass_i in 2:
		_rich_state(true)
		if pass_i == 1:
			GameState.clues.clear()
		for id in Data.letter_order:
			var r := LetterReader.new()
			ui.push_modal(r)
			r.open(id)
			r.modulate.a = 1.0
			await audit(r, "letter %s%s" % [id, " (no clues)" if pass_i == 1 else ""])
			r._flip()
			await get_tree().create_timer(0.45).timeout
			await audit(r, "envelope %s%s" % [id, " (no clues)" if pass_i == 1 else ""])
			ui.pop_modal(r)

	# Satchel: all four tabs, full of mixed content
	_rich_state(false)
	var s := Satchel.new()
	ui.push_modal(s)
	s.open("letters")
	s.modulate.a = 1.0
	for tab in ["letters", "clues", "people", "items"]:
		s._show(tab)
		await audit(s, "satchel %s" % tab)
		# scroll to the end too
		s._scroll.scroll_vertical = 100000
		await audit(s, "satchel %s (end)" % tab)
	ui.pop_modal(s)

	# Conversation panels
	_rich_state(true)
	for npc in ["mari", "tobias", "june"]:
		var ap := Panels.AskPanel.new()
		ui.push_modal(ap)
		ap.open(npc)
		ap.modulate.a = 1.0
		await audit(ap, "ask %s" % npc)
		ui.pop_modal(ap)
	var lp := Panels.LetterPicker.new()
	ui.push_modal(lp)
	lp.open("felix")
	lp.modulate.a = 1.0
	await audit(lp, "letter picker")
	ui.pop_modal(lp)
	for id in Data.letter_order:
		for who in Data.letter(id).get("candidates", []):
			var cd := Panels.ConfirmDelivery.new()
			ui.push_modal(cd)
			cd.open(id, who)
			cd.modulate.a = 1.0
			await audit(cd, "confirm %s -> %s" % [id, who])
			ui.pop_modal(cd)
	var cb := Panels.ConfirmBox.new()
	ui.push_modal(cb)
	cb.open("Erase every saved game and discovered ending? This can't be undone.", "Erase", "Keep")
	cb.modulate.a = 1.0
	await audit(cb, "confirm box")
	ui.pop_modal(cb)

	# Menus
	var pm := Panels.PauseMenu.new()
	ui.push_modal(pm)
	pm.open()
	pm.modulate.a = 1.0
	await audit(pm, "pause menu")
	ui.pop_modal(pm)
	var sp := Panels.SettingsPanel.new()
	ui.push_modal(sp)
	sp.open()
	sp.modulate.a = 1.0
	await audit(sp, "settings")
	ui.pop_modal(sp)
	for slot in ["1", "2", "3"]:
		GameState.save_game(slot)
	for mode in ["save", "load"]:
		var sv := Panels.SavePanel.new()
		ui.push_modal(sv)
		sv.open(mode)
		sv.modulate.a = 1.0
		await audit(sv, "saves %s" % mode)
		ui.pop_modal(sv)
	for slot in ["1", "2", "3"]:
		GameState.delete_save(slot)

	# Cards: every night card and every consequence in the game
	var oroot: Control = ui.overlay.get_child(0)
	for c in _consequences():
		var card: Control
		if c[0] == "consequence":
			card = Panels.ConsequenceCard.new()
			card.setup(c[1], c[2])
		else:
			card = Panels.TitleCard.new()
			card.setup(c[1], c[2], false)
		oroot.add_child(card)
		card.modulate.a = 1.0
		await audit(card, "%s card \"%s\"" % [c[0], c[1]])
		card.queue_free()
	for n in Story.NIGHT_CARDS:
		var tc := Panels.TitleCard.new()
		tc.setup(Story.NIGHT_CARDS[n][0], Story.NIGHT_CARDS[n][1], true)
		oroot.add_child(tc)
		tc.modulate.a = 1.0
		await audit(tc, "night card %d" % n)
		tc.queue_free()
	for who in ["mari", "memorial", "wren", "tobias"]:
		var st := Panels.DeliveredStamp.new()
		st.setup("blue_door", who)
		oroot.add_child(st)
		st.modulate.a = 1.0
		await audit(st, "stamp %s" % who)
		st.queue_free()

	# Toasts (the longest clue title)
	var longest := ""
	for cid in Data.clues:
		var tt: String = Data.clue(cid).get("title", "")
		if tt.length() > longest.length():
			longest = tt
	ui.toast("Clue noted — " + longest, "clue")
	ui.toast("The Chute is ringing at the post office.", "chute")
	await get_tree().create_timer(0.4).timeout
	await audit(ui._toasts, "toasts")

	# Ending: every fate text, then every end card
	await _endings()

	# World name tags at every object in every place
	await _world_tags()
	main.test_mode = false


func _endings() -> void:
	var texts: Array = []
	# Gather fate texts under several world states
	var combos := [
		{"theo_home": true, "reunited": true, "lamp_lit": true, "june_path": "stay"},
		{"reply_posted": true, "odile_burned": true, "june_path": "leave", "june_mum": true},
		{"bakery_lamp_lit": true, "june_path": "", "june_mum": true},
		{"june_path": "", "reunited": true},
	]
	for cmb in combos:
		_rich_state(false)
		for f in ["theo_home", "reunited", "lamp_lit", "reply_posted", "odile_burned", "bakery_lamp_lit", "june_mum"]:
			GameState.flags.erase(f)
		for k in cmb:
			GameState.set_flag(k, cmb[k])
		for fate in Story.fates():
			texts.append(fate)
	var e := EndingScreen.new()
	ui.screens.add_child(e)
	e._bg = ColorRect.new()
	e.add_child(e._bg)
	var done := {}
	for fate in texts:
		if done.has(fate.text):
			continue
		done[fate.text] = true
		e._fate_card(fate)
		await get_tree().create_timer(1.0).timeout
		await audit(e, "fate %s" % fate.who)
		e._tap = true
		await get_tree().create_timer(0.9).timeout
	for id in Data.endings:
		var E: Dictionary = Data.endings[id]
		e.ending_id = id
		e._end_card(E)
		await get_tree().create_timer(1.4).timeout
		await audit(e, "end card %s" % id)
		for c in e.get_children():
			if c is VBoxContainer:
				c.queue_free()
		await get_tree().process_frame
	e.queue_free()


func _world_tags() -> void:
	for loc in Data.locations:
		await main.goto_location(loc, "default", false, false)
		var w = main.world
		var vr := get_viewport().get_visible_rect()
		# Walk the player along the whole place: shown tags never overlap.
		var x := 40.0
		while x < float(w.width):
			w.player.position = w.clamp_to_band(Vector2(x, 1000))
			w.camera_follow()
			w._update_camera(0.0, true)
			w._layout_tags()
			await get_tree().process_frame
			var shown: Array = []
			for nid in w.npcs:
				var a = w.npcs[nid]
				if a.show_label:
					shown.append([a.id, a.tag_screen_rect()])
			for hid in w.hotspots:
				var h = w.hotspots[hid]
				if h.visible and h.tag_ok and (h.near or h.is_exit()):
					var r: Rect2 = h.tag_screen_rect()
					if vr.intersects(r):
						shown.append([hid, r])
			for i in shown.size():
				checked += 1
				if not vr.grow(1.0).encloses(shown[i][1]):
					fail("world tag %s in %s is cut off by the screen edge @%s" % [shown[i][0], loc, shown[i][1]])
				for j in range(i + 1, shown.size()):
					if shown[i][1].intersects(shown[j][1]):
						fail("world tags %s and %s overlap in %s @x=%d" % [shown[i][0], shown[j][0], loc, x])
			x += 90.0
		# Look straight at each object: its tag must be fully on screen.
		for hid in w.hotspots:
			var h = w.hotspots[hid]
			if not h.visible or h.def.get("label", "") == "":
				continue
			w._cam_override = true
			w._cam_x = h.rect.get_center().x
			w._update_camera(0.0, true)
			for nn in [false, true]:
				h.news = nn
				await get_tree().process_frame
				var sr: Rect2 = h.tag_screen_rect()
				checked += 1
				if not vr.grow(1.0).encloses(sr):
					fail("world tag \"%s\" in %s goes off the screen @%s" % [h.def.label, loc, sr])
		w.camera_follow()
