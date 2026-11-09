extends Node2D
## Visual marker for an interactive object: a soft sparkle when there's
## something new to discover, a name chip when the player is close, and a
## signpost arrow for exits.

var def: Dictionary = {}
var rect := Rect2()
var news := false
var near := false
## PC: the mouse is over it (set by the location).
var hovered := false
## PC: it's what the E key will use; the name tag shows an "E" key cap.
var key_hint := false
var _t := 0.0
var _near_a := 0.0
var _font: Font
var _glow: Texture2D


func setup(d: Dictionary) -> void:
	def = d
	var r: Array = d.get("rect", [0, 0, 10, 10])
	rect = Rect2(r[0], r[1], r[2], r[3])
	_t = randf() * 5.0
	_font = load("res://assets/fonts/Lora.ttf") if ResourceLoader.exists("res://assets/fonts/Lora.ttf") else ThemeDB.fallback_font
	if ResourceLoader.exists("res://assets/art/fx/glow.png"):
		_glow = load("res://assets/art/fx/glow.png")


func is_exit() -> bool:
	return def.has("exit")


## False when this tag would cover another (the location decides).
var tag_ok := true
var _tag_a := 1.0


func _process(delta: float) -> void:
	_t += delta
	_near_a = move_toward(_near_a, 1.0 if near else 0.0, delta * 4.0)
	_tag_a = move_toward(_tag_a, 1.0 if tag_ok else 0.0, delta * 6.0)
	queue_redraw()


## Where the name tag sits (local coordinates, before keeping it on screen).
func tag_anchor() -> Vector2:
	if is_exit():
		var c := rect.get_center()
		return Vector2(c.x, rect.position.y + rect.size.y * 0.42) + Vector2(0, -34)
	return Vector2(rect.get_center().x, rect.position.y) + Vector2(0, -48 if news else -22)


## The tag's rectangle on screen.
func tag_screen_rect() -> Rect2:
	var label: String = def.get("label", "")
	if label == "" or _font == null or not is_inside_tree():
		return Rect2()
	return get_canvas_transform() * get_global_transform() * chip_rect(tag_anchor(), label)


func _draw() -> void:
	var top := Vector2(rect.get_center().x, rect.position.y)
	if is_exit():
		_draw_exit()
		return
	if news:
		var p := top + Vector2(0, -18 + sin(_t * 2.2) * 5.0)
		var pulse := 0.65 + 0.35 * sin(_t * 3.0)
		if _glow:
			draw_texture_rect(_glow, Rect2(p - Vector2(34, 34), Vector2(68, 68)), false, Color(1.0, 0.86, 0.55, 0.55 * pulse))
		_star(p, 11.0 * (0.9 + 0.1 * pulse), Color(1.0, 0.95, 0.8, 0.95))
	if _near_a * _tag_a > 0.01:
		_chip(tag_anchor(), def.get("label", ""), _near_a * _tag_a)


func _draw_exit() -> void:
	var arrow: String = def.get("arrow", "right")
	var c := rect.get_center()
	var p := Vector2(c.x, rect.position.y + rect.size.y * 0.42)
	var bob := sin(_t * 2.4) * 4.0
	var dirv := Vector2.RIGHT
	match arrow:
		"left": dirv = Vector2.LEFT
		"up": dirv = Vector2.UP
		"down": dirv = Vector2.DOWN
	p += dirv * bob
	var a := 0.55 + 0.45 * _near_a
	var side := dirv.orthogonal()
	var tri := PackedVector2Array([p + dirv * 16, p - dirv * 10 + side * 13, p - dirv * 4, p - dirv * 10 - side * 13])
	if _glow:
		draw_texture_rect(_glow, Rect2(p - Vector2(30, 30), Vector2(60, 60)), false, Color(1.0, 0.9, 0.7, 0.35 * a))
	draw_colored_polygon(tri, Color(1.0, 0.96, 0.86, 0.85 * a))
	if _tag_a > 0.01:
		_chip(tag_anchor(), def.get("label", ""), a * (0.55 + 0.45 * _near_a) * _tag_a)


func _star(p: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var ang := TAU * i / 8.0 - PI * 0.5
		var rr := r if i % 2 == 0 else r * 0.32
		pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, c)


## The name tag over an object. It is kept fully on screen: near the edge
## of a scene it slides inwards instead of being cut off.
func chip_rect(p: Vector2, text: String) -> Rect2:
	var fs := 21
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + (KEYCAP if key_hint else 0.0)
	var r := Rect2(p + Vector2(-w * 0.5 - 12, -25), Vector2(w + 24, 34))
	if is_inside_tree():
		var to_screen := get_canvas_transform() * get_global_transform()
		var vr := get_viewport_rect()
		# Tags of things that are on screen slide into view (a tall object's
		# tag would otherwise sit above the top of the screen); tags of
		# things off screen stay put.
		if vr.intersects(to_screen * rect) or vr.intersects(to_screen * r):
			var to_local := to_screen.affine_inverse()
			var tl: Vector2 = to_local * (vr.position + Vector2(10, 10))
			var br: Vector2 = to_local * (vr.end - Vector2(10, 10))
			r.position.x = clampf(r.position.x, tl.x, maxf(tl.x, br.x - r.size.x))
			r.position.y = clampf(r.position.y, tl.y, maxf(tl.y, br.y - r.size.y))
	return r


func _chip(p: Vector2, text: String, a: float) -> void:
	if text == "" or _font == null:
		return
	var fs := 21
	var r := chip_rect(p, text)
	draw_rect(r, Color(0.07, 0.07, 0.13, (0.8 if hovered else 0.66) * a), true)
	draw_rect(r, Color(0.85, 0.72, 0.45, (0.9 if hovered else 0.5) * a), false, 1.5)
	var x := r.position.x + 12.0
	if key_hint:
		draw_keycap(self, _font, Vector2(x, r.position.y + 6.0), a)
		x += KEYCAP
	draw_string(_font, Vector2(x, r.position.y + 23.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.98, 0.93, 0.83, a))


## Width of the "E" key cap and the gap after it.
const KEYCAP := 31.0


## A small gold key cap with an "E" on it (shared with Actor's name tag).
static func draw_keycap(ci: CanvasItem, font: Font, pos: Vector2, a: float) -> void:
	var kr := Rect2(pos, Vector2(23, 23))
	ci.draw_rect(kr, Color(0.85, 0.72, 0.45, 0.92 * a), true)
	var ts := font.get_string_size("E", HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
	ci.draw_string(font, Vector2(kr.position.x + (kr.size.x - ts.x) * 0.5, kr.position.y + 17.5), "E",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.07, 0.07, 0.13, a))
