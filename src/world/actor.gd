extends Node2D
## A character in the world: a Puppet plus movement, depth scaling,
## footsteps, a soft ground shadow and a name label when nearby.

const Puppet := preload("res://src/world/puppet.gd")

signal arrived

var id := ""
var puppet: Node2D
var location: Node = null
var is_player := false
var speed := 250.0
var target := Vector2.ZERO
var moving := false
var surface := "wood"
var show_label := false
var _label_alpha := 0.0
var _last_step := 0
var _font: Font


func setup(char_id: String, loc: Node) -> void:
	id = char_id
	location = loc
	puppet = Puppet.new()
	var cdef: Dictionary = Data.characters.get(char_id, {})
	puppet.configure(cdef.get("puppet", {}))
	add_child(puppet)
	_font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://assets/fonts/Lora.ttf"):
		_font = load("res://assets/fonts/Lora.ttf")
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/world/shaders/paper_grain.gdshader")
	var grain := load("res://assets/art/fx/grain.png") if ResourceLoader.exists("res://assets/art/fx/grain.png") else null
	if grain:
		mat.set_shader_parameter("grain", grain)
		puppet.material = mat
	_update_depth()


func face(dir: int) -> void:
	if dir != 0:
		puppet.facing = 1 if dir > 0 else -1


func face_toward(x: float) -> void:
	if absf(x - position.x) > 4.0:
		face(1 if x > position.x else -1)


func set_talking(on: bool, expr := "neutral") -> void:
	puppet.talking = on
	puppet.expression = expr if on else ("neutral" if expr in ["surprised", "angry"] else expr)
	if not on:
		# Let expressions linger a moment, then relax.
		var t := get_tree().create_timer(1.6)
		t.timeout.connect(func():
			if is_instance_valid(puppet) and not puppet.talking:
				puppet.expression = "neutral")


func walk_to(p: Vector2) -> void:
	target = p
	if position.distance_to(p) < 3.0:
		moving = false
		puppet.walking = false
		return
	moving = true
	puppet.walking = true


func walk_to_async(p: Vector2) -> void:
	walk_to(p)
	if moving:
		await arrived


func stop() -> void:
	moving = false
	puppet.walking = false


func depth_scale() -> float:
	return scale.y


func _update_depth() -> void:
	if location:
		var s: float = location.depth_scale(position.y)
		scale = Vector2(s, s)


func _process(delta: float) -> void:
	if moving:
		var to := target - position
		var dist := to.length()
		var step := speed * delta * scale.y
		if dist <= step:
			position = target
			moving = false
			puppet.walking = false
			arrived.emit()
		else:
			position += to / dist * step
			if absf(to.x) > 1.5:
				face(1 if to.x > 0 else -1)
			puppet.walk_phase += step / 24.0
			var k := int(floor(puppet.walk_phase / PI))
			if k != _last_step:
				_last_step = k
				if is_player:
					Audio.step(surface)
		_update_depth()
	var want := 1.0 if show_label else 0.0
	if not is_equal_approx(_label_alpha, want):
		_label_alpha = move_toward(_label_alpha, want, delta * 4.0)
	queue_redraw()


func hit_rect() -> Rect2:
	var s := scale.y
	var h := 270.0 * float(Data.characters.get(id, {}).get("puppet", {}).get("height", 1.0))
	return Rect2(position + Vector2(-48 * s, -h * s - 6 * s), Vector2(96 * s, (h + 20) * s))


func _draw() -> void:
	# Soft ground shadow (drawn unscaled by facing).
	var rx := 40.0 * float(Data.characters.get(id, {}).get("puppet", {}).get("build", 1.0))
	for i in 4:
		var k := 1.0 - i * 0.22
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, rx * (0.7 + i * 0.16), Color(0.02, 0.0, 0.06, 0.11 * k), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _label_alpha > 0.01 and not is_player and _font:
		var nm := Data.char_first_name(id)
		var fs := 22
		var w := _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var h := 270.0 * float(Data.characters.get(id, {}).get("puppet", {}).get("height", 1.0))
		var p := Vector2(-w * 0.5, -h - 26)
		var a := _label_alpha
		draw_rect(Rect2(p + Vector2(-12, -24), Vector2(w + 24, 34)), Color(0.07, 0.07, 0.13, 0.62 * a), true)
		draw_string(_font, p, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.97, 0.92, 0.82, a))
