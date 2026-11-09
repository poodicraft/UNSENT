extends RefCounted
## A generic auto-player. From ANY game state it plays legally to an ending:
## it walks through real exits, finds where each clue can be learned by
## reading the dialogue data, delivers letters to their true recipients,
## sleeps when allowed, and plays the Lantern Night finale.
## Used by tests/playthrough.gd (--playtest=compat) to prove that saves can
## always be continued.

var test: Node          # the playthrough node (provides goto/examine/talk)
var main: Node
var ui: Node
var log_lines: Array = []
var _clue_sources: Dictionary = {}   # clue -> [node ids]
var _attempts: Dictionary = {}       # action key -> times tried


func _init(t: Node) -> void:
	test = t
	main = t.main
	ui = t.ui
	for node_id in Data.dialogue:
		for ins in Data.dialogue[node_id]:
			if ins.t == "cmd" and ins.cmd == "clue":
				var c: String = ins.args[0]
				if not _clue_sources.has(c):
					_clue_sources[c] = []
				_clue_sources[c].append(node_id)


func f(name: String) -> Variant:
	return GameState.get_flag(name, false)


func note(s: String) -> void:
	log_lines.append(s)


## Plays until an ending. Returns the ending id, or "" if it got stuck.
func run_to_end(max_steps := 300) -> String:
	for step in max_steps:
		if main.last_ending != "":
			return main.last_ending
		var acted: bool = await _act()
		if not acted:
			note("STUCK at night %d in %s" % [int(f("night")), GameState.location])
			return ""
	note("gave up after %d steps" % max_steps)
	return ""


func _tried(key: String) -> int:
	_attempts[key] = int(_attempts.get(key, 0)) + 1
	return _attempts[key]


func _act() -> bool:
	# Unread letters first (a thorough player reads everything).
	for id in GameState.held_letters():
		if not GameState.is_read(id):
			note("read " + id)
			await ui.open_letter(id)
			await Story.letter_closed(id)
			return true
	if f("lantern_night"):
		return await _finale()
	if Story.chute_waiting():
		note("collect chute")
		await go("post_office")
		await test.examine("chute")
		return true
	if GameState.has_item("mari_reply") and _tried("post") < 3:
		note("post reply")
		await go("post_office")
		await test.examine("outbox")
		return true
	for id in GameState.held_letters():
		var L: Dictionary = Data.letter(id)
		if L.get("auto_keep", false):
			continue
		var target := _true_recipient(id)
		if target == "":
			continue
		if Story.can_deliver(id, target):
			if _tried("deliver:" + id) > 3:
				continue
			note("deliver %s -> %s" % [id, target])
			await deliver(id, target)
			return true
		if await _gather(id, target):
			return true
	if Story.can_sleep():
		note("sleep (night %d)" % int(f("night")))
		await go("post_office")
		await test.talk("odile", [], ["Sleep"])
		return true
	# Explore: go where an arrival scene would play, or anywhere unvisited.
	for loc in Data.locations:
		if loc == GameState.location:
			continue
		var fires := false
		for e in Data.locations[loc].get("on_enter", []):
			if Story.eval(e.get("if", "true")):
				fires = true
		if (fires or not f("visited_" + loc)) and can_reach(loc) and _tried("explore:" + loc) <= 2:
			note("explore " + loc)
			await go(loc)
			return true
	return false


func _true_recipient(id: String) -> String:
	var outs: Dictionary = Data.letter(id).get("outcomes", {})
	for who in outs:
		if outs[who].get("correct", false):
			return who
	return ""


# ─── Evidence gathering ──────────────────────────────────────────────

func _gather(letter_id: String, target: String) -> bool:
	for cid in Data.clues_for_letter(letter_id):
		if GameState.has_clue(cid):
			continue
		if not target in Data.clue_supports(cid, letter_id):
			continue
		for node_id in _clue_sources.get(cid, []):
			var key := "src:%s:%s" % [cid, node_id]
			if int(_attempts.get(key, 0)) >= 2:
				continue
			if await _visit_source(node_id, key):
				return true
	return false


func _visit_source(node_id: String, key: String) -> bool:
	var parts := node_id.split(".")
	# "<npc>.ask.<clue>" — ask the npc about a clue we already have
	if parts.size() == 3 and parts[1] == "ask":
		var npc := parts[0]
		var about := parts[2]
		if not GameState.has_clue(about):
			return false
		var loc := npc_location(npc)
		if loc == "" or not await can_reach(loc):
			return false
		_tried(key)
		note("ask %s about %s" % [npc, about])
		await go(loc)
		await test.talk(npc, [["ask", about]], ["That's all", "Nothing", "See you", "I'll leave", "I'll let you", "Not yet"])
		return true
	# An examinable object (node or one of its sub-nodes)
	for loc in Data.locations:
		for o in Data.locations[loc].get("objects", []):
			var n: String = o.get("node", "")
			if n != "" and (node_id == n or node_id.begins_with(n + ".")):
				if o.has("if") and not Story.eval(o["if"]):
					continue
				if not await can_reach(loc):
					continue
				_tried(key)
				note("examine %s.%s" % [loc, o.id])
				await go(loc)
				await test.examine(o.id, ["Not now", "Not yet"])
				return true
	# An NPC's own conversation (e.g. a first meeting)
	var npc2 := parts[0]
	if Data.characters.has(npc2):
		var loc2 := npc_location(npc2)
		if loc2 != "" and await can_reach(loc2):
			_tried(key)
			note("talk %s (for %s)" % [npc2, node_id])
			await go(loc2)
			await test.talk(npc2, [], ["That's all", "Nothing", "See you", "I'll leave", "I'll let you", "Not yet"])
			return true
	return false


# ─── Movement through real exits ─────────────────────────────────────

func npc_location(npc: String) -> String:
	if Story.world and Story.world.npc(npc) != null:
		return GameState.location
	for loc in Data.locations:
		for p in Data.locations[loc].get("npcs", []):
			if p.id == npc and Story.eval(p.get("if", "true")):
				return loc
	return ""


func _edges(loc: String) -> Array:
	var out: Array = []
	for o in Data.locations[loc].get("objects", []):
		if o.has("exit"):
			out.append({"to": o.exit.to, "obj": o.id, "cond": o.exit.get("if", "")})
	if loc == "cliff":
		out.append({"to": "lamp_room", "obj": "lighthouse_door", "cond": "has_item(\"lighthouse_key\") or ($lantern_night and lamp_keeper() != \"nobody\")"})
	return out


func _path(from: String, to: String) -> Array:
	var prev := {from: null}
	var q := [from]
	while not q.is_empty():
		var cur: String = q.pop_front()
		if cur == to:
			break
		for e in _edges(cur):
			if prev.has(e.to):
				continue
			if e.cond != "" and not Story.eval(e.cond):
				continue
			prev[e.to] = {"from": cur, "obj": e.obj}
			q.append(e.to)
	if not prev.has(to):
		return []
	var steps: Array = []
	var c := to
	while prev[c] != null:
		steps.push_front(prev[c].obj)
		c = prev[c].from
	return steps


func can_reach(loc: String) -> bool:
	return GameState.location == loc or not _path(GameState.location, loc).is_empty()


func go(loc: String) -> void:
	var guard := 0
	while GameState.location != loc and guard < 8:
		guard += 1
		var steps := _path(GameState.location, loc)
		if steps.is_empty():
			note("no path %s -> %s" % [GameState.location, loc])
			return
		var obj_id: String = steps[0]
		if obj_id == "lighthouse_door":
			await test.examine(obj_id, ["Climb"])
		else:
			await test.examine(obj_id)


func deliver(id: String, who: String) -> void:
	if who == "memorial":
		await go("harbor")
		await test.examine("memorial", ["Leave Felix's letter"])
		return
	if who == "wren":
		await Story.keep_letter(id)
		return
	var loc := npc_location(who)
	await go(loc)
	await test.talk(who, [["deliver", id]], ["That's all", "Nothing", "See you", "I'll leave", "I'll let you"])


# ─── Lantern Night ───────────────────────────────────────────────────

func _finale() -> bool:
	ui.prefer = ["Climb", "Light your own", "Wait here", "Stay", "Let me keep", "Then let me keep the light"]
	if Story.f("lamp_resolved") or Story.f("finale"):
		# Mid-finale: the climax must still be reachable from the harbour.
		if _tried("finale_resume") > 3:
			return false
		note("resume finale at the pier")
		await go("harbor")
		await test.examine("pier_end", ["Wait here"])
		return true
	if Story.lamp_keeper() == "nobody":
		if GameState.location == "lamp_room" and int(f("lamp_sequence")) >= 1:
			note("light the lamp")
			for o in ["valve", "wick", "matchbox"]:
				await test.examine(o)
				if main.last_ending != "":
					break
			return true
		if not GameState.has_item("lighthouse_key"):
			if _tried("ask_key") > 2:
				return false
			note("ask Tobias for the key")
			await go("cliff")
			await test.talk("tobias", [], ["Let me keep", "Then let me keep the light"])
			return true
		note("climb to the lamp room")
		await go("lamp_room")
		return true
	if _tried("pier_wait") > 3:
		return false
	note("wait at the end of the pier")
	await go("harbor")
	await test.examine("pier_end", ["Wait here"])
	return true
