extends Node2D
## A few gulls drifting across the sky with lazy wingbeats.

var area := Rect2(0, 260, 2400, 380)
var count := 4
var _gulls: Array = []


func _ready() -> void:
	for i in count:
		_gulls.append({
			"pos": Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y)),
			"speed": randf_range(28.0, 55.0) * (1.0 if randf() > 0.4 else -1.0),
			"phase": randf() * TAU,
			"size": randf_range(0.7, 1.15),
			"glide": randf() * 5.0,
		})


func _process(delta: float) -> void:
	for g in _gulls:
		g.pos.x += g.speed * delta
		g.pos.y += sin(g.phase * 0.3) * 6.0 * delta
		g.glide -= delta
		if g.glide < -2.2:
			g.glide = randf_range(2.0, 6.0)
		g.phase += delta * (7.0 if g.glide < 0.0 else 0.6)
		if g.pos.x > area.end.x + 60:
			g.pos.x = area.position.x - 60
		elif g.pos.x < area.position.x - 60:
			g.pos.x = area.end.x + 60
	queue_redraw()


func _draw() -> void:
	for g in _gulls:
		var p: Vector2 = g.pos
		var s: float = g.size * 1.6
		var flap := sin(g.phase) * 7.0 * s
		var col := Color(0.96, 0.93, 0.9, 0.9)
		var left := PackedVector2Array([p + Vector2(-16, -flap) * s / 1.6, p + Vector2(-8, -4 - flap * 0.4) * s / 1.6, p])
		var right := PackedVector2Array([p, p + Vector2(8, -4 - flap * 0.4) * s / 1.6, p + Vector2(16, -flap) * s / 1.6])
		draw_polyline(left, col, 2.2 * s / 1.6, true)
		draw_polyline(right, col, 2.2 * s / 1.6, true)
