class_name PaperPuppet
extends Node3D
## A printed cardboard character: body, two arms and a head are separate
## die-cut cards hinged like a paper puppet; eyes, brows and mouth are printed
## overlays swapped for expressions. Everything is Sprite3D (one quad each),
## unshaded, in the Compatibility renderer.
##
## Animation is procedural and deliberately "paper": a springy bob, a waddle,
## a two-frame stride, arms swinging on hinge pins, a flip-turn when changing
## direction, squash & stretch for big reactions.
##
## Exposes the same small API as the 3D Character so the shared dialogue
## system can drive either.

signal arrived(success: bool)

const LAYER := 0.006          # card spacing in metres (front-to-back)
const LEAN := -0.12           # standees lean back slightly, like real cardboard
const SHADOW_SIZE := Vector2(0.95, 0.32)

var id := ""
var display_name := ""
var speed := 2.1
var talking := false
var seated := false            # API parity with Character
var expression := "happy"
var base_expression := "happy"
var fx: PaperFX
var click_body: StaticBody3D

var _data: Dictionary = {}
var _lean: Node3D
var _flip: Node3D
var _bob: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _body: Sprite3D
var _head_card: Sprite3D
var _eyes: Sprite3D
var _brows: Sprite3D
var _mouth: Sprite3D
var _front: Sprite3D
var _shadow: MeshInstance3D
var _bubble: Label3D
var _carry_point: Node3D

var _neck := Vector2.ZERO
var _path: Array = []
var _moving := false
var _facing := 1.0
var _t := 0.0
var _walk_phase := 0.0
var _walk_amt := 0.0
var _blink_t := 2.0
var _blink := 0.0
var _talk_t := 0.0
var _mouth_open := false
var _gesture := ""
var _gesture_t := 0.0
var _gesture_len := 0.0
var _frozen := false
var _red := 0.0
var _turn_tween: Tween
var _eyes_name := "eyes_open"
var _mouth_name := "mouth_smile"

static var _shadow_mat: StandardMaterial3D


func build(char_id: String, def: Dictionary, font: Font, effects: PaperFX) -> void:
	id = char_id
	display_name = str(def.get("name", char_id))
	fx = effects
	var look: Dictionary = def.get("look", {})
	base_expression = str(look.get("face", "happy"))
	_data = PuppetData.get_data(id)
	_t = randf() * 10.0
	_blink_t = randf_range(1.0, 4.0)

	_shadow = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SHADOW_SIZE
	_shadow.mesh = quad
	_shadow.rotation.x = -PI * 0.5
	_shadow.position.y = 0.004
	_shadow.material_override = shadow_material()
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)

	_lean = _node(self, "Lean")
	_lean.rotation.x = LEAN
	_flip = _node(_lean, "Flip")
	_bob = _node(_flip, "Bob")
	var rig: Dictionary = _data.get("rig", {})
	_neck = PuppetData.pt(rig.get("neck", [256, 300]))
	var sl := PuppetData.pt(rig.get("shoulder_l", [160, 360]))
	var sr := PuppetData.pt(rig.get("shoulder_r", [352, 360]))

	# arms hang behind the body card, so the torso outline forms the shoulder
	_arm_l = _node(_bob, "ArmL")
	_arm_l.position = PuppetData.to_local(sl, PuppetData.FEET) + Vector3(0, 0, -LAYER)
	_card(_arm_l, "arm_l", sl, 0.0)
	_arm_r = _node(_bob, "ArmR")
	_arm_r.position = PuppetData.to_local(sr, PuppetData.FEET) + Vector3(0, 0, -LAYER)
	_card(_arm_r, "arm_r", sr, 0.0)
	_body = _card(_bob, "body_stand", PuppetData.FEET, 0.0)

	_head = _node(_bob, "Head")
	_head.position = PuppetData.to_local(_neck, PuppetData.FEET) + Vector3(0, 0, LAYER)
	_head_card = _card(_head, "head", _neck, 0.0)
	_eyes = _card(_head, "eyes_open", _neck, LAYER * 0.5)
	_brows = _card(_head, "brows_neutral", _neck, LAYER * 0.7)
	_mouth = _card(_head, "mouth_smile", _neck, LAYER * 0.5)
	if _data.get("tex", {}).has("front"):
		_front = _card(_head, "front", _neck, LAYER * 0.9)

	_carry_point = _node(_bob, "Carry")
	_carry_point.position = Vector3(0, 0.95, LAYER * 4)

	_bubble = Label3D.new()
	_bubble.font = font
	_bubble.font_size = 40
	_bubble.outline_size = 22
	_bubble.modulate = Color("2b2230")
	_bubble.outline_modulate = Color("fffaf0")
	_bubble.pixel_size = 0.0045
	_bubble.position = Vector3(0, 2.25, 0.05)
	_bubble.width = 560.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.visible = false
	_bubble.render_priority = 10
	_bubble.outline_render_priority = 9
	_bubble.no_depth_test = true
	add_child(_bubble)

	click_body = StaticBody3D.new()
	click_body.set_meta("interact_id", id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 1.9, 0.35)
	shape.shape = box
	shape.position = Vector3(0, 0.95, 0)
	click_body.add_child(shape)
	add_child(click_body)
	set_expression(base_expression)


static func shadow_material() -> StandardMaterial3D:
	if _shadow_mat == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.27, 0.16, 0.08, 0.5))
		g.set_color(1, Color(0.27, 0.16, 0.08, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 128
		t.height = 128
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.albedo_texture = t
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return _shadow_mat


# ================================================================== API

func walk_path(points: Array) -> void:
	if _moving:
		arrived.emit(false)
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


func face_point(p: Vector3, _instant := false) -> void:
	var dx := p.x - global_position.x
	if absf(dx) > 0.15:
		_turn_to(signf(dx))


func face_yaw(_yaw: float, _instant := false) -> void:
	pass


func stand_up() -> void:
	seated = false


func sit_at(pos: Vector3, _yaw: float, _typing := true) -> void:
	position = pos


func set_expression(expr: String) -> void:
	expression = expr
	var parts := PuppetData.expression_parts(expr)
	_eyes_name = parts[0]
	_mouth_name = parts[2]
	_set_card(_eyes, _eyes_name, _neck)
	_set_card(_brows, parts[1], _neck)
	_set_card(_mouth, _mouth_name, _neck)


func reset_expression() -> void:
	set_expression(base_expression)


func set_talking(on: bool) -> void:
	talking = on
	if not on:
		_mouth_open = false
		_set_card(_mouth, _mouth_name, _neck)


func gesture(g: String, duration := 1.6) -> void:
	_gesture = g
	_gesture_t = 0.0
	_gesture_len = duration
	if g in ["shock", "cheer", "rage"]:
		_squash(1.0)


## Freeze in place (awkward silence). Only the blinking continues.
func freeze(on: bool) -> void:
	_frozen = on


func emote(text: String, _color := Color.WHITE, _duration := 1.6) -> void:
	if fx:
		fx.emote(self, text)


func bark(text: String, duration := 3.0) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble.modulate.a = 0.0
	_bubble.outline_modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bubble, "modulate:a", 1.0, 0.2)
	tw.tween_property(_bubble, "outline_modulate:a", 1.0, 0.2)
	tw.chain().tween_interval(duration)
	tw.chain().tween_callback(_hide_bubble)


func _hide_bubble() -> void:
	_bubble.visible = false


func carry(prop: Node3D) -> void:
	for c in _carry_point.get_children():
		c.queue_free()
	if prop:
		_carry_point.add_child(prop)


func set_disheveled(on: bool) -> void:
	_head.rotation.z = 0.12 if on else 0.0


func set_redness(amount: float) -> void:
	_red = clampf(amount, 0.0, 1.0)
	var tint := Color(1.0, 1.0 - 0.45 * _red, 1.0 - 0.5 * _red)
	_head_card.modulate = tint


func head_top() -> Vector3:
	return global_position + Vector3(0, 2.05, 0)


func arm_texture() -> Texture2D:
	return _data.get("tex", {}).get("arm_r")


# ================================================================== animation

func _process(delta: float) -> void:
	_t += delta
	_update_move(delta)
	_update_face(delta)
	_update_pose(delta)


func _update_move(delta: float) -> void:
	if _moving and not _path.is_empty():
		var target: Vector3 = _path[0]
		var to := Vector3(target.x - position.x, 0, target.z - position.z)
		var dist := to.length()
		var step := speed * delta
		if absf(to.x) > 0.05:
			_turn_to(signf(to.x))
		if dist <= step:
			position = Vector3(target.x, position.y, target.z)
			_path.remove_at(0)
			if _path.is_empty():
				_moving = false
				_set_card(_body, "body_stand", PuppetData.FEET)
				arrived.emit(true)
		else:
			position += to / dist * step
	_walk_amt = move_toward(_walk_amt, 1.0 if _moving else 0.0, delta * 6.0)
	if _moving:
		var prev := int(_walk_phase / PI)
		_walk_phase += delta * speed * 4.2
		if int(_walk_phase / PI) != prev:
			# two-frame stride, swapped on each footfall
			_set_card(_body, "body_walk" if int(_walk_phase / PI) % 2 == 0 else "body_stand", PuppetData.FEET)


func _update_face(delta: float) -> void:
	_blink_t -= delta
	if _blink_t <= 0.0 and _eyes_name != "eyes_happy":
		_blink = 0.13
		_blink_t = randf_range(2.2, 5.0)
		_set_card(_eyes, "eyes_blink", _neck)
	if _blink > 0.0:
		_blink -= delta
		if _blink <= 0.0:
			_set_card(_eyes, _eyes_name, _neck)
	if talking and not _frozen:
		_talk_t -= delta
		if _talk_t <= 0.0:
			_talk_t = randf_range(0.08, 0.15)
			_mouth_open = not _mouth_open
			_set_card(_mouth, "mouth_talk" if _mouth_open else _mouth_name, _neck)


func _update_pose(delta: float) -> void:
	if _frozen:
		return
	var w := _walk_amt
	var ph := _walk_phase
	# rest pose: arms hang slightly outward
	var al := -0.06 + sin(_t * 1.7) * 0.02
	var ar := 0.06 - sin(_t * 1.7 + 0.6) * 0.02
	var head_tilt := sin(_t * 0.9) * 0.025
	var head_y := 0.0
	var bob_y := sin(_t * 2.2) * 0.006
	var sway := sin(_t * 1.1) * 0.012
	# walking: hop + waddle + arm swing
	bob_y += absf(sin(ph)) * 0.055 * w
	sway += sin(ph) * 0.07 * w
	al += sin(ph) * 0.3 * w
	ar += sin(ph) * 0.3 * w
	if talking:
		head_y += absf(sin(_t * 9.0)) * 0.01
		head_tilt += sin(_t * 3.3) * 0.04

	if _gesture != "":
		_gesture_t += delta
		var k := _gesture_t
		var env := clampf(minf(k * 6.0, (_gesture_len - k) * 6.0), 0.0, 1.0)
		match _gesture:
			"wave":
				ar = lerpf(ar, 2.55 + sin(k * 13.0) * 0.35, env)
				head_tilt = lerpf(head_tilt, -0.08, env)
			"point":
				ar = lerpf(ar, 1.5 + sin(k * 5.0) * 0.05, env)
				head_tilt = lerpf(head_tilt, -0.06, env)
			"shrug":
				al = lerpf(al, -0.85, env)
				ar = lerpf(ar, 0.85, env)
				head_tilt = lerpf(head_tilt, 0.2, env)
				bob_y += 0.03 * env
			"cheer":
				al = lerpf(al, -2.75 + sin(k * 12.0) * 0.12, env)
				ar = lerpf(ar, 2.75 - sin(k * 12.0) * 0.12, env)
				bob_y += absf(sin(k * 8.0)) * 0.16 * env
			"shock":
				al = lerpf(al, -1.2, env)
				ar = lerpf(ar, 1.2, env)
				bob_y += maxf(0.0, sin(minf(k * 7.0, PI))) * 0.22
			"facepalm":
				al = lerpf(al, 2.75, env)
				head_y -= 0.02 * env
				head_tilt = lerpf(head_tilt, 0.12, env)
			"present":
				al = lerpf(al, -1.05, env)
				ar = lerpf(ar, 1.05, env)
			"rage":
				al = lerpf(al, -2.1 + sin(k * 26.0) * 0.3, env)
				ar = lerpf(ar, 2.1 - sin(k * 26.0) * 0.3, env)
				sway += sin(k * 40.0) * 0.05 * env
				bob_y += absf(sin(k * 18.0)) * 0.05 * env
			"slump":
				head_y -= 0.035 * env
				al = lerpf(al, 0.02, env)
				ar = lerpf(ar, -0.02, env)
			"nod":
				head_y -= absf(sin(k * 11.0)) * 0.025 * env
			"headshake":
				head_tilt += sin(k * 14.0) * 0.14 * env
			"fist":
				ar = lerpf(ar, 2.9 + absf(sin(k * 10.0)) * 0.2, env)
				bob_y += absf(sin(k * 10.0)) * 0.05 * env
			"confused":
				ar = lerpf(ar, 2.7, env)
				head_tilt = lerpf(head_tilt, 0.24, env)
			"sip":
				ar = lerpf(ar, 2.4, env)
			"bow":
				head_y -= 0.04 * env
		if _gesture_t >= _gesture_len:
			_gesture = ""

	var r := minf(1.0, delta * 14.0)
	_arm_l.rotation.z = lerpf(_arm_l.rotation.z, al, r)
	_arm_r.rotation.z = lerpf(_arm_r.rotation.z, ar, r)
	_head.rotation.z = lerpf(_head.rotation.z, head_tilt, r)
	_head.position.y = lerpf(_head.position.y, PuppetData.to_local(_neck, PuppetData.FEET).y + head_y, r)
	_bob.position.y = lerpf(_bob.position.y, bob_y, minf(1.0, delta * 20.0))
	_bob.rotation.z = lerpf(_bob.rotation.z, sway, r)
	_bob.scale = _bob.scale.lerp(Vector3.ONE, minf(1.0, delta * 8.0))
	_shadow.scale = Vector3.ONE * (1.0 - clampf(_bob.position.y, 0.0, 0.3) * 1.2)


func _squash(amount: float) -> void:
	_bob.scale = Vector3(1.0 + 0.12 * amount, 1.0 - 0.14 * amount, 1.0)


## The paper flip: a quick spin through edge-on, like turning a card over.
func _turn_to(dir: float) -> void:
	if dir == _facing:
		return
	_facing = dir
	if _turn_tween and _turn_tween.is_valid():
		_turn_tween.kill()
	_turn_tween = create_tween()
	_turn_tween.tween_property(_flip, "scale:x", 0.06 * dir, 0.09).set_ease(Tween.EASE_IN)
	_turn_tween.tween_property(_flip, "scale:x", dir, 0.11).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


# ================================================================== construction

func _card(parent: Node3D, part: String, pivot: Vector2, z: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.pixel_size = PuppetData.UNIT / float(_data.get("scale", 0.75))
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.shaded = false
	s.double_sided = true
	s.set_meta("z", z)
	parent.add_child(s)
	_set_card(s, part, pivot)
	return s


func _set_card(s: Sprite3D, part: String, pivot: Vector2) -> void:
	if s == null:
		return
	var tex: Dictionary = _data.get("tex", {})
	var rects: Dictionary = _data.get("parts", {})
	if not tex.has(part) or not rects.has(part):
		s.visible = false
		return
	s.visible = true
	s.texture = tex[part]
	var c := PuppetData.rect_center(rects[part])
	s.position = PuppetData.to_local(c, pivot) + Vector3(0, 0, float(s.get_meta("z", 0.0)))


func _node(parent: Node3D, n: String) -> Node3D:
	var nd := Node3D.new()
	nd.name = n
	parent.add_child(nd)
	return nd
