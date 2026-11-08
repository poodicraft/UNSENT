extends Node
## All mutable game state, plus save/load. Content lives in Data; rules in Story.

signal state_changed
signal clue_found(id: String)
signal item_changed(id: String, gained: bool)
signal letter_changed(id: String)
signal objective_changed(text: String)

const SAVE_VERSION := 1
const SLOTS := ["auto", "1", "2", "3"]
const META_PATH := "user://meta.json"

## Letter states: "" (not arrived), "chute", "held", "delivered", "kept", "faded"
var flags: Dictionary = {}
var clues: Array = []
var items: Array = []
var letters: Dictionary = {}
var asked: Dictionary = {}
var examined: Dictionary = {}
var location := "harbor"
var spawn := "intro"
var player_pos: Variant = null
var objective := ""
var play_time := 0.0
var unseen_clues := 0
var unseen_letters := 0
var in_game := false

## Persistent across playthroughs.
var endings_seen: Array = []


func _ready() -> void:
	_load_meta()
	new_game()
	in_game = false


func _process(delta: float) -> void:
	if in_game:
		play_time += delta


func new_game() -> void:
	flags = {"night": 1, "hope": 0, "june_path": "", "lamp_sequence": 0}
	clues = []
	items = []
	letters = {}
	asked = {}
	examined = {}
	location = "harbor"
	spawn = "intro"
	player_pos = null
	objective = ""
	play_time = 0.0
	unseen_clues = 0
	unseen_letters = 0
	in_game = true
	state_changed.emit()


# ─── Flags ───────────────────────────────────────────────────────────

func get_flag(name: String, default: Variant = false) -> Variant:
	return flags.get(name, default)


func set_flag(name: String, value: Variant = true) -> void:
	flags[name] = value
	state_changed.emit()


func add_flag(name: String, amount: float) -> void:
	var v = flags.get(name, 0)
	if not (v is int or v is float):
		v = 0
	var nv = v + amount
	flags[name] = int(nv) if (v is int and is_equal_approx(amount, round(amount))) else nv
	state_changed.emit()


# ─── Clues & items ───────────────────────────────────────────────────

func has_clue(id: String) -> bool:
	return id in clues


func add_clue(id: String) -> bool:
	if id in clues or not Data.clues.has(id):
		return false
	clues.append(id)
	unseen_clues += 1
	clue_found.emit(id)
	state_changed.emit()
	return true


func has_item(id: String) -> bool:
	return id in items


func add_item(id: String) -> void:
	if id in items:
		return
	items.append(id)
	item_changed.emit(id, true)
	state_changed.emit()


func remove_item(id: String) -> void:
	if id in items:
		items.erase(id)
		item_changed.emit(id, false)
		state_changed.emit()


# ─── Letters ─────────────────────────────────────────────────────────

func letter_state(id: String) -> String:
	return letters.get(id, {}).get("state", "")


func letter_to(id: String) -> String:
	return letters.get(id, {}).get("to", "")


func is_read(id: String) -> bool:
	return letters.get(id, {}).get("read", false)


func _ensure(id: String) -> Dictionary:
	if not letters.has(id):
		letters[id] = {"state": "", "to": "", "read": false}
	return letters[id]


func arrive(id: String) -> bool:
	if not Data.letters.has(id) or letter_state(id) != "":
		return false
	_ensure(id).state = "chute"
	letter_changed.emit(id)
	state_changed.emit()
	return true


func give_letter(id: String) -> void:
	_ensure(id).state = "held"
	unseen_letters += 1
	letter_changed.emit(id)
	state_changed.emit()


func chute_letters() -> Array:
	var out: Array = []
	for id in Data.letter_order:
		if letter_state(id) == "chute":
			out.append(id)
	return out


func collect_chute() -> Array:
	var got := chute_letters()
	for id in got:
		letters[id].state = "held"
		unseen_letters += 1
		letter_changed.emit(id)
	if not got.is_empty():
		state_changed.emit()
	return got


func held_letters() -> Array:
	var out: Array = []
	for id in Data.letter_order:
		if letter_state(id) == "held":
			out.append(id)
	return out


func collected_letters() -> Array:
	var out: Array = []
	for id in Data.letter_order:
		var s := letter_state(id)
		if s != "" and s != "chute":
			out.append(id)
	return out


func mark_read(id: String) -> void:
	_ensure(id).read = true
	state_changed.emit()


func mark_delivered(id: String, to: String) -> void:
	var l := _ensure(id)
	l.state = "kept" if to == "wren" else "delivered"
	l.to = to
	letter_changed.emit(id)
	state_changed.emit()


func return_letter(id: String) -> void:
	var l := _ensure(id)
	l.state = "held"
	l.to = ""
	letter_changed.emit(id)
	state_changed.emit()


func fade_letter(id: String) -> void:
	var l := _ensure(id)
	if l.state in ["held", "chute", ""]:
		l.state = "faded"
		letter_changed.emit(id)
		state_changed.emit()


func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


func mark_asked(npc: String, clue_id: String) -> void:
	asked["%s:%s" % [npc, clue_id]] = true


func was_asked(npc: String, clue_id: String) -> bool:
	return asked.has("%s:%s" % [npc, clue_id])


func mark_examined(obj_id: String) -> void:
	examined[obj_id] = true


# ─── Save / load ─────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"flags": flags, "clues": clues, "items": items, "letters": letters,
		"asked": asked, "examined": examined,
		"location": location, "spawn": spawn,
		"player_pos": [player_pos.x, player_pos.y] if player_pos is Vector2 else null,
		"objective": objective, "play_time": play_time,
		"saved_at": Time.get_unix_time_from_system(),
	}


func from_dict(d: Dictionary) -> void:
	new_game()
	flags = d.get("flags", flags)
	# JSON turns ints into floats; restore integer-valued counters.
	for k in ["night", "hope", "lamp_sequence"]:
		if flags.has(k):
			flags[k] = int(flags[k])
	clues = d.get("clues", [])
	items = d.get("items", [])
	letters = d.get("letters", {})
	asked = d.get("asked", {})
	examined = d.get("examined", {})
	location = d.get("location", "post_office")
	spawn = d.get("spawn", "default")
	var pp = d.get("player_pos", null)
	player_pos = Vector2(pp[0], pp[1]) if pp is Array and pp.size() == 2 else null
	objective = d.get("objective", "")
	play_time = d.get("play_time", 0.0)
	unseen_clues = 0
	unseen_letters = 0
	in_game = true
	state_changed.emit()


func _slot_path(slot: String) -> String:
	return "user://save_%s.json" % slot


func save_game(slot: String) -> bool:
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: %s" % slot)
		return false
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return true


func load_game(slot: String) -> bool:
	if not has_save(slot):
		return false
	var v = JSON.parse_string(FileAccess.get_file_as_string(_slot_path(slot)))
	if not (v is Dictionary):
		return false
	from_dict(v)
	return true


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_save(slot: String) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_slot_path(slot))


func slot_info(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(_slot_path(slot)))
	if not (v is Dictionary):
		return {}
	var fl: Dictionary = v.get("flags", {})
	var delivered := 0
	for id in v.get("letters", {}):
		if v.letters[id].get("state", "") in ["delivered", "kept"]:
			delivered += 1
	return {
		"night": int(fl.get("night", 1)),
		"lantern": fl.get("lantern_night", false),
		"location": v.get("location", ""),
		"play_time": v.get("play_time", 0.0),
		"saved_at": v.get("saved_at", 0),
		"delivered": delivered,
	}


func most_recent_slot() -> String:
	var best := ""
	var best_t := -1.0
	for s in SLOTS:
		var info := slot_info(s)
		if info.is_empty():
			continue
		if float(info.saved_at) > best_t:
			best_t = float(info.saved_at)
			best = s
	return best


func autosave() -> void:
	if in_game:
		save_game("auto")


func record_ending(id: String) -> void:
	if not id in endings_seen:
		endings_seen.append(id)
		_save_meta()


func _load_meta() -> void:
	if FileAccess.file_exists(META_PATH):
		var v = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		if v is Dictionary:
			endings_seen = v.get("endings", [])


func _save_meta() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"endings": endings_seen}))


func wipe_all() -> void:
	for s in SLOTS:
		delete_save(s)
	endings_seen = []
	_save_meta()
