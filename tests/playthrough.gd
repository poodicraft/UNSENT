extends Node
## Automated playthroughs of Chapter One through the real Story engine,
## with a stub UI (tests/stub_ui.gd) answering choices by policy.
##   godot --headless --path . -- --playtest=all|ferry|dusk|lamp
## Exits non-zero if any expectation fails.

const StubUI := preload("res://tests/stub_ui.gd")

var main: Node
var ui: Node
var failures: Array = []
var checks := 0


func _ready() -> void:
	main = get_parent()
	var route := "all"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--playtest="):
			route = a.substr(11)
	main.ui.queue_free()
	ui = StubUI.new()
	main.add_child(ui)
	main.ui = ui
	main.test_mode = true
	await get_tree().process_frame
	if route in ["all", "ferry"]:
		await _route_ferry()
	if route in ["all", "dusk"]:
		await _route_dusk()
	if route in ["all", "lamp"]:
		await _route_lamp()
	if route in ["all", "decoys"]:
		await _route_decoys()
	print("\nPLAYTEST: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAILED: ", f)
	get_tree().quit(1 if failures.size() > 0 else 0)


# ─── helpers ─────────────────────────────────────────────────────────

func expect(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		failures.append(msg)


func f(name: String) -> Variant:
	return GameState.get_flag(name, false)


func goto(loc: String, spawn := "default") -> void:
	await main.goto_location(loc, spawn, true, false)


func obj(id: String) -> Dictionary:
	for o in Data.locations[GameState.location].objects:
		if o.id == id:
			return o
	push_error("no object %s in %s" % [id, GameState.location])
	return {}


func examine(id: String, prefer: Array = []) -> void:
	var saved: Array = ui.prefer
	if not prefer.is_empty():
		ui.prefer = prefer
	await Story.interact(obj(id))
	ui.prefer = saved
	await get_tree().process_frame


func talk(npc: String, plan: Array = [], prefer: Array = []) -> void:
	var saved: Array = ui.prefer
	if not prefer.is_empty():
		ui.prefer = prefer
	ui.plan = plan.duplicate(true)
	await Story.talk_to(npc)
	ui.prefer = saved
	await get_tree().process_frame


func sleep_now() -> void:
	var n := int(f("night"))
	await talk("odile", [], ["Sleep"])
	expect(int(f("night")) == n + 1, "slept: night %d -> %d" % [n, int(f("night"))])


func begin(name: String) -> void:
	print("\n══ ROUTE: %s ══" % name)
	GameState.new_game()
	ui.transcript.clear()
	ui.prefer = ["Sleep", "Climb", "Light your own", "Wait here"]


func night_one(post_reply := true) -> void:
	await goto("harbor", "intro")
	expect(f("intro_done") and f("met_bram"), "intro on the evening ferry")
	await goto("post_office", "from_harbor")
	expect(Story.chute_waiting(), "first letter arrives in the Chute")
	await examine("chute")
	expect(GameState.letter_state("blue_door") == "held", "collected 'The Light Above the Blue Door'")
	expect(f("tutorial_done"), "tutorial follow-up played")
	await examine("teacup")
	await goto("square", "from_po")
	await examine("bakery_lamp")
	await examine("chalkboard")
	await talk("mari", [["ask", "c1_funeral"], ["deliver", "blue_door"]])
	expect(Story.delivered("blue_door") == "mari", "blue_door delivered to Mari")
	expect(f("bakery_lamp_lit"), "consequence: Mari re-lit the lamp above the blue door")
	expect(GameState.has_item("mari_reply"), "received Mari's reply")
	await goto("post_office", "from_square")
	if post_reply:
		await examine("outbox")
		expect(f("reply_posted"), "posted Mari's reply")
	await sleep_now()


# ─── Route 1: June stays, Wren takes her ticket → The Morning Ferry ──

func _route_ferry() -> void:
	begin("ferry (June keeps the light; Wren rides the 6:10)")
	await night_one()
	# Night 2
	await examine("chute")
	expect(GameState.letter_state("lamp_lit") == "held", "night 2 letters collected")
	expect(GameState.letter_state("second_oven") == "kept", "echo letter from Theo's future arrived & kept")
	await goto("harbor", "from_po")
	await examine("cliff_steps")
	expect(GameState.location == "cliff", "cliff path open on night 2")
	await talk("tobias", [["deliver", "lamp_lit"]])
	expect(f("tobias_knows"), "Tobias knows about Odile's letter")
	expect(GameState.has_item("lighthouse_key"), "Tobias gave the lighthouse key")
	await goto("harbor", "from_cliff")
	await talk("june", [["deliver", "lamp_room"]])
	expect(f("june_path") == "stay", "June stays (A Hundred and Twelve Stairs)")
	expect(GameState.letter_state("far_shore") == "faded", "the other future faded")
	expect(GameState.has_item("ferry_ticket"), "June gave Wren her ticket")
	await goto("post_office", "from_harbor")
	await goto("square", "from_po")
	await examine("bakery_umbrella")
	await talk("mari", [["deliver", "umbrella"]])
	expect(f("mari_bow"), "Mari knows who the man at the wheel is")
	await goto("post_office", "from_square")
	await examine("chute")
	expect(f("read_ps_1140"), "read the 11:40 warning from 2031")
	# save / load round trip
	var before := JSON.stringify(GameState.flags)
	GameState.save_game("1")
	GameState.set_flag("night", 99)
	GameState.load_game("1")
	expect(JSON.stringify(GameState.flags) == before, "save/load round-trip preserves state")
	await goto("post_office", "default")
	await sleep_now()
	# Night 3
	await examine("chute")
	await goto("harbor", "from_po")
	await examine("memorial", ["Not now"])
	await examine("cliff_steps")
	await examine("logbook")
	await talk("tobias", [["deliver", "eleven_fifty_two"]])
	expect(f("clock_running") and not f("clock_backward"), "the town clock is running again")
	await goto("cliff", "from_harbor")
	await talk("june", [["deliver", "little_bird"]])
	expect(f("june_mum"), "June and Mari bake together")
	await goto("harbor", "from_cliff")
	await goto("post_office", "from_harbor")
	await examine("chute")
	expect(GameState.letter_state("ticking") == "kept", "echo letter from Felix's future")
	await sleep_now()
	# Lantern Night
	expect(f("lantern_night") and GameState.has_item("paper_lantern"), "Lantern Night begins")
	expect(Story.lamp_keeper() == "june", "June keeps the lamp tonight")
	await goto("harbor", "from_po")
	await examine("cliff_steps")
	ui.prefer = ["Climb", "Take June's ticket", "Light your own"]
	await examine("lighthouse_door")
	expect(f("lamp_lit"), "the lamp is lit at 11:40")
	expect(f("reunited"), "Odile and Tobias meet at the end of the pier")
	expect(f("theo_home"), "Theo came home on the 8:15")
	expect(f("dawn"), "the sun rises over Hushwater")
	expect(main.last_ending == "morning_ferry", "ending: The Morning Ferry (got '%s')" % main.last_ending)
	expect(int(f("hope")) >= Story.DAWN_HOPE, "hope %d" % int(f("hope")))


# ─── Route 2: careless deliveries → The Long Dusk ────────────────────

func _route_dusk() -> void:
	begin("dusk (decoys and returns)")
	await night_one(false)
	await examine("chute")
	await examine("umbrella_stand")
	await talk("odile", [["ask", "c5_crusts"], ["deliver", "umbrella"]], ["Not yet", "That's all"])
	expect(Story.delivered("umbrella") == "odile", "umbrella misdelivered to Odile (decoy)")
	await goto("square", "from_po")
	await examine("felix_scope")
	await talk("felix", [["deliver", "far_shore"]])
	expect(Story.delivered("far_shore") == "felix", "far_shore misdelivered to Felix (decoy)")
	expect(GameState.letter_state("lamp_room") == "held", "the other June letter remains")
	await goto("post_office", "from_square")
	await sleep_now()
	await examine("chute")
	await goto("square", "from_po")
	await talk("felix", [["deliver", "eleven_fifty_two"]])
	expect(f("felix_locked"), "Felix locked his letter away (returned to sender)")
	await goto("post_office", "from_square")
	await sleep_now()
	expect(Story.lamp_keeper() == "tobias", "Tobias keeps his own lamp (he never learned)")
	await goto("harbor", "from_po")
	await examine("pier_end", ["Wait here"])
	expect(f("lamp_lit"), "Tobias relit the lamp at 11:40")
	expect(not f("dawn"), "no dawn")
	expect(main.last_ending == "long_dusk", "ending: The Long Dusk (got '%s')" % main.last_ending)


# ─── Route 3: Wren lights the lamp → First Light ─────────────────────

func _route_lamp() -> void:
	begin("lamp (June leaves; Wren keeps the light)")
	await night_one()
	await examine("chute")
	await goto("harbor", "from_po")
	await talk("june", [["deliver", "far_shore"]])
	expect(f("june_path") == "leave", "June will leave — after climbing with her grandfather")
	await examine("cliff_steps")
	await talk("tobias", [["deliver", "lamp_lit"]])
	expect(f("tobias_knows"), "Tobias knows")
	await goto("harbor", "from_cliff")
	await goto("post_office", "from_harbor")
	await goto("square", "from_po")
	await talk("mari", [["ask", "c5_thursday"], ["deliver", "umbrella"]])
	expect(f("mari_bow"), "umbrella to Mari")
	await goto("post_office", "from_square")
	await examine("chute")
	await sleep_now()
	await examine("chute")
	await goto("harbor", "from_po")
	await examine("memorial", ["Not now"])
	await examine("cliff_steps")
	await talk("june", [["ask", "c6_marguerite"], ["deliver", "eleven_fifty_two"]])
	expect(f("clock_backward"), "the clock runs backwards (June's outcome)")
	await talk("june", [["deliver", "little_bird"]])
	await goto("harbor", "from_cliff")
	await goto("post_office", "from_harbor")
	await sleep_now()
	expect(Story.lamp_keeper() == "nobody", "nobody is minding the lamp")
	await goto("harbor", "from_po")
	await examine("cliff_steps")
	ui.prefer = ["Climb", "Stay", "Light your own"]
	await examine("lighthouse_door")
	expect(GameState.location == "lamp_room" and int(f("lamp_sequence")) == 1, "11:40 — the automatic lamp failed")
	await examine("matchbox")
	expect(int(f("lamp_sequence")) == 1, "match refused before oil and wick")
	await examine("valve")
	await examine("wick")
	await examine("matchbox")
	expect(f("lit_by_wren"), "Wren lit the Hushwater Light")
	expect(f("reunited"), "reunion on the pier")
	expect(main.last_ending == "first_light", "ending: First Light (got '%s')" % main.last_ending)
	if OS.get_environment("UNSENT_DUMP") != "":
		var tr: Array = ui.transcript
		var start := 0
		for i in tr.size():
			if String(tr[i]).begins_with("[card] Lantern Night"):
				start = i
		for i in range(start, tr.size()):
			print("    | ", tr[i])


# ─── Route 4: evidence rules ──────────────────────────────────────────

func _route_decoys() -> void:
	begin("evidence rules")
	await night_one()
	await examine("chute")
	await goto("square", "from_po")
	await talk("mari", [["deliver", "lamp_lit"]])
	expect(GameState.letter_state("lamp_lit") == "held", "can't deliver without evidence")
	await talk("felix", [["deliver", "umbrella"]])
	expect(GameState.letter_state("umbrella") == "held", "can't hand letters to unrelated people")
	await goto("post_office", "from_square")
	await talk("odile", [["ask", "c2_violet"]], ["Do you want me to deliver", "Give it back"])
	expect(Story.delivered("lamp_lit") == "odile" and f("odile_burned"), "Odile asked for her letter back and burned it")
