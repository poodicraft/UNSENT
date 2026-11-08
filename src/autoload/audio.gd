extends Node
## Music (crossfaded), ambience beds, and pooled one-shot sound effects.
## Streams load from res://assets/audio/{music,ambience,sfx}/<id>.ogg

const MUSIC_DIR := "res://assets/audio/music/"
const AMB_DIR := "res://assets/audio/ambience/"
const SFX_DIR := "res://assets/audio/sfx/"
const POOL_SIZE := 10
## Variants available for randomised sounds (id -> count).
const VARIANTS := {
	"paper": 3, "step_wood": 4, "step_stone": 4, "step_grass": 4, "step_metal": 4,
}

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: AudioStreamPlayer
var _music_id := ""
var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var _amb_current: AudioStreamPlayer
var _amb_id := ""
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _cache: Dictionary = {}
var _missing: Dictionary = {}
var _duck := 0.0
var _duck_target := 0.0
var _music_tween: Tween
var _amb_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("Ambience")
	_ensure_bus("SFX")
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_amb_a = _make_player("Ambience")
	_amb_b = _make_player("Ambience")
	_music_current = _music_a
	_amb_current = _amb_a
	for i in POOL_SIZE:
		_pool.append(_make_player("SFX"))
	apply_volumes()
	Settings.changed.connect(apply_volumes)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func apply_volumes() -> void:
	_set_bus("Music", Settings.music_volume * (1.0 - _duck * 0.45))
	_set_bus("Ambience", Settings.ambience_volume)
	_set_bus("SFX", Settings.sfx_volume)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(idx, linear <= 0.001)


func _process(delta: float) -> void:
	if not is_equal_approx(_duck, _duck_target):
		_duck = move_toward(_duck, _duck_target, delta * 1.5)
		apply_volumes()


## Gently lowers the music (e.g. while reading a letter).
func duck(on: bool) -> void:
	_duck_target = 1.0 if on else 0.0


func _load(path: String, loop: bool) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if _missing.has(path):
		return null
	if not ResourceLoader.exists(path):
		_missing[path] = true
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = loop
	elif s is AudioStreamWAV and loop:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_cache[path] = s
	return s


func play_music(id: String, fade := 2.0) -> void:
	if id == _music_id:
		return
	_music_id = id
	var next := _music_b if _music_current == _music_a else _music_a
	var old := _music_current
	var stream := _load(MUSIC_DIR + id + ".ogg", true) if id != "" else null
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	if old.playing:
		_music_tween = create_tween()
		_music_tween.tween_property(old, "volume_db", -40.0, fade)
		_music_tween.tween_callback(old.stop)
	if stream:
		next.stream = stream
		next.volume_db = -40.0
		next.play()
		var t2 := create_tween()
		t2.tween_property(next, "volume_db", 0.0, fade).set_trans(Tween.TRANS_SINE)
	_music_current = next


func stop_music(fade := 2.0) -> void:
	play_music("", fade)


func play_ambience(id: String, fade := 2.5) -> void:
	if id == _amb_id:
		return
	_amb_id = id
	var next := _amb_b if _amb_current == _amb_a else _amb_a
	var old := _amb_current
	var stream := _load(AMB_DIR + id + ".ogg", true) if id != "" else null
	if _amb_tween and _amb_tween.is_valid():
		_amb_tween.kill()
	if old.playing:
		_amb_tween = create_tween()
		_amb_tween.tween_property(old, "volume_db", -40.0, fade)
		_amb_tween.tween_callback(old.stop)
	if stream:
		next.stream = stream
		next.volume_db = -40.0
		next.play()
		var t2 := create_tween()
		t2.tween_property(next, "volume_db", 0.0, fade)
	_amb_current = next


## Plays a one-shot effect. Randomised variants are picked automatically.
func sfx(id: String, volume_db := 0.0, pitch := 1.0, pitch_jitter := 0.0) -> void:
	var fname := id
	if VARIANTS.has(id):
		fname = "%s_%d" % [id, randi_range(1, VARIANTS[id])]
	var stream := _load(SFX_DIR + fname + ".ogg", false)
	if stream == null:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	p.play()


func step(surface: String) -> void:
	sfx("step_" + surface, -9.0, 1.0, 0.08)


func blip(voice: float) -> void:
	if voice <= 0.0:
		return
	sfx("blip", -16.0, voice, 0.05)
