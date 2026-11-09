extends Node
## All mutable game state, plus save/load. Content lives in Data; rules in Story.

signal state_changed
signal clue_found(id: String)
signal item_changed(id: String, gained: bool)
signal letter_changed(id: String)
signal objective_changed(text: String)

const SAVE_VERSION := 2
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
	var fl: Variant = d.get("flags", null)
	if fl is Dictionary:
		for k in fl:
			flags[k] = fl[k]
	# JSON turns ints into floats; restore integer-valued counters.
	for k in ["night", "hope", "lamp_sequence"]:
		if flags.has(k):
			flags[k] = int(flags[k])
	clues = _array(d.get("clues", []))
	items = _array(d.get("items", []))
	letters = {}
	var ld: Variant = d.get("letters", {})
	if ld is Dictionary:
		for id in ld:
			var e: Variant = ld[id]
			if e is Dictionary and Data.letters.has(id):
				letters[id] = {"state": str(e.get("state", "")), "to": str(e.get("to", "")), "read": bool(e.get("read", false))}
	asked = d.get("asked", {}) if d.get("asked", {}) is Dictionary else {}
	examined = d.get("examined", {}) if d.get("examined", {}) is Dictionary else {}
	location = str(d.get("location", "post_office"))
	spawn = str(d.get("spawn", "default"))
	var pp = d.get("player_pos", null)
	player_pos = Vector2(pp[0], pp[1]) if pp is Array and pp.size() == 2 else null
	objective = str(d.get("objective", ""))
	play_time = float(d.get("play_time", 0.0))
	unseen_clues = 0
	unseen_letters = 0
	in_game = true
	state_changed.emit()


func _array(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			var sx := str(x)
			if not sx in out:
				out.append(sx)
	return out


func _slot_path(slot: String) -> String:
	return "user://save_%s.json" % slot


## Writes a save safely: to a temporary file first, then swapped in, with the
## previous version kept as a backup. A save can't be lost to a crash or a
## phone switching off halfway through writing.
func save_game(slot: String, data: Dictionary = {}) -> bool:
	var d: Dictionary = data if not data.is_empty() else to_dict()
	d["version"] = SAVE_VERSION
	d["saved_at"] = Time.get_unix_time_from_system()
	var path := _slot_path(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: %s" % slot)
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	# Only replace the real save once the new one reads back correctly.
	var check: Variant = JSON.parse_string(FileAccess.get_file_as_string(tmp))
	if not (check is Dictionary):
		push_warning("Save verify failed: %s" % slot)
		return false
	if FileAccess.file_exists(path):
		var bak := path.replace(".json", ".bak.json")
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(path, bak)
	if DirAccess.rename_absolute(tmp, path) != OK:
		# Couldn't swap files: write the save in place instead.
		var direct := FileAccess.open(path, FileAccess.WRITE)
		if direct == null:
			return false
		direct.store_string(JSON.stringify(d))
		direct.close()
	return true


func _read_save(slot: String) -> Variant:
	var path := _slot_path(slot)
	for p in [path, path + ".tmp", path.replace(".json", ".bak.json")]:
		if FileAccess.file_exists(p):
			var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
			if v is Dictionary and v.has("flags"):
				return v
	return null


func load_game(slot: String) -> bool:
	var v: Variant = _read_save(slot)
	if not (v is Dictionary):
		return false
	from_dict(v)
	return true


func has_save(slot: String) -> bool:
	var p := _slot_path(slot)
	return FileAccess.file_exists(p) or FileAccess.file_exists(p.replace(".json", ".bak.json")) or FileAccess.file_exists(p + ".tmp")


func delete_save(slot: String) -> void:
	var p := _slot_path(slot)
	for f in [p, p.replace(".json", ".bak.json"), p + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


func slot_info(slot: String) -> Dictionary:
	var v: Variant = _read_save(slot)
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


## Autosave. In the middle of a scene this stores the calm moment just before
## the scene began (see Story.busy), never a half-played scene.
func autosave() -> void:
	if not in_game:
		return
	if Story.busy and not Story.stable_state.is_empty():
		save_game("auto", Story.stable_state.duplicate(true))
	else:
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
