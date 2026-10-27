class_name PaperPortrait
extends Control
## The dialogue portrait in the paper style: the speaker's printed head card
## with live expression overlays, blinking and a talking mouth, composed from
## the same textures as the 3D puppet (no extra viewport, no extra art).

const SIZE := 210.0

var current := ""
var talking := false
var expression := "happy"

var _data: Dictionary = {}
var _root: Control
var _layers: Dictionary = {}
var _k := 1.0
var _origin := Vector2.ZERO
var _eyes_name := "eyes_open"
var _mouth_name := "mouth_smile"
var _blink := 0.0
var _blink_t := 2.0
var _talk_t := 0.0
var _mouth_open := false
var _t := 0.0
var _tilt := 0.0
var _tilt_target := 0.0
var _gesture_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Returns self when the speaker has a paper puppet, otherwise null.
func show_char(id: String):
	if id == "" or not PuppetData.has_puppet(id):
		current = ""
		return null
	if id != current:
		_build(id)
	current = id
	return self


func _build(id: String) -> void:
	for c in get_children():
		c.queue_free()
	_layers.clear()
	_data = PuppetData.get_data(id)
	var rects: Dictionary = _data["parts"]
	var hr: Array = rects["head"]
	_k = (SIZE * 0.82) / maxf(float(hr[2]), float(hr[3]))
	var head_center := PuppetData.rect_center(hr)
	_origin = Vector2(SIZE * 0.5, SIZE * 0.56) - head_center * _k
	_root = Control.new()
	_root.size = Vector2(SIZE, SIZE)
	_root.pivot_offset = Vector2(SIZE * 0.5, SIZE * 0.9)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	for layer in ["head", "eyes", "brows", "mouth", "front"]:
		var layer_rect := TextureRect.new()
		layer_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer_rect.stretch_mode = TextureRect.STRETCH_SCALE
		layer_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(layer_rect)
		_layers[layer] = layer_rect
	_set_layer("head", "head")
	_set_layer("front", "front")
	set_expression(expression)


func _set_layer(layer: String, part: String) -> void:
	var layer_rect: TextureRect = _layers.get(layer)
	if layer_rect == null:
		return
	var tex: Dictionary = _data.get("tex", {})
	var rects: Dictionary = _data.get("parts", {})
	if not tex.has(part):
		layer_rect.visible = false
		return
	var r: Array = rects[part]
	layer_rect.visible = true
	layer_rect.texture = tex[part]
	layer_rect.position = _origin + Vector2(float(r[0]), float(r[1])) * _k
	layer_rect.size = Vector2(float(r[2]), float(r[3])) * _k


func set_expression(expr: String) -> void:
	expression = expr
	if _data.is_empty():
		return
	var parts := PuppetData.expression_parts(expr)
	_eyes_name = parts[0]
	_mouth_name = parts[2]
	_set_layer("eyes", _eyes_name)
	_set_layer("brows", parts[1])
	_set_layer("mouth", _mouth_name)


func reset_expression() -> void:
	set_expression("happy")


func set_talking(on: bool) -> void:
	talking = on
	if not on and not _data.is_empty():
		_set_layer("mouth", _mouth_name)


func gesture(g: String, _duration := 1.6) -> void:
	_gesture_t = 0.5
	match g:
		"shrug", "confused":
			_tilt_target = 0.14
		"shock", "cheer", "rage":
			_tilt_target = -0.08
		_:
			_tilt_target = 0.05


func emote(_text: String, _c := Color.WHITE, _d := 1.6) -> void:
	pass


func set_redness(_a: float) -> void:
	pass


func _process(delta: float) -> void:
	if _data.is_empty() or _root == null:
		return
	_t += delta
	_blink_t -= delta
	if _blink_t <= 0.0 and _eyes_name != "eyes_happy":
		_blink = 0.12
		_blink_t = randf_range(2.0, 4.5)
		_set_layer("eyes", "eyes_blink")
	if _blink > 0.0:
		_blink -= delta
		if _blink <= 0.0:
			_set_layer("eyes", _eyes_name)
	if talking:
		_talk_t -= delta
		if _talk_t <= 0.0:
			_talk_t = randf_range(0.08, 0.15)
			_mouth_open = not _mouth_open
			_set_layer("mouth", "mouth_talk" if _mouth_open else _mouth_name)
	if _gesture_t > 0.0:
		_gesture_t -= delta
		if _gesture_t <= 0.0:
			_tilt_target = 0.0
	_tilt = lerpf(_tilt, _tilt_target + sin(_t * 1.3) * 0.02, minf(1.0, delta * 8.0))
	_root.rotation = _tilt
	_root.position.y = (absf(sin(_t * 9.0)) * 3.0 if talking else sin(_t * 2.0) * 1.5)
