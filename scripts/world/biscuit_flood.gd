class_name BiscuitFlood
extends Node3D
## Crumbworth's emergency surplus procedure: "ship excess to nearest partner".
## Thousands of biscuits pour through the front door and pile up in drifts.
## Simple CPU particles in a MultiMesh with a height-field so piles grow.

const MAX := 1600
const PILE_CELL := 0.3

var origin := Vector3(11.0, 1.2, 9.5)
var rate := 220.0
var duration := 7.0
var bounds_min := Vector2(-14.7, -9.7)
var bounds_max := Vector2(14.7, 7.85)

var _mm: MultiMesh
var _pos: PackedVector3Array = PackedVector3Array()
var _vel: PackedVector3Array = PackedVector3Array()
var _rot: PackedVector3Array = PackedVector3Array()
var _resting: PackedByteArray = PackedByteArray()
var _count := 0
var _t := 0.0
var _spawn_acc := 0.0
var _heights: Dictionary = {}
var running := false
var crates: Array[Node3D] = []


func _ready() -> void:
	var biscuit := CylinderMesh.new()
	biscuit.top_radius = 0.075
	biscuit.bottom_radius = 0.075
	biscuit.height = 0.026
	biscuit.radial_segments = 14
	biscuit.rings = 1
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.roughness = 0.75
	biscuit.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = biscuit
	_mm.instance_count = MAX
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	add_child(mmi)
	_pos.resize(MAX)
	_vel.resize(MAX)
	_rot.resize(MAX)
	_resting.resize(MAX)


func start() -> void:
	running = true
	_t = 0.0
	for i in 4:
		_spawn_crate(i)


func is_done() -> bool:
	return not running


func _spawn_crate(i: int) -> void:
	var c := Node3D.new()
	var box := MeshInstance3D.new()
	box.mesh = MeshLib.rounded_box(Vector3(0.7, 0.5, 0.5), 0.04)
	box.material_override = Mats.soft(Color("c79a62"), 0.9, 0.0)
	c.add_child(box)
	var tape := MeshInstance3D.new()
	tape.mesh = MeshLib.rounded_box(Vector3(0.72, 0.08, 0.52), 0.01)
	tape.material_override = Mats.soft(Color("e85d5d"), 0.6, 0.0)
	tape.position.y = 0.1
	c.add_child(tape)
	var l := Label3D.new()
	l.text = Loc.t("world.crate")
	l.font_size = 15
	l.pixel_size = 0.004
	l.modulate = Color("5a3a1a")
	l.position = Vector3(0, -0.05, 0.26)
	c.add_child(l)
	add_child(c)
	c.position = origin + Vector3(randf_range(-0.6, 0.6), 0.5, 0)
	crates.append(c)
	var land := Vector3(origin.x + randf_range(-2.5, 2.5), 0.25, 6.6 - i * 1.1 - randf() * 0.5)
	var tw := create_tween()
	tw.tween_interval(i * 0.6)
	tw.tween_property(c, "position", Vector3(land.x, 1.8, (c.position.z + land.z) * 0.5), 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position", land, 0.35).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(c, "rotation", Vector3(0, randf_range(-1.0, 1.0), randf_range(-0.3, 0.3)), 0.7)
	tw.tween_callback(func(): Audio.sfx("crash", -4.0, 1.0, 0.15))


func _process(delta: float) -> void:
	if running:
		_t += delta
		if _t < duration:
			_spawn_acc += rate * delta
			while _spawn_acc >= 1.0 and _count < MAX:
				_spawn_acc -= 1.0
				_spawn()
		elif _all_resting():
			running = false
	_simulate(minf(delta, 1.0 / 30.0))


func _spawn() -> void:
	var i := _count
	_count += 1
	_pos[i] = origin + Vector3(randf_range(-0.7, 0.7), randf_range(-0.3, 0.6), 0.0)
	_vel[i] = Vector3(randf_range(-2.8, 2.8), randf_range(1.0, 4.0), randf_range(-9.5, -3.5))
	_rot[i] = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	_resting[i] = 0
	var shade := randf_range(0.0, 1.0)
	var col := Color("e0a458").lerp(Color("b5743a"), shade)
	if randf() < 0.12:
		col = Color("5a3a28")   # the chocolate ones
	_mm.set_instance_color(i, col)
	_mm.visible_instance_count = _count


func _ground(p: Vector3) -> float:
	var key := Vector2i(int(floor(p.x / PILE_CELL)), int(floor(p.z / PILE_CELL)))
	return float(_heights.get(key, 0.0))


func _settle(p: Vector3) -> float:
	var key := Vector2i(int(floor(p.x / PILE_CELL)), int(floor(p.z / PILE_CELL)))
	var h := float(_heights.get(key, 0.0))
	_heights[key] = minf(h + 0.011, 0.9)
	return h


func _simulate(dt: float) -> void:
	for i in _count:
		if _resting[i] == 1:
			continue
		var p := _pos[i]
		var v := _vel[i]
		v.y -= 9.8 * dt
		p += v * dt
		if p.x < bounds_min.x or p.x > bounds_max.x:
			v.x = -v.x * 0.4
			p.x = clampf(p.x, bounds_min.x, bounds_max.x)
		if p.z < bounds_min.y or (p.z > bounds_max.y and p.x < 9.9) or (p.z > bounds_max.y and p.x > 12.1):
			if p.y < 0.5:
				v.z = -v.z * 0.4
				p.z = clampf(p.z, bounds_min.y, bounds_max.y)
		var g := _ground(p) + 0.013
		var r := _rot[i]
		if p.y <= g:
			p.y = g
			if absf(v.y) < 1.2 and Vector2(v.x, v.z).length() < 1.0:
				_resting[i] = 1
				p.y = _settle(p) + 0.013
				r = Vector3(randf_range(-0.25, 0.25), r.y, randf_range(-0.25, 0.25))
			else:
				v.y = -v.y * 0.3
				v.x *= 0.55
				v.z *= 0.55
		else:
			r += Vector3(v.z, 0.0, -v.x) * dt * 1.5
		_pos[i] = p
		_vel[i] = v
		_rot[i] = r
		_mm.set_instance_transform(i, Transform3D(Basis.from_euler(r), p))


func _all_resting() -> bool:
	for i in _count:
		if _resting[i] == 0:
			return false
	return true
