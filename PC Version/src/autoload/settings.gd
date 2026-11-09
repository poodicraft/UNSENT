extends Node
## Player preferences, persisted to user://settings.cfg.
## (On Windows user:// is %APPDATA%\UNSENT.)

signal changed

const PATH := "user://settings.cfg"
## The window size used when leaving fullscreen (shrunk to fit small screens).
const WINDOWED_SIZE := Vector2i(1600, 900)
const MIN_WINDOW_SIZE := Vector2i(960, 540)

var music_volume := 0.8
var ambience_volume := 0.7
var sfx_volume := 0.85
var text_speed := 1.0        # 0.5 .. 2.0 (multiplier), 3.0 = instant
var text_size := 1           # 0 small, 1 medium, 2 large
var reduce_motion := false
var show_hints := true       # sparkle markers over unexplored things
# PC display options
var fullscreen := true
var vsync := true


## The game is laid out for 16:9 and fills taller or wider screens up to
## this shape (16:10, 4:3, 18:9…). Wider still (21:9, 32:9 ultra-wides) the
## extra width becomes side bars, so every scene stays fully in view.
const MAX_ASPECT := 2.0
const BASE_SIZE := Vector2i(1920, 1080)


func _ready() -> void:
	load_settings()
	get_tree().root.size_changed.connect(_fit_aspect)
	_fit_aspect()
	if _window_ok():
		DisplayServer.window_set_min_size(MIN_WINDOW_SIZE)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		# The game starts fullscreen (project setting), so only a player who
		# chose a window needs a change here. That way a window mode given on
		# the command line (--windowed, used by the tests) is respected too:
		# the engine applies it before this runs and doesn't report it to us.
		if not fullscreen:
			apply_display()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	music_volume = cf.get_value("audio", "music", music_volume)
	ambience_volume = cf.get_value("audio", "ambience", ambience_volume)
	sfx_volume = cf.get_value("audio", "sfx", sfx_volume)
	text_speed = cf.get_value("text", "speed", text_speed)
	text_size = cf.get_value("text", "size", text_size)
	reduce_motion = cf.get_value("access", "reduce_motion", reduce_motion)
	show_hints = cf.get_value("access", "show_hints", show_hints)
	fullscreen = cf.get_value("display", "fullscreen", fullscreen)
	vsync = cf.get_value("display", "vsync", vsync)


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music", music_volume)
	cf.set_value("audio", "ambience", ambience_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("text", "speed", text_speed)
	cf.set_value("text", "size", text_size)
	cf.set_value("access", "reduce_motion", reduce_motion)
	cf.set_value("access", "show_hints", show_hints)
	cf.set_value("display", "fullscreen", fullscreen)
	cf.set_value("display", "vsync", vsync)
	cf.save(PATH)
	changed.emit()


## Base font size scaled by the text-size preference.
func font(base: int) -> int:
	var mul: float = [0.88, 1.0, 1.16][clampi(text_size, 0, 2)]
	return int(round(base * mul))


# ─── Display (PC) ────────────────────────────────────────────────────

func _fit_aspect() -> void:
	var root := get_tree().root
	var win := root.size
	if win.y <= 0:
		return
	var a := float(win.x) / float(win.y)
	var aspect := Window.CONTENT_SCALE_ASPECT_EXPAND
	var base := BASE_SIZE
	if a > MAX_ASPECT + 0.001:
		aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		base = Vector2i(roundi(BASE_SIZE.y * MAX_ASPECT), BASE_SIZE.y)
	if root.content_scale_aspect != aspect or root.content_scale_size != base:
		root.content_scale_aspect = aspect
		root.content_scale_size = base


func _window_ok() -> bool:
	return DisplayServer.get_name() != "headless"


func is_fullscreen() -> bool:
	if not _window_ok():
		return fullscreen
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## Applies the fullscreen / windowed and v-sync preferences.
func apply_display() -> void:
	if not _window_ok():
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if fullscreen and not is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_center_window()


## A comfortable 16:9 window, centred on the screen it's on.
func _center_window() -> void:
	var scr := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(scr)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return
	var w := mini(WINDOWED_SIZE.x, int(usable.size.x * 0.9))
	var h := int(w * 9.0 / 16.0)
	if h > int(usable.size.y * 0.9):
		h = int(usable.size.y * 0.9)
		w = int(h * 16.0 / 9.0)
	var sz := Vector2i(maxi(w, MIN_WINDOW_SIZE.x), maxi(h, MIN_WINDOW_SIZE.y))
	DisplayServer.window_set_size(sz)
	DisplayServer.window_set_position(usable.position + (usable.size - sz) / 2)


## F11 / Alt+Enter.
func toggle_fullscreen() -> void:
	fullscreen = not is_fullscreen()
	apply_display()
	save_settings()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply_display()
	save_settings()


func set_vsync(on: bool) -> void:
	vsync = on
	apply_display()
	save_settings()
