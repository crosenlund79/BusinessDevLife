class_name PaperFX
extends Node3D
## Cheap, readable comic effects made of printed sprites: reaction symbols,
## celebration bursts, phone embers and the cartoon dust-cloud brawl.
## Every effect is a handful of Sprite3D quads animated with tweens.

const DIR := "res://art/sprites/fx/%s.png"
const PX := 0.0021          # metres per texture pixel

const EMOTES := {
	"!": "exclaim", "!!": "exclaim", "?": "question", "!?": "question", "?!": "question",
	"…": "dots", "...": "dots", "♥": "heart", "<3": "heart", "#@$%!": "grawlix",
	"*": "star", "✓": "sparkle", "~": "sweat", "anger": "anger",
}

static var _tex: Dictionary = {}

var _ember_sources: Dictionary = {}   # Node3D -> accumulated time
var _brawl: Node3D
var _brawl_t := 0.0
var _brawl_spawn := 0.0
var _brawl_limbs: Array = []
var _limb: Sprite3D


static func tex(n: String) -> Texture2D:
	if not _tex.has(n):
		var path := DIR % n
		_tex[n] = load(path) if ResourceLoader.exists(path) else null
	return _tex[n]


func make_sprite(n: String, pos: Vector3, size := 1.0) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex(n)
	s.pixel_size = PX * size
	s.shaded = false
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.no_depth_test = true
	s.render_priority = 6
	s.position = pos
	add_child(s)
	return s


## A reaction symbol popping above a puppet's head.
func emote(puppet: Node3D, text: String) -> void:
	var kind: String = EMOTES.get(text, "exclaim")
	var top: Vector3 = puppet.head_top() if puppet.has_method("head_top") else puppet.global_position + Vector3(0, 2.0, 0)
	pop(kind, top + Vector3(0.28, 0.05, 0.1), 1.0, 1.5)
	if text == "!!":
		pop(kind, top + Vector3(0.05, 0.12, 0.1), 0.85, 1.5)


func pop(kind: String, pos: Vector3, size := 1.0, life := 1.4) -> Sprite3D:
	var s := make_sprite(kind, pos, size)
	s.scale = Vector3.ONE * 0.1
	s.rotation.z = randf_range(-0.25, 0.25)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "position:y", pos.y + 0.12, 0.22)
	tw.tween_property(s, "rotation:z", -s.rotation.z, life * 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "modulate:a", 0.0, 0.25)
	tw.tween_callback(s.queue_free)
	Audio.sfx("pop", -12.0, 1.3, 0.15)
	return s


## Confetti-style burst: hearts and sparkles for cake, stars for brawls...
func burst(pos: Vector3, kinds: Array, count := 10, spread := 0.9, up := 1.3, life := 1.3) -> void:
	for i in count:
		var s := make_sprite(kinds[i % kinds.size()], pos, randf_range(0.55, 0.95))
		s.scale = Vector3.ONE * 0.2
		var target := pos + Vector3(randf_range(-spread, spread), randf_range(up * 0.4, up), randf_range(0.0, 0.3))
		var tw := create_tween().set_parallel(true)
		tw.tween_property(s, "position", target, life * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(i * 0.03)
		tw.tween_property(s, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.03)
		tw.tween_property(s, "rotation:z", randf_range(-1.5, 1.5), life)
		tw.tween_property(s, "modulate:a", 0.0, 0.35).set_delay(life * 0.7)
		tw.chain().tween_callback(s.queue_free)


## Continuous illustrated embers rising from `source` (the escalation phone).
func set_embers(source: Node3D, on: bool) -> void:
	if on:
		_ember_sources[source] = 0.0
	else:
		_ember_sources.erase(source)


func _process(delta: float) -> void:
	for src in _ember_sources.keys():
		if not is_instance_valid(src):
			_ember_sources.erase(src)
			continue
		_ember_sources[src] += delta
		if _ember_sources[src] > 0.09:
			_ember_sources[src] = 0.0
			var start: Vector3 = src.global_position + Vector3(randf_range(-0.12, 0.12), 0.05, 0.05)
			var e := make_sprite("ember", start, randf_range(0.35, 0.6))
			var tw := create_tween().set_parallel(true)
			tw.tween_property(e, "position", start + Vector3(randf_range(-0.25, 0.25), randf_range(0.5, 0.9), 0), 0.9)
			tw.tween_property(e, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
			tw.tween_property(e, "scale", Vector3.ONE * 0.3, 0.9)
			tw.chain().tween_callback(e.queue_free)
	if _brawl:
		_update_brawl(delta)


# ================================================================== brawl

func start_brawl(center: Vector3, puppets: Array) -> void:
	stop_brawl([])
	_brawl = Node3D.new()
	_brawl.position = center
	add_child(_brawl)
	_brawl_limbs.clear()
	for p in puppets:
		p.visible = false
		if p.has_method("arm_texture"):
			_brawl_limbs.append(p.arm_texture())
	for i in 7:
		var puff := Sprite3D.new()
		puff.texture = tex("puff")
		puff.pixel_size = PX * randf_range(1.2, 1.6)
		puff.shaded = false
		puff.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		var a := TAU * i / 7.0
		puff.position = Vector3(cos(a) * 0.45, 0.85 + sin(a) * 0.35, 0.02 * i)
		puff.set_meta("phase", randf() * TAU)
		puff.set_meta("base", puff.position)
		_brawl.add_child(puff)
	_limb = Sprite3D.new()
	_limb.pixel_size = PuppetData.UNIT / 0.75
	_limb.shaded = false
	_limb.visible = false
	_brawl.add_child(_limb)
	_brawl.scale = Vector3.ONE * 0.2
	create_tween().tween_property(_brawl, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_brawl_t = 0.0
	Audio.sfx("whoosh", -2.0, 0.8)


func grow_brawl() -> void:
	if _brawl:
		create_tween().tween_property(_brawl, "scale", Vector3.ONE * 1.35, 0.3).set_trans(Tween.TRANS_BACK)


func stop_brawl(puppets: Array) -> void:
	if _brawl == null:
		return
	var c := _brawl.global_position
	_brawl.queue_free()
	_brawl = null
	for p in puppets:
		p.visible = true
	burst(c + Vector3(0, 0.9, 0), ["puff", "star"], 8, 1.2, 0.8, 0.8)


func _update_brawl(delta: float) -> void:
	_brawl_t += delta
	var t := _brawl_t
	# the whole cloud bounces about like a tumble-dryer full of managers
	_brawl.position.x += sin(t * 2.3) * delta * 0.9
	_brawl.position.y = absf(sin(t * 6.5)) * 0.18
	_brawl.rotation.z = sin(t * 3.1) * 0.08
	for c in _brawl.get_children():
		if c == _limb:
			continue
		var ph: float = c.get_meta("phase")
		var base: Vector3 = c.get_meta("base")
		var s := 1.0 + 0.18 * sin(t * 9.0 + ph)
		c.scale = Vector3(s, s, 1.0)
		c.position = base + Vector3(sin(t * 7.0 + ph) * 0.05, cos(t * 8.0 + ph) * 0.05, 0)
	_brawl_spawn -= delta
	if _brawl_spawn <= 0.0:
		_brawl_spawn = randf_range(0.1, 0.2)
		var kind: String = ["grawlix", "star", "exclaim", "question", "anger", "star", "sweat"][randi() % 7]
		burst(_brawl.global_position + Vector3(randf_range(-0.3, 0.3), 1.0, 0.25), [kind], 1, 1.1, 1.1, 0.9)
		Audio.sfx(["bonk", "pop", "boing", "whoosh"][randi() % 4], -8.0, 1.0, 0.25)
	# an arm occasionally pokes out of the cloud
	if not _brawl_limbs.is_empty() and randf() < delta * 2.5:
		_limb.texture = _brawl_limbs[randi() % _brawl_limbs.size()]
		var side := -1.0 if randf() < 0.5 else 1.0
		_limb.position = Vector3(side * 0.75, 0.9 + randf_range(-0.2, 0.3), 0.3)
		_limb.rotation.z = side * PI * 0.5
		_limb.visible = true
		get_tree().create_timer(0.18).timeout.connect(_hide_limb)


func _hide_limb() -> void:
	if is_instance_valid(_limb):
		_limb.visible = false
