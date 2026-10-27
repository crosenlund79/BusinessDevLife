class_name World
extends Node3D
## The 3D office: environment, characters, point-and-click input, hover
## feedback, objective markers and ambient office life.

signal interacted(id: String)
signal hover_changed(text: String)

var nav := NavGrid.new()
var builder := OfficeBuilder.new()
var rig: CameraRig
var defs: Dictionary = {}
var chars: Dictionary = {}
var player: Character
var font: Font
var ambient := true

var _hover_ring: MeshInstance3D
var _hover_id := ""
var _markers: Array[Node3D] = []
var _marker_targets: Array = []
var _t := 0.0
var _bark_timer := 6.0
var _olu_route := ["olu_a", "olu_c", "olu_b", "olu_d"]
var _olu_i := 0
var _olu_wait := 3.0
var _brawl: BrawlCloud
var _phone_level := 0
var _phone_t := 0.0
var _phone_base := Vector3.ZERO
var _interact_token := 0


func setup(ui_font: Font) -> void:
	font = ui_font
	_environment()
	builder.build(self, nav, font)
	_load_defs()
	for id in ["maggie", "tobias", "sanne", "bogdan", "chad", "kevin", "pia", "olu", "player"]:
		_spawn(id)
	player = chars["player"]
	player.speed = 3.3
	player.click_body.collision_layer = 0
	rig = CameraRig.new()
	add_child(rig)
	rig.follow = player
	_hover_ring = MeshInstance3D.new()
	_hover_ring.mesh = MeshLib.torus(0.46, 0.56)
	_hover_ring.material_override = Mats.unshaded(Color(1.0, 0.75, 0.2, 0.85))
	_hover_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hover_ring.visible = false
	add_child(_hover_ring)
	for i in 3:
		_markers.append(_make_marker())
	var phone: Node3D = builder.props["phone"]
	_phone_base = phone.position
	reset_positions()


func reset_positions() -> void:
	place("maggie", builder.points["maggie_desk"], 0.0)
	seat("tobias", "tobias")
	seat("sanne", "sanne")
	seat("kevin", "kevin")
	seat("pia", "pia")
	seat("bogdan", "bogdan_desk")
	seat("chad", "chad_desk", false)
	place("olu", builder.points["olu_a"], PI * 0.5)
	place("player", builder.points["entrance"], PI)
	rig.snap()


# ================================================================= characters

func _load_defs() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	if parsed is Dictionary:
		defs = parsed


func _spawn(id: String) -> Character:
	var c := Character.new()
	c.name = id.capitalize()
	add_child(c)
	c.build(id, defs.get(id, {}), font)
	chars[id] = c
	return c


func npc(id: String) -> Character:
	return chars.get(id)


func def(id: String) -> Dictionary:
	return defs.get(id, {})


func place(id: String, pos: Vector3, yaw := 0.0) -> void:
	var c := npc(id)
	if c == null:
		return
	c.stop_walking()
	c.stand_up()
	c.position = Vector3(pos.x, 0.0, pos.z)
	c.face_yaw(yaw, true)


func seat(id: String, seat_name: String, typing := true) -> void:
	var c := npc(id)
	var s: Array = builder.seats.get(seat_name, [])
	if c == null or s.is_empty():
		return
	c.sit_at(s[0], s[1], typing)


func seat_pos(seat_name: String) -> Vector3:
	var s: Array = builder.seats.get(seat_name, [Vector3.ZERO, 0.0])
	return s[0]


func point(n: String) -> Vector3:
	return builder.points.get(n, Vector3.ZERO)


## Walks a character to `pos`. Returns false if interrupted.
func walk(id: String, pos: Vector3) -> bool:
	var c := npc(id)
	if c == null:
		return false
	c.stand_up()
	var path := nav.find_path(c.position, pos)
	if path.is_empty() or c.position.distance_to(Vector3(pos.x, 0, pos.z)) < 0.05:
		return true
	c.walk_path(path)
	var ok: bool = await c.arrived
	return ok


## Starts several walks at once and waits for all of them.
func walk_many(targets: Dictionary) -> void:
	for id in targets:
		var c := npc(id)
		if c == null:
			continue
		c.stand_up()
		var path := nav.find_path(c.position, targets[id])
		if not path.is_empty():
			c.walk_path(path)
	for id in targets:
		var c := npc(id)
		if c and c.is_moving():
			await c.arrived


func shake_camera(amount: float) -> void:
	rig.shake(amount)


func face_each_other(a: String, b: String) -> void:
	var ca := npc(a)
	var cb := npc(b)
	if ca and cb:
		if not ca.seated:
			ca.face_point(cb.global_position)
		if not cb.seated:
			cb.face_point(ca.global_position)


func skin_colors(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		var look: Dictionary = def(id).get("look", {})
		out.append(Color(str(look.get("skin", "#f0c4a0"))))
	return out


# ================================================================= input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			rig.zoom(-1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rig.zoom(1.0)
		elif event.button_index == MOUSE_BUTTON_LEFT and not Game.input_locked:
			_click(event.position)
	elif event is InputEventMouseMotion and not Game.input_locked:
		_update_hover(event.position)


func _click(screen_pos: Vector2) -> void:
	var hit := _pick(screen_pos)
	if hit != "":
		Audio.sfx("click", -6.0)
		request_interact(hit)
		return
	var floor_pt = _floor_point(screen_pos)
	if floor_pt == null:
		return
	_interact_token += 1
	_spawn_click_ping(floor_pt)
	var path := nav.find_path(player.position, floor_pt)
	if not path.is_empty():
		player.walk_path(path)


func request_interact(id: String) -> void:
	_interact_token += 1
	var token := _interact_token
	var approach := _approach_for(id)
	var path := nav.find_path(player.position, approach)
	if not path.is_empty() and player.position.distance_to(approach) > 0.3:
		player.walk_path(path)
		var ok: bool = await player.arrived
		if not ok or token != _interact_token or Game.input_locked:
			return
	var target := _target_pos(id)
	player.face_point(target)
	var c := npc(id)
	if c and not c.seated and not c.is_moving():
		c.face_point(player.global_position)
	interacted.emit(id)


func _approach_for(id: String) -> Vector3:
	if builder.interactables.has(id):
		var it: Interactable = builder.interactables[id]
		return it.approach
	var c := npc(id)
	if c == null:
		return player.position
	var facing := Vector3(sin(c.rotation.y), 0, cos(c.rotation.y))
	var best := c.position + facing
	var best_score := INF
	for radius in [0.95, 1.7]:
		for i in 16:
			var a := TAU * i / 16.0
			var dir := Vector3(cos(a), 0, sin(a))
			var p: Vector3 = c.position + dir * radius
			if not nav.is_free(nav.to_cell(p)):
				continue
			var score: float = p.distance_to(player.position) * 0.25 + (1.0 - dir.dot(facing)) * 1.2 + (radius - 0.95) * 0.4
			if score < best_score:
				best_score = score
				best = p
	return best


func _target_pos(id: String) -> Vector3:
	if builder.interactables.has(id):
		var it: Interactable = builder.interactables[id]
		return it.face_target
	var c := npc(id)
	return c.global_position if c else Vector3.ZERO


func _pick(screen_pos: Vector2) -> String:
	var from := rig.cam.project_ray_origin(screen_pos)
	var dir := rig.cam.project_ray_normal(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	var res := get_world_3d().direct_space_state.intersect_ray(q)
	if res.is_empty():
		return ""
	var col = res.get("collider")
	if col and col.has_meta("interact_id"):
		return str(col.get_meta("interact_id"))
	return ""


func _floor_point(screen_pos: Vector2):
	var from := rig.cam.project_ray_origin(screen_pos)
	var dir := rig.cam.project_ray_normal(screen_pos)
	return Plane(Vector3.UP, 0.0).intersects_ray(from, dir)


func _update_hover(screen_pos: Vector2) -> void:
	var id := _pick(screen_pos)
	if id == _hover_id:
		return
	_hover_id = id
	if id == "":
		_hover_ring.visible = false
		hover_changed.emit("")
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	Audio.sfx("hover", -14.0, 1.2, 0.1)
	var label_text := ""
	if builder.interactables.has(id):
		var it: Interactable = builder.interactables[id]
		label_text = Loc.t(it.label_key)
		_hover_ring.scale = Vector3.ONE * it.ring_radius / 0.5
		_hover_ring.position = Vector3(it.position.x, 0.03, it.position.z)
	else:
		var c := npc(id)
		var d := def(id)
		label_text = Loc.t("hover.talk", {"name": str(d.get("name", id)).split(" ")[0]})
		_hover_ring.scale = Vector3.ONE * 1.1
		_hover_ring.position = Vector3(c.position.x, 0.03, c.position.z)
	_hover_ring.visible = true
	hover_changed.emit(label_text)


func clear_hover() -> void:
	_hover_id = ""
	_hover_ring.visible = false
	hover_changed.emit("")


func _spawn_click_ping(p: Vector3) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = MeshLib.torus(0.2, 0.26)
	ring.material_override = Mats.unshaded(Color(1, 1, 1, 0.8))
	ring.position = p + Vector3(0, 0.03, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * 2.2, 0.35)
	tw.tween_property(ring, "transparency", 1.0, 0.35)
	tw.chain().tween_callback(ring.queue_free)


# ================================================================= markers

func set_markers(ids: Array) -> void:
	_marker_targets = ids.duplicate()


func _make_marker() -> Node3D:
	var m := Node3D.new()
	var cone := MeshInstance3D.new()
	cone.mesh = MeshLib.cylinder(0.2, 0.0, 0.38, 4)
	cone.material_override = Mats.emissive(Color("ffb627"), 1.6)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(cone)
	var ball := MeshInstance3D.new()
	ball.mesh = MeshLib.sphere(0.13, 16)
	ball.material_override = Mats.emissive(Color("ffb627"), 1.6)
	ball.position.y = 0.36
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(ball)
	m.visible = false
	add_child(m)
	return m


func _update_markers() -> void:
	for i in _markers.size():
		var m := _markers[i]
		if i >= _marker_targets.size():
			m.visible = false
			continue
		var id: String = _marker_targets[i]
		var pos := Vector3.ZERO
		if builder.interactables.has(id):
			var it: Interactable = builder.interactables[id]
			pos = it.position + Vector3(0, 2.0, 0)
			pos.y = maxf(pos.y, 2.2)
		elif chars.has(id):
			var c: Character = chars[id]
			pos = c.global_position + Vector3(0, 2.35 * c.scale.y + (-0.4 if c.seated else 0.0), 0)
		else:
			m.visible = false
			continue
		m.visible = true
		m.position = pos + Vector3(0, absf(sin(_t * 3.0)) * 0.25, 0)
		m.rotation.y = _t * 2.0


# ================================================================= effects

func phone_buzz(level: int) -> void:
	_phone_level = level
	_phone_t = 0.0


func start_brawl(center: Vector3, ids: Array) -> BrawlCloud:
	_brawl = BrawlCloud.new()
	_brawl.font = font
	add_child(_brawl)
	for id in ids:
		var c := npc(id)
		if c:
			c.visible = false
	_brawl.start(center, skin_colors(ids))
	return _brawl


func stop_brawl(ids: Array, positions: Dictionary) -> void:
	if _brawl:
		_brawl.stop()
	for id in ids:
		var c := npc(id)
		if c:
			c.visible = true
			if positions.has(id):
				var p: Array = positions[id]
				place(id, p[0], p[1])
			c.set_disheveled(true)


func start_biscuits() -> BiscuitFlood:
	var flood := BiscuitFlood.new()
	add_child(flood)
	flood.origin = point("delivery_origin")
	flood.start()
	return flood


func screen(id: String) -> ScreenContent:
	return builder.screens.get(id)


func make_cake() -> Node3D:
	return builder.make_cake()


# ================================================================= ambient life

func _process(delta: float) -> void:
	_t += delta
	_update_markers()
	_update_phone(delta)
	if _hover_ring.visible:
		_hover_ring.rotation.y += delta * 0.8
	if not ambient:
		return
	_bark_timer -= delta
	if _bark_timer <= 0.0:
		_bark_timer = randf_range(7.0, 14.0)
		_random_bark()
	_olu_patrol(delta)


func _random_bark() -> void:
	var options := ["tobias", "sanne", "kevin", "pia", "olu", "bogdan", "chad", "maggie"]
	var id: String = options[randi() % options.size()]
	var c := npc(id)
	if c == null or not c.visible or c.talking:
		return
	if c.global_position.distance_to(player.global_position) > 11.0:
		return
	var lines = Loc.get_data("barks." + id)
	if lines is Array and not lines.is_empty():
		c.bark(str(lines[randi() % lines.size()]), 3.2)
		if id == "pia" and randf() < 0.5:
			Audio.sfx("bell", -10.0)


func _olu_patrol(delta: float) -> void:
	var olu := npc("olu")
	if olu == null or olu.is_moving() or olu.seated or not olu.visible:
		return
	_olu_wait -= delta
	if _olu_wait > 0.0:
		return
	_olu_wait = randf_range(3.0, 6.0)
	_olu_i = (_olu_i + 1) % _olu_route.size()
	var path := nav.find_path(olu.position, point(_olu_route[_olu_i]))
	if not path.is_empty():
		olu.walk_path(path)


func _update_phone(delta: float) -> void:
	var phone: Node3D = builder.props.get("phone")
	if phone == null:
		return
	if _phone_level <= 0:
		phone.position = phone.position.lerp(_phone_base, minf(1.0, delta * 4.0))
		return
	_phone_t += delta
	var amp := 0.004 * _phone_level
	# vibrate and slowly creep across the desk, as phones do
	phone.position = _phone_base + Vector3(randf_range(-amp, amp) + sin(_phone_t * 0.7) * 0.03 * _phone_level, 0, randf_range(-amp, amp) - minf(_phone_t * 0.02 * _phone_level, 0.18))
	phone.rotation.y = sin(_phone_t * 25.0) * 0.06 * _phone_level


# ================================================================= setup

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("6aa6e6")
	sky_mat.sky_horizon_color = Color("e9f0f3")
	sky_mat.ground_bottom_color = Color("cdbb9e")
	sky_mat.ground_horizon_color = Color("ece2d0")
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("fff1dd")
	env.ambient_light_sky_contribution = 0.75
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssao_power = 1.3
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.light_angular_distance = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 48.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30.0, -150.0, 0.0)
	fill.light_color = Color(0.78, 0.86, 1.0)
	fill.light_energy = 0.3
	fill.shadow_enabled = false
	add_child(fill)
