extends Node2D
## Lighthouse beam. A 2D fake of a rotating 3D beam: the beam's on-screen
## length follows cos(angle), and the lamp flares when it faces the viewer.

var length := 1500.0
var width := 110.0
var phase := 0.0
var speed := 0.75
var intensity := 1.0
var target_intensity := 1.0
var _glow: Texture2D


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	if ResourceLoader.exists("res://assets/art/fx/glow.png"):
		_glow = load("res://assets/art/fx/glow.png")


func set_on(on: bool, instant := false) -> void:
	target_intensity = 1.0 if on else 0.0
	if instant:
		intensity = target_intensity


func _process(delta: float) -> void:
	phase += delta * speed
	intensity = move_toward(intensity, target_intensity, delta * 1.6)
	queue_redraw()


func _draw() -> void:
	if intensity <= 0.01:
		return
	var c := cos(phase)
	var s := sin(phase)
	var dir := 1.0 if c >= 0.0 else -1.0
	var reach := length * absf(c)
	var a := 0.17 * intensity * (0.4 + 0.6 * absf(c))
	var warm := Color(1.0, 0.94, 0.78)
	var pts := PackedVector2Array([
		Vector2(0, -width * 0.07), Vector2(dir * reach, -width * 0.5),
		Vector2(dir * reach, width * 0.5), Vector2(0, width * 0.07)])
	var cols := PackedColorArray([Color(warm, a), Color(warm, 0.0), Color(warm, 0.0), Color(warm, a)])
	draw_polygon(pts, cols)
	# inner core
	var core := PackedVector2Array([
		Vector2(0, -width * 0.03), Vector2(dir * reach * 0.8, -width * 0.16),
		Vector2(dir * reach * 0.8, width * 0.16), Vector2(0, width * 0.03)])
	draw_polygon(core, PackedColorArray([Color(warm, a * 1.2), Color(warm, 0.0), Color(warm, 0.0), Color(warm, a * 1.2)]))
	var flare := pow(maxf(s, 0.0), 8.0)
	if _glow:
		var r := 70.0 + flare * 160.0
		draw_texture_rect(_glow, Rect2(-r, -r, r * 2, r * 2), false, Color(warm, (0.45 + flare * 0.55) * intensity))
	else:
		draw_circle(Vector2.ZERO, 26.0 + flare * 40.0, Color(warm, 0.5 * intensity))
