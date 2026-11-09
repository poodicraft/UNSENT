extends Control
## Small vector icons, drawn to fit the control's rect.

var kind := "letter":
	set(v):
		kind = v
		queue_redraw()
var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()
var pad := 0.26


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var u := s * (1.0 - pad * 2.0)
	var b := o + Vector2(s, s) * pad
	var w := maxf(2.0, s * 0.055)
	var c := color
	var P := func(x: float, y: float) -> Vector2:
		return b + Vector2(x, y) * u
	match kind:
		"satchel":
			var body := PackedVector2Array([P.call(0.05, 0.38), P.call(0.95, 0.38), P.call(0.9, 0.95), P.call(0.1, 0.95)])
			draw_colored_polygon(body, Color(c, 0.18))
			_poly(body, c, w)
			_poly(PackedVector2Array([P.call(0.05, 0.38), P.call(0.95, 0.38), P.call(0.8, 0.66), P.call(0.2, 0.66)]), c, w)
			draw_arc(P.call(0.5, 0.38), u * 0.28, PI, TAU, 16, c, w, true)
			draw_circle(P.call(0.5, 0.66), u * 0.06, c, true, -1.0, true)
		"pause":
			draw_rect(Rect2(P.call(0.22, 0.12), Vector2(u * 0.18, u * 0.76)), c)
			draw_rect(Rect2(P.call(0.6, 0.12), Vector2(u * 0.18, u * 0.76)), c)
		"letter":
			var r := PackedVector2Array([P.call(0.02, 0.2), P.call(0.98, 0.2), P.call(0.98, 0.82), P.call(0.02, 0.82)])
			draw_colored_polygon(r, Color(c, 0.15))
			_poly(r, c, w)
			draw_polyline(PackedVector2Array([P.call(0.02, 0.2), P.call(0.5, 0.56), P.call(0.98, 0.2)]), c, w, true)
		"clue":
			draw_arc(P.call(0.42, 0.42), u * 0.3, 0.0, TAU, 24, c, w * 1.2, true)
			draw_line(P.call(0.64, 0.64), P.call(0.95, 0.95), c, w * 1.8, true)
		"people":
			draw_circle(P.call(0.36, 0.3), u * 0.15, c, false, w, true)
			draw_arc(P.call(0.36, 0.86), u * 0.3, PI, TAU, 16, c, w, true)
			draw_circle(P.call(0.7, 0.36), u * 0.12, Color(c, 0.7), false, w, true)
			draw_arc(P.call(0.72, 0.88), u * 0.24, PI * 1.05, TAU, 14, Color(c, 0.7), w, true)
		"item", "key":
			draw_circle(P.call(0.28, 0.5), u * 0.2, c, false, w * 1.2, true)
			draw_line(P.call(0.48, 0.5), P.call(0.95, 0.5), c, w * 1.2, true)
			draw_line(P.call(0.8, 0.5), P.call(0.8, 0.7), c, w * 1.2, true)
			draw_line(P.call(0.92, 0.5), P.call(0.92, 0.66), c, w * 1.2, true)
		"back":
			draw_polyline(PackedVector2Array([P.call(0.62, 0.15), P.call(0.28, 0.5), P.call(0.62, 0.85)]), c, w * 1.4, true)
		"close", "cross":
			draw_line(P.call(0.15, 0.15), P.call(0.85, 0.85), c, w * 1.3, true)
			draw_line(P.call(0.85, 0.15), P.call(0.15, 0.85), c, w * 1.3, true)
		"check":
			draw_polyline(PackedVector2Array([P.call(0.1, 0.52), P.call(0.4, 0.8), P.call(0.92, 0.2)]), c, w * 1.4, true)
		"dot":
			draw_circle(P.call(0.5, 0.5), u * 0.36, c, true, -1.0, true)
		"ring":
			draw_circle(P.call(0.5, 0.5), u * 0.33, c, false, maxf(1.5, w * 1.1), true)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := TAU * i / 10.0 - PI * 0.5
				var r2 := 0.48 if i % 2 == 0 else 0.2
				pts.append(P.call(0.5 + cos(a) * r2, 0.52 + sin(a) * r2))
			draw_colored_polygon(pts, c)
		"chute":
			draw_rect(Rect2(P.call(0.36, 0.0), Vector2(u * 0.28, u * 0.6)), Color(c, 0.2))
			_poly(PackedVector2Array([P.call(0.36, 0.0), P.call(0.64, 0.0), P.call(0.64, 0.6), P.call(0.36, 0.6)]), c, w)
			_poly(PackedVector2Array([P.call(0.12, 0.62), P.call(0.88, 0.62), P.call(0.76, 0.98), P.call(0.24, 0.98)]), c, w)
		"gear":
			draw_circle(P.call(0.5, 0.5), u * 0.17, c, false, w * 1.2, true)
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(P.call(0.5 + cos(a) * 0.28, 0.5 + sin(a) * 0.28), P.call(0.5 + cos(a) * 0.44, 0.5 + sin(a) * 0.44), c, w * 1.6, true)
			draw_arc(P.call(0.5, 0.5), u * 0.3, 0.0, TAU, 24, c, w, true)
		"quill":
			draw_polyline(PackedVector2Array([P.call(0.1, 0.9), P.call(0.86, 0.12)]), c, w, true)
			var f := PackedVector2Array([P.call(0.86, 0.1), P.call(0.48, 0.3), P.call(0.32, 0.66), P.call(0.6, 0.5)])
			draw_colored_polygon(f, Color(c, 0.4))
			_poly(f, c, w * 0.8)
		"flip":
			draw_arc(P.call(0.5, 0.5), u * 0.36, PI * 0.15, PI * 1.6, 20, c, w * 1.2, true)
			draw_colored_polygon(PackedVector2Array([P.call(0.86, 0.36), P.call(0.98, 0.62), P.call(0.68, 0.6)]), c)
		"ticket":
			_poly(PackedVector2Array([P.call(0.0, 0.25), P.call(1.0, 0.25), P.call(1.0, 0.75), P.call(0.0, 0.75)]), c, w)
			for i in 5:
				draw_circle(P.call(0.68, 0.3 + i * 0.1), u * 0.02, c, true, -1.0, true)
		"lantern":
			_poly(PackedVector2Array([P.call(0.3, 0.2), P.call(0.7, 0.2), P.call(0.78, 0.82), P.call(0.22, 0.82)]), c, w)
			draw_rect(Rect2(P.call(0.36, 0.42), Vector2(u * 0.28, u * 0.22)), Color(c, 0.5))
			draw_line(P.call(0.5, 0.02), P.call(0.5, 0.2), c, w, true)
		"fade":
			for i in 3:
				draw_line(P.call(0.1, 0.25 + i * 0.25), P.call(0.9, 0.25 + i * 0.25), Color(c, 0.9 - i * 0.3), w, true)
		"home":
			_poly(PackedVector2Array([P.call(0.12, 0.5), P.call(0.5, 0.12), P.call(0.88, 0.5), P.call(0.88, 0.92), P.call(0.12, 0.92)]), c, w)
		_:
			draw_circle(P.call(0.5, 0.5), u * 0.3, c, true, -1.0, true)


func _poly(p: PackedVector2Array, c: Color, w: float) -> void:
	var q := p.duplicate()
	q.append(p[0])
	draw_polyline(q, c, w, true)
