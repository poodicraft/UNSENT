extends Control
## In-game heads-up display: pause and satchel buttons, the current
## objective, and the location name banner.

const Kit := preload("res://src/ui/ui_kit.gd")

var _pause: Button
var _satchel: Button
var _badge: Label
var _badge_bg: Panel
var _objective: Label
var _obj_panel: PanelContainer
var _banner: Label
var _banner_line: ColorRect
var _top_margin := 34.0
var _obj_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y > 0 and safe.position.y > 0:
		_top_margin = maxf(34.0, float(safe.position.y) / float(win.y) * 1280.0 + 12.0)

	_pause = Kit.icon_button("pause", 88)
	_pause.position = Vector2(26, _top_margin)
	_pause.pressed.connect(func(): Story.main.ui.open_pause())
	add_child(_pause)

	_satchel = Kit.icon_button("satchel", 100)
	_satchel.anchor_left = 1.0
	_satchel.anchor_right = 1.0
	_satchel.offset_left = -126
	_satchel.offset_right = -26
	_satchel.offset_top = _top_margin - 6
	_satchel.offset_bottom = _top_margin + 94
	_satchel.pressed.connect(_on_satchel)
	add_child(_satchel)

	_badge_bg = Panel.new()
	_badge_bg.add_theme_stylebox_override("panel", Kit.box(Kit.WAX, 18, 2, Color("#f3c891"), 0, 0))
	_badge_bg.size = Vector2(36, 36)
	_badge_bg.position = Vector2(64, -4)
	_badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_satchel.add_child(_badge_bg)
	_badge = Kit.label("", 20, Color.WHITE, "serif_bold", HORIZONTAL_ALIGNMENT_CENTER)
	_badge.size = Vector2(36, 36)
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_bg.add_child(_badge)
	_badge_bg.visible = false

	_obj_panel = PanelContainer.new()
	_obj_panel.add_theme_stylebox_override("panel", Kit.box(Color(0.06, 0.07, 0.14, 0.72), 22, 0, Kit.GOLD, 0, 12))
	_obj_panel.anchor_left = 0.0
	_obj_panel.anchor_right = 1.0
	_obj_panel.offset_left = 130
	_obj_panel.offset_right = -146
	_obj_panel.offset_top = _top_margin + 6
	_obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_obj_panel)
	_objective = Kit.label("", 21, Color("#e9dfcc"), "italic", HORIZONTAL_ALIGNMENT_CENTER)
	_obj_panel.add_child(_objective)
	_obj_panel.modulate.a = 0.0

	_banner = Kit.label("", 40, Kit.CREAM, "display", HORIZONTAL_ALIGNMENT_CENTER)
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.offset_top = _top_margin + 120
	_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_banner.add_theme_constant_override("shadow_offset_y", 3)
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner_line = ColorRect.new()
	_banner_line.color = Kit.GOLD
	_banner_line.anchor_left = 0.5
	_banner_line.anchor_right = 0.5
	_banner_line.offset_left = -90
	_banner_line.offset_right = 90
	_banner_line.offset_top = _top_margin + 178
	_banner_line.offset_bottom = _top_margin + 180
	_banner_line.modulate.a = 0.0
	_banner_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner_line)

	GameState.objective_changed.connect(_on_objective)
	GameState.letter_changed.connect(func(_id): _refresh_badge())
	_on_objective(GameState.objective)


func _on_satchel() -> void:
	if Story.busy or Story.main.ui.modal_open():
		return
	Audio.sfx("ui_open", -3.0)
	await Story.main.ui.open_satchel("letters")


func set_cinematic(on: bool) -> void:
	var t := create_tween().set_parallel(true)
	for c in [_pause, _satchel, _obj_panel]:
		t.tween_property(c, "modulate:a", 0.0 if on else (1.0 if c != _obj_panel else _obj_alpha()), 0.3)
	_pause.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
	_satchel.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP


func _obj_alpha() -> float:
	return 0.0 if GameState.objective == "" else 0.85


func _on_objective(text: String) -> void:
	_objective.text = text
	_flash_objective()


func _flash_objective() -> void:
	if _objective.text == "":
		_obj_panel.modulate.a = 0.0
		return
	if _obj_tween and _obj_tween.is_valid():
		_obj_tween.kill()
	_obj_tween = create_tween()
	_obj_tween.tween_property(_obj_panel, "modulate:a", 1.0, 0.3)
	_obj_tween.tween_interval(5.0)
	_obj_tween.tween_property(_obj_panel, "modulate:a", 0.0, 1.0)


func show_location(name: String) -> void:
	_banner.text = name
	var t := create_tween().set_parallel(false)
	t.tween_property(_banner, "modulate:a", 1.0, 0.8)
	t.parallel().tween_property(_banner_line, "modulate:a", 0.8, 0.8)
	t.tween_interval(1.8)
	t.tween_property(_banner, "modulate:a", 0.0, 1.0)
	t.parallel().tween_property(_banner_line, "modulate:a", 0.0, 1.0)


func bump_badge() -> void:
	_refresh_badge()
	var t := create_tween()
	t.tween_property(_satchel, "scale", Vector2(1.12, 1.12), 0.12)
	t.tween_property(_satchel, "scale", Vector2.ONE, 0.2)


func clear_badge() -> void:
	GameState.unseen_clues = 0
	GameState.unseen_letters = 0
	_refresh_badge()


func _refresh_badge() -> void:
	var n := GameState.unseen_clues + GameState.unseen_letters
	_badge_bg.visible = n > 0
	_badge.text = str(mini(n, 9)) + ("+" if n > 9 else "")


func _process(_delta: float) -> void:
	_satchel.pivot_offset = _satchel.size * 0.5
