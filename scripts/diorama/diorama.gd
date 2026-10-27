class_name Diorama
extends Node3D
## The illustrated diorama: a cardboard office room on a desk.
##
## Rendering approach (Compatibility renderer, no real-time lights):
##   * room shell = a few textured quads (floor, walls, cardboard edges)
##   * everything is UNSHADED; light and shading are painted into the art
##   * soft contact shadows and light pools are tiny gradient quads
##   * props and characters are die-cut Sprite3D standees leaning back 7°
##   * fixed camera with a gentle drift, so the flat pieces never turn edge-on
##
## Exposes the same API as the 3D World (npc, chars, shake_camera,
## phone_buzz, hover_changed, interacted) so the shared UI and dialogue work.

signal interacted(id: String)
signal hover_changed(text: String)

const X_MIN := -5.0
const X_MAX := 5.0
const Z_BACK := -3.0
const Z_FRONT := 2.4
const WALL_H := 3.2
const BASE_H := 0.4
const PROP_LEAN := -0.12
const SPR := "res://art/sprites/%s.png"

var nav := NavGrid.new()
var fx: PaperFX
var camera: Camera3D
var font: Font
var defs: Dictionary = {}
var chars: Dictionary = {}
var player: PaperPuppet
var interactables: Dictionary = {}    # id -> {pos, approach, label, height}
var props: Dictionary = {}
var ambient := true

var _hover_id := ""
var _hover_ring: Sprite3D
var _markers: Array[Sprite3D] = []
var _marker_targets: Array = []
var _t := 0.0
var _shake := 0.0
var _cam_base := Vector3(0, 5.0, 10.6)
var _cam_look := Vector3(0, 1.2, -0.7)
var _interact_token := 0
var _phone_level := 0
var _phone_base := Vector3.ZERO
var _clock_min: Node3D
var _clock_hour: Node3D
var _clock_speed := 1.0
var _bark_timer := 7.0


func setup(ui_font: Font, character_defs: Dictionary) -> void:
	font = ui_font
	defs = character_defs
	nav.configure(Vector2(X_MIN + 0.1, Z_BACK + 0.1), 39, 21, 0.25)
	_environment()
	fx = PaperFX.new()
	fx.name = "FX"
	add_child(fx)
	_build_room()
	_build_props()
	_hover_ring = _flat_sprite("fx/ring", Vector3.ZERO, 1.0)
	_hover_ring.visible = false
	for i in 3:
		var m := _sprite("fx/arrow", Vector3.ZERO, 0.38, false)
		m.no_depth_test = true
		m.render_priority = 8
		m.visible = false
		_markers.append(m)


# ================================================================ characters

func spawn(id: String, pos: Vector3) -> PaperPuppet:
	var p := PaperPuppet.new()
	p.name = id.capitalize()
	add_child(p)
	p.build(id, defs.get(id, {}), font, fx)
	p.position = pos
	chars[id] = p
	if id == "player":
		player = p
		p.speed = 2.6
		p.click_body.collision_layer = 0
	return p


func npc(id: String):
	return chars.get(id)


func walk(id: String, pos: Vector3) -> bool:
	var c: PaperPuppet = chars.get(id)
	if c == null:
		return false
	var path := nav.find_path(c.position, pos)
	if path.is_empty() or c.position.distance_to(Vector3(pos.x, 0, pos.z)) < 0.05:
		return true
	c.walk_path(path)
	var ok: bool = await c.arrived
	return ok


func shake_camera(amount: float) -> void:
	_shake = maxf(_shake, amount)


func set_markers(ids: Array) -> void:
	_marker_targets = ids.duplicate()


## 0 calm, 1 buzzing, 2 hot, 3 on fire (embers).
func phone_buzz(level: int) -> void:
	_phone_level = level
	var phone: Sprite3D = props.get("phone")
	if phone == null:
		return
	phone.texture = _tex(SPR % ("props/phone_hot" if level >= 2 else "props/phone"))
	fx.set_embers(phone, level >= 3)


## Makes the wall clock race (meetings) or crawl.
func set_clock_speed(mult: float) -> void:
	_clock_speed = mult


# ================================================================ input

func _unhandled_input(event: InputEvent) -> void:
	if Game.input_locked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(event.position)
	elif event is InputEventMouseMotion:
		_update_hover(event.position)


func _click(screen_pos: Vector2) -> void:
	var hit := _pick(screen_pos)
	if hit != "":
		Audio.sfx("click", -6.0)
		request_interact(hit)
		return
	var fp = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos))
	if fp == null:
		return
	_interact_token += 1
	var path := nav.find_path(player.position, fp)
	if not path.is_empty():
		player.walk_path(path)
		fx.pop("ring", Vector3(fp.x, 0.05, fp.z), 0.5, 0.3)


func request_interact(id: String) -> void:
	_interact_token += 1
	var token := _interact_token
	var approach := _approach_for(id)
	var path := nav.find_path(player.position, approach)
	if not path.is_empty() and player.position.distance_to(approach) > 0.25:
		player.walk_path(path)
		var ok: bool = await player.arrived
		if not ok or token != _interact_token or Game.input_locked:
			return
	var target := _target_pos(id)
	player.face_point(target)
	var c: PaperPuppet = chars.get(id)
	if c and not c.is_moving():
		c.face_point(player.global_position)
	interacted.emit(id)


func _approach_for(id: String) -> Vector3:
	if interactables.has(id):
		return interactables[id]["approach"]
	var c: PaperPuppet = chars.get(id)
	if c == null:
		return player.position
	# stand beside the character, on the side the player is coming from
	var side := -1.0 if player.position.x < c.position.x else 1.0
	for s in [side, -side]:
		var p := c.position + Vector3(s * 0.85, 0, 0.15)
		if nav.is_free(nav.to_cell(p)):
			return p
	return c.position + Vector3(0, 0, 0.7)


func _target_pos(id: String) -> Vector3:
	if interactables.has(id):
		return interactables[id]["pos"]
	var c: PaperPuppet = chars.get(id)
	return c.global_position if c else Vector3.ZERO


func _pick(screen_pos: Vector2) -> String:
	var from := camera.project_ray_origin(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(screen_pos) * 100.0)
	var res := get_world_3d().direct_space_state.intersect_ray(q)
	if res.is_empty():
		return ""
	var col = res.get("collider")
	if col and col.has_meta("interact_id"):
		return str(col.get_meta("interact_id"))
	return ""


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
	var text := ""
	var pos := Vector3.ZERO
	var w := 1.0
	if interactables.has(id):
		text = Loc.t(interactables[id]["label"])
		pos = interactables[id]["pos"]
		w = interactables[id]["width"]
	elif chars.has(id):
		text = Loc.t("hover.talk", {"name": str(defs.get(id, {}).get("name", id)).split(" ")[0]})
		pos = chars[id].position
		w = 0.9
	_hover_ring.position = Vector3(pos.x, 0.02, pos.z + 0.05)
	_hover_ring.scale = Vector3.ONE * clampf(w, 0.7, 2.2)
	_hover_ring.visible = true
	hover_changed.emit(text)


func clear_hover() -> void:
	_hover_id = ""
	_hover_ring.visible = false
	hover_changed.emit("")


# ================================================================ per-frame

func _process(delta: float) -> void:
	_t += delta
	# camera: fixed framing with a slow drift and a hint of follow, never rotating
	var follow := player.position.x * 0.12 if player else 0.0
	var drift := Vector3(sin(_t * 0.13) * 0.18 + follow, sin(_t * 0.09) * 0.06, 0)
	var shake := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.4)
		shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.12
	camera.position = _cam_base + drift + shake
	camera.look_at(_cam_look + Vector3(follow * 0.8, 0, 0) + shake * 0.4, Vector3.UP)
	_update_markers()
	_update_phone(delta)
	_update_clock(delta)
	if ambient:
		_bark_timer -= delta
		if _bark_timer <= 0.0:
			_bark_timer = randf_range(8.0, 14.0)
			_random_bark()


func _update_markers() -> void:
	for i in _markers.size():
		var m := _markers[i]
		if i >= _marker_targets.size():
			m.visible = false
			continue
		var id: String = _marker_targets[i]
		var pos := Vector3.ZERO
		if chars.has(id):
			pos = chars[id].position + Vector3(0, 2.35, 0)
		elif interactables.has(id):
			pos = interactables[id]["pos"] + Vector3(0, float(interactables[id]["height"]) + 0.35, 0.1)
		else:
			m.visible = false
			continue
		m.visible = true
		m.position = pos + Vector3(0, absf(sin(_t * 3.2)) * 0.18, 0.2)


func _update_phone(delta: float) -> void:
	var phone: Sprite3D = props.get("phone")
	if phone == null:
		return
	if _phone_level <= 0:
		phone.position = phone.position.lerp(_phone_base, minf(1.0, delta * 5.0))
		phone.rotation.z = lerpf(phone.rotation.z, 0.0, minf(1.0, delta * 5.0))
		return
	var amp := 0.006 * _phone_level
	phone.position = _phone_base + Vector3(randf_range(-amp, amp) + sin(_t * 0.8) * 0.04 * _phone_level, randf_range(0, amp), 0)
	phone.rotation.z = sin(_t * 30.0) * 0.05 * _phone_level


func _update_clock(delta: float) -> void:
	if _clock_min == null:
		return
	var tm := Time.get_time_dict_from_system()
	var real_min := float(tm["minute"]) + float(tm["second"]) / 60.0
	if is_equal_approx(_clock_speed, 1.0):
		_clock_min.rotation.z = -TAU * real_min / 60.0
		_clock_hour.rotation.z = -TAU * (float(int(tm["hour"]) % 12) + real_min / 60.0) / 12.0
	else:
		_clock_min.rotation.z -= delta * _clock_speed * 0.5
		_clock_hour.rotation.z -= delta * _clock_speed * 0.04


func _random_bark() -> void:
	var ids := chars.keys()
	var id: String = ids[randi() % ids.size()]
	if id == "player":
		return
	var lines = Loc.get_data("barks." + id)
	if lines is Array and not lines.is_empty():
		chars[id].bark(str(lines[randi() % lines.size()]), 3.0)


# ================================================================ construction

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e9dcc8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	camera = Camera3D.new()
	camera.fov = 30.0
	camera.near = 0.5
	camera.far = 80.0
	add_child(camera)
	camera.position = _cam_base
	camera.look_at(_cam_look, Vector3.UP)
	camera.current = true


func _build_room() -> void:
	var w := X_MAX - X_MIN
	var d := Z_FRONT - Z_BACK
	# the desk the diorama stands on (soft, out of focus)
	_quad("surfaces/tabletop", Vector3(0, -BASE_H - 0.01, 2.0), Vector2(70, 40), Vector3(-PI * 0.5, 0, 0), Vector2(14, 8), Color(0.85, 0.8, 0.78))
	# cardboard base: front + sides show corrugated flutes
	_quad("surfaces/corrugated", Vector3(0, -BASE_H * 0.5, Z_FRONT + 0.2), Vector2(w + 0.4, BASE_H), Vector3.ZERO, Vector2((w + 0.4) / (BASE_H * 4.0), 1))
	_quad("surfaces/corrugated", Vector3(X_MIN - 0.2, -BASE_H * 0.5, (Z_BACK + Z_FRONT) * 0.5 + 0.1), Vector2(d + 0.2, BASE_H), Vector3(0, -PI * 0.5, 0), Vector2((d + 0.2) / (BASE_H * 4.0), 1))
	_quad("surfaces/corrugated", Vector3(X_MAX + 0.2, -BASE_H * 0.5, (Z_BACK + Z_FRONT) * 0.5 + 0.1), Vector2(d + 0.2, BASE_H), Vector3(0, PI * 0.5, 0), Vector2((d + 0.2) / (BASE_H * 4.0), 1))
	# paper top rim of the base
	_color_quad(Vector3(0, 0.0, Z_FRONT + 0.1), Vector2(w + 0.4, 0.2), Vector3(-PI * 0.5, 0, 0), Color("f3e3c8"))
	# floor
	_quad("surfaces/floor", Vector3(0, 0, (Z_BACK + Z_FRONT) * 0.5), Vector2(w, d), Vector3(-PI * 0.5, 0, 0), Vector2(w / 1.7, d / 1.7))
	# back wall: wainscot + wallpaper, with a cardboard top edge
	_quad("surfaces/wainscot", Vector3(0, 0.55, Z_BACK), Vector2(w, 1.1), Vector3.ZERO, Vector2(w / 2.2, 1))
	_quad("surfaces/wall", Vector3(0, 1.1 + (WALL_H - 1.1) * 0.5, Z_BACK), Vector2(w, WALL_H - 1.1), Vector3.ZERO, Vector2(w / 1.6, (WALL_H - 1.1) / 1.6))
	_quad("surfaces/corrugated", Vector3(0, WALL_H, Z_BACK - 0.07), Vector2(w + 0.28, 0.14), Vector3(-PI * 0.5, 0, 0), Vector2((w + 0.28) / 0.56, 1))
	# side walls (shorter than the room so the front stays open)
	var side_d := d - 1.3
	var side_z := Z_BACK + side_d * 0.5
	for sx in [X_MIN, X_MAX]:
		var rot := Vector3(0, PI * 0.5 if sx < 0 else -PI * 0.5, 0)
		_quad("surfaces/wainscot", Vector3(sx, 0.55, side_z), Vector2(side_d, 1.1), rot, Vector2(side_d / 2.2, 1))
		_quad("surfaces/wall", Vector3(sx, 1.1 + (WALL_H - 1.1) * 0.5, side_z), Vector2(side_d, WALL_H - 1.1), rot, Vector2(side_d / 1.6, (WALL_H - 1.1) / 1.6), Color(0.93, 0.9, 0.86))
		_quad("surfaces/corrugated", Vector3(sx - signf(sx) * 0.07, WALL_H, side_z), Vector2(0.14, side_d), Vector3(-PI * 0.5, 0, 0), Vector2(1, side_d / 0.56))
		# the cut front edge of the wall: raw cardboard
		_quad("surfaces/corrugated", Vector3(sx - signf(sx) * 0.07, WALL_H * 0.5, Z_BACK + side_d), Vector2(WALL_H, 0.14), Vector3(0, 0, PI * 0.5), Vector2(WALL_H / 0.56, 1))
	# painted ambient occlusion where walls meet the floor
	_gradient_quad(Vector3(0, 0.003, Z_BACK + 0.35), Vector2(w, 0.7), Vector3(-PI * 0.5, 0, 0), Color(0.35, 0.2, 0.1, 0.32), true)
	for sx in [X_MIN, X_MAX]:
		_gradient_quad(Vector3(sx - signf(sx) * 0.3, 0.003, side_z), Vector2(side_d, 0.6), Vector3(-PI * 0.5, -PI * 0.5 if sx > 0 else PI * 0.5, 0), Color(0.35, 0.2, 0.1, 0.25), true)
	# warm window light spilling on the floor and wall (additive, one quad each)
	_glow_quad(Vector3(0.1, 0.006, -1.6), Vector2(4.8, 2.6), Vector3(-PI * 0.5, 0, 0), Color(1.0, 0.82, 0.55, 0.32))
	_glow_quad(Vector3(0.1, 1.9, Z_BACK + 0.01), Vector2(5.0, 3.0), Vector3.ZERO, Color(1.0, 0.9, 0.7, 0.18))
	# walls block the nav grid edges
	nav.block_rect(Vector3(0, 0, Z_BACK), Vector2(w, 0.3), 0.0)


func _build_props() -> void:
	# --- wall decals (printed cards pinned to the wall)
	_decal("decals/window", Vector3(0.1, 1.95, Z_BACK + 0.02), 2.8)
	_decal("decals/poster", Vector3(-2.3, 2.05, Z_BACK + 0.02), 0.82)
	_label(Loc.t("world.poster_title"), Vector3(-2.3, 1.72, Z_BACK + 0.05), 34, Color("fbfaf6"), 0.0)
	_decal("decals/door", Vector3(2.25, 1.08, Z_BACK + 0.02), 1.12)
	_label(Loc.t("world.room_meeting"), Vector3(2.25, 2.33, Z_BACK + 0.05), 26, Color("2b3a55"), -0.03)
	_decal("decals/clock", Vector3(2.25, 2.78, Z_BACK + 0.02), 0.5)
	_clock_hour = _hand("decals/clock_hand_short", Vector3(2.25, 2.78, Z_BACK + 0.05), 0.12)
	_clock_min = _hand("decals/clock_hand_long", Vector3(2.25, 2.78, Z_BACK + 0.06), 0.18)
	_flat_sprite("decals/rug", Vector3(0.4, 0.008, 0.45), 3.0)
	# --- standees
	_standee("props/bookshelf", Vector3(-4.2, 0, -2.7), 1.25, "bookshelf", "hover.bookshelf", Vector2(1.2, 0.5))
	_standee("props/plant_small", Vector3(-1.5, 0, -2.7), 0.5, "", "", Vector2(0.4, 0.3))
	_standee("props/whiteboard", Vector3(-3.0, 0, -1.5), 1.5, "whiteboard", "hover.whiteboard", Vector2(1.2, 0.3))
	var board_text := _label(Loc.t("world.whiteboard"), Vector3(0, 1.16, 0.03), 26, Color("2a3550"), 0.02)
	board_text.reparent(props["props/whiteboard@holder"], false)
	_standee("props/printer", Vector3(-4.35, 0, -0.35), 0.85, "printer", "hover.printer", Vector2(0.8, 0.5))
	_standee("props/plant_tall", Vector3(-4.4, 0, 1.3), 0.9, "plant_tall", "hover.plant", Vector2(0.6, 0.4))
	_standee("props/desk", Vector3(0.15, 0, -1.15), 1.8, "desk", "hover.laptop", Vector2(1.8, 0.55))
	_standee("props/chair", Vector3(1.25, 0, -0.78), 0.62, "", "", Vector2.ZERO)
	_standee("props/coffee_counter", Vector3(4.0, 0, -2.65), 2.0, "coffee", "hover.coffee", Vector2(2.0, 0.55))
	_standee("props/water_cooler", Vector3(4.55, 0, -1.15), 0.5, "water_cooler", "hover.water_cooler", Vector2(0.45, 0.4))
	_standee("props/cake_table", Vector3(2.6, 0, -0.5), 1.05, "cake_table", "hover.cake", Vector2(0.85, 0.5))
	# the phone lies on the desk, in front of the desk card
	var phone := _sprite("props/phone", Vector3(0.56, 0.74, -1.15 + 0.08), 0.32, false)
	phone.render_priority = 2
	props["phone"] = phone
	_phone_base = phone.position
	# window, door and clock are clickable too
	_add_interact("window", "hover.window", Vector3(0.1, 1.1, Z_BACK + 0.2), Vector3(2.8, 2.0, 0.2), Vector3(-0.6, 0, -2.3), 2.0)
	_add_interact("door", "hover.door", Vector3(2.25, 0.0, Z_BACK + 0.2), Vector3(1.1, 2.2, 0.2), Vector3(2.25, 0, -2.2), 2.2)
	_add_interact("clock", "hover.clock", Vector3(2.25, 2.55, Z_BACK + 0.2), Vector3(0.5, 0.5, 0.2), Vector3(1.6, 0, -2.2), 2.9)


## A die-cut prop standing on the floor, leaning back slightly, with a contact shadow.
func _standee(path: String, pos: Vector3, width: float, id: String, label: String, foot: Vector2) -> Sprite3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.x = PROP_LEAN
	add_child(holder)
	var t := _tex(SPR % path)
	var s := Sprite3D.new()
	s.texture = t
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var h := 1.0
	if t:
		s.pixel_size = width / float(t.get_width())
		h = float(t.get_height()) * s.pixel_size
	s.position = Vector3(0, h * 0.5, 0)
	holder.add_child(s)
	var shadow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width * 1.05, maxf(0.35, foot.y * 1.2))
	shadow.mesh = q
	shadow.material_override = PaperPuppet.shadow_material()
	shadow.rotation.x = -PI * 0.5
	shadow.position = pos + Vector3(0, 0.004, 0.05)
	add_child(shadow)
	if foot != Vector2.ZERO:
		nav.block_rect(pos, foot, 0.12)
	if id != "":
		_add_interact(id, label, pos, Vector3(width, h, 0.4), pos + Vector3(0, 0, maxf(0.55, foot.y * 0.5 + 0.45)), h)
	props[path] = s
	props[path + "@holder"] = holder
	return s


func _add_interact(id: String, label: String, pos: Vector3, size: Vector3, approach: Vector3, height: float) -> void:
	var body := StaticBody3D.new()
	body.set_meta("interact_id", id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
	body.position = pos
	add_child(body)
	interactables[id] = {"pos": pos, "approach": approach, "label": label, "width": size.x, "height": height}


func _decal(path: String, pos: Vector3, width: float) -> Sprite3D:
	var s := _sprite(path, pos, width, true)
	return s


func _hand(path: String, pivot: Vector3, length: float) -> Node3D:
	var n := Node3D.new()
	n.position = pivot
	add_child(n)
	var s := Sprite3D.new()
	s.texture = _tex(SPR % path)
	s.shaded = false
	if s.texture:
		s.pixel_size = length / float(s.texture.get_height()) * 1.15
		s.position = Vector3(0, float(s.texture.get_height()) * s.pixel_size * 0.42, 0)
	n.add_child(s)
	return n


func _sprite(path: String, pos: Vector3, width: float, opaque: bool) -> Sprite3D:
	var t := _tex(SPR % path)
	var s := Sprite3D.new()
	s.texture = t
	s.shaded = false
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if opaque:
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	if t:
		s.pixel_size = width / float(t.get_width())
	s.position = pos
	add_child(s)
	return s


## A sprite lying flat on the floor (rug, hover ring).
func _flat_sprite(path: String, pos: Vector3, width: float) -> Sprite3D:
	var s := _sprite(path, pos, width, false)
	s.rotation.x = -PI * 0.5
	return s


func _label(text: String, pos: Vector3, size: int, color: Color, tilt: float, lean := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UIKit.display_font()
	l.font_size = size
	l.modulate = color
	l.outline_size = 0
	l.pixel_size = 0.004
	l.position = pos
	l.rotation = Vector3(lean, 0, tilt)
	l.shaded = false
	l.double_sided = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l


func _quad(path: String, pos: Vector3, size: Vector2, rot: Vector3, tiles: Vector2, tint := Color.WHITE) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _tex(SPR % path)
	mat.albedo_color = tint
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.uv1_scale = Vector3(tiles.x, tiles.y, 1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _mesh_quad(pos, size, rot, mat)


func _color_quad(pos: Vector3, size: Vector2, rot: Vector3, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _mesh_quad(pos, size, rot, mat)


## Linear dark-to-clear strip used as painted contact shadow along walls.
func _gradient_quad(pos: Vector3, size: Vector2, rot: Vector3, color: Color, vertical: bool) -> MeshInstance3D:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 16 if vertical else 128
	t.height = 128 if vertical else 16
	t.fill_from = Vector2(0.5, 0.0) if vertical else Vector2(0.0, 0.5)
	t.fill_to = Vector2(0.5, 1.0) if vertical else Vector2(1.0, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = t
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return _mesh_quad(pos, size, rot, mat)


func _glow_quad(pos: Vector3, size: Vector2, rot: Vector3, color: Color) -> MeshInstance3D:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 128
	t.height = 128
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = t
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return _mesh_quad(pos, size, rot, mat)


func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _mesh_quad(pos: Vector3, size: Vector2, rot: Vector3, mat: Material) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
