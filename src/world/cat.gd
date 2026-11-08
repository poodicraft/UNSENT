extends Node2D
## Postscript, the post office cat: an ink-black loaf with a stamp-shaped
## white patch, a swishing tail, and opinions.

var _t := 0.0
var _blink := 0.0
var _blink_timer := 3.0
var _alert := 0.0


func poke() -> void:
	_alert = 2.0


func _process(delta: float) -> void:
	_t += delta
	_alert = maxf(0.0, _alert - delta)
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 0.18
		_blink_timer = randf_range(2.0, 6.0)
	_blink = maxf(0.0, _blink - delta)
	queue_redraw()


func _draw() -> void:
	var fur := Color("#1c1a24")
	var fur2 := Color("#2b2836")
	var outline := Color("#0c0b10")
	# cushion
	var cushion := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		cushion.append(Vector2(cos(a) * 58, sin(a) * 15 + 6))
	draw_colored_polygon(cushion, Color("#8a3b4a"))
	draw_polyline(cushion + PackedVector2Array([cushion[0]]), Color("#5a2230"), 2.0, true)
	# tail
	var sw := sin(_t * 1.3) * 10.0
	var tail := PackedVector2Array([Vector2(-40, -6), Vector2(-56, -10 + sw * 0.3), Vector2(-62, -24 + sw), Vector2(-54, -36 + sw * 1.2)])
	draw_polyline(tail, fur, 8.0, true)
	# body loaf
	var body := PackedVector2Array()
	for i in 28:
		var a := PI + PI * i / 27.0
		body.append(Vector2(cos(a) * 46, sin(a) * 30 - 2))
	body.append(Vector2(46, 4))
	body.append(Vector2(-46, 4))
	draw_colored_polygon(body, fur)
	draw_polyline(body + PackedVector2Array([body[0]]), outline, 2.0, true)
	# head
	var lift := 8.0 if _alert > 0.0 else 0.0
	var hc := Vector2(30, -30 - lift + sin(_t * 0.8) * 0.8)
	draw_circle(hc, 19.0, fur2, true, -1.0, true)
	for e in [Vector2(-12, -13), Vector2(8, -15)]:
		var ear := PackedVector2Array([hc + e + Vector2(-6, 4), hc + e + Vector2(2, -12), hc + e + Vector2(8, 4)])
		draw_colored_polygon(ear, fur2)
	# stamp-shaped white patch
	draw_rect(Rect2(hc + Vector2(-8, 14), Vector2(12, 10)), Color("#efe7da"), true)
	# eyes
	var open := _blink <= 0.0
	for ep in [Vector2(-6, -2), Vector2(8, -2)]:
		if open and _alert > 0.0:
			draw_circle(hc + ep, 4.2, Color("#e9c54a"), true, -1.0, true)
			draw_circle(hc + ep, 1.8, Color.BLACK, true, -1.0, true)
		elif open:
			draw_line(hc + ep + Vector2(-4, 0), hc + ep + Vector2(4, -1), Color("#e9c54a"), 2.4, true)
		else:
			draw_line(hc + ep + Vector2(-4, 1), hc + ep + Vector2(4, 1), Color("#000000"), 2.0, true)
	draw_circle(hc + Vector2(1, 6), 2.0, Color("#d98a9a"), true, -1.0, true)
