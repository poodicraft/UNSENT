extends Node
## Player preferences, persisted to user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"

var music_volume := 0.8
var ambience_volume := 0.7
var sfx_volume := 0.85
var text_speed := 1.0        # 0.5 .. 2.0 (multiplier), 3.0 = instant
var text_size := 1           # 0 small, 1 medium, 2 large
var reduce_motion := false
var show_hints := true       # sparkle markers over unexplored things


func _ready() -> void:
	load_settings()


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


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music", music_volume)
	cf.set_value("audio", "ambience", ambience_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("text", "speed", text_speed)
	cf.set_value("text", "size", text_size)
	cf.set_value("access", "reduce_motion", reduce_motion)
	cf.set_value("access", "show_hints", show_hints)
	cf.save(PATH)
	changed.emit()


## Base font size scaled by the text-size preference.
func font(base: int) -> int:
	var mul: float = [0.88, 1.0, 1.16][clampi(text_size, 0, 2)]
	return int(round(base * mul))
