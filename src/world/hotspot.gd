extends Node2D
## Visual marker for an interactive object: a soft sparkle when there's
## something new to discover, a name chip when the player is close, and a
## signpost arrow for exits.

var def: Dictionary = {}
var rect := Rect2()
var news := false
var near := false
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


func _process(delta: float) -> void:
	_t += delta
	_near_a = move_toward(_near_a, 1.0 if near else 0.0, delta * 4.0)
	queue_redraw()


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
	if _near_a > 0.01:
		_chip(top + Vector2(0, -48 if news else -22), def.get("label", ""), _near_a)


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
	_chip(p + Vector2(0, -34), def.get("label", ""), a * (0.55 + 0.45 * _near_a))


func _star(p: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var ang := TAU * i / 8.0 - PI * 0.5
		var rr := r if i % 2 == 0 else r * 0.32
		pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, c)


func _chip(p: Vector2, text: String, a: float) -> void:
	if text == "" or _font == null:
		return
	var fs := 21
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var r := Rect2(p + Vector2(-w * 0.5 - 12, -25), Vector2(w + 24, 34))
	draw_rect(r, Color(0.07, 0.07, 0.13, 0.66 * a), true)
	draw_rect(r, Color(0.85, 0.72, 0.45, 0.5 * a), false, 1.5)
	draw_string(_font, p + Vector2(-w * 0.5, -2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.98, 0.93, 0.83, a))
