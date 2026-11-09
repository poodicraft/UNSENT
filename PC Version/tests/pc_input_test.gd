extends Node
## Plays the PC version with REAL mouse and keyboard events, pushed through
## Input.parse_input_event (so the window stretch, GUI routing, hover and
## every key handler run for real). Nothing in the game is called directly.
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --windowed --resolution 1920x1080 -- --test=pc_input_test
## Checks: the title menu by keyboard, dialogue with Space / Enter / number
## keys, mouse hover (hand cursor + name tag), walking with the keyboard,
## E to interact, the letter reader (wheel, T, Esc), the satchel (Tab, I,
## 1-4, arrows), the pause menu and Quit to Desktop confirmation, a
## "click to continue" card dismissed with Space, and F11.

var main: Node
var failures: Array = []
var checks := 0


func _ready() -> void:
	main = get_parent()
	await get_tree().process_frame
	await _script()
	print("PCINPUT: %d checks, %d failure(s)" % [checks, failures.size()])
	for f in failures:
		print("  FAILED: ", f)
	get_tree().quit(1 if failures.size() > 0 else 0)


func expect(c: bool, msg: String) -> void:
	checks += 1
	print(("  ok   " if c else "  FAIL ") + msg)
	if not c:
		failures.append(msg)


# ─── Input helpers ───────────────────────────────────────────────────

func wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Viewport (UI) coordinates → window pixels, as the OS reports the mouse.
func to_window(p: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * p


func move_mouse(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = to_window(p)
	m.global_position = m.position
	Input.parse_input_event(m)
	await frames(3)


func click(p: Vector2) -> void:
	await move_mouse(p)
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.button_mask = MOUSE_BUTTON_MASK_LEFT
	d.position = to_window(p)
	d.global_position = d.position
	Input.parse_input_event(d)
	await wait(0.06)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = d.position
	u.global_position = d.position
	Input.parse_input_event(u)
	await frames(3)


func click_control(c: Control) -> void:
	await click(c.get_global_rect().get_center())


func wheel(p: Vector2, down := true, notches := 3) -> void:
	await move_mouse(p)
	for i in notches:
		for pressed in [true, false]:
			var w := InputEventMouseButton.new()
			w.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
			w.pressed = pressed
			w.factor = 1.0
			w.position = to_window(p)
			w.global_position = w.position
			Input.parse_input_event(w)
		await frames(2)
	await wait(0.2)


func _key_event(k: Key, pressed: bool, alt := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = pressed
	e.alt_pressed = alt
	return e


func key(k: Key, alt := false) -> void:
	Input.parse_input_event(_key_event(k, true, alt))
	await frames(2)
	Input.parse_input_event(_key_event(k, false, alt))
	await frames(3)


func hold(k: Key, secs: float) -> void:
	Input.parse_input_event(_key_event(k, true))
	await wait(secs)
	Input.parse_input_event(_key_event(k, false))
	await frames(3)


func top_modal() -> Control:
	return main.ui.top_modal()


func find_button(root: Node, pred: Callable) -> Control:
	if root is Control and (root is Button or (root is PanelContainer and root.has_signal("pressed"))) and root.is_visible_in_tree() and pred.call(root):
		return root
	for c in root.get_children():
		var b := find_button(c, pred)
		if b:
			return b
	return null


func button_text(root: Node, text: String) -> Control:
	return find_button(root, func(b: Control): return b is Button and b.text.findn(text) >= 0)


func _card() -> Control:
	for c in main.ui.overlay.get_child(0).get_children():
		if c.has_signal("done"):
			return c
	return null


func world_to_screen(wp: Vector2) -> Vector2:
	return main.world.get_viewport().get_canvas_transform() * wp


## Plays through dialogue with the KEYBOARD only (Space to continue, number
## keys to choose) until the game is idle or a panel opens.
func play_until_idle(timeout := 40.0) -> void:
	var t := 0.0
	var quiet := 0.0
	while t < timeout:
		await wait(0.12)
		t += 0.12
		var ui = main.ui
		var dlg = ui.dialogue
		if _card():
			await key(KEY_SPACE)
			quiet = 0.0
			continue
		if ui.modal_open():
			return
		if dlg.visible and dlg._choosing:
			var btns: Array = dlg._live_choices()
			if btns.size() > 0:
				var pick := 0
				for i in btns.size():
					if btns[i].text in ["Goodbye"]:
						pick = i
				await wait(0.3)
				await key((KEY_1 + pick) as Key)
			quiet = 0.0
			continue
		if dlg.visible and dlg._waiting:
			await key(KEY_SPACE if randf() < 0.5 else KEY_ENTER)
			quiet = 0.0
			continue
		if not Story.busy and not main._changing and not dlg.visible:
			quiet += 0.12
			if quiet > 0.8:
				return
		else:
			quiet = 0.0


# ─── The script ──────────────────────────────────────────────────────

func _script() -> void:
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	print("viewport ", vs, "  window ", DisplayServer.window_get_size())
	expect(vs.x >= vs.y, "the PC version runs in landscape (%s)" % vs)
	main.show_title()
	await wait(2.2)
	expect(main.title != null, "title screen is up")
	expect(button_text(main.title, "Quit") != null, "title menu has Quit")

	# Esc on the title asks before quitting; Esc again cancels.
	await key(KEY_ESCAPE)
	await wait(0.4)
	var qb := top_modal()
	expect(qb != null and button_text(qb, "Quit") != null, "Esc on the title asks 'Quit UNSENT?'")
	await key(KEY_ESCAPE)
	await wait(0.4)
	expect(not main.ui.modal_open() and main.title != null, "Esc cancels the quit question")

	# The menu works from the keyboard: arrows to "New Game", Enter.
	var nb := button_text(main.title, "New")
	expect(nb != null, "title has a New Game button")
	if nb == null:
		return
	for i in 8:
		if nb.has_focus():
			break
		await key(KEY_DOWN)
	expect(nb.has_focus(), "arrow keys move through the title menu")
	await key(KEY_ENTER)
	await wait(0.5)
	if main.ui.modal_open():
		var yes := button_text(top_modal(), "Begin")
		if yes:
			await click_control(yes)
		await wait(0.3)
	var tt := 0.0
	while main.title != null and tt < 6.0:
		await wait(0.2)
		tt += 0.2
	expect(main.title == null, "Enter on New Game starts the game")
	await wait(1.0)
	await play_until_idle()
	expect(Story.f("intro_done") and GameState.location == "harbor", "intro played with Space / Enter / number keys")

	# ── Mouse hover: something on screen, near the middle ──
	var w = main.world
	var door = w.hotspots.get("po_back_door")
	expect(door != null, "harbour has the post office door")
	if door == null:
		return
	var target = null
	var best := INF
	for hid in w.hotspots:
		var h = w.hotspots[hid]
		var sp := world_to_screen(h.rect.get_center())
		if h.visible and sp.x > 200 and sp.x < vs.x - 200 and sp.y > 160 and absf(sp.x - vs.x * 0.5) < best:
			best = absf(sp.x - vs.x * 0.5)
			target = h
	expect(target != null, "something to hover is on screen")
	if target:
		await move_mouse(world_to_screen(target.rect.get_center()))
		await wait(0.4)
		expect(target.hovered, "hovering '%s' highlights it" % target.def.get("label", ""))
		expect(Input.get_current_cursor_shape() == Input.CURSOR_POINTING_HAND, "the cursor becomes a pointing hand over it")
		expect(target.near and target._near_a > 0.5, "...and its name tag shows")
		await move_mouse(Vector2(vs.x * 0.5, 40))
		await wait(0.3)
		expect(not target.hovered and Input.get_current_cursor_shape() == Input.CURSOR_ARROW, "the cursor goes back to an arrow over empty sky")

	# ── Keyboard walking ──
	var x0: float = w.player.position.x
	await hold(KEY_D, 1.0)
	var x1: float = w.player.position.x
	expect(x1 > x0 + 100.0, "holding D walks right (%.0f -> %.0f)" % [x0, x1])
	await wait(0.3)
	expect(not w.player.moving, "releasing the key stops walking")
	await hold(KEY_LEFT, 0.6)
	expect(w.player.position.x < x1 - 50.0, "holding Left walks left")

	# ── Click the door to go into the post office ──
	await click(world_to_screen(door.rect.get_center()))
	var t := 0.0
	while GameState.location != "post_office" and t < 25.0:
		await wait(0.25)
		t += 0.25
	expect(GameState.location == "post_office", "clicking the door walks there and goes in")
	await wait(0.6)
	await play_until_idle()

	# ── E: walk to the Chute with the keyboard and use it ──
	w = main.world
	var chute = w.hotspots.get("chute")
	t = 0.0
	while t < 12.0 and (w._kb_focus.get("id", "") != "chute"):
		var dir: Key = KEY_A if w.player.position.x > chute.rect.get_center().x else KEY_D
		await hold(dir, 0.25)
		t += 0.3
	expect(w._kb_focus.get("id", "") == "chute", "walking near the Chute makes it the E target")
	await wait(0.2)
	expect(chute.key_hint, "its name tag shows the E key")
	await key(KEY_E)
	t = 0.0
	while not main.ui.modal_open() and t < 20.0:
		await wait(0.2)
		t += 0.2
		if main.ui.dialogue.visible and main.ui.dialogue._waiting:
			await key(KEY_SPACE)
	var r := top_modal()
	expect(r != null and r.get("letter_id") == "blue_door", "E at the Chute collects the letter and opens it")
	if r == null:
		return
	await wait(0.6)

	# ── Letter reader: wheel scroll, T to turn over, Esc to close ──
	var sc: ScrollContainer = r._scroll
	var before: int = sc.scroll_vertical
	await wheel(sc.get_global_rect().get_center(), true, 4)
	expect(sc.scroll_vertical > before, "the mouse wheel scrolls the letter (%d -> %d)" % [before, sc.scroll_vertical])
	await key(KEY_T)
	await wait(0.6)
	expect(r._showing_back, "T turns the letter over")
	await key(KEY_T)
	await wait(0.6)
	expect(not r._showing_back, "T turns it back")
	await key(KEY_ESCAPE)
	await wait(0.6)
	# (A freed object compares equal to null, so check validity first.)
	expect(not is_instance_valid(r) or top_modal() != r, "Esc closes the letter")
	await play_until_idle()
	expect(Story.f("tutorial_done"), "Odile's tutorial follows (played with the keyboard)")

	# ── Satchel: Tab / I, number keys and arrows, Tab / Esc to close ──
	await key(KEY_TAB)
	await wait(0.5)
	var s := top_modal()
	expect(s != null and s.has_method("_build_letters"), "Tab opens the satchel")
	if s:
		await key(KEY_2)
		await wait(0.2)
		expect(s._tab == "clues", "2 shows the clue notebook")
		await key(KEY_RIGHT)
		await wait(0.2)
		expect(s._tab == "people", "Right moves to the next tab")
		await key(KEY_TAB)
		await wait(0.5)
		expect(not main.ui.modal_open(), "Tab closes the satchel again")
	await key(KEY_I)
	await wait(0.5)
	expect(top_modal() != null and top_modal().has_method("_build_letters"), "I opens the satchel too")
	await key(KEY_ESCAPE)
	await wait(0.5)
	expect(not main.ui.modal_open(), "Esc closes the satchel")

	# ── Pause menu: Esc, and Quit to Desktop asks first ──
	await key(KEY_ESCAPE)
	await wait(0.5)
	var pm := top_modal()
	expect(pm != null and button_text(pm, "Quit to Desktop") != null, "Esc opens the pause menu, with Quit to Desktop")
	if pm:
		await click_control(button_text(pm, "Quit to Desktop"))
		await wait(0.5)
		var cb := top_modal()
		expect(cb != null and cb != pm and button_text(cb, "Quit") != null, "Quit to Desktop asks for confirmation")
		if cb:
			await click_control(button_text(cb, "Cancel"))
			await wait(0.5)
		expect(top_modal() == pm and pm.visible, "Cancel returns to the pause menu")
		await key(KEY_ESCAPE)
		await wait(0.5)
	expect(not main.ui.modal_open(), "Esc closes the pause menu")

	# ── Talk to Odile with a click; Enter and number keys in the conversation ──
	var od = main.world.npc("odile")
	expect(od != null, "Odile is at the counter")
	if od:
		await click(world_to_screen(od.position + Vector2(0, -120)))
		t = 0.0
		while not main.ui.dialogue.visible and t < 10.0:
			await wait(0.2)
			t += 0.2
		expect(main.ui.dialogue.visible, "clicking Odile starts a conversation")
		var saw_badges := false
		t = 0.0
		while (Story.busy or main.ui.dialogue.visible) and t < 30.0:
			await wait(0.15)
			t += 0.15
			var dlg = main.ui.dialogue
			if main.ui.modal_open():
				await key(KEY_ESCAPE)
				continue
			if dlg._choosing:
				var btns: Array = dlg._live_choices()
				for b in btns:
					for c in b.get_children():
						if c is Label and c.text.is_valid_int():
							saw_badges = true
				var bye := btns.size() - 1
				await wait(0.3)
				await key((KEY_1 + bye) as Key)
			elif dlg._waiting:
				await key(KEY_ENTER)
		expect(saw_badges, "choices are numbered for the keyboard")
		expect(not Story.busy, "the conversation ends with the number key for Goodbye")

	# ── A 'click to continue' card closes with Space ──
	var done := [false]
	var go := func():
		await main.ui.consequence("A test consequence.", "Press Space.")
		done[0] = true
	go.call()
	await wait(1.2)
	await key(KEY_SPACE)
	await wait(0.8)
	expect(done[0], "Space dismisses a consequence card")

	# ── F11 / Alt+Enter toggle fullscreen (and are remembered) ──
	var fs0: bool = Settings.is_fullscreen()
	await key(KEY_F11)
	await wait(0.8)
	expect(Settings.fullscreen != fs0, "F11 switches fullscreen / windowed")
	await key(KEY_ENTER, true)
	await wait(0.8)
	expect(Settings.fullscreen == fs0, "Alt+Enter switches back")
	Settings.set_fullscreen(true)   # leave the default preference in place
