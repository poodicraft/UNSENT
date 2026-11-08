extends Node
## Top-level controller: title screen, location changes, save/load,
## endings, Android back button and lifecycle autosaves.

const Location := preload("res://src/world/location.gd")
const UIRoot := preload("res://src/ui/ui_root.gd")
const TitleScreen := preload("res://src/ui/title_screen.gd")
const EndingScreen := preload("res://src/ui/ending_screen.gd")

var world: Node2D = null
var ui: Node
var test_mode := false
var last_ending := ""
var title: Control = null
var _holder: Node2D
var _changing := false


func _ready() -> void:
	Story.main = self
	get_tree().set_auto_accept_quit(false)
	_holder = Node2D.new()
	_holder.name = "World"
	add_child(_holder)
	ui = UIRoot.new()
	add_child(ui)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--tour" or a == "--uismoke" or a.begins_with("--playtest"):
			var path := "res://tests/playthrough.gd"
			if a == "--tour":
				path = "res://tests/screenshot_tour.gd"
			elif a == "--uismoke":
				path = "res://tests/ui_smoke.gd"
			var T: Script = load(path)
			if T and T.can_instantiate():
				add_child(T.new())
			else:
				push_error("Test script failed to load: " + path)
				get_tree().quit(2)
			return
	show_title()


func input_blocked() -> bool:
	return title != null or ui.modal_open() or _changing


func _process(_delta: float) -> void:
	if world and world.player and not _changing:
		GameState.player_pos = world.player.position


# ─── Title ───────────────────────────────────────────────────────────

func show_title() -> void:
	_clear_world()
	GameState.in_game = false
	ui.set_world_ui(false)
	ui.dialogue.close()
	ui.letterbox(false)
	# A living diorama behind the title.
	GameState.new_game()
	GameState.in_game = false
	GameState.set_flag("intro_done", true)
	world = Location.new()
	_holder.add_child(world)
	world.build("harbor", "default")
	world.title_mode()
	Audio.play_music("theme", 2.5)
	title = TitleScreen.new()
	ui.root.add_child(title)
	title.action.connect(_on_title_action)
	ui.fade_instant(1.0)
	await ui.fade(false, 1.6)


func _on_title_action(id: String) -> void:
	match id:
		"new":
			if GameState.most_recent_slot() != "":
				var ok: bool = await ui.confirm("Start a new game? Your autosave will be replaced as you play.", "Begin", "Cancel")
				if not ok:
					return
			new_game()
		"continue":
			load_slot(GameState.most_recent_slot())
		"load":
			var slot: String = await ui.open_saves("load")
			if slot != "":
				load_slot(slot)
		"settings":
			await ui.open_settings()
		"credits":
			title.show_credits()


func _close_title() -> void:
	if title:
		title.queue_free()
		title = null


func new_game() -> void:
	await ui.fade(true, 1.0)
	_close_title()
	GameState.new_game()
	ui.set_world_ui(true)
	await goto_location("harbor", "intro", true, false)


func load_slot(slot: String) -> void:
	if slot == "":
		return
	await ui.fade(true, 0.8)
	_close_title()
	if not GameState.load_game(slot):
		ui.toast("That save couldn't be loaded.", "fade")
		show_title()
		return
	ui.set_world_ui(true)
	ui.hud._on_objective(GameState.objective)
	var pos: Variant = GameState.player_pos
	await goto_location(GameState.location, GameState.spawn, false, false, pos)


func go_title() -> void:
	await ui.fade(true, 0.8)
	_close_title()
	show_title()


# ─── Locations ───────────────────────────────────────────────────────

func _clear_world() -> void:
	if world:
		world.queue_free()
		world = null


## Swaps the current location. `fade` controls the transition; when
## `run_on_enter` is true the location's arrival scenes may play.
func goto_location(loc_id: String, spawn: String, run_on_enter := true, fade := true, saved_pos: Variant = null) -> void:
	_changing = true
	if fade:
		await ui.fade(true, 0.42)
	_clear_world()
	await get_tree().process_frame
	GameState.location = loc_id
	GameState.spawn = spawn
	world = Location.new()
	_holder.add_child(world)
	world.build(loc_id, spawn, saved_pos)
	GameState.set_flag("visited_" + loc_id, true)
	_changing = false
	await ui.fade(false, 0.5)
	ui.hud.show_location(Data.locations.get(loc_id, {}).get("name", ""))
	if not Story.busy:
		GameState.autosave()
	if run_on_enter and not Story.busy:
		for e in world.def.get("on_enter", []):
			if Story.eval(e.get("if", "true")):
				await Story.run(e.node)
				break


# ─── Endings ─────────────────────────────────────────────────────────

func play_ending(id: String) -> void:
	GameState.record_ending(id)
	last_ending = id
	if test_mode:
		return
	ui.set_world_ui(false)
	var e := EndingScreen.new()
	ui.root.add_child(e)
	await e.play(id)
	e.queue_free()
	GameState.delete_save("auto")
	go_title()


# ─── Platform ────────────────────────────────────────────────────────

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_back()
		NOTIFICATION_WM_CLOSE_REQUEST:
			GameState.autosave()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if title == null and not _changing:
				GameState.autosave()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_back()


func _back() -> void:
	if ui.back_pressed():
		return
	if title:
		get_tree().quit()
		return
	if not Story.busy:
		ui.open_pause()
