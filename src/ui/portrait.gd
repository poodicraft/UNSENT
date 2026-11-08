extends Control
## A circular portrait showing a live puppet's head and shoulders.

const Puppet := preload("res://src/world/puppet.gd")

var puppet: Node2D
var char_id := ""
var _ring_col := Color("#d9b46c")


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_char(id: String, expr: String, talking: bool) -> void:
	if id != char_id:
		char_id = id
		if puppet:
			puppet.queue_free()
			puppet = null
		var cdef: Dictionary = Data.characters.get(id, {})
		if cdef.has("puppet"):
			puppet = Puppet.new()
			puppet.configure(cdef.puppet)
			puppet.portrait = true
			add_child(puppet)
			_ring_col = Data.char_color(id)
	if puppet:
		puppet.expression = expr
		puppet.talking = talking
		_layout()
	queue_redraw()


func set_talking(on: bool) -> void:
	if puppet:
		puppet.talking = on


func _layout() -> void:
	if puppet == null:
		return
	var h := float(Data.characters.get(char_id, {}).get("puppet", {}).get("height", 1.0))
	var sc := size.x / 92.0
	puppet.scale = Vector2(sc, sc)
	# Head centre sits at roughly y = -228*h in puppet space.
	puppet.position = Vector2(size.x * 0.40, size.y * 0.58 + 228.0 * h * sc - 14.0 * sc)
	puppet.facing = 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	draw_circle(size * 0.5, r, Color("#2a3150"), true, -1.0, true)
	draw_circle(size * 0.5, r * 0.82, Color(_ring_col, 0.16), true, -1.0, true)
