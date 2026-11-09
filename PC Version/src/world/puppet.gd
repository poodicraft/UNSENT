extends Node2D
## A procedurally drawn "paper puppet" character.
##
## Everything is vector-drawn every frame from a small config dictionary
## (colours, body type, hair, hat, accessories), so characters stay crisp
## at any screen density and new characters need no art. Origin = feet,
## facing +x. Supports walk/idle/talk animation, gestures (two-bone IK arms)
## and facial expressions.

var cfg: Dictionary = {}
var facing := 1
var walking := false
var walk_phase := 0.0
var talking := false
var expression := "neutral"
var holding := false
var portrait := false          # true when drawn as a dialogue portrait

var _gesture := ""
var _gesture_t := 0.0
var _t := 0.0
var _blink_timer := 2.0
var _blink := 0.0
var _mouth := 0.0

# Derived proportions
var H := 1.0
var B := 1.0
var _c: Dictionary = {}        # parsed colours

const OUTLINE_W := 2.2

var _hip := Vector2.ZERO
var _lean := 0.0


## Upper-body transform: rotates a point around the hip by the current lean.
func _u(p: Vector2) -> Vector2:
	return _hip + (p - _hip).rotated(_lean)


func configure(c: Dictionary) -> void:
	cfg = c
	H = float(c.get("height", 1.0))
	B = float(c.get("build", 1.0))
	_c.clear()
	for k in c.keys():
		var v = c[k]
		if v is String and v.begins_with("#"):
			_c[k] = Color(v)
	if c.has("mittens"):
		_c["mitten_front"] = Color(c.mittens[0])
		_c["mitten_back"] = Color(c.mittens[1])
	_t = randf() * 10.0
	_blink_timer = randf_range(1.0, 4.0)
	queue_redraw()


func col(key: String, fallback := Color.MAGENTA) -> Color:
	return _c.get(key, fallback)


func gesture(name: String) -> void:
	_gesture = name
	_gesture_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	_gesture_t += delta
	if _gesture != "" and _gesture_t > _gesture_len(_gesture):
		_gesture = ""
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 0.13
		_blink_timer = randf_range(2.2, 5.5)
	_blink = maxf(0.0, _blink - delta)
	if talking:
		_mouth = absf(sin(_t * 13.0)) * (0.6 + 0.4 * absf(sin(_t * 4.1)))
	else:
		_mouth = move_toward(_mouth, 0.0, delta * 6.0)
	queue_redraw()


func _gesture_len(g: String) -> float:
	match g:
		"wave": return 1.6
		"reach": return 1.4
		"nod": return 0.7
		"shake": return 0.8
		"jump": return 0.5
	return 1.0


# ═══════════════════════════════════════════════════════════════════
#  Geometry helpers
# ═══════════════════════════════════════════════════════════════════

func _ellipse(c: Vector2, rx: float, ry: float, n := 22) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p


func _arc(c: Vector2, rx: float, ry: float, a0: float, a1: float, n := 14) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p


func _capsule(a: Vector2, b: Vector2, ra: float, rb: float, n := 7) -> PackedVector2Array:
	var d := b - a
	if d.length() < 0.01:
		d = Vector2(0, 0.01)
	var ang := d.angle()
	var p := PackedVector2Array()
	for i in n + 1:
		var t := ang + PI * 0.5 + PI * i / n
		p.append(a + Vector2(cos(t), sin(t)) * ra)
	for i in n + 1:
		var t := ang - PI * 0.5 + PI * i / n
		p.append(b + Vector2(cos(t), sin(t)) * rb)
	return p


func _chaikin(pts: PackedVector2Array, iterations := 2) -> PackedVector2Array:
	var p := pts
	for _k in iterations:
		var q := PackedVector2Array()
		var n := p.size()
		for i in n:
			var a := p[i]
			var b := p[(i + 1) % n]
			q.append(a.lerp(b, 0.25))
			q.append(a.lerp(b, 0.75))
		p = q
	return p


func _fill(pts: PackedVector2Array, color: Color, outline := true, ow := OUTLINE_W) -> void:
	if pts.size() < 3:
		return
	draw_colored_polygon(pts, color)
	if outline:
		var o := pts.duplicate()
		o.append(pts[0])
		draw_polyline(o, color.darkened(0.42), ow, true)


func _line(pts: PackedVector2Array, color: Color, w := 2.0) -> void:
	draw_polyline(pts, color, w, true)


func _dot(c: Vector2, r: float, color: Color, outline := false) -> void:
	draw_circle(c, r, color, true, -1.0, true)
	if outline:
		draw_circle(c, r, color.darkened(0.42), false, 1.6, true)


## Two-bone IK: returns elbow position for a shoulder→target reach.
func _ik(s: Vector2, t: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var d := t - s
	var dist := clampf(d.length(), 1.0, (l1 + l2) * 0.999)
	var a := acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
	var base := d.angle()
	var ang := base + a * bend
	return s + Vector2(cos(ang), sin(ang)) * l1


# ═══════════════════════════════════════════════════════════════════
#  Drawing
# ═══════════════════════════════════════════════════════════════════

func _draw() -> void:
	if cfg.is_empty():
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))

	var body: String = cfg.get("body", "coat")
	var swing := 0.0
	var bob := 0.0
	if walking:
		swing = sin(walk_phase) * 0.46
		bob = -absf(sin(walk_phase)) * 3.5 + 1.5
	var breath := sin(_t * 1.9) * 1.1
	var hop := 0.0
	if _gesture == "jump":
		hop = -sin(clampf(_gesture_t / 0.5, 0.0, 1.0) * PI) * 22.0
	var stoop := float(cfg.get("stoop", 0.0))

	var hip := Vector2(0, -100.0 * H + bob + hop)
	var leg_len := 100.0 * H + bob + hop
	var leg_w := 7.0 * sqrt(B) * (0.92 if B < 0.9 else 1.0)
	var sh_y := hip.y - 86.0 * H + breath * 0.35
	var sw := 25.0 * B
	var lean := stoop * 0.30 + (0.05 if walking else 0.0)

	# Upper-body transform: rotate around the hip by `lean`
	_hip = hip
	_lean = lean

	var neck_top := _u(Vector2(4, sh_y - 12.0 * H))
	var head_c := _u(Vector2(6, sh_y - 42.0 * H + breath * 0.5))
	if talking:
		head_c.y += sin(_t * 5.0) * 0.8
	if _gesture == "nod":
		head_c.y += sin(_gesture_t * 18.0) * 3.0

	var dark_skin := col("skin").darkened(0.12)
	var pants := col("pants", Color(0.2, 0.2, 0.25))
	var shoes := col("shoes", Color(0.15, 0.12, 0.1))

	# ── Back accessories (behind everything) ──
	if cfg.get("telescope", false):
		var a := _u(Vector2(-26, sh_y + 52))
		var b := _u(Vector2(-4, sh_y - 26))
		_fill(_capsule(a, b, 5.0, 4.0), Color("#c9a14a"))
		var ring := a.lerp(b, 0.32)
		var nrm := (b - a).orthogonal().normalized() * 5.0
		_line(PackedVector2Array([ring - nrm, ring + nrm]), Color("#8a6a2a"), 2.0)
		_dot(b, 5.2, Color("#8a6a2a"), true)

	# ── Back leg ──
	var hem_y := _hem_y(body, hip, sh_y)
	_leg(hip + Vector2(-6.0 * B, 0), leg_len, -swing, leg_w, pants.darkened(0.18), shoes.darkened(0.18), -1)

	# ── Back arm ──
	var sh_back := _u(Vector2(-sw + 8.0, sh_y + 7.0))
	var sh_front := _u(Vector2(sw - 9.0, sh_y + 7.0))
	var arm_l1 := 44.0 * H
	var arm_l2 := 40.0 * H
	var hands := _arm_targets(sh_front, sh_back, arm_l1, arm_l2, swing, hip, head_c)
	_arm(sh_back, hands.back_elbow, hands.back_hand, true)

	# ── Torso ──
	_torso(body, hip, sh_y, sw, hem_y)

	# ── Front leg ──
	_leg(hip + Vector2(6.0 * B, 0), leg_len, swing, leg_w, pants, shoes, 1)
	if body in ["dress", "longcoat", "raincoat"]:
		# Long garments cover the top of the legs: redraw the skirt hem over the front leg.
		_skirt(body, hip, sh_y, sw, hem_y)

	# ── Satchel (front) ──
	if cfg.has("satchel"):
		var s0 := _u(Vector2(-sw + 6, sh_y + 4))
		var s1 := hip + Vector2(sw + 4, -8)
		_line(PackedVector2Array([s0, s1]), col("satchel").darkened(0.25), 5.0)
		var bag := PackedVector2Array([s1 + Vector2(-16, -14), s1 + Vector2(14, -16), s1 + Vector2(17, 12), s1 + Vector2(-14, 14)])
		_fill(_chaikin(bag, 1), col("satchel"))
		_fill(PackedVector2Array([s1 + Vector2(-16, -14), s1 + Vector2(14, -16), s1 + Vector2(12, -2), s1 + Vector2(-14, 0)]), col("satchel").darkened(0.15))
		_dot(s1 + Vector2(-1, -1), 2.6, Color("#e3c070"))

	# ── Neck & head ──
	_fill(_capsule(_u(Vector2(3, sh_y + 2)), neck_top, 7.5, 7.0), dark_skin, false)
	_head(head_c)

	# ── Scarf / bow tie over the neck ──
	if cfg.has("scarf"):
		var sc := col("scarf")
		var n0 := _u(Vector2(2, sh_y - 4))
		_fill(_capsule(n0 + Vector2(-13, 0), n0 + Vector2(13, 2), 7.5, 7.5), sc)
		var flutter := sin(_t * 2.3) * 2.5 + (swing * 6.0)
		var tail := PackedVector2Array([n0 + Vector2(-10, 2), n0 + Vector2(-2, 4), n0 + Vector2(-8 + flutter * 0.4, 42), n0 + Vector2(-18 + flutter, 38)])
		_fill(tail, sc.darkened(0.08))
	if cfg.has("bowtie"):
		var bt := _u(Vector2(9, sh_y - 1))
		_fill(PackedVector2Array([bt, bt + Vector2(-8, -5), bt + Vector2(-8, 5)]), col("bowtie"))
		_fill(PackedVector2Array([bt, bt + Vector2(8, -5), bt + Vector2(8, 5)]), col("bowtie"))
		_dot(bt, 2.4, col("bowtie").darkened(0.2))

	# ── Held letter + front arm ──
	if holding:
		var fhand: Vector2 = hands.front_hand
		var bhand: Vector2 = hands.back_hand
		var lc: Vector2 = (fhand + bhand) * 0.5 + Vector2(4, -6)
		var paper := PackedVector2Array([lc + Vector2(-16, -12), lc + Vector2(17, -14), lc + Vector2(18, 11), lc + Vector2(-15, 13)])
		_fill(paper, Color("#f4ead6"))
		_line(PackedVector2Array([lc + Vector2(-12, -4), lc + Vector2(12, -6)]), Color(0.3, 0.3, 0.4, 0.5), 1.4)
		_line(PackedVector2Array([lc + Vector2(-12, 2), lc + Vector2(10, 0)]), Color(0.3, 0.3, 0.4, 0.5), 1.4)
	_arm(sh_front, hands.front_elbow, hands.front_hand, false)


func _hem_y(body: String, hip: Vector2, sh_y: float) -> float:
	match body:
		"longcoat": return hip.y + 52.0 * H
		"dress": return hip.y + 62.0 * H
		"raincoat": return hip.y + 40.0 * H
		"peacoat": return hip.y + 26.0 * H
		"coat": return hip.y + 30.0 * H
		"sweater": return hip.y + 6.0 * H
		"waistcoat": return hip.y + 4.0 * H
		"jacket": return hip.y + 8.0 * H
	return hip.y + 20.0 * H


func _leg(h: Vector2, length: float, ang: float, w: float, c_pants: Color, c_shoe: Color, side: int) -> void:
	var foot := h + Vector2(sin(ang) * length, cos(ang) * length)
	# Lift the swinging foot a little on the forward pass.
	if walking and ang > 0.05:
		foot.y -= ang * 9.0
	_fill(_capsule(h, foot + Vector2(0, -5), w, w * 0.86), c_pants)
	var shoe := PackedVector2Array()
	var sc := foot + Vector2(5, -4)
	shoe = _ellipse(sc, 12.5, 6.2, 14)
	_fill(shoe, c_shoe)


func _arm_targets(sf: Vector2, sb: Vector2, l1: float, l2: float, swing: float, hip: Vector2, head: Vector2) -> Dictionary:
	var g := _gesture
	var r := {}
	# Default: hanging arms with walk swing (FK).
	var fa := 0.10 - swing * 0.85
	var ba := 0.06 + swing * 0.85
	var fe := sf + Vector2(sin(fa), cos(fa)) * l1
	var fh := fe + Vector2(sin(fa + 0.22), cos(fa + 0.22)) * l2
	var be := sb + Vector2(sin(ba), cos(ba)) * l1
	var bh := be + Vector2(sin(ba + 0.22), cos(ba + 0.22)) * l2
	if holding:
		fh = sf + Vector2(30, 22)
		bh = sb + Vector2(36, 26)
		fe = _ik(sf, fh, l1, l2, 1.0)
		be = _ik(sb, bh, l1, l2, 1.0)
	elif g == "reach":
		var k := sin(clampf(_gesture_t / _gesture_len(g), 0.0, 1.0) * PI)
		fh = sf.lerp(sf + Vector2(18, -78), k) if k > 0.0 else fh
		fe = _ik(sf, fh, l1, l2, -1.0)
	elif g == "wave":
		fh = head + Vector2(26 + sin(_gesture_t * 14.0) * 10.0, -24)
		fe = _ik(sf, fh, l1, l2, 1.0)
	elif expression == "thinking" and not walking:
		fh = head + Vector2(18, 30)
		fe = _ik(sf, fh, l1, l2, 1.0)
	r.front_elbow = fe
	r.front_hand = fh
	r.back_elbow = be
	r.back_hand = bh
	return r


func _arm(s: Vector2, e: Vector2, h: Vector2, back: bool) -> void:
	var body: String = cfg.get("body", "coat")
	var sleeve := col("coat")
	if body == "waistcoat":
		sleeve = col("trim")
	if back:
		sleeve = sleeve.darkened(0.16)
	var w := 6.5 * sqrt(B) + 0.5
	_fill(_capsule(s, e, w + 0.6, w), sleeve)
	var fore := sleeve
	if cfg.get("sleeves", "") == "rolled":
		fore = col("skin").darkened(0.08 if back else 0.0)
	_fill(_capsule(e, h, w, w * 0.88), fore)
	var hand_c := col("skin")
	if _c.has("mitten_front"):
		hand_c = col("mitten_back") if back else col("mitten_front")
	elif back:
		hand_c = hand_c.darkened(0.12)
	_dot(h, 6.4, hand_c, true)


func _torso(body: String, hip: Vector2, sh_y: float, sw: float, hem_y: float) -> void:
	var coat := col("coat")
	var coat2 := col("coat2", coat.darkened(0.15))
	var trim := col("trim", coat.lightened(0.3))
	var ww := sw * (1.04 if B > 1.2 else 0.98)
	var hw := sw * 1.2
	match body:
		"dress": hw = sw * 1.55
		"longcoat": hw = sw * 1.32
		"raincoat": hw = sw * 1.4
		"peacoat": hw = sw * 1.18
		"sweater": hw = sw * 1.02
		"waistcoat": hw = sw * 0.96
		"jacket": hw = sw * 1.06
	var pts := PackedVector2Array([
		_u(Vector2(-sw + 3, sh_y - 2)),
		_u(Vector2(sw - 1, sh_y - 1)),
		_u(Vector2(sw + 1, sh_y + 10)),
		_u(Vector2(ww + 1, hip.y - 10)),
		Vector2(hw, hem_y),
		Vector2(-hw * 0.96, hem_y),
		_u(Vector2(-ww - 1, hip.y - 10)),
		_u(Vector2(-sw - 1, sh_y + 10)),
	])
	pts = _chaikin(pts, 2)
	if body == "waistcoat":
		_fill(pts, trim)          # shirt
	else:
		_fill(pts, coat)
	# Back-side shading strip
	var shade := PackedVector2Array([
		_u(Vector2(-sw + 3, sh_y + 2)), _u(Vector2(-sw * 0.35, sh_y + 4)),
		Vector2(-hw * 0.45, hem_y - 2), Vector2(-hw * 0.94, hem_y - 2),
		_u(Vector2(-ww, hip.y - 10)), _u(Vector2(-sw, sh_y + 12)),
	])
	if body != "waistcoat":
		_fill(_chaikin(shade, 1), Color(coat2, 0.75), false)

	match body:
		"sweater":
			for i in 4:
				var x := -10.0 + i * 8.0
				var line := PackedVector2Array()
				for k in 7:
					var y := lerpf(sh_y + 14, hip.y - 2, k / 6.0)
					line.append(_u(Vector2(x + sin(k * 1.6) * 2.0, y)))
				_line(line, coat2.lightened(0.15), 1.6)
			var band := PackedVector2Array([Vector2(-hw, hem_y - 10), Vector2(hw, hem_y - 10), Vector2(hw, hem_y), Vector2(-hw * 0.96, hem_y)])
			_fill(band, coat2)
			_fill(_capsule(_u(Vector2(-12, sh_y - 2)), _u(Vector2(16, sh_y - 1)), 7.0, 7.0), coat2)
		"peacoat":
			for i in 3:
				var y := sh_y + 22 + i * 20
				_dot(_u(Vector2(4, y)), 2.8, trim, true)
				_dot(_u(Vector2(16, y)), 2.8, trim, true)
			_fill(PackedVector2Array([_u(Vector2(-4, sh_y - 2)), _u(Vector2(16, sh_y - 2)), _u(Vector2(8, sh_y + 20))]), coat2)
		"longcoat":
			_line(PackedVector2Array([_u(Vector2(10, sh_y + 4)), Vector2(12, hem_y)]), coat2.darkened(0.2), 2.0)
			for i in 3:
				_dot(_u(Vector2(15, sh_y + 26 + i * 22)), 2.6, trim, true)
			_fill(PackedVector2Array([_u(Vector2(-2, sh_y - 3)), _u(Vector2(18, sh_y - 1)), _u(Vector2(10, sh_y + 22))]), coat2)
			# belt
			_fill(PackedVector2Array([_u(Vector2(-ww - 1, hip.y - 14)), _u(Vector2(ww + 1, hip.y - 14)), _u(Vector2(ww + 1, hip.y - 7)), _u(Vector2(-ww - 1, hip.y - 7))]), coat2.darkened(0.15), false)
		"raincoat":
			# hood bunched behind the neck
			_fill(_ellipse(_u(Vector2(-12, sh_y - 4)), 15, 10, 14), coat2)
			for i in 3:
				var tg := _u(Vector2(13, sh_y + 22 + i * 20))
				_fill(PackedVector2Array([tg + Vector2(-5, -2), tg + Vector2(5, -2), tg + Vector2(5, 2), tg + Vector2(-5, 2)]), trim, false)
			_line(PackedVector2Array([_u(Vector2(9, sh_y + 4)), Vector2(10, hem_y)]), coat2, 1.8)
		"waistcoat":
			var vest := PackedVector2Array([
				_u(Vector2(-sw + 4, sh_y + 2)), _u(Vector2(2, sh_y + 4)),
				_u(Vector2(12, sh_y + 46)), _u(Vector2(sw - 1, sh_y + 8)),
				_u(Vector2(ww + 1, hip.y - 4)), _u(Vector2(10, hip.y + 4)),
				_u(Vector2(-ww - 1, hip.y - 6)),
			])
			_fill(_chaikin(vest, 1), coat)
			for i in 3:
				_dot(_u(Vector2(13, sh_y + 52 + i * 11)), 2.2, Color("#d9c27a"), true)
			_line(PackedVector2Array([_u(Vector2(14, sh_y + 60)), _u(Vector2(22, sh_y + 68)), _u(Vector2(20, sh_y + 76))]), Color("#e3c46a"), 1.6)
		"dress":
			_fill(PackedVector2Array([_u(Vector2(-ww - 2, hip.y - 18)), _u(Vector2(ww + 2, hip.y - 18)), _u(Vector2(ww + 2, hip.y - 10)), _u(Vector2(-ww - 2, hip.y - 10))]), trim.darkened(0.1), false)
		"jacket":
			_line(PackedVector2Array([_u(Vector2(8, sh_y + 2)), _u(Vector2(10, hip.y + 6))]), trim, 1.8)
			_fill(PackedVector2Array([_u(Vector2(-6, sh_y - 3)), _u(Vector2(16, sh_y - 1)), _u(Vector2(9, sh_y + 18))]), coat2)

	# Apron (Mari)
	if cfg.has("apron"):
		var ap := col("apron")
		var apron := PackedVector2Array([
			_u(Vector2(-6, sh_y + 18)), _u(Vector2(20, sh_y + 16)),
			Vector2(hw * 0.7, hem_y - 6), Vector2(-hw * 0.25, hem_y - 4),
		])
		_fill(_chaikin(apron, 1), ap)
		var pk := _u(Vector2(8, hip.y - 2))
		_fill(PackedVector2Array([pk + Vector2(-9, -6), pk + Vector2(9, -7), pk + Vector2(9, 6), pk + Vector2(-9, 7)]), ap.darkened(0.08))
		if cfg.get("flour", false):
			for i in 5:
				_dot(_u(Vector2(-2 + i * 5, hip.y - 30 + (i % 2) * 9)), 1.6, Color(1, 1, 1, 0.75))
	# Shawl (Odile)
	if cfg.has("shawl"):
		var sh := col("shawl")
		var shawl := PackedVector2Array([
			_u(Vector2(-sw - 3, sh_y + 4)), _u(Vector2(-2, sh_y - 5)), _u(Vector2(sw + 3, sh_y + 6)),
			_u(Vector2(sw - 2, sh_y + 30)), _u(Vector2(4, sh_y + 52)), _u(Vector2(-sw + 1, sh_y + 34)),
		])
		_fill(_chaikin(shawl, 1), sh)
		for i in 6:
			var fp := _u(Vector2(-sw + 3 + i * 9, sh_y + 34 + absf(2.5 - i) * -4.0 + 14))
			_line(PackedVector2Array([fp, fp + Vector2(0, 7)]), sh.darkened(0.2), 1.4)


func _skirt(body: String, hip: Vector2, sh_y: float, sw: float, hem_y: float) -> void:
	var coat := col("coat")
	var hw := sw * (1.55 if body == "dress" else (1.32 if body == "longcoat" else 1.4))
	var ww := sw * 0.98
	var top := hip.y - 14.0
	var pts := PackedVector2Array([
		_u(Vector2(-ww - 1, top)), _u(Vector2(ww + 1, top)),
		Vector2(hw, hem_y), Vector2(-hw * 0.96, hem_y),
	])
	_fill(_chaikin(pts, 1), coat)
	if cfg.has("apron"):
		var ap := col("apron")
		var apron := PackedVector2Array([_u(Vector2(-6, top)), _u(Vector2(22, top)), Vector2(hw * 0.7, hem_y - 6), Vector2(-hw * 0.25, hem_y - 4)])
		_fill(_chaikin(apron, 1), ap)
	if body == "longcoat":
		_line(PackedVector2Array([_u(Vector2(12, top)), Vector2(12, hem_y)]), col("coat2").darkened(0.2), 2.0)
	if body == "raincoat":
		_line(PackedVector2Array([_u(Vector2(10, top)), Vector2(10, hem_y)]), col("coat2"), 1.8)


func _head(c: Vector2) -> void:
	var rx := 30.0
	var ry := 33.0
	var skin := col("skin")
	var hair := col("hair", Color(0.2, 0.15, 0.12))
	var style: String = cfg.get("hair_style", "short")
	var hat: String = cfg.get("hat", "")

	# Hair behind the head
	match style:
		"bun":
			_dot(c + Vector2(-25, -26), 13.5, hair, true)
			if cfg.get("pencil", false):
				_line(PackedVector2Array([c + Vector2(-40, -38), c + Vector2(-14, -16)]), Color("#e8b84a"), 3.2)
				_dot(c + Vector2(-40, -38), 1.8, Color("#f0a0a0"))
		"wild":
			for p in [Vector2(-24, -20), Vector2(-10, -32), Vector2(-30, -2), Vector2(4, -34), Vector2(-26, 14)]:
				_dot(c + p, 15.0, hair, true)
		"curly":
			for p in [Vector2(-28, 6), Vector2(-30, -8), Vector2(-22, 16)]:
				_dot(c + p, 10.0, hair, true)
		"messy":
			_dot(c + Vector2(-22, 4), 15.0, hair, false)

	# Ear + head
	_fill(_ellipse(c, rx, ry, 26), skin)
	_dot(c + Vector2(-14, 5), 6.0, skin.darkened(0.08), true)

	# Beard sits on the jaw, below the face features.
	var beard: String = cfg.get("beard", "")
	if beard == "full":
		var bc := col("beard_color", hair)
		var bp := PackedVector2Array([
			c + Vector2(-6, 4), c + Vector2(2, 10), c + Vector2(14, 12), c + Vector2(26, 8),
			c + Vector2(31, 14), c + Vector2(26, 34), c + Vector2(12, 44), c + Vector2(-4, 36), c + Vector2(-10, 20),
		])
		_fill(_chaikin(bp, 2), bc)
	elif beard == "stubble":
		var sp := PackedVector2Array([c + Vector2(-4, 8), c + Vector2(26, 10), c + Vector2(26, 28), c + Vector2(8, 34), c + Vector2(-6, 22)])
		_fill(_chaikin(sp, 2), Color(col("beard_color", hair), 0.35), false)

	_face(c)

	if beard == "mustache":
		var mc := col("beard_color", hair)
		var mp := PackedVector2Array([c + Vector2(14, 10), c + Vector2(24, 8), c + Vector2(33, 10), c + Vector2(34, 17), c + Vector2(26, 14), c + Vector2(17, 16), c + Vector2(11, 17)])
		_fill(_chaikin(mp, 1), mc)

	# Hair front / cap
	match style:
		"short", "bun", "messy", "wild":
			var cap := _arc(c + Vector2(-1, -1), rx * 1.08, ry * 1.06, -PI * 0.27, -PI * 1.22, 16)
			cap.append(c + Vector2(-22, 12))
			cap.append(c + Vector2(-16, -6))
			cap.append(c + Vector2(-2, -18))
			cap.append(c + Vector2(14, -20))
			if style == "messy":
				var jag := PackedVector2Array()
				for i in cap.size():
					var p := cap[i]
					if i < 17 and i % 2 == 1:
						p += (p - c).normalized() * 5.0
					jag.append(p)
				cap = jag
			_fill(cap, hair)
			if style == "messy":
				_line(PackedVector2Array([c + Vector2(14, -22), c + Vector2(22, -10), c + Vector2(20, -4)]), hair, 3.0)
		"curly":
			pass

	# Accessories on the head
	if cfg.get("goggles", false):
		var band := _arc(c, rx * 1.02, ry * 0.4, PI * 0.95, PI * 2.05, 10)
		band = PackedVector2Array(Array(band).map(func(p): return p + Vector2(0, -16)))
		_line(band, Color("#5a3e2a"), 5.0)
		for gp in [Vector2(10, -20), Vector2(24, -20)]:
			_dot(c + gp, 7.6, Color("#c9a14a"), true)
			_dot(c + gp, 5.0, Color(0.6, 0.85, 0.9, 0.75))
			_dot(c + gp + Vector2(-1.5, -1.5), 1.6, Color(1, 1, 1, 0.8))
	match hat:
		"postal":
			var hc := col("hat_color")
			var crown := PackedVector2Array([c + Vector2(-30, -16), c + Vector2(24, -18), c + Vector2(26, -36), c + Vector2(-26, -40)])
			_fill(_chaikin(crown, 1), hc)
			var brim := PackedVector2Array([c + Vector2(10, -20), c + Vector2(42, -16), c + Vector2(40, -12), c + Vector2(8, -14)])
			_fill(_chaikin(brim, 1), hc.darkened(0.25))
			_fill(PackedVector2Array([c + Vector2(-29, -20), c + Vector2(25, -22), c + Vector2(25, -17), c + Vector2(-29, -15)]), hc.darkened(0.3), false)
			_dot(c + Vector2(10, -29), 3.4, Color("#e3c070"), true)
		"beanie":
			var hc := col("hat_color")
			var dome := _arc(c + Vector2(-2, -4), rx * 1.08, ry * 1.02, -PI * 0.08, -PI * 1.02, 16)
			_fill(dome, hc)
			var band := PackedVector2Array([c + Vector2(-34, -6), c + Vector2(30, -9), c + Vector2(31, 1), c + Vector2(-33, 4)])
			_fill(_chaikin(band, 1), hc.darkened(0.18))
			for i in 7:
				var x := -26.0 + i * 8.5
				_line(PackedVector2Array([c + Vector2(x, -6), c + Vector2(x, 1)]), hc.darkened(0.32), 1.2)
		"headscarf":
			var hc := col("hat_color")
			var sc := _arc(c + Vector2(-2, -2), rx * 1.12, ry * 1.08, -PI * 0.18, -PI * 1.1, 16)
			sc.append(c + Vector2(-20, 10))
			sc.append(c + Vector2(-8, -12))
			sc.append(c + Vector2(16, -18))
			_fill(sc, hc)
			_fill(PackedVector2Array([c + Vector2(-32, 2), c + Vector2(-48, -6), c + Vector2(-44, 10)]), hc.darkened(0.12))
			_fill(PackedVector2Array([c + Vector2(-32, 4), c + Vector2(-44, 18), c + Vector2(-30, 16)]), hc.darkened(0.2))
			for p in [Vector2(-16, -22), Vector2(-2, -28), Vector2(-24, -6), Vector2(8, -26)]:
				_dot(c + p, 2.0, Color("#fff1c0"))
	if cfg.get("glasses", "") == "round":
		var gc := Color("#2a2030")
		draw_circle(c + Vector2(9, -3), 7.5, gc, false, 1.8, true)
		draw_circle(c + Vector2(23, -4), 6.4, gc, false, 1.8, true)
		_line(PackedVector2Array([c + Vector2(16, -4), c + Vector2(17, -4)]), gc, 1.8)
		_line(PackedVector2Array([c + Vector2(2, -3), c + Vector2(-6, -1)]), gc, 1.6)
		_dot(c + Vector2(6, -6), 1.6, Color(1, 1, 1, 0.6))


func _face(c: Vector2) -> void:
	var ink := Color("#241b22")
	var e := expression
	var blink := _blink > 0.0 or e == "tired"
	var near := c + Vector2(9, -3)
	var far := c + Vector2(23, -4)
	var look := Vector2.ZERO
	if e == "thinking":
		look = Vector2(1.0, -2.0)
	elif e == "shy" or e == "sad":
		look = Vector2(0.5, 1.5)

	# Cheeks
	var blush := 0.32
	if e == "shy" or e == "happy":
		blush = 0.55
	draw_circle(c + Vector2(6, 9), 6.5, Color(col("cheek", Color(0.9, 0.55, 0.5)), blush), true, -1.0, true)

	# Eyes
	for i in 2:
		var p := near if i == 0 else far
		var s := 1.0 if i == 0 else 0.82
		if blink:
			_line(PackedVector2Array([p + Vector2(-3.5, 0.5) * s, p + Vector2(3.5, 0.5) * s]), ink, 2.0)
		elif e == "happy":
			_line(_arc(p + Vector2(0, 2) * s, 4.0 * s, 3.6 * s, PI * 1.1, PI * 1.9, 6), ink, 2.2)
		elif e == "surprised":
			draw_circle(p, 4.6 * s, Color.WHITE, true, -1.0, true)
			draw_circle(p + look, 2.6 * s, ink, true, -1.0, true)
		else:
			_fill(_ellipse(p + look * 0.6, 2.9 * s, 3.9 * s, 10), ink, false)
			draw_circle(p + look * 0.6 + Vector2(-0.9, -1.3) * s, 0.9 * s, Color(1, 1, 1, 0.85), true, -1.0, true)

	# Brows
	var b_in := 0.0     # positive = inner end raised (sad), negative = lowered (angry)
	var b_lift := 0.0
	match e:
		"sad": b_in = 3.2
		"angry": b_in = -3.6
		"surprised": b_lift = 4.0
		"happy": b_lift = 1.5
		"thinking": b_lift = 1.0
		"shy": b_in = 1.5
	var hair := col("hair", ink).darkened(0.2)
	if cfg.get("hair_style", "") == "bun" or cfg.get("hair", "") == "":
		hair = Color(0.45, 0.42, 0.46)
	for i in 2:
		var p := (near if i == 0 else far) + Vector2(0, -8.5 - b_lift)
		var s := 1.0 if i == 0 else 0.8
		# inner end is towards the nose (+x on near eye's right, far eye's left)
		var inner := Vector2(4.0, 0) if i == 0 else Vector2(-3.5, 0)
		var outer := -inner
		_line(PackedVector2Array([p + outer * s + Vector2(0, 0.5), p + inner * s - Vector2(0, b_in)]), hair, 2.2)
		if e == "thinking" and i == 1:
			pass

	# Nose
	var skin := col("skin")
	var nose := PackedVector2Array([c + Vector2(28, -2), c + Vector2(35, 6), c + Vector2(29, 9)])
	_fill(nose, skin.darkened(0.06), false)
	_line(PackedVector2Array([c + Vector2(29, -1), c + Vector2(35, 6), c + Vector2(29, 9)]), skin.darkened(0.35), 1.6)

	# Mouth
	var m := c + Vector2(18, 16)
	var open := _mouth
	if open > 0.08:
		var mo := _ellipse(m + Vector2(0, 1), 4.2 + open * 1.2, 1.2 + open * 4.2, 12)
		_fill(mo, Color("#5a2a30"), false)
	else:
		match e:
			"happy", "shy":
				_line(_arc(m + Vector2(0, -3), 6.0, 4.0, PI * 0.15, PI * 0.85, 8), ink, 2.0)
			"sad":
				_line(_arc(m + Vector2(0, 4), 5.0, 3.0, PI * 1.2, PI * 1.8, 8), ink, 2.0)
			"surprised":
				_fill(_ellipse(m + Vector2(0, 1), 3.0, 3.6, 10), Color("#5a2a30"), false)
			"angry":
				_line(PackedVector2Array([m + Vector2(-5, 1), m + Vector2(5, 0)]), ink, 2.2)
			"thinking":
				_line(PackedVector2Array([m + Vector2(-3, 1), m + Vector2(5, -1)]), ink, 2.0)
			_:
				_line(_arc(m + Vector2(0, -1.5), 5.0, 2.2, PI * 0.2, PI * 0.8, 6), ink, 1.8)
	if cfg.get("flour", false):
		draw_circle(c + Vector2(4, 12), 2.2, Color(1, 1, 1, 0.7), true, -1.0, true)
		draw_circle(c + Vector2(9, 15), 1.4, Color(1, 1, 1, 0.6), true, -1.0, true)
