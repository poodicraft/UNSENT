extends Node2D
## A small expanding ring showing where the player tapped to walk.

var _t := 1.0


func show_at(p: Vector2) -> void:
	position = p
	_t = 0.0


func _process(delta: float) -> void:
	if _t < 1.0:
		_t = minf(1.0, _t + delta * 2.2)
		queue_redraw()


func _draw() -> void:
	if _t >= 1.0:
		return
	var a := 1.0 - _t
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_arc(Vector2.ZERO, 14.0 + _t * 30.0, 0.0, TAU, 32, Color(1.0, 0.93, 0.78, 0.7 * a), 3.0, true)
	draw_arc(Vector2.ZERO, 6.0 + _t * 12.0, 0.0, TAU, 24, Color(1.0, 0.93, 0.78, 0.5 * a), 2.0, true)
