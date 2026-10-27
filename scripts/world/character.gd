class_name Character
extends Node3D
## A stylised, procedurally assembled office worker.
##
## Everything is built from soft primitives (rounded boxes, capsules, spheres)
## with deliberate proportions: ~4.7 heads tall, big expressive eyes, chunky
## brows and a big friendly nose, in the spirit of the "The Office" concept.
## Animation is procedural: walk cycle, breathing, blinking, talking mouth,
## sitting, typing and a library of comedic gestures.

signal arrived(success: bool)

const FACE := {
	# mouth, brow raise, brow tilt (+ = angry), eye open, one-brow smug
	"neutral": ["flat", 0.0, 0.0, 1.0, false],
	"happy": ["smile", 0.008, -0.05, 1.0, false],
	"joy": ["grin", 0.016, -0.1, 0.85, false],
	"sad": ["frown", 0.004, -0.38, 0.9, false],
	"angry": ["grimace", -0.012, 0.42, 0.9, false],
	"furious": ["grimace", -0.016, 0.6, 1.05, false],
	"shock": ["open", 0.03, -0.12, 1.25, false],
	"smug": ["smirk", 0.0, 0.1, 0.8, true],
	"worried": ["wobble", 0.012, -0.32, 1.05, false],
	"deadpan": ["flat", -0.008, 0.06, 0.55, false],
	"talk": ["talk", 0.0, 0.0, 1.0, false],
}

var id := ""
var display_name := ""
var look: Dictionary = {}
var speed := 2.6
var seated := false
var typing := false
var talking := false
var expression := "neutral"
var base_expression := "happy"
var disheveled := false

var _path: Array = []
var _moving := false
var _target_yaw := 0.0
var _walk_phase := 0.0
var _walk_amount := 0.0
var _t := 0.0
var _blink_timer := 2.0
var _blink := 0.0
var _talk_timer := 0.0
var _mouth_open := false
var _gesture := ""
var _gesture_t := 0.0
var _gesture_len := 0.0
var _seat_yaw := 0.0
var _carry := false

# rig
var body: Node3D
var torso: Node3D
var head: Node3D
var hair_root: Node3D
var thigh_l: Node3D
var thigh_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var upper_l: Node3D
var upper_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var eye_l: Node3D
var eye_r: Node3D
var brow_px: Node3D
var brow_nx: Node3D
var mouth: MeshInstance3D
var mouth_mat: StandardMaterial3D
var skin_mat: StandardMaterial3D
var hold_point: Node3D
var emote_label: Label3D
var bubble_label: Label3D
var click_body: StaticBody3D

var _skin: Color
var _hair: Color
var _font: Font


func build(char_id: String, def: Dictionary, font: Font = null) -> void:
	id = char_id
	display_name = str(def.get("name", char_id))
	look = def.get("look", {})
	_font = font
	base_expression = str(look.get("face", "happy"))
	expression = base_expression
	_skin = Color(str(look.get("skin", "#f0c4a0")))
	_hair = Color(str(look.get("hair", "#5a3a22")))
	var shirt := Color(str(look.get("shirt", "#ffffff")))
	var top := Color(str(look.get("jacket", look.get("shirt", "#ffffff"))))
	var pants := Color(str(look.get("pants", "#2b3a55")))
	var shoes := Color(str(look.get("shoes", "#3b2a20")))
	var width := float(look.get("width", 1.0))
	var accessories: Array = look.get("accessories", [])

	skin_mat = Mats.soft(_skin, 0.7, 0.3).duplicate()
	var shirt_mat := Mats.soft(shirt, 0.85, 0.15)
	var top_mat := Mats.soft(top, 0.85, 0.15)
	var pants_mat := Mats.soft(pants, 0.85, 0.1)
	var shoe_mat := Mats.glossy(shoes, 0.35)

	scale = Vector3.ONE * float(look.get("height", 1.0))

	body = _node(self, "Body", Vector3.ZERO)
	# --- legs (thigh + shin with knees, so sitting looks natural)
	thigh_l = _node(body, "ThighL", Vector3(0.1, 0.9, 0))
	thigh_r = _node(body, "ThighR", Vector3(-0.1, 0.9, 0))
	for thigh in [thigh_l, thigh_r]:
		_mesh(thigh, MeshLib.capsule(0.092, 0.5), Vector3(0, -0.22, 0), pants_mat)
		var shin := _node(thigh, "Shin", Vector3(0, -0.44, 0))
		_mesh(shin, MeshLib.capsule(0.082, 0.48), Vector3(0, -0.21, 0), pants_mat)
		_mesh(shin, MeshLib.rounded_box(Vector3(0.14, 0.09, 0.27), 0.04), Vector3(0, -0.41, 0.05), shoe_mat)
		if thigh == thigh_l:
			shin_l = shin
		else:
			shin_r = shin

	# --- pelvis + torso
	_mesh(body, MeshLib.rounded_box(Vector3(0.38 * width, 0.22, 0.26), 0.1), Vector3(0, 0.93, 0), pants_mat)
	torso = _node(body, "Torso", Vector3(0, 0.98, 0))
	var chest := _mesh(torso, MeshLib.capsule(0.205, 0.64), Vector3(0, 0.24, 0), top_mat)
	chest.scale = Vector3(1.14 * width, 1.0, 0.8)
	if look.has("jacket"):
		# open jacket / cardigan: show the shirt as a front panel
		_mesh(torso, MeshLib.rounded_box(Vector3(0.13, 0.42, 0.06), 0.03), Vector3(0, 0.3, 0.145), shirt_mat)
	# collar
	_mesh(torso, MeshLib.rounded_box(Vector3(0.2, 0.06, 0.14), 0.03), Vector3(0, 0.53, 0.04), shirt_mat)

	# --- arms with elbows
	upper_l = _node(torso, "UpperL", Vector3(0.25 * width, 0.44, 0))
	upper_r = _node(torso, "UpperR", Vector3(-0.25 * width, 0.44, 0))
	for upper in [upper_l, upper_r]:
		_mesh(upper, MeshLib.capsule(0.072, 0.38), Vector3(0, -0.15, 0), top_mat)
		var fore := _node(upper, "Fore", Vector3(0, -0.31, 0))
		_mesh(fore, MeshLib.capsule(0.064, 0.36), Vector3(0, -0.14, 0), top_mat)
		_mesh(fore, MeshLib.sphere(0.072), Vector3(0, -0.33, 0.0), skin_mat)
		if upper == upper_l:
			fore_l = fore
		else:
			fore_r = fore

	hold_point = _node(torso, "Hold", Vector3(0, 0.05, 0.38))

	# --- neck + head
	_mesh(torso, MeshLib.cylinder(0.062, 0.07, 0.14), Vector3(0, 0.58, 0), skin_mat)
	head = _node(torso, "Head", Vector3(0, 0.6, 0))
	var skull := _mesh(head, MeshLib.sphere(0.2, 32), Vector3(0, 0.2, 0), skin_mat)
	skull.scale = Vector3(1.0, 1.08, 0.96)
	# ears
	for sx in [1.0, -1.0]:
		var ear := _mesh(head, MeshLib.sphere(0.046), Vector3(0.197 * sx, 0.19, -0.01), skin_mat)
		ear.scale = Vector3(0.45, 1.0, 0.75)
	# big friendly nose
	var nose_col: Color = _skin.lerp(Color(0.95, 0.5, 0.45), 0.18)
	var nose := _mesh(head, MeshLib.sphere(0.052), Vector3(0, 0.145, 0.19), Mats.soft(nose_col, 0.6, 0.3))
	nose.scale = Vector3(0.85, 0.9, 1.0)
	# cheeks
	for sx in [1.0, -1.0]:
		var cheek := _mesh(head, MeshLib.sphere(0.042), Vector3(0.11 * sx, 0.115, 0.14), Mats.soft(_skin.lerp(Color(1.0, 0.55, 0.55), 0.22), 0.8, 0.0))
		cheek.scale = Vector3(1.0, 0.75, 0.6)
	# eyes
	var eye_col := Color(str(look.get("eyes", "#4a3322")))
	eye_l = _make_eye(Vector3(0.078, 0.205, 0.158), eye_col)
	eye_r = _make_eye(Vector3(-0.078, 0.205, 0.158), eye_col)
	# brows
	var brow_mat := Mats.soft(_hair.darkened(0.25), 0.8, 0.0)
	brow_px = _node(head, "BrowPX", Vector3(0.08, 0.275, 0.176))
	brow_nx = _node(head, "BrowNX", Vector3(-0.08, 0.275, 0.176))
	for brow in [brow_px, brow_nx]:
		_mesh(brow, MeshLib.rounded_box(Vector3(0.1, 0.03, 0.03), 0.013), Vector3.ZERO, brow_mat)
	# mouth (painted)
	var has_beard := str(look.get("beard", "")) == "full"
	mouth = MeshInstance3D.new()
	mouth.mesh = MeshLib.quad(Vector2(0.15, 0.075))
	mouth.position = Vector3(0, 0.075, 0.236 if has_beard else 0.166)
	mouth.rotation.x = 0.25
	mouth_mat = StandardMaterial3D.new()
	mouth_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mouth_mat.alpha_scissor_threshold = 0.4
	mouth_mat.roughness = 0.7
	mouth_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouth.material_override = mouth_mat
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.add_child(mouth)

	hair_root = _node(head, "Hair", Vector3.ZERO)
	_build_hair(str(look.get("hair_style", "short")))
	_build_facial_hair(str(look.get("beard", "")))
	for acc in accessories:
		_build_accessory(str(acc))

	# Floating labels
	emote_label = _make_label(64, Vector3(0, 2.35, 0))
	bubble_label = _make_label(30, Vector3(0, 2.6, 0))
	bubble_label.width = 520.0
	bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Click target
	click_body = StaticBody3D.new()
	click_body.set_meta("interact_id", id)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 2.0
	shape.shape = cap
	shape.position = Vector3(0, 1.0, 0)
	click_body.add_child(shape)
	add_child(click_body)

	set_expression(base_expression)
	_blink_timer = randf_range(1.0, 4.0)
	_t = randf() * 10.0


# ------------------------------------------------------------------ public api

func walk_path(points: Array) -> void:
	if _moving:
		arrived.emit(false)
	seated = false
	typing = false
	_path.clear()
	for p in points:
		_path.append(p)
	_moving = not _path.is_empty()
	if not _moving:
		arrived.emit(true)


func stop_walking() -> void:
	if _moving:
		_moving = false
		_path.clear()
		arrived.emit(false)


func is_moving() -> bool:
	return _moving


func face_point(p: Vector3, instant := false) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	_target_yaw = atan2(d.x, d.z)
	if instant:
		rotation.y = _target_yaw


func face_yaw(yaw: float, instant := false) -> void:
	_target_yaw = yaw
	if instant:
		rotation.y = yaw


func sit_at(pos: Vector3, yaw: float, is_typing := true) -> void:
	stop_walking()
	position = pos
	seated = true
	typing = is_typing
	_seat_yaw = yaw
	face_yaw(yaw, true)


func stand_up() -> void:
	seated = false
	typing = false


func set_expression(expr: String) -> void:
	if not FACE.has(expr):
		expr = "neutral"
	expression = expr
	_apply_face()


func reset_expression() -> void:
	set_expression(base_expression)


func gesture(g: String, duration := 1.6) -> void:
	_gesture = g
	_gesture_t = 0.0
	_gesture_len = duration


func set_talking(on: bool) -> void:
	talking = on
	if not on:
		_mouth_open = false
		_apply_face()


func carry(prop: Node3D) -> void:
	for c in hold_point.get_children():
		c.queue_free()
	if prop:
		hold_point.add_child(prop)
		_carry = true
	else:
		_carry = false


func set_disheveled(on: bool) -> void:
	disheveled = on
	hair_root.rotation = Vector3(0.12, 0.3, 0.35) if on else Vector3.ZERO
	hair_root.position = Vector3(0.03, -0.02, 0) if on else Vector3.ZERO


func set_redness(amount: float) -> void:
	skin_mat.albedo_color = _skin.lerp(Color(0.95, 0.32, 0.28), clampf(amount, 0.0, 1.0))


func emote(text: String, color := Color("ffb627"), duration := 1.6) -> void:
	emote_label.text = text
	emote_label.modulate = color
	emote_label.visible = true
	emote_label.scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(emote_label, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(duration)
	tw.tween_property(emote_label, "scale", Vector3.ONE * 0.01, 0.15)
	tw.tween_callback(func(): emote_label.visible = false)


func bark(text: String, duration := 3.0) -> void:
	bubble_label.text = text
	bubble_label.visible = true
	bubble_label.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(bubble_label, "modulate", Color.WHITE, 0.2)
	tw.tween_interval(duration)
	tw.tween_property(bubble_label, "modulate", Color(1, 1, 1, 0), 0.4)
	tw.tween_callback(func(): bubble_label.visible = false)


# ------------------------------------------------------------------ animation

func _process(delta: float) -> void:
	_t += delta
	_update_movement(delta)
	_update_face(delta)
	_update_pose(delta)


func _update_movement(delta: float) -> void:
	if _moving and not _path.is_empty():
		var target: Vector3 = _path[0]
		var to := Vector3(target.x - position.x, 0, target.z - position.z)
		var dist := to.length()
		var step := speed * delta
		if dist <= step:
			position = Vector3(target.x, position.y, target.z)
			_path.remove_at(0)
			if _path.is_empty():
				_moving = false
				arrived.emit(true)
		else:
			position += to / dist * step
			_target_yaw = atan2(to.x, to.z)
	_walk_amount = move_toward(_walk_amount, 1.0 if _moving else 0.0, delta * 6.0)
	if _walk_amount > 0.0:
		_walk_phase += delta * speed * 4.0
	rotation.y = lerp_angle(rotation.y, _target_yaw, minf(1.0, delta * 10.0))


func _update_face(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 0.14
		_blink_timer = randf_range(2.0, 5.0)
	if _blink > 0.0:
		_blink -= delta
	var open: float = FACE[expression][3]
	var lid := 0.1 if _blink > 0.0 else open
	eye_l.scale.y = lerpf(eye_l.scale.y, lid, minf(1.0, delta * 30.0))
	eye_r.scale.y = eye_l.scale.y
	if talking:
		_talk_timer -= delta
		if _talk_timer <= 0.0:
			_talk_timer = randf_range(0.07, 0.15)
			_mouth_open = not _mouth_open
			mouth_mat.albedo_texture = FaceArt.mouth("talk" if _mouth_open else _base_mouth())


func _base_mouth() -> String:
	return FACE[expression][0]


func _apply_face() -> void:
	var f: Array = FACE[expression]
	mouth_mat.albedo_texture = FaceArt.mouth(f[0])
	var raise: float = f[1]
	var tilt: float = f[2]
	brow_px.position.y = 0.275 + raise
	brow_nx.position.y = 0.275 + raise
	brow_px.rotation.z = tilt
	brow_nx.rotation.z = -tilt
	if f[4]:
		brow_px.position.y += 0.025
		brow_px.rotation.z = -0.2


func _update_pose(delta: float) -> void:
	var w := _walk_amount
	var ph := _walk_phase
	var swing := sin(ph)
	# targets (euler radians)
	var t_thigh_l := Vector3(swing * 0.55 * w, 0, 0)
	var t_thigh_r := Vector3(-swing * 0.55 * w, 0, 0)
	var t_shin_l := Vector3(maxf(0.0, -swing) * 0.7 * w, 0, 0)
	var t_shin_r := Vector3(maxf(0.0, swing) * 0.7 * w, 0, 0)
	var t_up_l := Vector3(-swing * 0.45 * w, 0, 0.1)
	var t_up_r := Vector3(swing * 0.45 * w, 0, -0.1)
	var t_fo_l := Vector3(-0.25 - 0.2 * w, 0, 0)
	var t_fo_r := Vector3(-0.25 - 0.2 * w, 0, 0)
	var t_head := Vector3(sin(_t * 0.7) * 0.03, sin(_t * 0.43) * 0.08, 0)
	var t_torso := Vector3(0.04 * w, 0, 0)
	var body_y := absf(cos(ph)) * 0.045 * w
	var breathe := 1.0 + sin(_t * 2.1) * 0.012

	if seated:
		t_thigh_l = Vector3(-1.5, 0, 0.06)
		t_thigh_r = Vector3(-1.5, 0, -0.06)
		t_shin_l = Vector3(1.45, 0, 0)
		t_shin_r = Vector3(1.45, 0, 0)
		body_y = -0.4
		if typing:
			t_up_l = Vector3(-0.45, 0, 0.18)
			t_up_r = Vector3(-0.45, 0, -0.18)
			t_fo_l = Vector3(-1.25 + sin(_t * 17.0) * 0.07, 0, -0.1)
			t_fo_r = Vector3(-1.25 + sin(_t * 15.0 + 1.3) * 0.07, 0, 0.1)
			t_head = Vector3(0.12 + sin(_t * 0.5) * 0.02, sin(_t * 0.3) * 0.05, 0)

	if _carry:
		t_up_l = Vector3(-0.55, 0, 0.12)
		t_up_r = Vector3(-0.55, 0, -0.12)
		t_fo_l = Vector3(-1.0, 0, -0.25)
		t_fo_r = Vector3(-1.0, 0, 0.25)

	if talking:
		t_head.x += sin(_t * 6.5) * 0.04
		t_head.z += sin(_t * 3.1) * 0.03

	# gestures
	if _gesture != "":
		_gesture_t += delta
		var k := _gesture_t
		var env := clampf(minf(k * 5.0, (_gesture_len - k) * 5.0), 0.0, 1.0)
		match _gesture:
			"wave":
				t_up_r = t_up_r.lerp(Vector3(0, 0, -1.25), env)
				t_fo_r = t_fo_r.lerp(Vector3(0, 0, -1.1 + sin(k * 14.0) * 0.45), env)
			"cheer":
				t_up_l = t_up_l.lerp(Vector3(0, 0, 2.6), env)
				t_up_r = t_up_r.lerp(Vector3(0, 0, -2.6), env)
				t_fo_l = t_fo_l.lerp(Vector3.ZERO, env)
				t_fo_r = t_fo_r.lerp(Vector3.ZERO, env)
				if not seated:
					body_y += absf(sin(k * 9.0)) * 0.16 * env
			"shrug":
				t_up_l = t_up_l.lerp(Vector3(-0.3, 0, 0.55), env)
				t_up_r = t_up_r.lerp(Vector3(-0.3, 0, -0.55), env)
				t_fo_l = t_fo_l.lerp(Vector3(-1.2, 0, 0.6), env)
				t_fo_r = t_fo_r.lerp(Vector3(-1.2, 0, -0.6), env)
				t_head = t_head.lerp(Vector3(0, 0, 0.22), env)
			"facepalm":
				t_up_r = t_up_r.lerp(Vector3(-1.1, 0, 0.35), env)
				t_fo_r = t_fo_r.lerp(Vector3(-1.9, 0, 0.0), env)
				t_head = t_head.lerp(Vector3(0.35, 0, 0), env)
			"point":
				t_up_r = t_up_r.lerp(Vector3(-1.45, 0, 0.0), env)
				t_fo_r = t_fo_r.lerp(Vector3(-0.1, 0, 0), env)
			"present":
				t_up_l = t_up_l.lerp(Vector3(-0.4, 0, 1.05), env)
				t_fo_l = t_fo_l.lerp(Vector3(-0.6, 0, 0.3), env)
				t_up_r = t_up_r.lerp(Vector3(-0.4, 0, -1.05), env)
				t_fo_r = t_fo_r.lerp(Vector3(-0.6, 0, -0.3), env)
			"shock":
				t_up_l = t_up_l.lerp(Vector3(-0.2, 0, 1.0), env)
				t_up_r = t_up_r.lerp(Vector3(-0.2, 0, -1.0), env)
				t_fo_l = t_fo_l.lerp(Vector3(0, 0, 0.9), env)
				t_fo_r = t_fo_r.lerp(Vector3(0, 0, -0.9), env)
				if not seated:
					body_y += maxf(0.0, sin(minf(k * 8.0, PI))) * 0.25
			"slump":
				t_head = t_head.lerp(Vector3(0.45, 0, 0), env)
				t_torso = t_torso.lerp(Vector3(0.22, 0, 0), env)
				t_up_l = t_up_l.lerp(Vector3(0.1, 0, 0.02), env)
				t_up_r = t_up_r.lerp(Vector3(0.1, 0, -0.02), env)
			"nod":
				t_head.x += sin(k * 12.0) * 0.18 * env
			"headshake":
				t_head.y += sin(k * 13.0) * 0.35 * env
			"fist":
				t_up_r = t_up_r.lerp(Vector3(-0.4, 0, -0.3), env)
				t_fo_r = t_fo_r.lerp(Vector3(-2.1 + absf(sin(k * 10.0)) * 0.4, 0, 0), env)
			"rage":
				t_up_l = t_up_l.lerp(Vector3(-0.4, 0, 0.8 + sin(k * 20.0) * 0.3), env)
				t_up_r = t_up_r.lerp(Vector3(-0.4, 0, -0.8 - sin(k * 20.0) * 0.3), env)
				t_fo_l = t_fo_l.lerp(Vector3(-1.6, 0, 0), env)
				t_fo_r = t_fo_r.lerp(Vector3(-1.6, 0, 0), env)
				body_y += absf(sin(k * 16.0)) * 0.05 * env
			"sip":
				t_up_r = t_up_r.lerp(Vector3(-0.5, 0, 0.1), env)
				t_fo_r = t_fo_r.lerp(Vector3(-2.0, 0, 0.2), env)
				t_head = t_head.lerp(Vector3(-0.15, 0, 0), env)
			"bow":
				t_torso = t_torso.lerp(Vector3(0.45, 0, 0), env)
				t_head = t_head.lerp(Vector3(0.2, 0, 0), env)
		if _gesture_t >= _gesture_len:
			_gesture = ""

	var r := minf(1.0, delta * 12.0)
	thigh_l.rotation = thigh_l.rotation.lerp(t_thigh_l, r)
	thigh_r.rotation = thigh_r.rotation.lerp(t_thigh_r, r)
	shin_l.rotation = shin_l.rotation.lerp(t_shin_l, r)
	shin_r.rotation = shin_r.rotation.lerp(t_shin_r, r)
	upper_l.rotation = upper_l.rotation.lerp(t_up_l, r)
	upper_r.rotation = upper_r.rotation.lerp(t_up_r, r)
	fore_l.rotation = fore_l.rotation.lerp(t_fo_l, r)
	fore_r.rotation = fore_r.rotation.lerp(t_fo_r, r)
	head.rotation = head.rotation.lerp(t_head, r)
	torso.rotation = torso.rotation.lerp(t_torso, r)
	torso.scale = Vector3(1.0, breathe, 1.0)
	body.position.y = lerpf(body.position.y, body_y, minf(1.0, delta * 18.0))


# ------------------------------------------------------------------ construction

func _make_eye(pos: Vector3, iris_col: Color) -> Node3D:
	var eye := _node(head, "Eye", pos)
	var white := _mesh(eye, MeshLib.sphere(0.053), Vector3.ZERO, Mats.glossy(Color(0.99, 0.99, 0.97), 0.15))
	white.scale = Vector3(0.95, 1.12, 0.55)
	var iris := _mesh(eye, MeshLib.sphere(0.03), Vector3(0, -0.004, 0.02), Mats.glossy(iris_col, 0.2))
	iris.scale = Vector3(1.0, 1.08, 0.45)
	var pupil := _mesh(iris, MeshLib.sphere(0.017), Vector3(0, 0, 0.022), Mats.glossy(Color(0.05, 0.04, 0.05), 0.1))
	pupil.scale = Vector3(1.0, 1.0, 0.6)
	var glint := _mesh(eye, MeshLib.sphere(0.008, 8), Vector3(0.012, 0.014, 0.036), Mats.emissive(Color.WHITE, 2.0))
	glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return eye


func _build_hair(style: String) -> void:
	var mat := Mats.soft(_hair, 0.65, 0.35)
	var cap_pos := Vector3(0, 0.272, -0.058)
	match style:
		"bald_sides":
			for sx in [1.0, -1.0]:
				var tuft := _mesh(hair_root, MeshLib.sphere(0.08), Vector3(0.175 * sx, 0.24, -0.06), mat)
				tuft.scale = Vector3(0.6, 1.0, 1.2)
			var back := _mesh(hair_root, MeshLib.sphere(0.15), Vector3(0, 0.22, -0.11), mat)
			back.scale = Vector3(1.25, 0.65, 0.8)
			return
		"buzz":
			var c := _mesh(hair_root, MeshLib.sphere(0.21, 32), Vector3(0, 0.25, -0.035), mat)
			c.scale = Vector3(1.0, 0.92, 1.0)
			return
	var cap := _mesh(hair_root, MeshLib.sphere(0.216, 32), cap_pos, mat)
	cap.scale = Vector3(1.02, 0.93, 1.02)
	match style:
		"tousled":
			var tufts := [
				Vector3(0.0, 0.43, 0.06), Vector3(0.1, 0.42, 0.0), Vector3(-0.1, 0.42, 0.01),
				Vector3(0.05, 0.45, -0.08), Vector3(-0.07, 0.44, -0.1), Vector3(0.14, 0.36, 0.08),
				Vector3(-0.15, 0.35, 0.06), Vector3(0.0, 0.39, 0.14),
			]
			for i in tufts.size():
				var tuft := _mesh(hair_root, MeshLib.sphere(0.085), tufts[i], mat)
				tuft.scale = Vector3(1.0, 0.75, 1.15)
				tuft.rotation = Vector3(randf_range(-0.4, 0.4), i * 0.8, randf_range(-0.4, 0.4))
			var quiff := _mesh(hair_root, MeshLib.capsule(0.06, 0.22), Vector3(0.05, 0.37, 0.15), mat)
			quiff.rotation = Vector3(1.1, 0, -0.9)
		"bun":
			_mesh(hair_root, MeshLib.sphere(0.1), Vector3(0, 0.44, -0.12), mat)
			var wrap := _mesh(hair_root, MeshLib.torus(0.07, 0.1), Vector3(0, 0.4, -0.1), Mats.soft(_hair.darkened(0.15), 0.6, 0.2))
			wrap.rotation.x = -0.6
		"bob":
			for sx in [1.0, -1.0]:
				var side := _mesh(hair_root, MeshLib.capsule(0.09, 0.36), Vector3(0.18 * sx, 0.16, -0.02), mat)
				side.rotation.z = 0.12 * sx
			var back := _mesh(hair_root, MeshLib.sphere(0.2), Vector3(0, 0.17, -0.1), mat)
			back.scale = Vector3(1.05, 1.0, 0.8)
			var fringe := _mesh(hair_root, MeshLib.capsule(0.06, 0.34), Vector3(0.0, 0.36, 0.14), mat)
			fringe.rotation = Vector3(0.0, 0.0, PI * 0.5 - 0.15)
		"slick":
			var ridge := _mesh(hair_root, MeshLib.capsule(0.07, 0.28), Vector3(0.06, 0.4, 0.04), mat)
			ridge.rotation = Vector3(PI * 0.5, 0.2, 0)
			var quiff := _mesh(hair_root, MeshLib.sphere(0.1), Vector3(-0.03, 0.42, 0.1), mat)
			quiff.scale = Vector3(1.3, 0.7, 0.9)
		"curly":
			for i in 22:
				var a := TAU * i / 22.0
				var ring := 0.13 + (i % 3) * 0.035
				var p := Vector3(cos(a) * ring, 0.38 + (i % 2) * 0.05, sin(a) * ring - 0.04)
				_mesh(hair_root, MeshLib.sphere(0.065), p, mat)
		"ponytail":
			var tail := _mesh(hair_root, MeshLib.capsule(0.07, 0.36), Vector3(0, 0.22, -0.26), mat)
			tail.rotation.x = 0.35
			_mesh(hair_root, MeshLib.sphere(0.045), Vector3(0, 0.36, -0.22), Mats.soft(Color("e85d5d"), 0.6, 0.0))
		"long":
			var back := _mesh(hair_root, MeshLib.rounded_box(Vector3(0.4, 0.5, 0.14), 0.07), Vector3(0, 0.08, -0.13), mat)
			back.rotation.x = 0.08
			for sx in [1.0, -1.0]:
				var side := _mesh(hair_root, MeshLib.capsule(0.07, 0.42), Vector3(0.18 * sx, 0.12, 0.0), mat)
				side.rotation.z = 0.08 * sx
		_:
			var front := _mesh(hair_root, MeshLib.sphere(0.12), Vector3(0.05, 0.4, 0.08), mat)
			front.scale = Vector3(1.4, 0.6, 1.0)


func _build_facial_hair(kind: String) -> void:
	var mat := Mats.soft(_hair.darkened(0.1), 0.7, 0.2)
	match kind:
		"full":
			var beard := _mesh(head, MeshLib.sphere(0.17, 28), Vector3(0, 0.07, 0.07), mat)
			beard.scale = Vector3(1.12, 0.78, 0.98)
			for sx in [1.0, -1.0]:
				var side := _mesh(head, MeshLib.capsule(0.05, 0.2), Vector3(0.17 * sx, 0.15, 0.02), mat)
				side.rotation.z = 0.1 * sx
		"moustache":
			for sx in [1.0, -1.0]:
				var m := _mesh(head, MeshLib.capsule(0.03, 0.13), Vector3(0.045 * sx, 0.103, 0.19), mat)
				m.rotation = Vector3(0, 0, PI * 0.5 + 0.35 * sx)
		"stubble":
			var s := _mesh(head, MeshLib.sphere(0.16), Vector3(0, 0.08, 0.05), Mats.soft(_skin.lerp(_hair, 0.35), 0.9, 0.0))
			s.scale = Vector3(1.15, 0.7, 0.95)


func _build_accessory(acc: String) -> void:
	match acc:
		"glasses":
			var frame := Mats.glossy(Color(str(look.get("glasses_color", "#1d1f24"))), 0.3)
			for sx in [1.0, -1.0]:
				var rim := _mesh(head, MeshLib.torus(0.045, 0.058), Vector3(0.078 * sx, 0.205, 0.2), frame)
				rim.rotation.x = PI * 0.5
			var bridge := _mesh(head, MeshLib.capsule(0.009, 0.06), Vector3(0, 0.215, 0.205), frame)
			bridge.rotation.z = PI * 0.5
			for sx in [1.0, -1.0]:
				var arm := _mesh(head, MeshLib.capsule(0.008, 0.2), Vector3(0.14 * sx, 0.215, 0.1), frame)
				arm.rotation.x = PI * 0.5
		"tie":
			var tie_mat := Mats.glossy(Color(str(look.get("tie", "#c0392b"))), 0.35)
			_mesh(torso, MeshLib.rounded_box(Vector3(0.05, 0.05, 0.03), 0.012), Vector3(0, 0.5, 0.17), tie_mat)
			var tie := _mesh(torso, MeshLib.rounded_box(Vector3(0.07, 0.34, 0.025), 0.015), Vector3(0, 0.3, 0.17), tie_mat)
			tie.rotation.x = -0.12
			tie.name = "Tie"
		"lanyard":
			var strap := Mats.soft(Color("2b5fae"), 0.7, 0.0)
			for sx in [1.0, -1.0]:
				var s := _mesh(torso, MeshLib.rounded_box(Vector3(0.025, 0.3, 0.01), 0.004), Vector3(0.06 * sx, 0.4, 0.165), strap)
				s.rotation = Vector3(-0.15, 0, -0.28 * sx)
			_mesh(torso, MeshLib.rounded_box(Vector3(0.09, 0.12, 0.012), 0.01), Vector3(0, 0.22, 0.18), Mats.solid(Color.WHITE, 0.4))
			_mesh(torso, MeshLib.rounded_box(Vector3(0.07, 0.03, 0.014), 0.005), Vector3(0, 0.25, 0.181), Mats.solid(Color("2b5fae"), 0.4))
		"headphones":
			var hp := Mats.glossy(Color(str(look.get("headphones", "#2bb3a3"))), 0.3)
			for i in 9:
				var a := PI * float(i) / 8.0
				_mesh(head, MeshLib.sphere(0.03), Vector3(cos(a) * 0.225, 0.22 + sin(a) * 0.24, -0.02), hp)
			for sx in [1.0, -1.0]:
				var cup := _mesh(head, MeshLib.cylinder(0.065, 0.065, 0.06), Vector3(0.215 * sx, 0.2, -0.01), hp)
				cup.rotation.z = PI * 0.5
		"headset":
			var hs := Mats.glossy(Color("2e3138"), 0.3)
			for i in 9:
				var a := PI * float(i) / 8.0
				_mesh(head, MeshLib.sphere(0.018), Vector3(cos(a) * 0.218, 0.22 + sin(a) * 0.235, -0.01), hs)
			var cup := _mesh(head, MeshLib.cylinder(0.05, 0.05, 0.04), Vector3(-0.21, 0.2, -0.01), hs)
			cup.rotation.z = PI * 0.5
			var boom := _mesh(head, MeshLib.capsule(0.012, 0.22), Vector3(-0.15, 0.1, 0.12), hs)
			boom.rotation = Vector3(0.9, 0.0, 0.6)
			_mesh(head, MeshLib.sphere(0.022), Vector3(-0.07, 0.07, 0.19), Mats.solid(Color("111111"), 0.5))
		"pearls":
			var pearl := Mats.glossy(Color("fff8ee"), 0.1)
			for i in 11:
				var a := PI * (0.15 + 0.7 * float(i) / 10.0)
				_mesh(torso, MeshLib.sphere(0.018, 10), Vector3(cos(a) * 0.13, 0.5 - sin(a) * 0.08, 0.1 + sin(a) * 0.06), pearl)
		"earrings":
			for sx in [1.0, -1.0]:
				_mesh(head, MeshLib.sphere(0.018, 10), Vector3(0.2 * sx, 0.13, 0.0), Mats.glossy(Color("f2b134"), 0.2))
		"pocket_square":
			_mesh(torso, MeshLib.rounded_box(Vector3(0.06, 0.04, 0.02), 0.008), Vector3(0.12, 0.42, 0.16), Mats.soft(Color("f2b134"), 0.6, 0.0))
		"pen":
			_mesh(torso, MeshLib.capsule(0.01, 0.1), Vector3(-0.1, 0.42, 0.16), Mats.glossy(Color("2b5fae"), 0.3))


func _make_label(size: int, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.font_size = size
	if _font:
		l.font = _font
	l.outline_size = int(size * 0.28)
	l.outline_modulate = Color(0.12, 0.13, 0.18)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.004
	l.position = pos
	l.visible = false
	l.render_priority = 5
	l.outline_render_priority = 4
	add_child(l)
	return l


func _node(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = n
	node.position = pos
	parent.add_child(node)
	return node


func _mesh(parent: Node3D, m: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi
