extends Node
## Read-only content database: letters, clues, characters, locations, items,
## endings, compiled dialogue, and per-scene art metadata.

const DlgParser := preload("res://src/core/dlg_parser.gd")

const DIALOGUE_FILES := ["story", "odile", "mari", "june", "tobias", "felix", "bram", "objects", "outcomes"]

var letters: Dictionary = {}
var letter_order: Array = []
var clues: Dictionary = {}
var characters: Dictionary = {}
var locations: Dictionary = {}
var items: Dictionary = {}
var endings: Dictionary = {}
var dialogue: Dictionary = {}
var _meta_cache: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	letters.clear()
	letter_order.clear()
	var arr = _json("res://data/letters.json")
	if arr is Array:
		for l in arr:
			letters[l.id] = l
			letter_order.append(l.id)
	clues = _dict(_json("res://data/clues.json"))
	characters = _dict(_json("res://data/characters.json"))
	locations = _dict(_json("res://data/locations.json"))
	items = _dict(_json("res://data/items.json"))
	endings = _dict(_json("res://data/endings.json"))
	dialogue.clear()
	for f in DIALOGUE_FILES:
		DlgParser.parse_file("res://data/dialogue/%s.dlg" % f, dialogue)


func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Data: missing %s" % path)
		return null
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	if v == null:
		push_error("Data: invalid JSON in %s" % path)
	return v


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


# ─── Lookups ─────────────────────────────────────────────────────────

func letter(id: String) -> Dictionary:
	return letters.get(id, {})


func clue(id: String) -> Dictionary:
	return clues.get(id, {})


func clue_supports(clue_id: String, letter_id: String) -> Array:
	var s = clue(clue_id).get("supports", [])
	if s is Dictionary:
		return s.get(letter_id, [])
	return s


func clue_refutes(clue_id: String, letter_id: String) -> Array:
	var r = clue(clue_id).get("refutes", [])
	if r is Dictionary:
		return r.get(letter_id, [])
	return r


func char_name(id: String) -> String:
	if id == "memorial":
		return "The Marguerite memorial"
	return characters.get(id, {}).get("name", id.capitalize())


func char_first_name(id: String) -> String:
	if id == "memorial":
		return "the memorial"
	if id == "wren":
		return "yourself"
	var n := char_name(id)
	return n.split(" ")[0]


func char_color(id: String) -> Color:
	return Color(characters.get(id, {}).get("color", "#d8d0c0"))


func item_name(id: String) -> String:
	return items.get(id, {}).get("name", id.capitalize())


## Art metadata emitted by tools/art (layers, props, anchors).
func meta(scene_id: String) -> Dictionary:
	if _meta_cache.has(scene_id):
		return _meta_cache[scene_id]
	var path := "res://assets/art/scenes/%s/meta.json" % scene_id
	var m := {}
	if FileAccess.file_exists(path):
		m = _dict(_json(path))
	_meta_cache[scene_id] = m
	return m


## Clues (in the order they appear in the database) belonging to a letter.
func clues_for_letter(letter_id: String) -> Array:
	var out: Array = []
	for cid in clues.keys():
		if letter_id in clues[cid].get("letters", []):
			out.append(cid)
	return out
