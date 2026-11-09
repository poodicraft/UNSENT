extends Node
## Visual regression tour: visits every location and major UI screen and
## saves screenshots to build/shots/. Run with:
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --windowed --resolution 1920x1080 -- --tour [--only=name]

var main: Node
var out := "res://build/shots/"
var only := ""


func _ready() -> void:
	main = get_parent()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await get_tree().process_frame
	await _run()
	print("TOUR DONE")
	get_tree().quit()


func _frames(n := 10) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(12)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out + name + ".png")
	print("shot ", name)


func _want(name: String) -> bool:
	return only == "" or name.begins_with(only)


func _setup_state() -> void:
	GameState.new_game()
	for f in ["intro_done", "met_odile", "met_mari", "met_june", "met_tobias", "met_felix", "met_bram", "tutorial_done",
			"visited_cliff", "visited_lamp_room"]:
		GameState.set_flag(f, true)
	GameState.set_flag("night", 2)
	GameState.set_objective("Find who 'The Light Above the Blue Door' was written for.")
	main.ui.set_world_ui(true)


func _run() -> void:
	if only == "layout":
		main.show_title()
		await _frames(30)
		var hud = main.ui.hud
		print("viewport: ", get_viewport().get_visible_rect())
		print("ui.root rect: ", main.ui.root.get_rect())
		print("hud rect: ", hud.get_rect())
		print("obj panel rect: ", hud._obj_panel.get_rect(), " anchors ", hud._obj_panel.anchor_left, ",", hud._obj_panel.anchor_right, " offs ", hud._obj_panel.offset_left, ",", hud._obj_panel.offset_right)
		print("satchel rect: ", hud._satchel.get_rect())
		print("title rect: ", main.title.get_rect())
		for c in main.title.get_children():
			print("  ", c.get_class(), " ", c.get_rect())
		return
	if _want("title"):
		main.show_title()
		await _frames(120)
		await _shot("title")
		main._close_title()
	_setup_state()
	for loc in ["post_office", "square", "harbor", "cliff", "lamp_room"]:
		if not _want(loc):
			continue
		await main.goto_location(loc, "default", false, false)
		await _frames(60)
		await _shot(loc)
		if loc in ["square", "harbor", "cliff"]:
			main.world._cam_override = true
			main.world._cam_x = main.world.width - 300
			await _frames(30)
			await _shot(loc + "_right")
			main.world._cam_override = false

	if _want("dialogue"):
		await main.goto_location("square", "default", false, false)
		main.world.player.position = Vector2(1180, 1000)
		await _frames(30)
		Story.busy = true
		main.ui.dialogue.say("mari", "happy", "Oh! A new face! Nobody has a new face in Hushwater. Come here, let me — you've got dusk all over your coat, sweetheart, here—")
		await _frames(150)
		await _shot("dialogue")
		main.ui.dialogue.choose(["Ask about…", "Deliver a letter…", "Goodbye"], true)
		await get_tree().create_timer(0.6).timeout   # let the choices finish fading in
		await _shot("dialogue_choices")
		main.ui.dialogue.chose.emit(2)
		main.ui.dialogue.close()
		Story.busy = false

	if _want("letter"):
		for id in ["blue_door", "far_shore", "lamp_room", "eleven_fifty_two", "little_bird", "umbrella", "lamp_lit", "final_dawn"]:
			GameState.arrive(id)
		GameState.collect_chute()
		GameState.add_clue("c1_lamp")
		GameState.add_clue("c1_dark_lamp")
		GameState.add_clue("c1_po_lamp")
		GameState.add_clue("c1_tea")
		var r = load("res://src/ui/letter_reader.gd").new()
		main.ui.push_modal(r)
		r.open("blue_door")
		await _shot("letter_blue_door")
		r._flip()
		await _frames(30)
		await _shot("letter_envelope")
		main.ui.pop_modal(r)
		for id in ["far_shore", "eleven_fifty_two", "lamp_room", "little_bird", "umbrella", "lamp_lit", "final_dawn"]:
			var r2 = load("res://src/ui/letter_reader.gd").new()
			main.ui.push_modal(r2)
			r2.open(id)
			await _shot("letter_" + id)
			main.ui.pop_modal(r2)

	if _want("satchel"):
		var s = load("res://src/ui/satchel.gd").new()
		main.ui.push_modal(s)
		s.open("letters")
		await _shot("satchel_letters")
		s._show("clues")
		await _shot("satchel_clues")
		s._show("people")
		await _shot("satchel_people")
		main.ui.pop_modal(s)

	if _want("deliver"):
		var P := load("res://src/ui/panels.gd")
		var c = P.ConfirmDelivery.new()
		main.ui.push_modal(c)
		c.open("blue_door", "mari")
		await _shot("deliver_confirm")
		main.ui.pop_modal(c)
		var a = P.AskPanel.new()
		main.ui.push_modal(a)
		a.open("odile")
		await _shot("ask_panel")
		main.ui.pop_modal(a)
		main.ui.consequence("Mari lit the lamp above the blue door.", "For the first time in two years, someone across the bay might see it.")
		await _shot("consequence")
		for card_node in main.ui.overlay.get_child(0).get_children():
			if card_node.has_signal("done"):
				card_node.queue_free()

	if _want("pause"):
		var P2 := load("res://src/ui/panels.gd")
		var pm = P2.PauseMenu.new()
		main.ui.push_modal(pm)
		pm.open()
		await _shot("pause")
		main.ui.pop_modal(pm)
		var st = P2.SettingsPanel.new()
		main.ui.push_modal(st)
		st.open()
		await _shot("settings")
		main.ui.pop_modal(st)

	if _want("storm"):
		GameState.set_flag("lantern_night", true)
		GameState.set_flag("night", 4)
		await main.goto_location("harbor", "finale", false, false)
		await _frames(90)
		await _shot("storm_harbor")
		await main.goto_location("cliff", "default", false, false)
		await _frames(60)
		await _shot("storm_cliff")

	if _want("dawn"):
		GameState.set_flag("lantern_night", true)
		GameState.set_flag("finale", true)
		GameState.set_flag("dawn", true)
		GameState.set_flag("lamp_lit", true)
		await main.goto_location("harbor", "finale", false, false)
		main.world.set_mood("dawn", 0.0)
		await _frames(60)
		await _shot("dawn_harbor")

	if _want("ending"):
		for fl in ["theo_home", "reunited", "lamp_lit", "clock_running", "mari_bow", "june_mum", "dawn"]:
			GameState.set_flag(fl, true)
		GameState.set_flag("june_path", "stay")
		await main.goto_location("harbor", "finale", false, false)
		main.world.set_mood("dawn", 0.0)
		var E = load("res://src/ui/ending_screen.gd").new()
		main.ui.root.add_child(E)
		E.play("first_light")
		await get_tree().create_timer(3.0).timeout
		await _shot("ending_fate")
		for i in 6:
			E._tap = true
			await get_tree().create_timer(1.8).timeout
		await get_tree().create_timer(2.0).timeout
		await _shot("ending_card")

