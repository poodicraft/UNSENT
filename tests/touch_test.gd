extends Node
## Plays the game with REAL touch events, exactly like a phone delivers them:
## InputEventScreenTouch press/release in window pixels, pushed through
## Input.parse_input_event (so touch→mouse emulation, viewport stretch and
## GUI routing all run for real). Nothing is called directly.
##   xvfb-run godot --path . --resolution 720x1280 -- --test=touch_test
## Checks: the title buttons, dialogue, walking, the Chute, and — above all —
## that every way of closing a letter works (X, bottom Close, Android back),
## then the satchel, pause and settings close the same way.

var main: Node
var failures: Array = []
var checks := 0
## Set by other tests that only borrow the touch helpers.
var helper_only := false


func _ready() -> void:
	if helper_only:
		return
	main = get_parent()
	await get_tree().process_frame
	await _script()
	print("TOUCHTEST: %d checks, %d failure(s)" % [checks, failures.size()])
	for f in failures:
		print("  FAILED: ", f)
	get_tree().quit(1 if failures.size() > 0 else 0)


func expect(c: bool, msg: String) -> void:
	checks += 1
	print(("  ok   " if c else "  FAIL ") + msg)
	if not c:
		failures.append(msg)


# ─── Touch helpers ───────────────────────────────────────────────────

## Viewport (canvas) coordinates → window pixels, as the OS reports touches.
func to_window(p: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * p


func touch(p: Vector2, hold := 0.08) -> void:
	var wp := to_window(p)
	var d := InputEventScreenTouch.new()
	d.index = 0
	d.position = wp
	d.pressed = true
	Input.parse_input_event(d)
	await get_tree().create_timer(hold).timeout
	var u := InputEventScreenTouch.new()
	u.index = 0
	u.position = wp
	u.pressed = false
	Input.parse_input_event(u)
	await get_tree().process_frame
	await get_tree().process_frame


func tap_control(c: Control) -> void:
	await touch(c.get_global_rect().get_center())


func back() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame


func wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout


## Finds a tappable control: a Button, or a TapCard (a panel that taps).
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


func icon_button(root: Node, kind: String) -> Control:
	return find_button(root, func(b: Control):
		for c in b.get_children():
			if c.get("kind") == kind:
				return true
		return false)


func top_modal() -> Control:
	return main.ui._modals.back() if main.ui.modal_open() else null


## Taps through dialogue (lines and first choices) until the game is idle.
func play_until_idle(timeout := 40.0, prefer := "") -> void:
	var t := 0.0
	var quiet := 0.0
	while t < timeout:
		await wait(0.12)
		t += 0.12
		var ui = main.ui
		var dlg = ui.dialogue
		var card := _card()
		if card:
			await touch(Vector2(360, 640))
			quiet = 0.0
			continue
		if ui.modal_open():
			return
		if dlg.visible and dlg._choosing:
			var btns: Array = dlg._choices.get_children()
			if btns.size() > 0:
				var pick: Button = btns[0]
				for b in btns:
					if prefer != "" and b.text.findn(prefer) >= 0:
						pick = b
				if pick.text == "Ask about…" or pick.text == "Deliver a letter…":
					pick = btns.back()
				await wait(0.3)
				await tap_control(pick)
			quiet = 0.0
			continue
		if dlg.visible and dlg._waiting:
			await touch(Vector2(360, main.get_viewport().get_visible_rect().size.y - 200))
			quiet = 0.0
			continue
		if not Story.busy and not main._changing and not dlg.visible:
			quiet += 0.12
			if quiet > 0.8:
				return
		else:
			quiet = 0.0


func _card() -> Control:
	for c in main.ui.overlay.get_child(0).get_children():
		if c.has_signal("done"):
			return c
	return null


func world_to_screen(wp: Vector2) -> Vector2:
	return main.world.get_viewport().get_canvas_transform() * wp


func tap_object(id: String) -> void:
	var h = main.world.hotspots.get(id)
	expect(h != null, "object '%s' exists" % id)
	if h:
		await touch(world_to_screen(h.rect.get_center()))


func walk_to_object(id: String) -> void:
	# Scroll the camera there first if the object is off-screen.
	for attempt in 6:
		var h = main.world.hotspots.get(id)
		if h == null:
			return
		var sp := world_to_screen(h.rect.get_center())
		var vs: Vector2 = main.get_viewport().get_visible_rect().size
		if sp.x > 40 and sp.x < vs.x - 40:
			await touch(sp)
			return
		# tap the ground towards it
		var dir := 1.0 if sp.x > vs.x * 0.5 else -1.0
		var before: Vector2 = main.world.player.position
		await touch(Vector2(vs.x * 0.5 + dir * vs.x * 0.42, vs.y * 0.80))
		await wait(1.6)
		print("    walk toward %s: obj on screen at %s, player %s -> %s" % [id, sp, before, main.world.player.position])
	expect(false, "could reach object '%s' on screen" % id)


# ─── The script ──────────────────────────────────────────────────────

func _script() -> void:
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	print("viewport ", vs, "  window ", DisplayServer.window_get_size())
	main.show_title()
	await wait(2.2)
	expect(main.title != null, "title screen is up")
	var nb := button_text(main.title, "New")
	expect(nb != null, "title has a New game button")
	if nb == null:
		return
	await tap_control(nb)
	await wait(0.5)
	# a confirm box appears only if a save exists
	print("    after New: modal_open=%s title=%s" % [main.ui.modal_open(), main.title])
	if main.ui.modal_open():
		var yes := button_text(top_modal(), "Begin")
		print("    confirm box Begin button: ", yes, " rect ", yes.get_global_rect() if yes else Rect2())
		if yes:
			await tap_control(yes)
		await wait(0.3)
		print("    after Begin: modal_open=%s" % main.ui.modal_open())
	var tt := 0.0
	while main.title != null and tt < 6.0:
		await wait(0.2)
		tt += 0.2
	expect(main.title == null, "tapping New game starts the game")
	await wait(1.0)
	await play_until_idle()
	expect(Story.f("intro_done") and GameState.location == "harbor", "intro played by tapping through it")

	await walk_to_object("po_back_door")
	await wait(0.5)
	var t := 0.0
	while GameState.location != "post_office" and t < 20.0:
		await wait(0.25)
		t += 0.25
	expect(GameState.location == "post_office", "walked into the post office by tapping its door")
	await play_until_idle()
	expect(GameState.letter_state("blue_door") == "chute", "first letter is waiting in the Chute")

	# ── Letter from the Chute: close with the X ──
	await _open_chute_letter()
	var r := top_modal()
	expect(r != null and r.get("letter_id") == "blue_door", "the Chute's letter opened in the reader")
	if r == null:
		return
	await wait(0.6)
	var x := icon_button(r, "close")
	expect(x != null, "reader has a close (X) button")
	if x:
		var rect := x.get_global_rect()
		expect(rect.position.y >= 0 and rect.end.x <= vs.x, "X button is fully on screen (%s)" % rect)
		await tap_control(x)
		await wait(0.6)
	expect(not main.ui.modal_open() or top_modal() != r, "tapping X closes the letter received from the Chute")
	await play_until_idle()
	expect(Story.f("tutorial_done"), "Odile's tutorial follows once the letter is closed")

	# ── From the satchel: bottom Close, Android back, X ──
	for how in ["bottom", "back", "x"]:
		var sat := icon_button(main.ui.hud, "satchel")
		expect(sat != null, "HUD has a satchel button")
		if sat == null:
			return
		await tap_control(sat)
		await wait(0.6)
		var s := top_modal()
		expect(s != null and s.has_method("_build_letters"), "satchel opens by tapping it")
		if s == null:
			return
		var card := find_button(s, func(b: Control): return b.has_meta("letter_id"))
		expect(card != null, "satchel lists the letter")
		if card == null:
			return
		await tap_control(card)
		await wait(0.6)
		var rd := top_modal()
		expect(rd != null and rd.get("letter_id") == "blue_door", "tapping it opens the reader")
		match how:
			"bottom":
				var cb := button_text(rd, "Close")
				expect(cb != null, "reader has a bottom Close button")
				if cb:
					var cr := cb.get_global_rect()
					expect(cr.end.y <= vs.y and cr.position.y >= vs.y * 0.6, "Close button sits at the bottom, on screen (%s)" % cr)
					await tap_control(cb)
			"back":
				await back()
			"x":
				await tap_control(icon_button(rd, "close"))
		await wait(0.6)
		expect(top_modal() == s, "reader closes with %s" % how)
		match how:
			"bottom":
				var sc := button_text(s, "Close")
				expect(sc != null, "satchel has a bottom Close button")
				if sc:
					await tap_control(sc)
			"back":
				await back()
			"x":
				await tap_control(icon_button(s, "close"))
		await wait(0.6)
		expect(not main.ui.modal_open(), "satchel closes with %s" % how)
		await play_until_idle()

	# ── Pause menu & settings ──
	var pb := icon_button(main.ui.hud, "pause")
	expect(pb != null, "HUD has a pause button")
	if pb:
		await tap_control(pb)
		await wait(0.5)
		var pm := top_modal()
		expect(pm != null, "pause menu opens")
		var st := button_text(pm, "Settings") if pm else null
		if st:
			await tap_control(st)
			await wait(0.5)
			var sp := top_modal()
			expect(sp != null and sp != pm, "settings open from pause")
			var done := button_text(sp, "Done")
			if done == null:
				done = icon_button(sp, "close")
			if done:
				await tap_control(done)
			await wait(0.5)
			expect(top_modal() == pm, "settings close")
		var resume := button_text(pm, "Resume") if pm else null
		if resume:
			await tap_control(resume)
		await wait(0.5)
		expect(not main.ui.modal_open(), "pause menu closes with Resume")
		await back()
		await wait(0.5)
		expect(main.ui.modal_open(), "Android back opens the pause menu")
		await back()
		await wait(0.5)
		expect(not main.ui.modal_open(), "Android back closes the pause menu")
	await _script_part2()


## Second part: things reached from the title screen and the overlays.
func _script_part2() -> void:
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	# Tap outside the pause menu: it closes.
	await back()
	await wait(0.6)
	expect(main.ui.modal_open(), "pause menu open again")
	await touch(Vector2(vs.x * 0.5, 40))
	await wait(0.5)
	expect(not main.ui.modal_open(), "tapping outside the pause menu closes it")
	# A 'tap to continue' card closes when tapping anywhere (not only on it).
	var done := [false]
	var go := func():
		await main.ui.consequence("A test consequence.", "Tap anywhere.")
		done[0] = true
	go.call()
	await wait(1.2)
	await touch(Vector2(40, vs.y - 60))
	await wait(0.8)
	expect(done[0], "a consequence card closes when tapping outside the card")
	# Install an old (v1.0.0) save taken while the first letter was being
	# read, then load it from the TITLE screen's Load Game panel.
	var raw := FileAccess.get_file_as_string("res://tests/fixtures/v1_0_0/a02_reading_first_letter.json")
	var fh := FileAccess.open("user://save_2.json", FileAccess.WRITE)
	fh.store_string(raw)
	fh.close()
	main.go_title()
	await wait(3.0)
	expect(main.title != null, "back on the title screen")
	var lb := button_text(main.title, "Load")
	expect(lb != null, "title has Load Game")
	if lb == null:
		return
	await tap_control(lb)
	await wait(0.8)
	var sp := top_modal()
	expect(sp != null, "Load Game panel opens over the title")
	var slot := find_button(sp, func(b: Control): return b.has_signal("pressed") and not (b is Button) and _has_text(b, "Slot 2")) if sp else null
	expect(slot != null, "the old save is listed")
	if slot == null:
		return
	await tap_control(slot)
	var t := 0.0
	while main.title != null and t < 8.0:
		await wait(0.2)
		t += 0.2
	expect(main.title == null, "tapping the old save loads it")
	await wait(1.5)
	# The interrupted moment resumes: Odile's lesson plays, visibly.
	var seen_dialogue := false
	t = 0.0
	while t < 20.0 and not seen_dialogue:
		await wait(0.2)
		t += 0.2
		if main.ui.dialogue.visible and main.ui.dialogue._waiting and not main.ui.modal_open():
			seen_dialogue = true
	expect(Story.f("tutorial_done"), "the old save resumes where it stopped (Odile's lesson)")
	expect(seen_dialogue, "...and the scene is on screen")
	await play_until_idle()
	expect(not Story.busy and not main.ui.modal_open(), "control returns to the player")
	expect(GameState.objective.begins_with("Find who"), "objective updated: %s" % GameState.objective)
	GameState.delete_save("2")


func _has_text(n: Node, text: String) -> bool:
	if (n is Label or n is Button) and n.text.find(text) >= 0:
		return true
	for c in n.get_children():
		if _has_text(c, text):
			return true
	return false


func _open_chute_letter() -> void:
	await walk_to_object("chute")
	var t := 0.0
	while not main.ui.modal_open() and t < 20.0:
		await wait(0.2)
		t += 0.2
		# tap through any line shown before the letter opens
		if main.ui.dialogue.visible and main.ui.dialogue._waiting:
			await touch(Vector2(360, main.get_viewport().get_visible_rect().size.y - 200))
