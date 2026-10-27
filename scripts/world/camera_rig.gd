class_name CameraRig
extends Node3D
## Management-sim camera: follows the player at a comfortable 3/4 angle,
## zooms with the mouse wheel and moves in for conversations.

const BOUNDS_MIN := Vector2(-12.5, -8.0)
const BOUNDS_MAX := Vector2(12.5, 6.5)

var cam: Camera3D
var follow: Node3D
var orbit := false

var _look := Vector3.ZERO
var _dist := 15.0
var _pitch := -50.0
var _yaw := 0.0
var _user_dist := 15.0
var _focus := false
var _focus_pos := Vector3.ZERO
var _focus_dist := 7.5
var _focus_pitch := -32.0
var _shake := 0.0
var _orbit_t := 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 34.0
	cam.near = 0.1
	cam.far = 250.0
	add_child(cam)
	cam.current = true


func zoom(step: float) -> void:
	_user_dist = clampf(_user_dist + step, 8.0, 22.0)


func focus_on(pos: Vector3, dist := 7.5, pitch := -30.0) -> void:
	_focus = true
	_focus_pos = pos
	_focus_dist = dist
	_focus_pitch = pitch


func release_focus() -> void:
	_focus = false


func shake(amount := 0.35) -> void:
	_shake = maxf(_shake, amount)


func snap() -> void:
	_look = _goal()
	_dist = _focus_dist if _focus else _user_dist
	_pitch = _focus_pitch if _focus else -50.0
	_place(0.0)


func _goal() -> Vector3:
	var g := _focus_pos if _focus else (follow.global_position if follow else Vector3.ZERO)
	g.x = clampf(g.x, BOUNDS_MIN.x, BOUNDS_MAX.x)
	g.z = clampf(g.z, BOUNDS_MIN.y, BOUNDS_MAX.y)
	return g


func _process(delta: float) -> void:
	if orbit:
		# a gentle sway rather than a full orbit: the north side is all windows
		_orbit_t += delta
		_yaw = sin(_orbit_t * 0.15) * 28.0
		_look = _look.lerp(Vector3(0, 0, -1.0), minf(1.0, delta * 1.5))
		_dist = lerpf(_dist, 21.0, minf(1.0, delta * 1.5))
		_pitch = lerpf(_pitch, -38.0, minf(1.0, delta * 1.5))
	else:
		_yaw = lerpf(_yaw, 0.0, minf(1.0, delta * 3.0))
		_look = _look.lerp(_goal(), minf(1.0, delta * 3.2))
		_dist = lerpf(_dist, _focus_dist if _focus else _user_dist, minf(1.0, delta * 2.5))
		_pitch = lerpf(_pitch, _focus_pitch if _focus else -50.0, minf(1.0, delta * 2.5))
	_place(delta)


func _place(delta: float) -> void:
	var p := deg_to_rad(_pitch)
	var y := deg_to_rad(_yaw)
	var offset := Vector3(sin(y) * cos(p), -sin(p), cos(y) * cos(p)) * _dist
	var look_at_pos := _look + Vector3(0, 0.9, 0)
	var shake_off := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.2)
		shake_off = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.3
	cam.global_position = look_at_pos + offset + shake_off
	cam.look_at(look_at_pos + shake_off * 0.5, Vector3.UP)
