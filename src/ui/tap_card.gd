extends PanelContainer
## A panel that behaves like a button but sizes itself to its content (a
## Button doesn't grow to fit child controls, so wrapped text spilled out).
## A tap — press and release inside without dragging — emits `pressed`.
## It lets drags through to a parent ScrollContainer, so lists of cards
## scroll with a finger on touch screens.

signal pressed

var disabled := false:
	set(v):
		disabled = v
		modulate.a = 0.5 if v else 1.0
var _normal: StyleBox
var _down: StyleBox
var _press := false
var _press_pos := Vector2.ZERO

const DRAG_CANCEL := 26.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE


func set_styles(normal: StyleBox, down: StyleBox = null) -> void:
	_normal = normal
	_down = down if down else normal
	add_theme_stylebox_override("panel", _normal)


func _gui_input(e: InputEvent) -> void:
	if disabled:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = true
			_press_pos = e.position
			_show_down(true)
		elif _press:
			_press = false
			_show_down(false)
			if Rect2(Vector2.ZERO, size).has_point(e.position):
				Audio.sfx("ui_tap", -4.0)
				pressed.emit()
	elif e is InputEventMouseMotion and _press:
		if e.position.distance_to(_press_pos) > DRAG_CANCEL or not Rect2(Vector2.ZERO, size).has_point(e.position):
			_press = false
			_show_down(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCROLL_BEGIN or what == NOTIFICATION_VISIBILITY_CHANGED:
		if _press:
			_press = false
			_show_down(false)


func _show_down(on: bool) -> void:
	if _normal:
		add_theme_stylebox_override("panel", _down if on else _normal)
