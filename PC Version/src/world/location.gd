extends Node2D
## One explorable diorama scene, assembled from:
##   data/locations.json             gameplay (walk band, objects, NPCs, exits)
##   assets/art/scenes/<id>/meta.json art (parallax layers, props)
## Owns the camera, player input, NPC placement and atmosphere (mood).
##
## PC version: the camera zooms so a widescreen monitor shows a well-framed
## slice of the diorama, the mouse highlights whatever it is over (with a
## pointing-hand cursor), and the keyboard can walk (A/D, arrows) and
## interact with the nearest thing (E).

const Actor := preload("res://src/world/actor.gd")
const Hotspot := preload("res://src/world/hotspot.gd")
const Cat := preload("res://src/world/cat.gd")
const Beam := preload("res://src/world/fx_beam.gd")
const Gulls := preload("res://src/world/fx_gulls.gd")
const Lanterns := preload("res://src/world/fx_lanterns.gd")
const ClockProp := preload("res://src/world/clock_prop.gd")

const HEIGHT := 1600.0
const ART_DIR := "res://assets/art/scenes/"

## How much of the scene is visible vertically on a 16:9 screen (world
## units). Scenes narrower than the screen zoom in so their art always fills
## it edge to edge (screens are at most 2:1 — see Settings.MAX_ASPECT);
## MIN_VIEW_H stops the zoom going so far that tall things leave the view.
const VIEW_H := 1020.0
const MIN_VIEW_H := 900.0
## Where the walk band sits on screen (fraction of the height, from the top).
const BAND_AT := 0.72

const MOODS := {
	"dusk": {"top": "#1b1d44", "mid": "#55467f", "hor": "#f1a27c", "glow": "#ffd29c", "cloud": "#c88aa2",
		"sun": 0.025, "stars": 1.0, "clouds": 0.55, "mod": "#ffffff",
		"sea_deep": "#20284f", "sea_hor": "#d9907e", "sea_glint": "#ffc590", "glint": 1.0},
	"storm": {"top": "#090b15", "mid": "#141a2b", "hor": "#2a3450", "glow": "#465676", "cloud": "#262c42",
		"sun": 0.22, "stars": 0.0, "clouds": 1.0, "mod": "#9ba6c8",
		"sea_deep": "#0b0f1f", "sea_hor": "#2c3754", "sea_glint": "#7f90b8", "glint": 0.35},
	"storm_dark": {"top": "#06070e", "mid": "#0d111d", "hor": "#1a2136", "glow": "#2a3450", "cloud": "#1a1f30",
		"sun": 0.3, "stars": 0.0, "clouds": 1.0, "mod": "#6f7898",
		"sea_deep": "#070a14", "sea_hor": "#1a2136", "sea_glint": "#4a587a", "glint": 0.15},
	"dawn": {"top": "#4673b5", "mid": "#a3bfe0", "hor": "#ffe2aa", "glow": "#fff3c6", "cloud": "#ffd8c2",
		"sun": -0.09, "stars": 0.0, "clouds": 0.35, "mod": "#fff8ee",
		"sea_deep": "#2f6098", "sea_hor": "#f6d6a8", "sea_glint": "#fff4cc", "glint": 0.7},
	"interior": {"mod": "#ffffff"},
	"storm_interior": {"mod": "#b4b9d4"},
	"dawn_interior": {"mod": "#fff5e6"},
}

var id := ""
var def: Dictionary = {}
var meta: Dictionary = {}
var width := 1800.0
var horizon := 840.0
var player: Node2D
var npcs: Dictionary = {}
var hotspots: Dictionary = {}
var actors_root: Node2D
var camera: Camera2D

var _layers: Array = []          # {node, factor, x}
var _props: Array = []           # {node, cond}
var _glows: Array = []           # {node, cond, energy, flicker, pulse, seed}
var _beam: Node2D = null
var _lanterns: Node2D = null
var _cat: Node2D = null
var _temp_npcs: Dictionary = {}
var _world_mod: CanvasModulate
var _fg_mod: CanvasModulate
var _sky_layer: CanvasLayer
var _sky_rect: ColorRect
var _sky_mat: ShaderMaterial
var _sea_rect: ColorRect
var _sea_mat: ShaderMaterial
var _light_layer: CanvasLayer
var _fg_layer: CanvasLayer
var _hud_layer: CanvasLayer
var _weather_layer: CanvasLayer
var _rain: CPUParticles2D
var _mood := ""
var _mood_tween: Tween
var _cam_x := 0.0
var _cam_y := 800.0
var _cam_override := false
var _shake := 0.0
var _pressing := false
var _pending: Dictionary = {}
var _tap_marker: Node2D
var _storm_timer := 6.0
var _band_top: PackedVector2Array
var _band_bot: PackedVector2Array
# PC: camera zoom and the extent of the scene's art (world units).
var _zoom := 1.0
var _art := Rect2(-80, -200, 1960, 1800)
# PC: mouse hover and keyboard control.
var _hover: Dictionary = {}
var _hand_cursor := false
var _mouse_in := true
var _mouse_pos := Vector2(-1, -1)
var _kb_walking := false
var _kb_focus: Dictionary = {}
var kb_mode := false


# ═══════════════════════════════════════════════════════════════════
#  Construction
# ═══════════════════════════════════════════════════════════════════

func build(loc_id: String, spawn_name: String, saved_pos: Variant = null) -> void:
	id = loc_id
	def = Data.locations.get(loc_id, {})
	meta = Data.meta(loc_id)
	width = float(def.get("width", 1800))
	horizon = float(meta.get("horizon", 840))
	_band_top = _pv(def.get("walk", {}).get("top", [[0, 980], [width, 980]]))
	_band_bot = _pv(def.get("walk", {}).get("bottom", [[0, 1040], [width, 1040]]))
	_art = _art_extent()

	_world_mod = CanvasModulate.new()
	add_child(_world_mod)

	var outdoor: bool = not def.get("interior", false) or meta.get("sky", false)
	if outdoor:
		_build_sky()
	if def.get("sea", false):
		_build_sea()
	_build_layers()

	actors_root = Node2D.new()
	actors_root.name = "Actors"
	actors_root.y_sort_enabled = true
	add_child(actors_root)

	_light_layer = CanvasLayer.new()
	_light_layer.layer = 1
	_light_layer.follow_viewport_enabled = true
	add_child(_light_layer)
	_fg_layer = CanvasLayer.new()
	_fg_layer.layer = 2
	_fg_layer.follow_viewport_enabled = true
	add_child(_fg_layer)
	_fg_mod = CanvasModulate.new()
	_fg_layer.add_child(_fg_mod)
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 4
	_hud_layer.follow_viewport_enabled = true
	add_child(_hud_layer)
	_weather_layer = CanvasLayer.new()
	_weather_layer.layer = 3
	add_child(_weather_layer)

	_build_props()
	_build_fg_layers()
	_build_glows()
	_build_fx()
	_build_hotspots()

	player = Actor.new()
	player.is_player = true
	player.surface = def.get("surface", "wood")
	actors_root.add_child(player)
	player.setup("wren", self)
	var spawns: Dictionary = def.get("spawns", {})
	var sp: Array = spawns.get(spawn_name, spawns.get("default", [width * 0.5, 1000]))
	player.position = Vector2(sp[0], sp[1])
	if saved_pos is Vector2:
		player.position = saved_pos
	player.position = clamp_to_band(player.position)
	player.arrived.connect(_on_player_arrived)
	if player.position.x > width * 0.6:
		player.face(-1)

	_tap_marker = preload("res://src/world/tap_marker.gd").new()
	_hud_layer.add_child(_tap_marker)

	camera = Camera2D.new()
	camera.ignore_rotation = true
	add_child(camera)
	camera.make_current()
	_cam_x = player.position.x
	_update_camera(0.0, true)

	refresh(true)
	set_mood(Story.mood_for(id), 0.0)
	Audio.play_music(Story.music_for(id))
	Audio.play_ambience(Story.ambience_for(id))


## The area covered by the scene's main art (its full-size, non-parallax
## layers). The camera never shows past its sides. Outdoors, the sky shader
## fills everything above it.
func _art_extent() -> Rect2:
	var r := Rect2()
	var first := true
	for L in meta.get("layers", []):
		if L.get("group", "world") != "world" or not is_equal_approx(float(L.get("factor", 1.0)), 1.0):
			continue
		var tex := _tex(L.get("tex", ""))
		if tex == null:
			continue
		var sc := float(L.get("scale", 1.0))
		var lr := Rect2(float(L.get("x", 0)), float(L.get("y", 0)), tex.get_width() * sc, tex.get_height() * sc)
		r = lr if first else r.merge(lr)
		first = false
	if first:
		r = Rect2(-80, -200, width + 160, HEIGHT + 200)
	return r


func _pv(arr: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for a in arr:
		p.append(Vector2(a[0], a[1]))
	return p


func _tex(path: String) -> Texture2D:
	var full := ART_DIR + id + "/" + path
	if ResourceLoader.exists(full):
		return load(full)
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _build_sky() -> void:
	_sky_layer = CanvasLayer.new()
	_sky_layer.layer = -10
	add_child(_sky_layer)
	_sky_rect = ColorRect.new()
	_sky_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = preload("res://src/world/shaders/sky.gdshader")
	if ResourceLoader.exists("res://assets/art/fx/clouds.png"):
		_sky_mat.set_shader_parameter("cloud_tex", load("res://assets/art/fx/clouds.png"))
	_sky_rect.material = _sky_mat
	_sky_layer.add_child(_sky_rect)


func _build_sea() -> void:
	var sea_layer := CanvasLayer.new()
	sea_layer.layer = -5
	sea_layer.follow_viewport_enabled = true
	add_child(sea_layer)
	_sea_rect = ColorRect.new()
	var sea_l := minf(-400.0, _art.position.x - 200.0)
	var sea_r := maxf(width + 400.0, _art.end.x + 200.0)
	_sea_rect.position = Vector2(sea_l, horizon)
	_sea_rect.size = Vector2(sea_r - sea_l, HEIGHT - horizon + 200)
	_sea_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sea_mat = ShaderMaterial.new()
	_sea_mat.shader = preload("res://src/world/shaders/sea.gdshader")
	_sea_rect.material = _sea_mat
	sea_layer.add_child(_sea_rect)


func _make_sprite(L: Dictionary) -> Sprite2D:
	var tex := _tex(L.get("tex", ""))
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	var sc: float = float(L.get("scale", 1.0))
	s.scale = Vector2(sc, sc)
	s.position = Vector2(float(L.get("x", 0)), float(L.get("y", 0)))
	if L.get("blend", "") == "add":
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = m
	return s


func _build_layers() -> void:
	for L in meta.get("layers", []):
		if L.get("group", "world") != "world":
			continue
		var s := _make_sprite(L)
		if s == null:
			continue
		s.z_index = int(L.get("z", -10))
		add_child(s)
		_layers.append({"node": s, "factor": float(L.get("factor", 1.0)), "x": s.position.x})


func _build_fg_layers() -> void:
	for L in meta.get("layers", []):
		if L.get("group", "world") != "fg":
			continue
		var s := _make_sprite(L)
		if s == null:
			continue
		_fg_layer.add_child(s)
		_layers.append({"node": s, "factor": float(L.get("factor", 1.0)), "x": s.position.x})


func _build_props() -> void:
	for P in meta.get("props", []):
		var node: Node2D = null
		var kind: String = P.get("kind", "sprite")
		match kind:
			"clock":
				var c := ClockProp.new()
				c.mode = P.get("mode", "tower")
				c.radius = float(P.get("r", 70))
				node = c
			_:
				node = _make_sprite(P)
		if node == null:
			continue
		if kind != "sprite":
			node.position = Vector2(float(P.get("x", 0)), float(P.get("y", 0)))
		if P.has("sort_y"):
			# Y-sorted with the actors: wrap so the sort origin is the prop's base.
			var holder := Node2D.new()
			holder.position = Vector2(0, float(P.sort_y))
			node.position.y -= float(P.sort_y)
			holder.add_child(node)
			actors_root.add_child(holder)
			_props.append({"node": holder, "cond": P.get("if", "")})
		elif P.get("group", "world") == "light":
			_light_layer.add_child(node)
			_props.append({"node": node, "cond": P.get("if", "")})
		else:
			node.z_index = int(P.get("z", -1))
			add_child(node)
			_props.append({"node": node, "cond": P.get("if", "")})


func _build_glows() -> void:
	var gtex: Texture2D = load("res://assets/art/fx/glow.png") if ResourceLoader.exists("res://assets/art/fx/glow.png") else null
	if gtex == null:
		return
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for G in def.get("glows", []) + meta.get("glows", []):
		var s := Sprite2D.new()
		s.texture = gtex
		s.material = add
		var size: float = float(G.get("size", 300))
		s.scale = Vector2.ONE * size / gtex.get_width()
		s.position = Vector2(G.pos[0], G.pos[1])
		var c := Color(G.get("color", "#ffd090"))
		s.modulate = c
		_light_layer.add_child(s)
		_glows.append({"node": s, "cond": G.get("if", ""), "energy": float(G.get("energy", 0.6)),
			"flicker": float(G.get("flicker", 0.05)), "pulse": G.get("pulse", false), "seed": randf() * 100.0,
			"color": c, "on": 1.0})


func _build_fx() -> void:
	# The art pipeline knows where the lamp actually is (and on which parallax
	# layer); fall back to the gameplay data's position.
	var lb: Dictionary = meta.get("beam", def.get("lighthouse_beam", {}))
	if not lb.is_empty():
		_beam = Beam.new()
		var bx: float = float(lb.get("x", lb.get("pos", [0, 0])[0]))
		var by: float = float(lb.get("y", lb.get("pos", [0, 0])[1]))
		var bf: float = float(lb.get("factor", 1.0))
		_beam.position = Vector2(bx, by)
		_beam.scale = Vector2.ONE * float(lb.get("scale", 1.0))
		if bf < 0.99:
			# A distant lighthouse: sweep behind the nearer scenery.
			_beam.z_index = -20
			add_child(_beam)
			_layers.append({"node": _beam, "factor": bf, "x": bx})
		else:
			_light_layer.add_child(_beam)
	for kind in def.get("particles", []):
		_add_particles(kind)
	if id == "harbor":
		_lanterns = Lanterns.new()
		_lanterns.area = Rect2(150, horizon + 30, width - 300, 60)
		_lanterns.visible = false
		add_child(_lanterns)
		_lanterns.z_index = -2


func _particle_tex(name: String) -> Texture2D:
	var p := "res://assets/art/fx/%s.png" % name
	return load(p) if ResourceLoader.exists(p) else null


func _add_particles(kind: String) -> void:
	var p := CPUParticles2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.local_coords = false
	match kind:
		"dust":
			p.texture = _particle_tex("dot")
			p.material = add
			p.amount = 34
			p.lifetime = 12.0
			p.preprocess = 12.0
			p.position = Vector2(width * 0.5, 600)
			p.emission_rect_extents = Vector2(width * 0.5, 420)
			p.gravity = Vector2(0, -2)
			p.direction = Vector2(1, -0.3)
			p.spread = 180.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 9.0
			p.scale_amount_min = 0.12
			p.scale_amount_max = 0.3
			p.color = Color(1.0, 0.86, 0.6, 0.45)
			p.color_ramp = _fade_ramp()
			_light_layer.add_child(p)
		"motes":
			p.texture = _particle_tex("dot")
			p.material = add
			p.amount = 22
			p.lifetime = 10.0
			p.preprocess = 10.0
			p.position = Vector2(width * 0.5, 560)
			p.emission_rect_extents = Vector2(width * 0.5, 360)
			p.gravity = Vector2(0, -3)
			p.spread = 180.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 10.0
			p.scale_amount_min = 0.1
			p.scale_amount_max = 0.24
			p.color = Color(1.0, 0.8, 0.6, 0.5)
			p.color_ramp = _fade_ramp()
			_light_layer.add_child(p)
		"leaves":
			p.texture = _particle_tex("leaf")
			p.amount = 12
			p.lifetime = 14.0
			p.preprocess = 14.0
			p.position = Vector2(width * 0.5, -20)
			p.emission_rect_extents = Vector2(width * 0.55, 10)
			p.gravity = Vector2(14, 60)
			p.direction = Vector2(1, 0.2)
			p.spread = 40.0
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 40.0
			p.angular_velocity_min = -90.0
			p.angular_velocity_max = 90.0
			p.scale_amount_min = 0.4
			p.scale_amount_max = 0.8
			p.color = Color(1, 1, 1, 0.95)
			p.z_index = 3
			actors_root.get_parent().add_child(p)
		"fireflies":
			p.texture = _particle_tex("dot")
			p.material = add
			p.amount = 26
			p.lifetime = 7.0
			p.preprocess = 7.0
			p.position = Vector2(width * 0.5, 880)
			p.emission_rect_extents = Vector2(width * 0.5, 160)
			p.gravity = Vector2(0, -4)
			p.spread = 180.0
			p.initial_velocity_min = 6.0
			p.initial_velocity_max = 18.0
			p.scale_amount_min = 0.12
			p.scale_amount_max = 0.24
			p.color = Color(1.0, 0.92, 0.5, 0.9)
			p.color_ramp = _blink_ramp()
			_light_layer.add_child(p)
		"spray":
			p.texture = _particle_tex("mist")
			p.amount = 10
			p.lifetime = 6.0
			p.preprocess = 6.0
			p.position = Vector2(width * 0.5, horizon + 140)
			p.emission_rect_extents = Vector2(width * 0.5, 40)
			p.gravity = Vector2(6, -5)
			p.spread = 30.0
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 12.0
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.6
			p.color = Color(1, 1, 1, 0.12)
			p.color_ramp = _fade_ramp()
			p.z_index = -3
			add_child(p)
		"gulls":
			var g := Gulls.new()
			g.area = Rect2(0, 260, width, 360)
			g.z_index = -8
			add_child(g)
			return


func _fade_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 1))
	g.add_point(0.75, Color(1, 1, 1, 1))
	return g


func _blink_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	for i in 6:
		g.add_point(0.1 + i * 0.15, Color(1, 1, 1, 1.0 if i % 2 == 0 else 0.15))
	return g


func _build_rain() -> void:
	if _rain:
		return
	_rain = CPUParticles2D.new()
	_rain.texture = _particle_tex("rain")
	_rain.amount = int(220 * clampf(get_viewport_rect().size.x / 720.0, 1.0, 2.4))
	_rain.lifetime = 0.9
	_rain.preprocess = 1.0
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var vs := get_viewport_rect().size
	_rain.position = Vector2(vs.x * 0.5, -40)
	_rain.emission_rect_extents = Vector2(vs.x * 0.75, 10)
	_rain.direction = Vector2(-0.28, 1)
	_rain.spread = 3.0
	_rain.gravity = Vector2(0, 600)
	_rain.initial_velocity_min = 1500.0
	_rain.initial_velocity_max = 1900.0
	_rain.scale_amount_min = 0.6
	_rain.scale_amount_max = 1.0
	_rain.color = Color(0.75, 0.82, 1.0, 0.38)
	_rain.particle_flag_align_y = true
	_weather_layer.add_child(_rain)


func _build_hotspots() -> void:
	for o in def.get("objects", []):
		var h := Hotspot.new()
		h.setup(o)
		_hud_layer.add_child(h)
		hotspots[o.id] = h
		if o.get("actor", "") == "cat":
			_cat = Cat.new()
			var ap: Array = o.get("actor_pos", [o.rect[0] + 50, o.rect[1] + 60])
			_cat.position = Vector2(ap[0], ap[1])
			var holder := Node2D.new()
			holder.position = Vector2(0, 0)
			holder.add_child(_cat)
			actors_root.add_child(holder)


# ═══════════════════════════════════════════════════════════════════
#  State refresh (props, NPCs, lights) — called after story changes
# ═══════════════════════════════════════════════════════════════════

func refresh(initial := false) -> void:
	for P in _props:
		P.node.visible = P.cond == "" or Story.eval(P.cond)
	for G in _glows:
		var on: bool = G.cond == "" or Story.eval(G.cond)
		G["target"] = 1.0 if on else 0.0
		if initial:
			G["on"] = G.target
	for hid in hotspots:
		var h: Node2D = hotspots[hid]
		var cond: String = h.def.get("if", "")
		h.visible = cond == "" or Story.eval(cond)
		h.news = h.visible and Story.object_has_news(h.def)
	_place_npcs(initial)
	if _beam:
		_beam.set_on(Story.lamp_glowing(), initial)
	if _lanterns:
		_lanterns.visible = Story.f("lantern_night")
		if Story.f("finale") and _lanterns.mode != "rise" and Story.f("lamp_resolved"):
			pass
	var want_rain: bool = Story.f("lantern_night") and not Story.f("dawn") and not def.get("interior", false)
	if want_rain:
		_build_rain()
	if _rain:
		_rain.emitting = want_rain
	var m := Story.mood_for(id)
	if m != _mood and not initial:
		set_mood(m, 1.2)
	if not initial:
		Audio.play_music(Story.music_for(id))
		Audio.play_ambience(Story.ambience_for(id))


func release_lanterns() -> void:
	if _lanterns:
		_lanterns.visible = true
		_lanterns.release()


func _place_npcs(initial: bool) -> void:
	var wanted := {}
	for P in def.get("npcs", []):
		if wanted.has(P.id):
			continue
		if Story.eval(P.get("if", "true")):
			wanted[P.id] = P
	for nid in npcs.keys():
		if not wanted.has(nid) and not (_temp_npcs.has(nid) and Story.busy):
			npcs[nid].queue_free()
			npcs.erase(nid)
			_temp_npcs.erase(nid)
	for nid in wanted:
		if npcs.has(nid):
			continue
		var P: Dictionary = wanted[nid]
		var a := _spawn_npc(nid, Vector2(P.pos[0], P.pos[1]))
		a.face(-1 if P.get("face", "left") == "left" else 1)


func _spawn_npc(nid: String, pos: Vector2) -> Node2D:
	var a := Actor.new()
	a.surface = def.get("surface", "wood")
	actors_root.add_child(a)
	a.setup(nid, self)
	a.position = pos
	a._update_depth()
	npcs[nid] = a
	return a


func npc(nid: String) -> Node2D:
	return npcs.get(nid, null)


func show_npc(nid: String, pos: Vector2) -> void:
	if npcs.has(nid):
		npcs[nid].position = pos
		npcs[nid]._update_depth()
		return
	_spawn_npc(nid, pos)
	_temp_npcs[nid] = true


func hide_npc(nid: String) -> void:
	if npcs.has(nid):
		npcs[nid].queue_free()
		npcs.erase(nid)


# ═══════════════════════════════════════════════════════════════════
#  Walk band & depth
# ═══════════════════════════════════════════════════════════════════

func _band_y(poly: PackedVector2Array, x: float) -> float:
	if poly.size() == 0:
		return 1000.0
	if x <= poly[0].x:
		return poly[0].y
	for i in range(1, poly.size()):
		if x <= poly[i].x:
			var a := poly[i - 1]
			var b := poly[i]
			return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 0.001))
	return poly[poly.size() - 1].y


func clamp_to_band(p: Vector2) -> Vector2:
	var x := clampf(p.x, _band_top[0].x, _band_top[_band_top.size() - 1].x)
	var t := _band_y(_band_top, x)
	var b := _band_y(_band_bot, x)
	return Vector2(x, clampf(p.y, t, b))


func depth_scale(y: float) -> float:
	var d: Dictionary = def.get("depth", {})
	var far: float = float(d.get("far", 940))
	var near: float = float(d.get("near", 1040))
	var t := clampf((y - far) / maxf(near - far, 1.0), 0.0, 1.0)
	return lerpf(float(d.get("far_scale", 0.9)), float(d.get("near_scale", 1.0)), t)


# ═══════════════════════════════════════════════════════════════════
#  Input: tap to walk / talk / examine
# ═══════════════════════════════════════════════════════════════════

func _blocked() -> bool:
	return _title_mode or Story.busy or (Story.main != null and Story.main.input_blocked())


## Remembers where the mouse is (for hover), from the events themselves.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse_pos = (event as InputEventMouse).position
		_mouse_in = true


func _unhandled_input(event: InputEvent) -> void:
	if _blocked():
		_pressing = false
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E \
			and not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed):
		get_viewport().set_input_as_handled()
		interact_nearest()
		return
	# Use the event's own position (not the OS cursor): with touch input the
	# cursor position can lag behind or differ from where the finger is.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			kb_mode = false
			_handle_tap(_event_world_pos(event))
		else:
			_pressing = false
	elif event is InputEventMouseMotion and _pressing and _pending.is_empty():
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_pressing = false
			return
		var wp := _event_world_pos(event)
		if wp.y > horizon - 120:
			player.walk_to(clamp_to_band(wp))


func _event_world_pos(event: InputEvent) -> Vector2:
	return get_canvas_transform().affine_inverse() * (event as InputEventMouse).position


## What a click at this world position would act on: a person, an object
## or exit, or nothing ({}).
func pick_at(wp: Vector2) -> Dictionary:
	for nid in npcs:
		var a: Node2D = npcs[nid]
		if a.hit_rect().has_point(wp):
			return {"kind": "npc", "id": nid, "node": a}
	var best: Node2D = null
	var best_area := INF
	for hid in hotspots:
		var h: Node2D = hotspots[hid]
		if not h.visible:
			continue
		var r: Rect2 = h.rect.grow(14)
		if r.has_point(wp) and r.get_area() < best_area:
			best = h
			best_area = r.get_area()
	if best:
		return {"kind": "obj", "id": best.def.id, "node": best}
	return {}


func _handle_tap(wp: Vector2) -> void:
	_pending = {}
	var hit := pick_at(wp)
	if hit.get("kind", "") == "npc":
		_go_npc(hit.id)
		return
	if hit.get("kind", "") == "obj":
		_go_object(hit.node)
		return
	if wp.y < horizon - 260 and not def.get("interior", false):
		return
	var t := clamp_to_band(Vector2(wp.x, maxf(wp.y, _band_y(_band_top, wp.x))))
	_tap_marker.show_at(t)
	player.walk_to(t)


func _go_npc(nid: String) -> void:
	var a: Node2D = npcs[nid]
	var side := -1.0 if player.position.x < a.position.x else 1.0
	var t := clamp_to_band(Vector2(a.position.x + side * 115.0 * a.scale.y, a.position.y + 6.0))
	if t.distance_to(a.position) < 60.0:
		t = clamp_to_band(Vector2(a.position.x - side * 115.0, a.position.y + 6.0))
	_pending = {"kind": "npc", "id": nid}
	_tap_marker.show_at(t)
	player.walk_to(t)
	if not player.moving:
		_on_player_arrived()


func _go_object(h: Node2D) -> void:
	var st: Array = h.def.get("stand", [h.rect.get_center().x, 1010])
	var t := clamp_to_band(Vector2(st[0], st[1]))
	_pending = {"kind": "obj", "id": h.def.id}
	_tap_marker.show_at(t)
	player.walk_to(t)
	if not player.moving:
		_on_player_arrived()


## E: talk to / examine / use whatever is nearest (the thing whose name tag
## is showing).
func interact_nearest() -> void:
	if _blocked() or _kb_focus.is_empty():
		return
	var f := _kb_focus
	_stop_kb_walk()
	if f.kind == "npc" and npcs.has(f.id):
		_go_npc(f.id)
	elif f.kind != "npc" and hotspots.has(f.id):
		_go_object(hotspots[f.id])


func _stop_kb_walk() -> void:
	if _kb_walking:
		_kb_walking = false
		if player and _pending.is_empty():
			player.stop()


## A/D or the arrow keys walk; W/S (up/down) step nearer or further.
func _keyboard_walk() -> void:
	if _blocked() or player == null:
		_stop_kb_walk()
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT) or Input.is_key_pressed(KEY_META):
		dir = Vector2.ZERO
	if dir == Vector2.ZERO:
		_stop_kb_walk()
		return
	kb_mode = true
	_kb_walking = true
	_pending = {}
	_pressing = false
	var t := clamp_to_band(player.position + Vector2(dir.x * 140.0, dir.y * 60.0))
	player.walk_to(t)


## Mouse hover: a hand cursor and the name tag over whatever is under the
## pointer, so it's clear what a click will do.
func _update_hover() -> void:
	var hit := {}
	if not _blocked() and _mouse_in and _mouse_pos.x >= 0.0 and not _pressing and get_viewport().gui_get_hovered_control() == null:
		hit = pick_at(get_canvas_transform().affine_inverse() * _mouse_pos)
	var old: Variant = _hover.get("node", null)
	var new: Variant = hit.get("node", null)
	if old != new:
		if old != null and is_instance_valid(old) and "hovered" in old:
			old.hovered = false
		if new != null and "hovered" in new:
			new.hovered = true
		_hover = hit
	_set_hand(not hit.is_empty())


func _set_hand(on: bool) -> void:
	if on == _hand_cursor:
		return
	_hand_cursor = on
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if on else Input.CURSOR_ARROW)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_MOUSE_EXIT:
			_mouse_in = false
		NOTIFICATION_WM_MOUSE_ENTER:
			_mouse_in = true
		NOTIFICATION_EXIT_TREE:
			_set_hand(false)


func _on_player_arrived() -> void:
	if _pending.is_empty():
		return
	var p := _pending
	_pending = {}
	if p.kind == "npc" and npcs.has(p.id):
		Story.talk_to(p.id)
	elif p.kind == "obj" and hotspots.has(p.id):
		var h: Node2D = hotspots[p.id]
		player.face_toward(h.rect.get_center().x)
		if h.def.get("actor", "") == "cat" and _cat:
			_cat.poke()
		Story.interact(h.def)


# ═══════════════════════════════════════════════════════════════════
#  Camera, mood, effects
# ═══════════════════════════════════════════════════════════════════

var _title_mode := false
var _title_t := 0.0


## Background for the title screen: no player, no markers, a slow drift.
func title_mode() -> void:
	_title_mode = true
	player.visible = false
	for nid in npcs:
		npcs[nid].visible = false
	_hud_layer.visible = false
	_cam_override = true
	_cam_x = width * 0.45


func camera_follow() -> void:
	_cam_override = false


func camera_pan(x: float, secs: float) -> void:
	_cam_override = true
	var vs := view_size()
	var tx := clampf(x, vs.x * 0.5, maxf(width - vs.x * 0.5, vs.x * 0.5))
	var tw := create_tween()
	tw.tween_property(self, "_cam_x", tx, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func shake(amount: float) -> void:
	if not Settings.reduce_motion:
		_shake = maxf(_shake, amount)


## The camera zoom for the current screen shape: VIEW_H world units tall,
## or closer when the scene's art isn't wide enough to fill the screen.
func _fit_zoom() -> void:
	var vs := get_viewport_rect().size
	if vs.y <= 0.0:
		return
	var vh := VIEW_H
	if vh * vs.x / vs.y > _art.size.x:
		vh = maxf(_art.size.x * vs.y / vs.x, MIN_VIEW_H)
	_zoom = vs.y / vh
	camera.zoom = Vector2(_zoom, _zoom)


## The part of the world on screen (world units).
func view_size() -> Vector2:
	return get_viewport_rect().size / _zoom


func _update_camera(delta: float, snap := false) -> void:
	_fit_zoom()
	var vs := view_size()
	if not _cam_override and player:
		var look := float(player.puppet.facing) * 70.0
		var tx := player.position.x + look
		_cam_x = tx if snap else lerpf(_cam_x, tx, 1.0 - exp(-delta * 3.2))
	var half := vs.x * 0.5
	var cx := clampf(_cam_x, half, maxf(width - half, half))
	if width < vs.x:
		# Wider than the walkable scene: centre it (the art runs past its ends).
		cx = clampf(width * 0.5, _art.position.x + half, maxf(_art.end.x - half, _art.position.x + half))
	var band_mid := (_band_y(_band_top, cx) + _band_y(_band_bot, cx)) * 0.5
	var top_lim := -INF if (_sky_mat != null and not def.get("interior", false)) else _art.position.y
	_cam_y = band_mid + vs.y * (0.5 - BAND_AT)
	_cam_y = clampf(_cam_y, top_lim + vs.y * 0.5, maxf(_art.end.y - vs.y * 0.5, top_lim + vs.y * 0.5))
	var off := Vector2.ZERO
	if _shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 14.0
		_shake = maxf(0.0, _shake - delta * 1.8)
	camera.position = Vector2(cx, _cam_y) + off
	var cam_left := cx - half
	for L in _layers:
		L.node.position.x = L.x + cam_left * (1.0 - L.factor)
	if _sky_mat:
		_sky_mat.set_shader_parameter("scroll", cam_left / maxf(width, 1.0))
		_sky_mat.set_shader_parameter("aspect", vs.x / vs.y)
		var top_world := _cam_y - vs.y * 0.5
		_sky_mat.set_shader_parameter("horizon", clampf((horizon - top_world) / vs.y, 0.2, 0.95))
	if _sea_mat:
		_sea_mat.set_shader_parameter("sun_x", _sky_mat.get_shader_parameter("sun_x") if _sky_mat else 0.72)


func _process(delta: float) -> void:
	if _title_mode:
		_title_t += delta
		_cam_x = width * 0.5 + sin(_title_t * 0.035) * width * 0.28
		for nid in npcs:
			npcs[nid].visible = false
	_keyboard_walk()
	_update_camera(delta)
	_update_hover()
	var t := Time.get_ticks_msec() / 1000.0
	for G in _glows:
		var tgt: float = G.get("target", 1.0)
		G.on = move_toward(G.on, tgt, delta * 1.5)
		var fl: float = G.flicker
		var e: float = G.energy * (1.0 + (sin(t * 7.3 + G.seed) * 0.6 + sin(t * 13.1 + G.seed * 2.0) * 0.4) * fl)
		if G.pulse:
			e *= 0.7 + 0.3 * sin(t * 3.0)
		var c: Color = G.color
		G.node.modulate = Color(c.r, c.g, c.b, clampf(e * G.on, 0.0, 1.0))
		G.node.visible = G.on > 0.01
	# player proximity labels
	if player:
		_layout_tags()
	# storm lightning
	if Story.f("lantern_night") and not Story.f("dawn"):
		_storm_timer -= delta
		if _storm_timer <= 0.0:
			_storm_timer = randf_range(7.0, 16.0)
			if not Story.busy:
				lightning(0.5)


## Name tags for people and things near the player. Tags never pile up on
## each other: the nearest wins, and a tag that would cover one already
## shown stays hidden until the player moves closer to it. On PC the thing
## under the mouse always shows its tag first, and the nearest thing is what
## the E key will use (marked with an "E" key cap after keyboard walking).
func _layout_tags() -> void:
	var px := player.position.x
	var quiet := Story.busy
	var hovered: Variant = _hover.get("node", null)
	var cands: Array = []
	var focus := {}
	var focus_d := INF
	for nid in npcs:
		var a: Node2D = npcs[nid]
		var d := absf(a.position.x - px)
		var hov: bool = a == hovered
		if a.visible and (d < 220.0 or hov) and not quiet:
			cands.append([-1000.0 if hov else d - 90.0, a, "npc"])   # people come first
		else:
			a.show_label = false
		if a.visible and not quiet and d < 220.0 and d - 90.0 < focus_d:
			focus_d = d - 90.0
			focus = {"kind": "npc", "id": nid, "node": a}
	for hid in hotspots:
		var h: Node2D = hotspots[hid]
		if not h.visible:
			h.near = false
			continue
		var d := absf(h.rect.get_center().x - px)
		var hov: bool = h == hovered
		if h.is_exit():
			h.near = (d < 170.0 or hov) and not quiet
			cands.append([-1000.0 if hov else d, h, "exit"])
		elif (d < 170.0 or hov) and not quiet:
			cands.append([-1000.0 if hov else d, h, "obj"])
		else:
			h.near = false
			h.tag_ok = true
		if not quiet and d < 170.0 and d < focus_d:
			focus_d = d
			focus = {"kind": "exit" if h.is_exit() else "obj", "id": hid, "node": h}
	var old_focus: Variant = _kb_focus.get("node", null)
	_kb_focus = focus
	var new_focus: Variant = focus.get("node", null)
	if old_focus != new_focus and old_focus != null and is_instance_valid(old_focus):
		old_focus.key_hint = false
	if new_focus != null:
		new_focus.key_hint = kb_mode and not _title_mode
	cands.sort_custom(func(x, y): return x[0] < y[0])
	var taken: Array = []
	var vr := get_viewport_rect()
	for c in cands:
		var r: Rect2 = c[1].tag_screen_rect()
		var ok := r.size.x > 0.0 and vr.intersects(r)
		for t in taken:
			if t.grow(4.0).intersects(r):
				ok = false
				break
		if ok:
			taken.append(r)
		match c[2]:
			"npc":
				c[1].show_label = ok
			"exit":
				c[1].tag_ok = ok
			"obj":
				c[1].near = ok
				c[1].tag_ok = true


func lightning(strength := 1.0) -> void:
	if _sky_mat == null and _sea_mat == null:
		return
	var tw := create_tween()
	tw.tween_method(_set_flash, strength, 0.0, 0.55).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(randf_range(0.4, 1.4)).timeout.connect(func(): Audio.sfx("thunder", -6.0 - (1.0 - strength) * 8.0))


func _set_flash(v: float) -> void:
	if _sky_mat:
		_sky_mat.set_shader_parameter("flash", v)
	if _sea_mat:
		_sea_mat.set_shader_parameter("flash", v)


func set_mood(name: String, secs: float) -> void:
	_mood = name
	var M: Dictionary = MOODS.get(name, MOODS.dusk)
	if _mood_tween and _mood_tween.is_valid():
		_mood_tween.kill()
	var mod := Color(M.get("mod", "#ffffff"))
	if secs <= 0.0:
		_world_mod.color = mod
		_fg_mod.color = mod
		if _sky_mat and M.has("top"):
			for k in _sky_keys(M):
				_sky_mat.set_shader_parameter(k[0], k[1])
		if _sea_mat and M.has("sea_deep"):
			for k in _sea_keys(M):
				_sea_mat.set_shader_parameter(k[0], k[1])
		return
	_mood_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_mood_tween.tween_property(_world_mod, "color", mod, secs)
	_mood_tween.tween_property(_fg_mod, "color", mod, secs)
	if _sky_mat and M.has("top"):
		for k in _sky_keys(M):
			_mood_tween.tween_property(_sky_mat, "shader_parameter/" + k[0], k[1], secs)
	if _sea_mat and M.has("sea_deep"):
		for k in _sea_keys(M):
			_mood_tween.tween_property(_sea_mat, "shader_parameter/" + k[0], k[1], secs)


func _sky_keys(M: Dictionary) -> Array:
	return [["top_color", Color(M.top)], ["mid_color", Color(M.mid)], ["horizon_color", Color(M.hor)],
		["glow_color", Color(M.glow)], ["cloud_color", Color(M.cloud)], ["sun_offset", float(M.sun)],
		["stars", float(M.stars)], ["clouds", float(M.clouds)]]


func _sea_keys(M: Dictionary) -> Array:
	return [["deep_color", Color(M.sea_deep)], ["horizon_color", Color(M.sea_hor)],
		["glint_color", Color(M.sea_glint)], ["glint", float(M.glint)]]
