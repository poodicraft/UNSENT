extends Node2D
## Paper lanterns for Lantern Night: bobbing on the water, or rising into the sky.

var area := Rect2(0, 860, 2400, 80)
var mode := "float"        # "float" or "rise"
var count := 14
var _items: Array = []
var _glow: Texture2D


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if ResourceLoader.exists("res://assets/art/fx/glow.png"):
		_glow = load("res://assets/art/fx/glow.png")
	for i in count:
		_items.append(_new_item(true))


func _new_item(initial: bool) -> Dictionary:
	var y := randf_range(area.position.y, area.end.y)
	if mode == "rise" and not initial:
		y = area.end.y + randf_range(0, 120)
	return {
		"pos": Vector2(randf_range(area.position.x, area.end.x), y),
		"phase": randf() * TAU,
		"size": randf_range(0.6, 1.1),
		"hue": randf_range(-0.04, 0.05),
		"speed": randf_range(18.0, 34.0),
	}


func release() -> void:
	mode = "rise"
	for it in _items:
		it.speed = randf_range(22.0, 40.0)


func _process(delta: float) -> void:
	for i in _items.size():
		var it: Dictionary = _items[i]
		it.phase += delta
		if mode == "rise":
			it.pos.y -= it.speed * delta
			it.pos.x += sin(it.phase * 0.7) * 10.0 * delta
			if it.pos.y < -80:
				_items[i] = _new_item(false)
		else:
			it.pos.x += sin(it.phase * 0.3) * 4.0 * delta
	queue_redraw()


func _draw() -> void:
	for it in _items:
		var p: Vector2 = it.pos
		var s: float = it.size
		var bob := sin(it.phase * 1.4) * 3.0 if mode == "float" else 0.0
		p.y += bob
		var c := Color.from_hsv(0.08 + it.hue, 0.55, 1.0)
		if _glow:
			var r := 70.0 * s
			draw_texture_rect(_glow, Rect2(p - Vector2(r, r * 1.1), Vector2(r * 2, r * 2)), false, Color(c, 0.5))
		var body := Rect2(p + Vector2(-9, -26) * s, Vector2(18, 24) * s)
		draw_rect(body, Color(1.0, 0.86, 0.55), true)
		draw_rect(Rect2(body.position + Vector2(0, body.size.y * 0.15), Vector2(body.size.x, body.size.y * 0.7)), Color(1.0, 0.95, 0.75), true)
		draw_rect(Rect2(p + Vector2(-10, -28) * s, Vector2(20, 3) * s), Color(0.55, 0.25, 0.2), true)
		draw_rect(Rect2(p + Vector2(-10, -3) * s, Vector2(20, 3) * s), Color(0.55, 0.25, 0.2), true)
