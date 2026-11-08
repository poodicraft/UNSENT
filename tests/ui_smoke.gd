extends Node
## Drives the REAL UI like a player: presses title buttons, taps through
## dialogue, walks by tapping the world, opens the Chute's letter, talks to
## Mari, checks the satchel, saves, and walks home. Screenshots key moments.
##   xvfb-run godot --path . --resolution 720x1280 -- --uismoke

var main: Node
var log_lines: Array = []
var _auto := true
var _shots := 0
var failures: Array = []


func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	await get_tree().process_frame
	await _script()
	print("UISMOKE: %d failure(s)" % failures.size())
	for f in failures:
		print("  FAILED: ", f)
	get_tree().quit(1 if failures.size() > 0 else 0)


func _expect(c: bool, msg: String) -> void:
	print(("  ok   " if c else "  FAIL ") + msg)
	if not c:
		failures.append(msg)


func _process(_d: float) -> void:
	if not _auto or main.ui == null:
		return
	var ui = main.ui
	var dlg = ui.dialogue
	# Dismiss cinematic cards
	for c in ui.overlay.get_child(0).get_children():
		if c.has_signal("done") and c.get("_can") != false and c.get("_ready_to_close") != false:
			var ev := InputEventMouseButton.new()
			ev.pressed = true
			ev.button_index = MOUSE_BUTTON_LEFT
			c._gui_input(ev)
	# Modals: close letters, satchels, ask panels
	if ui.modal_open():
		var top = ui._modals.back()
		if top.has_signal("answered") and top.get("letter_id") == null and Engine.get_process_frames() % 20 == 0:
			log_lines.append("confirm: yes")
			top.answered.emit(true)
			return
		if top.has_method("_close") and top.get("letter_id") != null:
			if Engine.get_process_frames() % 30 == 0:
				top._close()
		return
	if dlg.visible and dlg._choosing:
		if Engine.get_process_frames() % 20 == 0:
			var btns: Array = dlg._choices.get_children()
			if btns.size() > 0:
				var b: Button = btns.back() if btns.back().text == "Goodbye" else btns[0]
				log_lines.append("choose: " + b.text)
				b.pressed.emit()
	elif dlg.visible and dlg._waiting:
		if Engine.get_process_frames() % 6 == 0:
			var ev := InputEventMouseButton.new()
			ev.pressed = true
			ev.button_index = MOUSE_BUTTON_LEFT
			dlg._on_catcher_input(ev)


func _is_idle() -> bool:
	var w = main.world
	var walking: bool = w != null and w.player != null and (w.player.moving or not w._pending.is_empty())
	return not Story.busy and not main._changing and not main.ui.modal_open() and not main.ui.dialogue.visible and not walking


func _wait_idle(timeout := 30.0) -> void:
	var t := 0.0
	var quiet := 0.0
	while t < timeout:
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d
		quiet = quiet + d if _is_idle() else 0.0
		if quiet > 1.0:
			return


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://build/shots/smoke_%02d_%s.png" % [_shots, name])
	_shots += 1


func _tap_object(id: String) -> void:
	var w = main.world
	for hid in w.hotspots:
		if hid == id:
			var h = w.hotspots[hid]
			w._handle_tap(h.rect.get_center())
			return
	_expect(false, "object %s exists in %s" % [id, w.id])


func _tap_npc(id: String) -> void:
	var a = main.world.npc(id)
	_expect(a != null, "%s is here" % id)
	if a:
		main.world._handle_tap(a.position + Vector2(0, -120))


func _script() -> void:
	# Title
	main.show_title()
	await get_tree().create_timer(2.0).timeout
	_expect(main.title != null, "title screen shown")
	await _shot("title")
	main.title.action.emit("new")
	var tw := 0.0
	while main.title != null and tw < 10.0:
		await get_tree().process_frame
		tw += get_process_delta_time()
	_expect(main.title == null, "new game started from the title")
	await get_tree().create_timer(1.5).timeout
	await _shot("intro")
	await _wait_idle()
	_expect(GameState.location == "harbor" and Story.f("intro_done"), "intro played, standing on the quay")
	# Walk to the post office back door by tapping it
	_tap_object("po_back_door")
	await _wait_idle(40)
	_expect(GameState.location == "post_office", "walked into the post office")
	_expect(GameState.letter_state("blue_door") == "chute", "first letter waiting in the Chute")
	await _shot("post_office")
	# Tap the Chute: the letter opens in the real reader
	_auto = false
	_tap_object("chute")
	var t := 0.0
	while not main.ui.modal_open() and t < 20.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	_expect(main.ui.modal_open(), "letter reader opened from the Chute")
	await get_tree().create_timer(0.8).timeout
	await _shot("letter_from_chute")
	var reader = main.ui._modals.back()
	reader._on_meta("c1_lamp")
	await get_tree().create_timer(0.3).timeout
	_expect(GameState.has_clue("c1_lamp"), "tapping an underlined phrase notes a clue")
	_auto = true
	await _wait_idle(40)
	_expect(Story.f("tutorial_done"), "tutorial played after closing the letter")
	# Go out to the square and talk to Mari
	_tap_object("front_door")
	await _wait_idle(40)
	_expect(GameState.location == "square", "walked out to Lantern Square")
	_tap_npc("mari")
	var t2 := 0.0
	while not main.ui.dialogue.visible and t2 < 20.0:
		await get_tree().process_frame
		t2 += get_process_delta_time()
	await get_tree().create_timer(1.2).timeout
	await _shot("talk_mari")
	await _wait_idle(60)
	_expect(Story.f("met_mari"), "met Mari through the real dialogue UI")
	# Satchel opens and closes
	main.ui.hud._on_satchel()
	await get_tree().create_timer(0.8).timeout
	_expect(main.ui.modal_open(), "satchel opened from the HUD")
	await _shot("satchel")
	main.ui._modals.back()._close()
	await get_tree().create_timer(0.6).timeout
	_expect(not main.ui.modal_open(), "satchel closed")
	# Save from the pause menu path
	GameState.save_game("2")
	_expect(GameState.has_save("2"), "manual save written")
	_expect(GameState.has_save("auto"), "autosave written on location change")
	# Back home
	_tap_object("po_door")
	await _wait_idle(40)
	_expect(GameState.location == "post_office", "walked back into the post office")
	print("log: ", log_lines.slice(0, 30))
