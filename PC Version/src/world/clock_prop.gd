extends Node2D
## Clock hands drawn over a painted clock face.
##   tower: stopped at 11:52 until the story restarts it (forward or backward)
##   wall:  the post office clock, which has always run backwards

var mode := "tower"
var radius := 70.0
var _minutes := 11 * 60 + 52.0


func _process(delta: float) -> void:
	if mode == "wall":
		_minutes -= delta * 0.5
	elif Story.f("clock_running"):
		var dir := -1.0 if Story.f("clock_backward") else 1.0
		if _minutes < 11 * 60 + 53 and dir > 0:
			_minutes = 11 * 60 + 53
		_minutes += delta * dir * 0.05
	queue_redraw()


func _draw() -> void:
	var m := fposmod(_minutes, 720.0)
	var hour_a := (m / 720.0) * TAU - PI * 0.5
	var min_a := fposmod(m, 60.0) / 60.0 * TAU - PI * 0.5
	var ink := Color(0.12, 0.1, 0.13)
	var hl := Vector2(cos(hour_a), sin(hour_a)) * radius * 0.52
	var ml := Vector2(cos(min_a), sin(min_a)) * radius * 0.8
	draw_line(Vector2.ZERO, hl, ink, radius * 0.075, true)
	draw_line(Vector2.ZERO, ml, ink, radius * 0.05, true)
	if mode == "wall":
		var sec := -fmod(Time.get_ticks_msec() / 1000.0, 60.0) / 60.0 * TAU - PI * 0.5
		draw_line(Vector2.ZERO, Vector2(cos(sec), sin(sec)) * radius * 0.85, Color(0.66, 0.2, 0.18), radius * 0.025, true)
	draw_circle(Vector2.ZERO, radius * 0.07, Color(0.78, 0.6, 0.3), true, -1.0, true)
