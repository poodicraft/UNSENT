extends RefCounted
## Shared UI palette, fonts, styleboxes and small widget factories.

const INK := Color("#1d2236")
const INK_SOFT := Color("#4a4658")
const PAPER := Color("#f2e8d5")
const PAPER_DARK := Color("#e0d0b2")
const GOLD := Color("#d9b46c")
const GOLD_DIM := Color("#a8884f")
const NIGHT := Color("#11152a")
const NIGHT_2 := Color("#1b2139")
const CREAM := Color("#f3ead9")
const MUTED := Color("#a59d8c")
const WAX := Color("#a3322c")
const FUTURE := Color("#9cc3ee")
const PAST := Color("#d6a463")
const PRESENT := Color("#a6cf93")
const GOOD := Color("#7fbf7a")
const BAD := Color("#e0705f")

const HANDS := {
	"caveat": "res://assets/fonts/Caveat.ttf",
	"dancing": "res://assets/fonts/DancingScript.ttf",
	"patrick": "res://assets/fonts/PatrickHand.ttf",
	"gochi": "res://assets/fonts/GochiHand.ttf",
	"special": "res://assets/fonts/SpecialElite.ttf",
	"kalam": "res://assets/fonts/Kalam.ttf",
	"handlee": "res://assets/fonts/Handlee.ttf",
}
## Letter body size per handwriting (they have very different x-heights).
const HAND_SIZE := {
	"caveat": 38, "dancing": 33, "patrick": 31, "gochi": 32, "special": 25, "kalam": 27, "handlee": 28,
}

static var _fonts: Dictionary = {}
static var _theme: Theme


static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font = null
	match kind:
		"serif":
			f = _load("res://assets/fonts/Lora.ttf")
		"serif_bold":
			f = _variation(_load("res://assets/fonts/Lora.ttf"), 650)
		"italic":
			f = _load("res://assets/fonts/Lora-Italic.ttf")
		"display":
			f = _variation(_load("res://assets/fonts/Cinzel.ttf"), 600)
		"display_light":
			f = _load("res://assets/fonts/Cinzel.ttf")
		_:
			if HANDS.has(kind):
				f = _load(HANDS[kind])
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[kind] = f
	return f


static func _load(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	return null


static func _variation(base: Font, weight: int) -> Font:
	if base == null:
		return null
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {"wght": weight}
	return fv


static func box(bg: Color, radius := 18, border := 0, border_col := GOLD, shadow := 0, pad := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_col
	s.shadow_size = shadow
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_offset = Vector2(0, 4)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


static func paper_box(radius := 10, pad := 26) -> StyleBox:
	var p := "res://assets/art/ui/panel_paper.png"
	if ResourceLoader.exists(p):
		var t := StyleBoxTexture.new()
		t.texture = load(p)
		t.texture_margin_left = 40
		t.texture_margin_right = 40
		t.texture_margin_top = 40
		t.texture_margin_bottom = 40
		t.set_content_margin_all(pad)
		return t
	return box(PAPER, radius, 0, GOLD, 12, pad)


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("serif")
	t.default_font_size = 28
	# Buttons: cream paper pills with ink text
	var normal := box(Color("#efe4cf"), 40, 2, Color("#c9b48a"), 6, 14)
	normal.content_margin_left = 30
	normal.content_margin_right = 30
	var hover := normal.duplicate()
	hover.bg_color = Color("#f7eedc")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("#dccbaa")
	pressed.shadow_size = 1
	var disabled := normal.duplicate()
	disabled.bg_color = Color("#8d8678")
	disabled.border_color = Color("#6d675c")
	var focus := StyleBoxEmpty.new()
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color("#3d3a34"))
	t.set_font("font", "Button", font("serif_bold"))
	t.set_font_size("font_size", "Button", 27)
	t.set_color("font_color", "Label", CREAM)
	t.set_color("default_color", "RichTextLabel", CREAM)
	t.set_font("normal_font", "RichTextLabel", font("serif"))
	t.set_font("italics_font", "RichTextLabel", font("italic"))
	t.set_font("bold_font", "RichTextLabel", font("serif_bold"))
	t.set_font_size("normal_font_size", "RichTextLabel", 28)
	t.set_font_size("italics_font_size", "RichTextLabel", 28)
	t.set_font_size("bold_font_size", "RichTextLabel", 28)
	t.set_stylebox("panel", "PanelContainer", box(NIGHT_2, 22, 2, Color(GOLD, 0.6), 10, 20))
	# Thin, rounded scrollbars
	var grab := box(Color(GOLD, 0.55), 6, 0, GOLD, 0, 0)
	grab.content_margin_left = 6
	grab.content_margin_right = 6
	var track := StyleBoxEmpty.new()
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", track)
	# Sliders
	var slider := box(Color("#3a3f5c"), 8, 0, GOLD, 0, 0)
	slider.content_margin_top = 6
	slider.content_margin_bottom = 6
	var fill := box(GOLD, 8, 0, GOLD, 0, 0)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", slider)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	_theme = t
	return t


# ─── Widget factories ────────────────────────────────────────────────

static func label(text: String, size := 28, color := CREAM, kind := "serif", align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", Settings.font(size))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func rich(size := 28, color := CREAM) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.add_theme_color_override("default_color", color)
	for k in ["normal_font_size", "italics_font_size", "bold_font_size", "bold_italics_font_size"]:
		r.add_theme_font_size_override(k, Settings.font(size))
	r.add_theme_font_override("normal_font", font("serif"))
	r.add_theme_font_override("italics_font", font("italic"))
	r.add_theme_font_override("bold_font", font("serif_bold"))
	return r


static func button(text: String, min_h := 84) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", Settings.font(27))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(func(): Audio.sfx("ui_tap", -4.0))
	return b


static func dark_button(text: String, min_h := 80) -> Button:
	var b := button(text, min_h)
	var s := box(Color("#262c48"), 40, 2, Color(GOLD, 0.65), 4, 14)
	s.content_margin_left = 28
	s.content_margin_right = 28
	var p := s.duplicate()
	p.bg_color = Color("#343b5e")
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, CREAM)
	return b


static func wax_button(text: String, min_h := 88) -> Button:
	var b := button(text, min_h)
	var s := box(WAX, 44, 2, Color("#e2a15e"), 8, 14)
	s.content_margin_left = 34
	s.content_margin_right = 34
	var p := s.duplicate()
	p.bg_color = WAX.darkened(0.2)
	var d := s.duplicate()
	d.bg_color = Color("#5a4a48")
	d.border_color = Color("#6a5a50")
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color("#fff4e6"))
	b.add_theme_color_override("font_disabled_color", Color("#b0a49a"))
	return b


static func icon_button(icon: String, size := 92) -> Button:
	var Icon := preload("res://src/ui/icon.gd")
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	var s := box(Color(0.07, 0.08, 0.15, 0.72), size / 2, 2, Color(GOLD, 0.7), 6, 0)
	var p := s.duplicate()
	p.bg_color = Color(0.15, 0.17, 0.28, 0.9)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	var ic := Icon.new()
	ic.kind = icon
	ic.color = CREAM
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	b.pressed.connect(func(): Audio.sfx("ui_tap", -4.0))
	return b


## A small drawn mark (dot, ring, check, cross…) sized like text. Used
## instead of symbol characters, which the game's fonts don't all contain.
static func mark(kind: String, color: Color, size := 24) -> Control:
	var Icon := preload("res://src/ui/icon.gd")
	var ic := Icon.new()
	ic.kind = kind
	ic.color = color
	ic.pad = 0.12
	var px := float(Settings.font(size))
	ic.custom_minimum_size = Vector2(px, px)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return ic


## Puts a drawn mark at the start of a button, before its text.
static func lead_mark(b: Button, kind: String, color: Color) -> void:
	var m := mark(kind, color, 26)
	m.anchor_top = 0.5
	m.anchor_bottom = 0.5
	var px := m.custom_minimum_size.x
	m.offset_left = 22
	m.offset_right = 22 + px
	m.offset_top = -px * 0.5
	m.offset_bottom = px * 0.5
	b.add_child(m)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		if b.has_theme_stylebox_override(st):
			var sb: StyleBox = b.get_theme_stylebox(st).duplicate()
			sb.content_margin_left = 34 + px
			b.add_theme_stylebox_override(st, sb)


## Lets a control sit inside a ScrollContainer without blocking finger
## scrolling: it still receives taps, but drags pass through to the scroller.
static func in_list(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c


## A vertical scroller tuned for fingers: a small dead zone so a slightly
## shaky tap still counts as a tap, and no horizontal scrolling.
static func scroller() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.scroll_deadzone = 22
	s.follow_focus = false
	return s


## Screen insets (top, bottom) in UI units that must stay clear of the
## status bar, camera cut-out and gesture bar. Never less than a comfortable
## minimum so nothing hugs the rounded corners of a phone.
static func safe_insets(node: CanvasItem) -> Vector2:
	var top := 0.0
	var bottom := 0.0
	if OS.has_feature("mobile") and node.is_inside_tree():
		var win := DisplayServer.window_get_size()
		var safe := DisplayServer.get_display_safe_area()
		var vs := node.get_viewport_rect().size
		if win.y > 0 and safe.size.y > 0:
			var k := vs.y / float(win.y)
			top = clampf(float(safe.position.y) * k, 0.0, 180.0)
			bottom = clampf(float(win.y - safe.end.y) * k, 0.0, 140.0)
	return Vector2(maxf(top, 26.0), maxf(bottom, 14.0))


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "1.0.1"))


static func origin_color(origin: String) -> Color:
	match origin:
		"past": return PAST
		"future": return FUTURE
		"present": return PRESENT
	return MUTED


static func origin_label(origin: String) -> String:
	match origin:
		"past": return "From the past"
		"future": return "From the future"
		"present": return "From the present"
	return "Origin unknown"


static func fmt_time(secs: float) -> String:
	var m := int(secs / 60.0)
	return "%dh %02dm" % [m / 60, m % 60] if m >= 60 else "%d min" % m
