extends Node
## The director: runs dialogue, evaluates conditions, executes story commands,
## and owns the game's rules (evidence, delivery, nights, endings).

signal busy_changed(is_busy: bool)

const DAWN_HOPE := 7

var main: Node = null           # set by main.gd
## True while a scene, conversation or letter follow-up is playing.
## When a scene starts we remember the last calm state of the world: if the
## app is closed mid-scene, that calm state is what gets autosaved, so a save
## never captures a half-finished scene. When the scene ends, we autosave.
var busy := false:
	set(v):
		if busy != v:
			busy = v
			if v:
				stable_state = GameState.to_dict().duplicate(true)
				_last_activity = Time.get_ticks_msec()
			else:
				stable_state = {}
			busy_changed.emit(v)
var stable_state: Dictionary = {}
var _last_activity := 0
var _resume_nodes: Array = []
var _resume_letter := ""

var _expr_cache: Dictionary = {}
var _expr_failed: Dictionary = {}
var _dollar_re: RegEx
var _picks: Dictionary = {}
var _end_requested := false
var _abort := false
var _pending_ending := ""
var _conversation_npc := ""


func _ready() -> void:
	_dollar_re = RegEx.new()
	_dollar_re.compile("\\$([A-Za-z_][A-Za-z0-9_]*)")


var ui: Node:
	get:
		return main.ui if main else null

var world: Node:
	get:
		return main.world if main else null


# ═══════════════════════════════════════════════════════════════════
#  Conditions
# ═══════════════════════════════════════════════════════════════════

func eval(cond: String) -> bool:
	cond = cond.strip_edges()
	if cond == "" or cond == "true":
		return true
	if cond == "false":
		return false
	var e: Expression = _expr_cache.get(cond)
	if e == null:
		e = Expression.new()
		var src := _dollar_re.sub(cond, "f(\"$1\")", true)
		if e.parse(src) != OK:
			if not _expr_failed.has(cond):
				push_warning("Story: bad condition '%s': %s" % [cond, e.get_error_text()])
				_expr_failed[cond] = true
			return false
		_expr_cache[cond] = e
	var r = e.execute([], self, false)
	if e.has_execute_failed():
		if not _expr_failed.has(cond):
			push_warning("Story: condition failed '%s': %s" % [cond, e.get_error_text()])
			_expr_failed[cond] = true
		return false
	return bool(r) if (r is bool or r is int or r is float) else (r != null and str(r) != "")


# Functions callable from conditions ---------------------------------

func f(name: String) -> Variant:
	return GameState.get_flag(name, false)

func has_clue(id: String) -> bool:
	return GameState.has_clue(id)

func has_item(id: String) -> bool:
	return GameState.has_item(id)

func arrived(id: String) -> bool:
	return GameState.letter_state(id) != ""

func held(id: String) -> bool:
	return GameState.letter_state(id) == "held"

func read_letter(id: String) -> bool:
	return GameState.is_read(id)

func delivered(id: String) -> String:
	var s := GameState.letter_state(id)
	return GameState.letter_to(id) if s in ["delivered", "kept"] else ""

func resolved(id: String) -> bool:
	return GameState.letter_state(id) in ["delivered", "kept", "faded"]

func delivered_count() -> int:
	var n := 0
	for id in GameState.letters:
		if GameState.letter_state(id) in ["delivered", "kept"]:
			n += 1
	return n

func chute_waiting() -> bool:
	return not GameState.chute_letters().is_empty()

func met(id: String) -> bool:
	return bool(f("met_" + id))

func pick(n: int) -> int:
	if not _picks.has(n):
		_picks[n] = randi() % maxi(n, 1)
	return _picks[n]

func lamp_keeper() -> String:
	if f("june_path") == "stay":
		return "june"
	if not f("tobias_knows"):
		return "tobias"
	return "nobody"

func lamp_glowing() -> bool:
	if f("lamp_lit"):
		return true
	if not f("lantern_night"):
		return true
	return not (f("auto_lamp_failed") or f("lamp_failed"))

func can_sleep() -> bool:
	if f("lantern_night"):
		return false
	match int(f("night")):
		1:
			return delivered("blue_door") == "mari"
		2:
			var n := 0
			if resolved("lamp_lit"):
				n += 1
			if resolved("far_shore") or resolved("lamp_room"):
				n += 1
			if resolved("umbrella"):
				n += 1
			return n >= 2
		3:
			return resolved("eleven_fifty_two")
	return false


# ═══════════════════════════════════════════════════════════════════
#  Evidence & delivery rules
# ═══════════════════════════════════════════════════════════════════

func evidence(letter_id: String, who: String) -> Dictionary:
	var sup: Array = []
	var ref: Array = []
	for cid in GameState.clues:
		if not letter_id in Data.clue(cid).get("letters", []):
			continue
		if who in Data.clue_supports(cid, letter_id):
			sup.append(cid)
		if who in Data.clue_refutes(cid, letter_id):
			ref.append(cid)
	return {"support": sup, "refute": ref}


func can_deliver(letter_id: String, who: String) -> bool:
	var L := Data.letter(letter_id)
	if L.is_empty() or not who in L.get("candidates", []):
		return false
	return evidence(letter_id, who).support.size() >= int(L.get("min_evidence", 2))


## Candidates the player has some evidence for (for the letter reader).
func leads(letter_id: String) -> Array:
	var out: Array = []
	var L := Data.letter(letter_id)
	for who in L.get("candidates", []):
		var ev := evidence(letter_id, who)
		if ev.support.size() > 0 or ev.refute.size() > 0:
			out.append({"who": who, "support": ev.support.size(), "refute": ev.refute.size(),
				"ready": ev.support.size() >= int(L.get("min_evidence", 2))})
	return out


func letter_origin_known(letter_id: String) -> String:
	var L := Data.letter(letter_id)
	if L.get("auto_keep", false):
		return L.get("origin", "")
	for cid in GameState.clues:
		var c := Data.clue(cid)
		if letter_id in c.get("letters", []) and c.has("origin"):
			return c.origin
	return ""


func clue_obtainable(cid: String) -> bool:
	for lid in Data.clue(cid).get("letters", []):
		if GameState.letter_state(lid) in ["held", "chute"]:
			return true
	return false


func object_has_news(obj: Dictionary) -> bool:
	if not Settings.show_hints or obj.has("exit"):
		return false
	if obj.get("id", "") == "chute":
		return chute_waiting()
	if obj.get("id", "") == "outbox" and GameState.has_item("mari_reply"):
		return true
	if not GameState.examined.has(obj.get("id", "")):
		return true
	for c in obj.get("clues", []):
		if not GameState.has_clue(c) and clue_obtainable(c):
			return true
	return false


## Letters the player could hand over to `who` right now (held, not self-addressed).
func deliverable_letters() -> Array:
	var out: Array = []
	for id in GameState.held_letters():
		var L := Data.letter(id)
		if L.get("auto_keep", false):
			continue
		out.append(id)
	return out


# ═══════════════════════════════════════════════════════════════════
#  Running dialogue
# ═══════════════════════════════════════════════════════════════════

## Runs a node as a standalone sequence (cutscene / examine).
func run(node_id: String) -> void:
	if busy:
		await _exec(node_id)
		return
	busy = true
	_end_requested = false
	_abort = false
	await _exec(node_id)
	await _finish()


func _finish() -> void:
	if ui:
		ui.dialogue.close()
		ui.letterbox(false)
	busy = false
	_conversation_npc = ""
	if _pending_ending != "":
		var e := _pending_ending
		_pending_ending = ""
		await main.play_ending(e)
		return
	check_arrivals()
	if world:
		world.refresh()
	# The scene is over and the world is calm: keep the progress.
	if main and main.title == null:
		GameState.autosave()


## Executes a node chain (following -> jumps). Returns when it ends.
func _exec(node_id: String) -> void:
	var guard := 0
	while node_id != "" and node_id != "END" and not _abort:
		guard += 1
		if guard > 200:
			push_error("Story: jump loop at %s" % node_id)
			return
		if not Data.dialogue.has(node_id):
			push_warning("Story: missing node '%s'" % node_id)
			return
		_picks.clear()
		var next := ""
		for ins in Data.dialogue[node_id]:
			if _abort or _end_requested:
				return
			if ins.has("if") and not eval(ins["if"]):
				continue
			match ins.t:
				"line":
					await _say(ins.who, ins.expr, ins.text)
				"cmd":
					await _cmd(ins.cmd, ins.args)
				"goto":
					next = ins.target
					break
				"choice":
					var opts: Array = []
					for o in ins.options:
						if not o.has("if") or eval(o["if"]):
							opts.append(o)
					if opts.is_empty():
						continue
					var texts: Array = []
					for o in opts:
						texts.append(o.text)
					var idx: int = await ui.dialogue.choose(texts)
					Audio.sfx("ui_tap", -6.0)
					next = opts[clampi(idx, 0, opts.size() - 1)].target
					break
		if next == "END":
			return
		node_id = next


func _say(who: String, expr: String, text: String) -> void:
	_last_activity = Time.get_ticks_msec()
	var actor = world.npc(who) if world else null
	if actor:
		actor.set_talking(true, expr)
	elif who == "wren" and world and world.player:
		world.player.set_talking(true, expr)
	await ui.dialogue.say(who, expr, text)
	if actor and is_instance_valid(actor):
		actor.set_talking(false, expr)
	elif who == "wren" and world and world.player:
		world.player.set_talking(false, expr)


## Full NPC conversation: their talk node, then the Ask / Deliver hub.
func talk_to(npc_id: String) -> void:
	if busy:
		return
	busy = true
	_end_requested = false
	_abort = false
	_conversation_npc = npc_id
	var actor = world.npc(npc_id) if world else null
	if actor and world.player:
		actor.face_toward(world.player.position.x)
		world.player.face_toward(actor.position.x)
	await _exec(npc_id + ".talk")
	while not _end_requested and not _abort:
		var opts: Array = []
		var ids: Array = []
		if not GameState.clues.is_empty():
			opts.append("Ask about…")
			ids.append("ask")
		if not deliverable_letters().is_empty():
			opts.append("Deliver a letter…")
			ids.append("deliver")
		opts.append("Goodbye")
		ids.append("bye")
		var idx: int = await ui.dialogue.choose(opts, true)
		var pick_id: String = ids[clampi(idx, 0, ids.size() - 1)]
		if pick_id == "ask":
			Audio.sfx("ui_open", -4.0)
			var cid: String = await ui.ask_panel(npc_id)
			if cid == "":
				continue
			GameState.mark_asked(npc_id, cid)
			var node := "%s.ask.%s" % [npc_id, cid]
			if not Data.dialogue.has(node):
				node = npc_id + ".ask.default"
			await _exec(node)
			_end_requested = false
		elif pick_id == "deliver":
			Audio.sfx("ui_open", -4.0)
			var lid: String = await ui.pick_letter(npc_id)
			if lid == "":
				continue
			var ok: bool = await ui.confirm_delivery(lid, npc_id)
			if ok:
				await deliver(lid, npc_id)
				break
		else:
			break
	await _finish()


func interact(obj: Dictionary) -> void:
	if busy:
		return
	GameState.mark_examined(obj.get("id", ""))
	if obj.has("exit"):
		var ex: Dictionary = obj.exit
		if ex.has("if") and not eval(ex["if"]):
			if ex.has("locked_node"):
				await run(ex.locked_node)
			return
		Audio.sfx("door", -6.0)
		await main.goto_location(ex.to, ex.get("spawn", "default"), true)
		return
	if obj.has("node"):
		await run(obj.node)
	if world:
		world.refresh()


## Keeping a letter for yourself (delivering it to "wren").
func keep_letter(letter_id: String) -> void:
	if busy:
		return
	busy = true
	_end_requested = false
	_abort = false
	var ok: bool = await ui.confirm_delivery(letter_id, "wren")
	if ok:
		await deliver(letter_id, "wren")
	await _finish()


## Opens the evidence panel for delivering to an object/place (e.g. the memorial).
func try_deliver(letter_id: String, who: String) -> void:
	var ok: bool = await ui.confirm_delivery(letter_id, who)
	if ok:
		await deliver(letter_id, who)


func deliver(letter_id: String, who: String) -> void:
	var L := Data.letter(letter_id)
	var oc: Dictionary = L.get("outcomes", {}).get(who, {})
	GameState.mark_delivered(letter_id, who)
	GameState.add_flag("hope", int(oc.get("hope", 0)))
	GameState.set_flag("delivered_any", true)
	Audio.sfx("deliver")
	if ui:
		await ui.delivery_flourish(letter_id, who)
	var node: String = oc.get("node", "")
	if node != "":
		await _exec(node)
		_end_requested = true
	check_arrivals()
	if can_sleep() and not GameState.has_item("mari_reply"):
		GameState.set_objective("The night's work is done. Return to Odile when you're ready to sleep — or keep exploring.")
	GameState.autosave()


## Called after the player closes a letter (by whoever opened the reader).
## Handles letters addressed to the player and the tutorial follow-up.
func letter_closed(letter_id: String) -> void:
	_check_same_hand()
	var L := Data.letter(letter_id)
	var auto: bool = L.get("auto_keep", false) and GameState.letter_state(letter_id) == "held"
	var tutorial: bool = letter_id == "blue_door" and not f("tutorial_done")
	if not (auto or tutorial):
		return
	if busy:
		await _after_letter_hooks(letter_id)
	else:
		busy = true
		_end_requested = false
		_abort = false
		await _after_letter_hooks(letter_id)
		await _finish()


## True if closing this letter makes the story react (a letter addressed to
## you, or the first night's lesson).
func letter_has_hooks(letter_id: String) -> bool:
	var L := Data.letter(letter_id)
	var auto: bool = L.get("auto_keep", false) and GameState.letter_state(letter_id) == "held"
	var tutorial: bool = letter_id == "blue_door" and not f("tutorial_done")
	return auto or tutorial


## The satchel calls this right before it closes: once every panel is out of
## the way (so the scene that follows can be seen and tapped), it runs the
## letter's follow-up — and keeping the letter, if the player chose that.
func after_satchel_read(letter_id: String, keep: bool, satchel: Node = null) -> void:
	var guard := 0
	while is_instance_valid(satchel) and satchel.is_inside_tree() and not satchel.is_queued_for_deletion() and guard < 300:
		guard += 1
		await get_tree().process_frame
	if ui:
		await ui.dismiss_all()
	await letter_closed(letter_id)
	if keep:
		await keep_letter(letter_id)


func _check_same_hand() -> void:
	if GameState.is_read("far_shore") and GameState.is_read("lamp_room"):
		_give_clue("c34_same_hand")


func _give_clue(cid: String) -> void:
	if GameState.has_clue(cid) or not clue_obtainable(cid):
		return
	GameState.add_clue(cid)
	Audio.sfx("clue", -2.0)
	if ui:
		ui.toast_clue(cid)


func check_arrivals() -> void:
	var rang := false
	for id in Data.letter_order:
		var L := Data.letter(id)
		if L.has("arrive_if") and GameState.letter_state(id) == "" and eval(L.arrive_if):
			if GameState.arrive(id):
				rang = true
	if rang and ui:
		ui.toast("The Chute is ringing at the post office.", "chute")
		Audio.sfx("chute", -8.0)


# ═══════════════════════════════════════════════════════════════════
#  Commands
# ═══════════════════════════════════════════════════════════════════

func _arg(args: Array, i: int, default: Variant = "") -> Variant:
	return args[i] if i < args.size() else default


func _value(s: String) -> Variant:
	if s == "true":
		return true
	if s == "false":
		return false
	if s.is_valid_int():
		return s.to_int()
	if s.is_valid_float():
		return s.to_float()
	return s


func _cmd(cmd: String, args: Array) -> void:
	_last_activity = Time.get_ticks_msec()
	match cmd:
		"set":
			GameState.set_flag(_arg(args, 0), _value(_arg(args, 1, "true")) if args.size() > 1 else true)
		"unset":
			GameState.flags.erase(_arg(args, 0))
		"add":
			GameState.add_flag(_arg(args, 0), float(_arg(args, 1, "1")))
		"hope":
			GameState.add_flag("hope", float(_arg(args, 0, "1")))
		"clue":
			_give_clue(_arg(args, 0))
		"item":
			var iid: String = _arg(args, 0)
			if not GameState.has_item(iid):
				GameState.add_item(iid)
				Audio.sfx("item", -3.0)
				ui.toast("Received: " + Data.item_name(iid), "item")
		"take":
			GameState.remove_item(_arg(args, 0))
		"arrive":
			if GameState.arrive(_arg(args, 0)):
				Audio.sfx("chute", -4.0)
		"give_letter":
			GameState.give_letter(_arg(args, 0))
		"return_letter":
			GameState.return_letter(_arg(args, 0))
		"fade_letter":
			var lid: String = _arg(args, 0)
			if GameState.letter_state(lid) in ["held", "chute"]:
				GameState.fade_letter(lid)
				ui.toast("\"%s\" has faded. That future is gone." % Data.letter(lid).get("title", lid), "fade")
		"deliver":
			await deliver(_arg(args, 0), _arg(args, 1))
		"try_deliver":
			await try_deliver(_arg(args, 0), _arg(args, 1))
		"collect_chute":
			await _collect_chute()
		"read":
			var rid: String = _arg(args, 0)
			GameState.arrive(rid)
			GameState.collect_chute()
			await ui.open_letter(rid)
			if GameState.letter_state(rid) == "held":
				GameState.mark_delivered(rid, "wren")
		"objective":
			GameState.set_objective(_arg(args, 0))
		"consequence":
			ui.dialogue.close()
			await ui.consequence(_arg(args, 0), _arg(args, 1))
		"card":
			ui.dialogue.close()
			await ui.card(_arg(args, 0), _arg(args, 1))
		"music":
			Audio.play_music(_arg(args, 0))
		"ambience":
			Audio.play_ambience(_arg(args, 0))
		"sfx":
			Audio.sfx(_arg(args, 0))
		"mood":
			if world:
				world.set_mood(_arg(args, 0), float(_arg(args, 1, "1.5")))
		"wait":
			await get_tree().create_timer(float(_arg(args, 0, "1"))).timeout
		"fade":
			var out: bool = _arg(args, 0) == "out"
			if out:
				ui.dialogue.close()
			await ui.fade(out, float(_arg(args, 1, "0.8")))
		"letterbox":
			ui.letterbox(_arg(args, 0) == "on")
		"ripple":
			ui.ripple()
			Audio.sfx("ripple", -2.0)
		"shake":
			if world:
				world.shake(float(_arg(args, 0, "0.5")))
		"flash":
			ui.flash()
		"refresh":
			if world:
				world.refresh()
		"lanterns":
			if world and world.has_method("release_lanterns"):
				world.release_lanterns()
		"npc":
			await _cmd_npc(args)
		"player":
			await _cmd_player(args)
		"camera":
			if world:
				if _arg(args, 0) == "player":
					world.camera_follow()
				else:
					await world.camera_pan(float(_arg(args, 0)), float(_arg(args, 1, "1.5")))
		"goto_location":
			ui.dialogue.close()
			await main.goto_location(_arg(args, 0), _arg(args, 1, "default"), false)
			if _arg(args, 2) == "enter" and world:
				for e in world.def.get("on_enter", []):
					if eval(e.get("if", "true")):
						await _exec(e.node)
						break
		"sleep":
			await advance_night()
		"run":
			await _exec(_arg(args, 0))
		"judge":
			await judge()
		"ending":
			GameState.record_ending(_arg(args, 0))
			_pending_ending = _arg(args, 0)
			_end_requested = true
		"save":
			GameState.autosave()
		_:
			push_warning("Story: unknown command '%s'" % cmd)


func _cmd_npc(args: Array) -> void:
	if world == null:
		return
	var id: String = _arg(args, 0)
	var op: String = _arg(args, 1)
	var actor = world.npc(id)
	match op:
		"show":
			world.show_npc(id, Vector2(float(_arg(args, 2)), float(_arg(args, 3))))
			return
		"hide":
			world.hide_npc(id)
			return
	if actor == null:
		return
	match op:
		"face":
			actor.face(-1 if _arg(args, 2) == "left" else 1)
		"walk":
			await actor.walk_to_async(Vector2(float(_arg(args, 2)), float(_arg(args, 3))))
		"emote":
			actor.puppet.expression = _arg(args, 2)
		"anim":
			actor.puppet.gesture(_arg(args, 2))
		"hold":
			actor.puppet.holding = _arg(args, 2) == "on"


func _cmd_player(args: Array) -> void:
	if world == null or world.player == null:
		return
	var p = world.player
	match _arg(args, 0):
		"walk":
			await p.walk_to_async(Vector2(float(_arg(args, 1)), float(_arg(args, 2))))
		"face":
			p.face(-1 if _arg(args, 1) == "left" else 1)


func _collect_chute() -> void:
	var got := GameState.collect_chute()
	if got.is_empty():
		return
	Audio.sfx("chute_collect")
	for id in got:
		ui.toast("New letter: " + Data.letter(id).get("title", id), "letter")
	ui.dialogue.close()
	if got.size() == 1:
		await ui.open_letter(got[0])
		await letter_closed(got[0])
	else:
		await ui.open_satchel("letters")
	if not f("tutorial_done"):
		return
	if int(f("night")) >= 2 and GameState.objective.begins_with("Collect"):
		GameState.set_objective("Read the new letters. Find who each one belongs to.")


func _after_letter_hooks(letter_id: String) -> void:
	_check_same_hand()
	var L := Data.letter(letter_id)
	if L.get("auto_keep", false) and GameState.letter_state(letter_id) == "held":
		GameState.mark_delivered(letter_id, "wren")
		var node: String = L.get("outcomes", {}).get("wren", {}).get("node", "")
		if node != "":
			await _exec(node)
	if letter_id == "blue_door" and not f("tutorial_done"):
		await _exec("po.after_first_letter")


# ═══════════════════════════════════════════════════════════════════
#  Nights, judgement, endings
# ═══════════════════════════════════════════════════════════════════

const NIGHT_CARDS := {
	2: ["Night Two", "The Chute is restless."],
	3: ["Night Three", "The night before Lantern Night."],
	4: ["Lantern Night", "Seventeen years since the Long Storm."],
}


func advance_night() -> void:
	var n := int(f("night")) + 1
	ui.dialogue.close()
	ui.letterbox(false)
	await ui.fade(true, 1.2)
	GameState.set_flag("night", n)
	if n >= 4:
		GameState.set_flag("lantern_night", true)
	Audio.play_music("", 1.5)
	Audio.sfx("night")
	var card: Array = NIGHT_CARDS.get(n, ["Night", ""])
	await ui.card(card[0], card[1], true)
	for id in Data.letter_order:
		var L := Data.letter(id)
		if int(L.get("arrive_night", 0)) == n and not L.get("manual_arrival", false):
			GameState.arrive(id)
	check_arrivals()
	await main.goto_location("post_office", "bed", false, false)
	await ui.fade(false, 1.2)
	await _exec("night.%d.start" % n)
	GameState.autosave()


func judge() -> void:
	var dawn: bool = bool(f("lamp_lit")) and int(f("hope")) >= DAWN_HOPE
	GameState.set_flag("dawn", dawn)
	await _exec("ending.dawn" if dawn else "ending.dusk")


func mood_for(loc_id: String) -> String:
	var interior: bool = Data.locations.get(loc_id, {}).get("interior", false)
	if f("dawn"):
		return "dawn_interior" if interior else "dawn"
	if f("lantern_night"):
		if f("lamp_failed") and not f("lamp_lit"):
			return "storm_dark"
		return "storm_interior" if interior else "storm"
	return "interior" if interior else "dusk"


func music_for(loc_id: String) -> String:
	if f("dawn"):
		return "dawn"
	if f("finale"):
		return "lantern"
	if f("lantern_night"):
		return "storm"
	return Data.locations.get(loc_id, {}).get("music", "town")


func ambience_for(loc_id: String) -> String:
	if f("dawn"):
		return "harbor"
	if f("lantern_night"):
		return "storm"
	return Data.locations.get(loc_id, {}).get("ambience", "town")


## The ending montage: one card per life the letters touched.
func fates() -> Array:
	var out: Array = []
	# Mari & Theo
	var t := ""
	var mood := "happy"
	if f("theo_home"):
		t = "Theo came home on the 8:15. The lamp above the blue door never went dark again."
		mood = "happy"
	elif f("reply_posted"):
		t = "Mari's reply crossed the bay. The 8:15 turned back in the storm — but Theo will be on the next one. Mari keeps the lamp lit."
		mood = "happy"
	elif f("bakery_lamp_lit"):
		t = "Mari lights the lamp above the blue door every night now. Someday, someone across the bay will see it."
		mood = "happy"
	else:
		t = "The lamp above the blue door stayed dark. Across the bay, a man on the dock kept letting the 8:15 leave without him."
		mood = "sad"
	out.append({"who": "mari", "text": t, "mood": mood})
	# Odile & Tobias
	if f("reunited") and f("lamp_lit"):
		t = "For one night in forty-one years, another hand kept the Hushwater Light — and two old friends met at the end of the pier."
		mood = "happy"
	elif f("reunited"):
		t = "They met at the end of the pier, in the dark. Forty-one years late. But they met."
		mood = "happy"
	elif f("odile_burned"):
		t = "Odile burned her letter. Some letters stay unsent, and that is its own kind of answer."
		mood = "happy"
	else:
		t = "Tobias never knew there had been a question. Odile kept her lamp lit, and her silence."
		mood = "sad"
	out.append({"who": "odile", "text": t, "mood": mood})
	# June
	var jp: String = str(f("june_path"))
	if jp == "stay":
		t = "June became keeper of the Hushwater Light. She climbs the hundred and twelve stairs every night, with her whole heart."
		mood = "happy"
	elif jp == "leave":
		if f("june_mum"):
			t = "June left on the 6:10 with her grandfather's star chart and far too much bread. Her mother waved until the ferry was a speck."
			mood = "happy"
		else:
			t = "June left on the 6:10 with her grandfather's star chart in her pocket. She writes home every week."
			mood = "happy"
	else:
		if f("june_mum"):
			t = "June left on the 6:10. Mari packed her bread and waved. But June never climbed the lighthouse with her grandfather, and its lamp went dark the winter after."
			mood = "sad"
		else:
			t = "June left before anyone woke, without a word. The lighthouse went dark the winter after."
			mood = "sad"
	out.append({"who": "june", "text": t, "mood": mood})
	# Felix
	if f("clock_running") and not f("clock_backward"):
		t = "The town clock started again at 11:53, seventeen years late, and has not lost a second since."
		mood = "happy"
	elif f("clock_backward"):
		t = "The town clock runs backwards now. Felix calls it a calibration issue. June calls it her dad."
		mood = "happy"
	elif f("mari_knows_felix"):
		t = "Mari and Felix don't speak of that night. But on Lantern Night she leaves a bun on his step, and he eats it."
		mood = "happy"
	elif f("letter_to_sea"):
		t = "Felix's letter went out with the tide. He still stands at the stopped clock, waiting for something he can't name."
		mood = "sad"
	elif f("felix_locked"):
		t = "Felix locked his letter in a drawer. The town clock still reads 11:52."
		mood = "sad"
	elif f("felix_has_letter"):
		t = "Felix studies his EXHIBIT in its glass case. He has never been so happy, or so wrong."
		mood = "happy"
	else:
		t = "The typewritten letter was never delivered. The town clock still reads 11:52."
		mood = "sad"
	out.append({"who": "felix", "text": t, "mood": mood})
	# Bram
	if f("mari_bow"):
		t = "On Thursdays, Mari rides the 6:10 at the bow now, beside the wheel. Bram has started spelling 'weather' correctly. Mostly."
		mood = "happy"
	elif f("odile_kept_umbrella"):
		t = "Bram never learned his letter went astray. Odile winks at him every Thursday, which confuses him enormously."
		mood = "sad"
	elif f("bram_kept_letter"):
		t = "Bram still carries his letter in his coat pocket. Someday, he says."
		mood = "sad"
	else:
		t = "Bram still looks back at the stern every Thursday, and never says a word."
		mood = "sad"
	out.append({"who": "bram", "text": t, "mood": mood})
	return out


# ═══════════════════════════════════════════════════════════════════
#  Loading saves: repair & resume
# ═══════════════════════════════════════════════════════════════════
# Version 1.0.0 could autosave in the middle of a scene (whenever the app was
# sent to the background). These rules bring any such save back to a
# consistent state and replay whatever was interrupted, so every save can
# always be finished. They are idempotent: a healthy save passes unchanged.

## Called right after a save is read, before the world is built.
func repair_after_load() -> void:
	_resume_nodes.clear()
	_resume_letter = ""
	busy = false
	_pending_ending = ""
	_end_requested = false
	_abort = false
	var fixes: Array = []
	var night := maxi(1, int(f("night")))
	GameState.set_flag("night", night)
	if not Data.locations.has(GameState.location):
		GameState.location = "post_office"
		GameState.spawn = "default"
		GameState.player_pos = null
		fixes.append("unknown location")

	# The arrival on the quay was cut short: replay it.
	if f("intro_done") and not f("met_bram"):
		GameState.flags.erase("intro_done")
		GameState.location = "harbor"
		GameState.spawn = "intro"
		GameState.player_pos = null
		fixes.append("intro")
	# Odile's welcome was cut short before the first letter came: replay it.
	if f("met_odile") and GameState.letter_state("blue_door") == "":
		GameState.flags.erase("met_odile")
		fixes.append("first visit")

	# Delivery scenes that were cut short: apply what they would have done.
	for id in Data.letter_order:
		if _repair_outcome(id):
			fixes.append("outcome " + id)

	# A night began but its letters never arrived.
	var missing := false
	for id in Data.letter_order:
		var L := Data.letter(id)
		var n := int(L.get("arrive_night", 0))
		if n >= 2 and n <= night and not L.get("manual_arrival", false) and GameState.letter_state(id) == "":
			GameState.arrive(id)
			if n == night:
				missing = true
	if night >= 4 and not f("lantern_night"):
		GameState.set_flag("lantern_night", true)
		missing = true
	if missing:
		fixes.append("night %d start" % night)
		GameState.location = "post_office"
		GameState.spawn = "bed"
		GameState.player_pos = null
		if night < 4:
			_resume_nodes.append("night.%d.start" % night)
		# Lantern Night's opening replays by itself on entering the post office.
	for id in Data.letter_order:
		var L2 := Data.letter(id)
		if L2.has("arrive_if") and GameState.letter_state(id) == "" and eval(L2.arrive_if):
			GameState.arrive(id)

	# Lantern Night's finale was under way: replay it from the harbour.
	if f("lantern_night") and (f("finale") or f("lamp_resolved") or f("dawn")):
		GameState.flags.erase("dawn")
		GameState.location = "harbor"
		GameState.spawn = "finale"
		GameState.player_pos = null
		_resume_nodes = ["resume.finale"]
		fixes.append("finale")
	elif f("lantern_started") and not GameState.has_item("paper_lantern"):
		GameState.add_item("paper_lantern")
	# The lamp sequence can't be half-done unless the lightning has struck.
	if int(f("lamp_sequence")) > 0 and not f("auto_lamp_failed") and not f("lamp_resolved"):
		GameState.set_flag("auto_lamp_failed", true)

	# The first letter was collected but Odile's lesson never followed.
	if GameState.letter_state("blue_door") == "held" and not f("tutorial_done"):
		if GameState.is_read("blue_door"):
			_resume_nodes.push_front("po.after_first_letter")
		else:
			_resume_letter = "blue_door"
		fixes.append("tutorial")

	_repair_objective()
	var unread := 0
	for id in GameState.held_letters():
		if not GameState.is_read(id):
			unread += 1
	GameState.unseen_letters = unread
	if not fixes.is_empty():
		print("Save repaired: ", ", ".join(fixes))


## Applies the lasting effects of a delivery scene that didn't finish.
## Only state that is clearly missing is added; nothing is ever removed.
func _repair_outcome(letter_id: String) -> bool:
	var st := GameState.letter_state(letter_id)
	if not st in ["delivered", "kept"]:
		return false
	var who := GameState.letter_to(letter_id)
	var node: String = Data.letter(letter_id).get("outcomes", {}).get(who, {}).get("node", "")
	if node == "" or not Data.dialogue.has(node):
		return false
	var changed := false
	for ins in Data.dialogue[node]:
		if ins.t != "cmd":
			continue
		if ins.has("if") and not eval(ins["if"]):
			continue
		var a: Array = ins.args
		match ins.cmd:
			"set":
				var k: String = _arg(a, 0)
				var cur: Variant = GameState.flags.get(k, null)
				if cur == null or cur is bool and cur == false or cur is String and cur == "":
					GameState.set_flag(k, _value(_arg(a, 1, "true")) if a.size() > 1 else true)
					changed = true
			"item":
				var iid: String = _arg(a, 0)
				var used: bool = iid == "mari_reply" and bool(f("reply_posted"))
				if not GameState.has_item(iid) and not used:
					GameState.add_item(iid)
					changed = true
			"arrive":
				if GameState.arrive(_arg(a, 0)):
					changed = true
			"fade_letter":
				var fl: String = _arg(a, 0)
				if GameState.letter_state(fl) in ["held", "chute"]:
					GameState.fade_letter(fl)
					changed = true
			"return_letter":
				if GameState.letter_state(_arg(a, 0)) in ["delivered", "kept"]:
					GameState.return_letter(_arg(a, 0))
					changed = true
	return changed


## The objective shown in the HUD, rebuilt when the saved one no longer fits.
func _repair_objective() -> void:
	var o := GameState.objective
	var night := int(f("night"))
	var stale := o == ""
	if o.find("Chute") >= 0 and o.begins_with("Collect") and not chute_waiting():
		stale = true
	if o.begins_with("Post Mari's reply") and not GameState.has_item("mari_reply"):
		stale = true
	if o.begins_with("Find the post office") and f("met_odile"):
		stale = true
	if o.find("ready to sleep") >= 0 and not can_sleep():
		stale = true
	if chute_waiting() and not o.begins_with("Collect") and not f("lantern_night"):
		stale = true
	if not stale:
		return
	var n := ""
	if not f("intro_done"):
		n = ""
	elif not f("met_odile"):
		n = "Find the post office at the end of the quay."
	elif chute_waiting():
		n = "Collect the letter from the Chute." if night <= 1 else "Collect tonight's letters from the Chute."
	elif GameState.has_item("mari_reply"):
		n = "Post Mari's reply in the post office outbox."
	elif f("lantern_night"):
		n = "Lantern Night. Make sure someone is in the lamp room at 11:40." if f("tobias_knows") else "Lantern Night. Go down to the harbour before 11:40."
	elif can_sleep():
		n = "The night's work is done. Return to Odile when you're ready to sleep — or keep exploring."
	elif night <= 1:
		n = "Find who 'The Light Above the Blue Door' was written for."
	else:
		n = "Read the new letters. Find who each one belongs to."
	GameState.set_objective(n)


## Called once the loaded world is on screen: replays interrupted scenes.
func resume_after_load() -> void:
	if _resume_letter != "":
		var id := _resume_letter
		_resume_letter = ""
		busy = true
		_end_requested = false
		_abort = false
		await ui.open_letter(id)
		await _after_letter_hooks(id)
		await _finish()
	var nodes := _resume_nodes.duplicate()
	_resume_nodes.clear()
	for n in nodes:
		if Data.dialogue.has(n):
			await run(n)


# ═══════════════════════════════════════════════════════════════════
#  Safety net
# ═══════════════════════════════════════════════════════════════════
# If a scene ever stalls with nothing on screen to tap (no dialogue, no
# panel, no card) the player would be frozen. After a long quiet spell the
# director gives control back instead.

func _process(_delta: float) -> void:
	if not busy or main == null or ui == null:
		return
	var now := Time.get_ticks_msec()
	if _waiting_on_player():
		_last_activity = now
		return
	if now - _last_activity > 20000:
		push_warning("Story: a scene stalled; returning control to the player.")
		_abort = true
		_end_requested = true
		_pending_ending = ""
		if ui.dialogue:
			ui.dialogue.close()
		ui.letterbox(false)
		ui.fade_instant(0.0)
		busy = false
		_conversation_npc = ""
		if world:
			world.refresh()


func _waiting_on_player() -> bool:
	if ui.modal_open() or main._changing:
		return true
	if ui.dialogue.is_open():
		return true
	for c in ui.overlay.get_child(0).get_children():
		if c.has_signal("done"):
			return true
	var w = world
	if w and w.player and w.player.moving:
		return true
	return false

