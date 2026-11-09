extends RefCounted
## Compiles UNSENT .dlg dialogue scripts into instruction lists.
##
## Node   :  === node.id
## Line   :  speaker[expr]: text          (n: is narration)
## Choice :  * text -> target             (* [if cond] text -> target)
## Jump   :  -> target                    (-> END ends the conversation)
## Command:  ~ command arg "quoted arg"
## Guard  :  [if cond] <any instruction>
##
## Output: Dictionary node_id -> Array[Dictionary] of instructions:
##   {t:"line", who, expr, text}   {t:"cmd", cmd, args}
##   {t:"goto", target}            {t:"choice", options:[{text,target,if?}]}
## Any instruction may carry "if": condition-string.

static var _italic_re: RegEx
static var _speaker_re: RegEx


static func _init_regex() -> void:
	if _italic_re == null:
		_italic_re = RegEx.new()
		_italic_re.compile("\\*([^*]+)\\*")
		_speaker_re = RegEx.new()
		_speaker_re.compile("^([a-z_]+)(?:\\[([a-z_]+)\\])?:\\s?(.*)$")


static func parse_file(path: String, into: Dictionary) -> int:
	if not FileAccess.file_exists(path):
		push_error("DLG: missing file %s" % path)
		return 0
	var text := FileAccess.get_file_as_string(path)
	return parse_text(text, into, path)


static func parse_text(text: String, into: Dictionary, source := "") -> int:
	_init_regex()
	var count := 0
	var current_id := ""
	var current: Array = []
	var line_no := 0
	for raw in text.split("\n"):
		line_no += 1
		var line: String = raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("==="):
			if current_id != "":
				into[current_id] = current
				count += 1
			current_id = line.substr(3).strip_edges()
			if into.has(current_id):
				push_warning("DLG: duplicate node '%s' (%s:%d)" % [current_id, source, line_no])
			current = []
			continue
		if current_id == "":
			push_warning("DLG: text outside a node (%s:%d)" % [source, line_no])
			continue
		var cond := ""
		if line.begins_with("[if "):
			var close := _cond_end(line, 0)
			if close < 0:
				push_error("DLG: unclosed [if (%s:%d)" % [source, line_no])
				continue
			cond = line.substr(4, close - 4).strip_edges()
			line = line.substr(close + 1).strip_edges()
		var ins := _parse_instruction(line, source, line_no)
		if ins.is_empty():
			continue
		if ins.t == "choice_opt":
			ins.erase("t")
			if cond != "":
				ins["if"] = ("(%s) and (%s)" % [cond, ins["if"]]) if ins.has("if") else cond
			if current.size() > 0 and current[-1].t == "choice":
				current[-1].options.append(ins)
			else:
				current.append({"t": "choice", "options": [ins]})
			continue
		if cond != "":
			ins["if"] = cond
		current.append(ins)
	if current_id != "":
		into[current_id] = current
		count += 1
	return count


## Index of the "]" closing an "[if ...]" that starts at `start`, honouring quotes.
static func _cond_end(line: String, start: int) -> int:
	var depth := 0
	var in_str := false
	for i in range(start, line.length()):
		var ch := line[i]
		if ch == "\"":
			in_str = not in_str
		elif not in_str:
			if ch == "[":
				depth += 1
			elif ch == "]":
				depth -= 1
				if depth == 0:
					return i
	return -1


static func _parse_instruction(line: String, source: String, line_no: int) -> Dictionary:
	if line.begins_with("->"):
		return {"t": "goto", "target": line.substr(2).strip_edges()}
	if line.begins_with("~"):
		var parts := split_args(line.substr(1).strip_edges())
		if parts.is_empty():
			return {}
		var cmd: String = parts[0]
		parts.remove_at(0)
		return {"t": "cmd", "cmd": cmd, "args": parts}
	if line.begins_with("* "):
		var body := line.substr(2).strip_edges()
		var opt_cond := ""
		if body.begins_with("[if "):
			var close := _cond_end(body, 0)
			if close > 0:
				opt_cond = body.substr(4, close - 4).strip_edges()
				body = body.substr(close + 1).strip_edges()
		var arrow := body.rfind("->")
		if arrow < 0:
			push_error("DLG: choice without target (%s:%d)" % [source, line_no])
			return {}
		var opt := {
			"t": "choice_opt",
			"text": format_text(body.substr(0, arrow).strip_edges()),
			"target": body.substr(arrow + 2).strip_edges(),
		}
		if opt_cond != "":
			opt["if"] = opt_cond
		return opt
	var m := _speaker_re.search(line)
	if m:
		var expr := m.get_string(2)
		return {
			"t": "line",
			"who": m.get_string(1),
			"expr": expr if expr != "" else "neutral",
			"text": format_text(m.get_string(3)),
		}
	push_warning("DLG: unrecognised line (%s:%d): %s" % [source, line_no, line])
	return {}


## Converts *emphasis* into BBCode italics.
static func format_text(s: String) -> String:
	_init_regex()
	return _italic_re.sub(s, "[i]$1[/i]", true)


## Splits a command line into arguments, keeping "quoted strings" together.
static func split_args(s: String) -> Array:
	var out: Array = []
	var cur := ""
	var in_str := false
	var had_quote := false
	for i in s.length():
		var ch := s[i]
		if ch == "\"":
			in_str = not in_str
			had_quote = true
			continue
		if ch == " " and not in_str:
			if cur != "" or had_quote:
				out.append(cur)
			cur = ""
			had_quote = false
			continue
		cur += ch
	if cur != "" or had_quote:
		out.append(cur)
	return out
