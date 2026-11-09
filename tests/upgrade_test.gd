extends Node
## The update, end to end, as a player meets it.
##   phase=setup : leave the files a 1.0.0 install would have on the phone —
##                 an autosave made by 1.0.0 (taken mid-scene, while reading the
##                 first letter), a manual save, settings, discovered endings.
##   phase=check : start the new version fresh (autoloads read those files at
##                 boot), tap Continue with real touches, and check that every
##                 bit of progress and every setting is there.
##   godot --path . -- --test=upgrade_test --phase=setup
##   xvfb-run godot --path . --resolution 1080x2400 -- --test=upgrade_test --phase=check

const TouchTest := preload("res://tests/touch_test.gd")

var main: Node
var failures: Array = []
var checks := 0
var tt: Node


func _ready() -> void:
	main = get_parent()
	var phase := "check"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--phase="):
			phase = a.substr(8)
	await get_tree().process_frame
	if phase == "setup":
		_setup()
		print("UPGRADE SETUP: 1.0.0 files written")
		get_tree().quit(0)
		return
	tt = TouchTest.new()
	tt.helper_only = true
	tt.main = main
	add_child(tt)
	await _check()
	print("UPGRADETEST: %d checks, %d failure(s)" % [checks, failures.size()])
	for f in failures:
		print("  FAILED: ", f)
	get_tree().quit(1 if failures.size() > 0 else 0)


func expect(c: bool, msg: String) -> void:
	checks += 1
	print(("  ok   " if c else "  FAIL ") + msg)
	if not c:
		failures.append(msg)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _setup() -> void:
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("save_") or f == "meta.json" or f == "settings.cfg":
			DirAccess.remove_absolute("user://" + f)
	# The autosave 1.0.0 wrote while the first letter was open (the moment
	# the old version couldn't close the letter), and an older manual save.
	_write("user://save_auto.json", FileAccess.get_file_as_string("res://tests/fixtures/v1_0_0/a02_reading_first_letter.json"))
	var manual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1_0_0/a10_night2_mid.json"))
	manual["saved_at"] = float(manual.get("saved_at", 0)) - 3600.0
	_write("user://save_1.json", JSON.stringify(manual))
	# 1.0.0's settings file and endings record, in 1.0.0's format.
	var cf := ConfigFile.new()
	cf.set_value("audio", "music", 0.3)
	cf.set_value("audio", "ambience", 0.4)
	cf.set_value("audio", "sfx", 0.5)
	cf.set_value("text", "speed", 2.0)
	cf.set_value("text", "size", 2)
	cf.set_value("access", "reduce_motion", true)
	cf.set_value("access", "show_hints", false)
	cf.save("user://settings.cfg")
	_write("user://meta.json", JSON.stringify({"endings": ["long_dusk"]}))


func _check() -> void:
	# Settings and endings were read at boot, before any of our code ran.
	expect(is_equal_approx(Settings.music_volume, 0.3) and is_equal_approx(Settings.sfx_volume, 0.5), "volume settings kept")
	expect(Settings.text_size == 2 and is_equal_approx(Settings.text_speed, 2.0), "text size and speed kept")
	expect(Settings.reduce_motion and not Settings.show_hints, "accessibility settings kept")
	expect(GameState.endings_seen == ["long_dusk"], "discovered endings kept")
	expect(GameState.has_save("auto") and GameState.has_save("1"), "both saves still on the phone")
	main.show_title()
	await tt.wait(2.5)
	var cont = tt.button_text(main.title, "Continue")
	expect(cont != null, "title offers Continue")
	expect(tt._has_text(main.title, "Endings discovered: 1 / 3"), "title shows the endings found in 1.0.0")
	if cont == null:
		return
	await tt.tap_control(cont)
	var t := 0.0
	while main.title != null and t < 8.0:
		await tt.wait(0.2)
		t += 0.2
	expect(main.title == null, "tapping Continue loads the 1.0.0 autosave")
	await tt.wait(1.0)
	expect(GameState.location == "post_office", "back in the post office")
	expect(GameState.letter_state("blue_door") == "held", "the first letter is still in the satchel")
	var old_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1_0_0/a02_reading_first_letter.json"))
	var missing: Array = []
	for c in old_save.get("clues", []):
		if not GameState.has_clue(c):
			missing.append(c)
	expect(missing.is_empty() and GameState.clues.size() >= old_save.get("clues", []).size(), "every clue from 1.0.0 intact (%d)" % old_save.get("clues", []).size())
	expect(Story.f("met_odile") and Story.f("met_bram") and Story.f("intro_done"), "story so far intact")
	# The interrupted moment resumes and can be played through by touch.
	await tt.play_until_idle(40.0)
	expect(Story.f("tutorial_done"), "Odile's lesson (cut off in 1.0.0) plays")
	expect(not Story.busy and not main.ui.modal_open(), "the player is in control")
	expect(GameState.objective.begins_with("Find who"), "objective is current")
	# Open the letter from the satchel and close it with the new Close button.
	var sat = tt.icon_button(main.ui.hud, "satchel")
	await tt.tap_control(sat)
	await tt.wait(0.6)
	var card = tt.find_button(tt.top_modal(), func(b: Control): return b.has_meta("letter_id")) if tt.top_modal() else null
	expect(card != null, "the letter is in the satchel")
	if card:
		await tt.tap_control(card)
		await tt.wait(0.6)
		var cb = tt.button_text(tt.top_modal(), "Close")
		await tt.tap_control(cb)
		await tt.wait(0.6)
		expect(tt.top_modal() != null and tt.top_modal().has_method("_build_letters"), "the letter closes")
		await tt.back()
		await tt.wait(0.6)
	expect(not main.ui.modal_open(), "back to the game")
	# The new save format is written and reads back.
	GameState.autosave()
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://save_auto.json"))
	expect(d is Dictionary and int(d.get("version", 0)) == 2 and d.flags.get("tutorial_done", false), "progress autosaved in the new format")
	var info := GameState.slot_info("1")
	expect(not info.is_empty() and int(info.night) == 2, "the 1.0.0 manual save (night 2) is still listed")
	# Load it and compare against exactly what 1.0.0 wrote.
	var want: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1_0_0/a10_night2_mid.json"))
	expect(GameState.load_game("1"), "the 1.0.0 manual save loads")
	Story.repair_after_load()
	var lost: Array = []
	for c in want.clues:
		if not GameState.has_clue(c):
			lost.append(c)
	for lid in want.letters:
		if GameState.letter_state(lid) != want.letters[lid].state or GameState.is_read(lid) != bool(want.letters[lid].get("read", false)):
			lost.append(lid)
	for k in want.flags:
		if not GameState.flags.has(k):
			lost.append(k)
	for it in want.items:
		if not GameState.has_item(it):
			lost.append(it)
	expect(lost.is_empty(), "all %d clues, %d letters, %d story flags and items from 1.0.0 intact %s" % [want.clues.size(), want.letters.size(), want.flags.size(), lost])
