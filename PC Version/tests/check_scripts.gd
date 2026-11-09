extends SceneTree
## Loads every script and data file in the project and reports problems.
## Usage: godot --headless --path . -s tests/check_scripts.gd

var errors := 0


func _initialize() -> void:
	await process_frame
	for dir in ["res://src", "res://tests"]:
		_scan(dir)
	_check_content()
	print("CHECK DONE — %d problem(s)" % errors)
	quit(1 if errors > 0 else 0)


func _scan(path: String) -> void:
	for f in DirAccess.get_files_at(path):
		if f.ends_with(".gd"):
			var p := path.path_join(f)
			var s = load(p)
			if s == null or not (s is GDScript) or not s.can_instantiate():
				print("SCRIPT FAIL: ", p)
				errors += 1
	for d in DirAccess.get_directories_at(path):
		_scan(path.path_join(d))


func _check_content() -> void:
	var data = root.get_node("Data")
	var nodes: Dictionary = data.dialogue
	print("dialogue nodes: ", nodes.size(), " letters: ", data.letters.size(), " clues: ", data.clues.size())
	# Every jump / choice target must exist.
	for id in nodes:
		for ins in nodes[id]:
			var targets: Array = []
			if ins.t == "goto":
				targets.append(ins.target)
			elif ins.t == "choice":
				for o in ins.options:
					targets.append(o.target)
			elif ins.t == "cmd" and ins.cmd == "run":
				targets.append(ins.args[0])
			for t in targets:
				if t != "END" and not nodes.has(t):
					print("MISSING TARGET: %s -> %s" % [id, t])
					errors += 1
			if ins.t == "cmd" and ins.cmd in ["clue"]:
				if not data.clues.has(ins.args[0]):
					print("UNKNOWN CLUE: %s in %s" % [ins.args[0], id])
					errors += 1
			if ins.t == "cmd" and ins.cmd in ["item", "take"]:
				if not data.items.has(ins.args[0]):
					print("UNKNOWN ITEM: %s in %s" % [ins.args[0], id])
					errors += 1
			if ins.t == "cmd" and ins.cmd in ["arrive", "fade_letter", "return_letter", "give_letter", "read"]:
				if not data.letters.has(ins.args[0]):
					print("UNKNOWN LETTER: %s in %s" % [ins.args[0], id])
					errors += 1
			if ins.t == "line" and not data.characters.has(ins.who):
				print("UNKNOWN SPEAKER: %s in %s" % [ins.who, id])
				errors += 1
	# Letters: outcome nodes and clue markup
	var re := RegEx.new()
	re.compile("\\[\\[[^|\\]]+\\|([a-z0-9_]+)\\]\\]")
	for lid in data.letters:
		var L: Dictionary = data.letters[lid]
		for who in L.get("outcomes", {}):
			var n: String = L.outcomes[who].get("node", "")
			if n != "" and not nodes.has(n):
				print("MISSING OUTCOME NODE: ", n)
				errors += 1
		for m in re.search_all(L.get("body", "") + L.get("signature", "")):
			if not data.clues.has(m.get_string(1)):
				print("UNKNOWN CLUE IN LETTER %s: %s" % [lid, m.get_string(1)])
				errors += 1
		for d in L.get("envelope", {}).get("details", []):
			if d.get("clue", "") != "" and not data.clues.has(d.clue):
				print("UNKNOWN ENVELOPE CLUE: ", d.clue)
				errors += 1
	# Locations: object nodes
	for loc in data.locations:
		for o in data.locations[loc].get("objects", []):
			if o.has("node") and not nodes.has(o.node):
				print("MISSING OBJECT NODE: %s.%s -> %s" % [loc, o.id, o.node])
				errors += 1
			for c in o.get("clues", []):
				if not data.clues.has(c):
					print("UNKNOWN OBJECT CLUE: ", c)
					errors += 1
		for p in data.locations[loc].get("npcs", []):
			if not nodes.has(p.id + ".talk"):
				print("MISSING TALK NODE: ", p.id)
				errors += 1
	# Every condition must parse.
	var story = root.get_node("Story")
	for id in nodes:
		for ins in nodes[id]:
			if ins.has("if"):
				story.eval(ins["if"])
			if ins.t == "choice":
				for o in ins.options:
					if o.has("if"):
						story.eval(o["if"])
