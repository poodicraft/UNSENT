extends Node
## A headless stand-in for UIRoot used by automated playthroughs. It answers
## every UI request instantly, following a scripted policy:
##   plan      — queue of hub actions for NPC conversations:
##               ["ask", clue_id] / ["deliver", letter_id] / ["bye"]
##   prefer    — substrings preferred when picking a dialogue choice
## and keeps a transcript for assertions.

var transcript: Array = []
var plan: Array = []
var prefer: Array = []
var dialogue: Node
var hud: Node
var root: Control
var screens: Control
var overlay: Node
var _pending_ask := ""
var _pending_letter := ""
## Fixture capture: text marker -> fixture name. When a line containing the
## marker is shown, the current game state is written to snap_dir.
var snap_markers: Dictionary = {}
var snap_dir := ""


func snap(name: String) -> void:
	if snap_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(snap_dir)
	var f := FileAccess.open(snap_dir.path_join(name + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	f.close()
	print("    [fixture] ", name)


func _check_snap(text: String) -> void:
	for m in snap_markers.keys():
		if text.find(m) >= 0:
			snap(snap_markers[m])
			snap_markers.erase(m)


class StubDialogue extends Node:
	var owner_ui: Node
	var _open := false

	func say(who: String, expr: String, text: String) -> void:
		_open = true
		owner_ui.transcript.append("%s: %s" % [who, text])
		owner_ui._check_snap(text)
		await get_tree().process_frame

	func choose(options: Array, hub := false) -> int:
		_open = true
		await get_tree().process_frame
		if hub:
			return owner_ui._hub_choice(options)
		for p in owner_ui.prefer:
			for i in options.size():
				if String(options[i]).findn(p) >= 0:
					owner_ui.transcript.append("  > " + options[i])
					return i
		owner_ui.transcript.append("  > " + options[0])
		return 0

	func close() -> void:
		_open = false

	func is_open() -> bool:
		return _open


class StubHud extends Node:
	func show_location(_n: String) -> void:
		pass

	func set_cinematic(_on: bool) -> void:
		pass

	func bump_badge() -> void:
		pass

	func clear_badge() -> void:
		pass

	func _on_objective(_t: String) -> void:
		pass

	func refresh_badge() -> void:
		pass


func _init() -> void:
	dialogue = StubDialogue.new()
	dialogue.owner_ui = self
	add_child(dialogue)
	hud = StubHud.new()
	add_child(hud)
	root = Control.new()
	add_child(root)
	screens = Control.new()
	add_child(screens)
	overlay = Node.new()
	overlay.add_child(Node.new())
	add_child(overlay)


func _hub_choice(options: Array) -> int:
	var action: Array = plan.pop_front() if not plan.is_empty() else ["bye"]
	match action[0]:
		"ask":
			_pending_ask = action[1]
			return options.find("Ask about…")
		"deliver":
			_pending_letter = action[1]
			return options.find("Deliver a letter…")
	return options.find("Goodbye")


func set_world_ui(_on: bool) -> void:
	pass


func modal_open() -> bool:
	return false


func push_modal(_m) -> void:
	pass


func pop_modal(_m) -> void:
	pass


func back_pressed() -> bool:
	return false


func dismiss_all() -> void:
	await get_tree().process_frame


func open_credits() -> void:
	pass


func fade(_out: bool, _secs := 0.8) -> void:
	await get_tree().process_frame


func fade_instant(_a: float) -> void:
	pass


func letterbox(_on: bool) -> void:
	pass


func flash() -> void:
	pass


func ripple() -> void:
	transcript.append("[ripple]")


func toast(text: String, _icon := "") -> void:
	transcript.append("[toast] " + text)


func toast_clue(cid: String) -> void:
	transcript.append("[clue] " + cid)


func card(title: String, subtitle: String, _on_black := false) -> void:
	transcript.append("[card] %s — %s" % [title, subtitle])
	_check_snap("[card] " + title)
	await get_tree().process_frame


func consequence(title: String, subtitle: String) -> void:
	transcript.append("[consequence] %s" % title)
	await get_tree().process_frame


func delivery_flourish(letter_id: String, who: String) -> void:
	transcript.append("[delivered] %s -> %s" % [letter_id, who])
	await get_tree().process_frame


## Reading a letter: a thorough reader notes every underlined phrase and
## every envelope detail.
func open_letter(letter_id: String) -> void:
	GameState.mark_read(letter_id)
	_check_snap("[reading] " + letter_id)
	var L: Dictionary = Data.letter(letter_id)
	var re := RegEx.new()
	re.compile("\\[\\[[^|\\]]+\\|([a-z0-9_]+)\\]\\]")
	for m in re.search_all(L.get("body", "") + L.get("signature", "")):
		Story._give_clue(m.get_string(1))
	for d in L.get("envelope", {}).get("details", []):
		if d.get("clue", "") != "":
			Story._give_clue(d.clue)
	await get_tree().process_frame


func open_satchel(_tab := "letters") -> void:
	for id in GameState.held_letters():
		if not GameState.is_read(id):
			await open_letter(id)
			await Story.letter_closed(id)


func ask_panel(_npc: String) -> String:
	await get_tree().process_frame
	var c := _pending_ask
	_pending_ask = ""
	return c


func pick_letter(_npc: String) -> String:
	await get_tree().process_frame
	var l := _pending_letter
	_pending_letter = ""
	return l


func confirm_delivery(letter_id: String, who: String) -> bool:
	await get_tree().process_frame
	var ok := Story.can_deliver(letter_id, who)
	if not ok:
		transcript.append("[refused] %s -> %s (evidence %s)" % [letter_id, who, Story.evidence(letter_id, who)])
	return ok


func open_pause() -> void:
	pass


func open_settings() -> void:
	pass


func open_saves(_mode: String) -> String:
	return ""


func confirm(_q: String, _y := "", _n := "") -> bool:
	return true
