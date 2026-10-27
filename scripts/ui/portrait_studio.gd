class_name PortraitStudio
extends SubViewport
## A tiny private 3D "photo studio" that renders a live, animated head-and-
## shoulders portrait of whoever is speaking (or calling). Uses the same
## Character model as the office, so portraits always match the 3D cast.

var defs: Dictionary = {}
var font: Font
var current := ""
var _chars: Dictionary = {}
var _cam: Camera3D
var _pivot: Node3D
var _backdrop: MeshInstance3D
var shake := 0.0


func setup(px: int, character_defs: Dictionary, with_backdrop := false, backdrop_color := Color("e9dcc6")) -> void:
	size = Vector2i(px, px)
	own_world_3d = true
	transparent_bg = not with_backdrop
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	defs = character_defs
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = backdrop_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff1e0")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, 30, 0)
	key.light_energy = 1.2
	key.light_color = Color(1.0, 0.95, 0.88)
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 160, 0)
	rim.light_energy = 0.9
	rim.light_color = Color(0.75, 0.85, 1.0)
	add_child(rim)
	_pivot = Node3D.new()
	add_child(_pivot)
	if with_backdrop:
		# a soft office backdrop: blurred-looking shapes for a video-call feel
		_backdrop = MeshInstance3D.new()
		_backdrop.mesh = MeshLib.quad(Vector2(4.0, 3.0))
		_backdrop.position = Vector3(0, 1.7, -1.4)
		_backdrop.material_override = Mats.unshaded(backdrop_color)
		add_child(_backdrop)
		for i in 5:
			var shelf := MeshInstance3D.new()
			shelf.mesh = MeshLib.rounded_box(Vector3(0.5, 0.35 + (i % 2) * 0.3, 0.05), 0.04)
			shelf.material_override = Mats.unshaded(backdrop_color.darkened(0.08 + 0.05 * (i % 3)))
			shelf.position = Vector3(-1.2 + i * 0.6, 1.6 + (i % 2) * 0.35, -1.35)
			add_child(shelf)
	_cam = Camera3D.new()
	_cam.fov = 26.0
	add_child(_cam)
	_cam.position = Vector3(0, 1.82, 1.25)
	_cam.look_at(Vector3(0, 1.75, 0), Vector3.UP)
	_cam.current = true


func show_char(id: String) -> Character:
	if id == current and _chars.has(id):
		return _chars[id]
	for k in _chars:
		_chars[k].visible = false
	current = id
	if id == "" or not defs.has(id) or (defs[id].get("look", {}) as Dictionary).is_empty():
		return null
	if not _chars.has(id):
		var c := Character.new()
		_pivot.add_child(c)
		c.build(id, defs[id], font)
		c.click_body.queue_free()
		c.rotation.y = -0.18
		_chars[id] = c
	var ch: Character = _chars[id]
	ch.visible = true
	# frame faces consistently, regardless of character height
	var h := ch.scale.y
	_cam.position = Vector3(0.05, 1.82 * h, 1.2)
	_cam.look_at(Vector3(0, 1.76 * h, 0), Vector3.UP)
	return ch


func get_char(id: String) -> Character:
	return _chars.get(id)


func _process(delta: float) -> void:
	if shake > 0.0 and _cam:
		shake = maxf(0.0, shake - delta * 0.5)
		_cam.h_offset = randf_range(-1, 1) * shake * 0.03
		_cam.v_offset = randf_range(-1, 1) * shake * 0.03
