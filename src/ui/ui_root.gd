extends CanvasLayer
## Root of all UI. Owns the HUD, dialogue box, modal panels and overlays,
## and exposes the async API the Story director uses.

const Kit := preload("res://src/ui/ui_kit.gd")
const DialogueBox := preload("res://src/ui/dialogue_box.gd")
const Hud := preload("res://src/ui/hud.gd")
const LetterReader := preload("res://src/ui/letter_reader.gd")
const Satchel := preload("res://src/ui/satchel.gd")
const Panels := preload("res://src/ui/panels.gd")
const Icon := preload("res://src/ui/icon.gd")

var root: Control
var hud: Control
var dialogue: Control
var modal_layer: Control
var overlay: CanvasLayer
var _fade: ColorRect
var _flash: ColorRect
var _bars: Array = []
var _letterbox_on := false
var _toasts: VBoxContainer
var _ripple: ColorRect
var _ripple_mat: ShaderMaterial
var _grain: ColorRect
var _vignette: ColorRect
var _modals: Array = []


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Kit.theme()
	add_child(root)

	# Atmosphere overlays sit beneath the UI but above the world.
	var atmo := CanvasLayer.new()
	atmo.layer = 5
	add_child(atmo)
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = preload("res://src/world/shaders/vignette.gdshader")
	_vignette.material = vm
	atmo.add_child(_vignette)
	_grain = ColorRect.new()
	_grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://src/world/shaders/grain.gdshader")
	if ResourceLoader.exists("res://assets/art/fx/noise.png"):
		gm.set_shader_parameter("noise", load("res://assets/art/fx/noise.png"))
		atmo.add_child(_grain)
	_grain.material = gm
	_ripple = ColorRect.new()
	_ripple.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ripple_mat = ShaderMaterial.new()
	_ripple_mat.shader = preload("res://src/world/shaders/ripple.gdshader")
	_ripple.material = _ripple_mat
	_ripple.visible = false
	atmo.add_child(_ripple)

	hud = Hud.new()
	root.add_child(hud)

	# Letterbox bars (cinematic moments)
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0.02, 0.02, 0.04, 1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		if i == 0:
			bar.anchor_top = 0.0
			bar.anchor_bottom = 0.0
			bar.offset_top = -110
			bar.offset_bottom = 0
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = 0
			bar.offset_bottom = 110
		root.add_child(bar)
		_bars.append(bar)

	dialogue = DialogueBox.new()
	root.add_child(dialogue)

	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal_layer)

	overlay = CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)
	var oroot := Control.new()
	oroot.set_anchors_preset(Control.PRESET_FULL_RECT)
	oroot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oroot.theme = Kit.theme()
	overlay.add_child(oroot)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.85, 0.9, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oroot.add_child(_flash)
	_toasts = VBoxContainer.new()
	_toasts.anchor_left = 0.0
	_toasts.anchor_right = 1.0
	_toasts.offset_left = 40
	_toasts.offset_right = -40
	_toasts.offset_top = 150
	_toasts.add_theme_constant_override("separation", 10)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oroot.add_child(_toasts)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.02, 0.02, 0.05, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oroot.add_child(_fade)
	set_world_ui(false)


## Shows/hides in-game UI (HUD + atmosphere) — hidden on the title screen.
func set_world_ui(on: bool) -> void:
	hud.visible = on
	_vignette.visible = on
	_grain.visible = on


func modal_open() -> bool:
	return not _modals.is_empty()


func push_modal(m: Control) -> void:
	_modals.append(m)
	modal_layer.add_child(m)


func pop_modal(m: Control) -> void:
	_modals.erase(m)
	if is_instance_valid(m):
		m.queue_free()


## Android back / Escape: close the top modal, or open the pause menu.
func back_pressed() -> bool:
	if not _modals.is_empty():
		var top: Control = _modals.back()
		if top.has_method("on_back"):
			top.on_back()
			return true
	return false


# ─── Overlays ────────────────────────────────────────────────────────

func fade(out: bool, secs := 0.8) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if out else Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0 if out else 0.0, secs).set_trans(Tween.TRANS_SINE)
	await t.finished


func fade_instant(alpha: float) -> void:
	_fade.color.a = alpha
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if alpha > 0.5 else Control.MOUSE_FILTER_IGNORE


func letterbox(on: bool) -> void:
	if on == _letterbox_on:
		return
	_letterbox_on = on
	hud.set_cinematic(on)
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_bars[0], "offset_top", 0.0 if on else -110.0, 0.5)
	t.tween_property(_bars[0], "offset_bottom", 110.0 if on else 0.0, 0.5)
	t.tween_property(_bars[1], "offset_top", -110.0 if on else 0.0, 0.5)
	t.tween_property(_bars[1], "offset_bottom", 0.0 if on else 110.0, 0.5)


func flash() -> void:
	if Settings.reduce_motion:
		_flash.color.a = 0.25
	else:
		_flash.color.a = 0.85
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.0, 0.6).set_ease(Tween.EASE_OUT)


func ripple() -> void:
	if Settings.reduce_motion:
		return
	_ripple.visible = true
	var vs := root.get_viewport_rect().size
	_ripple_mat.set_shader_parameter("aspect", vs.x / vs.y)
	_ripple_mat.set_shader_parameter("progress", 0.0)
	var t := create_tween()
	t.tween_method(func(v): _ripple_mat.set_shader_parameter("progress", v), 0.0, 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): _ripple.visible = false)


func toast(text: String, icon := "star") -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Kit.box(Color(0.07, 0.08, 0.15, 0.92), 30, 2, Color(Kit.GOLD, 0.6), 8, 12))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(row)
	var ic := Icon.new()
	ic.kind = {"chute": "chute", "letter": "letter", "item": "item", "clue": "clue", "fade": "fade"}.get(icon, "star")
	ic.color = Kit.GOLD
	ic.custom_minimum_size = Vector2(40, 40)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var l := Kit.label(text, 23, Kit.CREAM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	_toasts.add_child(pc)
	pc.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(pc, "modulate:a", 1.0, 0.25)
	t.tween_interval(2.8)
	t.tween_property(pc, "modulate:a", 0.0, 0.5)
	t.tween_callback(pc.queue_free)


func toast_clue(cid: String) -> void:
	toast("Clue noted — " + Data.clue(cid).get("title", cid), "clue")
	hud.bump_badge()


## Full-screen title card (night changes). Waits for a tap or a few seconds.
func card(title: String, subtitle: String, on_black := false) -> void:
	var c := Panels.TitleCard.new()
	c.setup(title, subtitle, on_black)
	overlay.get_child(0).add_child(c)
	await c.done
	c.queue_free()


## The "consequence" card shown after a delivery changes something.
func consequence(title: String, subtitle: String) -> void:
	var c := Panels.ConsequenceCard.new()
	c.setup(title, subtitle)
	overlay.get_child(0).add_child(c)
	Audio.sfx("consequence", -3.0)
	await c.done
	c.queue_free()


func delivery_flourish(letter_id: String, who: String) -> void:
	var c := Panels.DeliveredStamp.new()
	c.setup(letter_id, who)
	overlay.get_child(0).add_child(c)
	await c.done
	c.queue_free()


# ─── Modal panels ────────────────────────────────────────────────────

func open_letter(letter_id: String) -> void:
	var r := LetterReader.new()
	push_modal(r)
	r.open(letter_id)
	Audio.duck(true)
	await r.closed
	Audio.duck(false)
	pop_modal(r)


func open_satchel(tab := "letters") -> void:
	var s := Satchel.new()
	push_modal(s)
	s.open(tab)
	hud.clear_badge()
	await s.closed
	pop_modal(s)


func ask_panel(npc_id: String) -> String:
	var p := Panels.AskPanel.new()
	push_modal(p)
	p.open(npc_id)
	var r: String = await p.picked
	pop_modal(p)
	return r


func pick_letter(npc_id: String) -> String:
	var p := Panels.LetterPicker.new()
	push_modal(p)
	p.open(npc_id)
	var r: String = await p.picked
	pop_modal(p)
	return r


func confirm_delivery(letter_id: String, who: String) -> bool:
	var p := Panels.ConfirmDelivery.new()
	push_modal(p)
	p.open(letter_id, who)
	var r: bool = await p.answered
	pop_modal(p)
	return r


func open_pause() -> void:
	if modal_open() or Story.busy:
		return
	var p := Panels.PauseMenu.new()
	push_modal(p)
	p.open()
	await p.closed
	pop_modal(p)


func open_settings() -> void:
	var p := Panels.SettingsPanel.new()
	push_modal(p)
	p.open()
	await p.closed
	pop_modal(p)


func open_saves(mode: String) -> String:
	var p := Panels.SavePanel.new()
	push_modal(p)
	p.open(mode)
	var r: String = await p.picked
	pop_modal(p)
	return r


func confirm(question: String, yes := "Yes", no := "Cancel") -> bool:
	var p := Panels.ConfirmBox.new()
	push_modal(p)
	p.open(question, yes, no)
	var r: bool = await p.answered
	pop_modal(p)
	return r
