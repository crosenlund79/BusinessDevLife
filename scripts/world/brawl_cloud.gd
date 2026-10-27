class_name BrawlCloud
extends Node3D
## The classic cartoon dust-cloud fight. Characters vanish into a bouncing
## cloud; corporate grawlix, stars, limbs and office supplies fly out.
## Nobody gets hurt. Several people get emotionally audited.

const PUFF_COUNT := 16

var font: Font
var words: Array = ["#@$%!", "!!", "?!", "KPI!", "ROI?!", "ASAP!!", "EOD!", "BONK", "@#!", "SYNERGY!", "%&*!", "SCOPE!", "!?!"]
var running := false
var intensity := 1.0
var _t := 0.0
var _spawn_t := 0.0
var _sfx_t := 0.0
var _limb_t := 0.0
var _center := Vector3.ZERO
var _puffs: Array[MeshInstance3D] = []
var _phases: Array[float] = []
var _flyers: Array = []   # {node, vel, spin, life, land}
var _cloud: Node3D
var _limb: MeshInstance3D
var _skin_cols: Array = []


func start(center: Vector3, skin_colors: Array) -> void:
	_center = center
	_skin_cols = skin_colors
	position = center
	_cloud = Node3D.new()
	add_child(_cloud)
	var mats := [Mats.soft(Color(0.98, 0.96, 0.92), 0.95, 0.5), Mats.soft(Color(0.9, 0.88, 0.84), 0.95, 0.5), Mats.soft(Color(1.0, 0.94, 0.85), 0.95, 0.5)]
	for i in PUFF_COUNT:
		var p := MeshInstance3D.new()
		p.mesh = MeshLib.sphere(0.42, 20)
		p.material_override = mats[i % 3]
		var a := TAU * i / PUFF_COUNT
		var ring := 0.55 + (i % 3) * 0.25
		p.position = Vector3(cos(a) * ring, 0.6 + (i % 4) * 0.28, sin(a) * ring * 0.7)
		_cloud.add_child(p)
		_puffs.append(p)
		_phases.append(randf() * TAU)
	_limb = MeshInstance3D.new()
	_limb.mesh = MeshLib.capsule(0.07, 0.6)
	_limb.visible = false
	_cloud.add_child(_limb)
	running = true
	scale = Vector3.ONE * 0.1
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func stop() -> void:
	running = false
	var tw := create_tween()
	tw.tween_property(_cloud, "scale", Vector3.ONE * 1.35, 0.12)
	tw.tween_property(_cloud, "scale", Vector3.ONE * 0.01, 0.25)
	tw.tween_callback(_cloud.queue_free)


func _process(delta: float) -> void:
	_t += delta
	if running:
		# bounce around like a tumble-dryer full of managers
		_cloud.position = Vector3(sin(_t * 2.1) * 0.9, absf(sin(_t * 6.5)) * 0.35, cos(_t * 1.6) * 0.5)
		_cloud.rotation.y = sin(_t * 1.3) * 0.4
		for i in _puffs.size():
			var ph := _phases[i]
			var s := 1.0 + 0.28 * sin(_t * (5.0 + i % 4) + ph)
			_puffs[i].scale = Vector3(s, s * 0.9, s)
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_t = randf_range(0.07, 0.16) / intensity
			if randf() < 0.55:
				_spawn_word()
			elif randf() < 0.75:
				_spawn_star()
			else:
				_spawn_prop()
		_sfx_t -= delta
		if _sfx_t <= 0.0:
			_sfx_t = randf_range(0.12, 0.3)
			Audio.sfx(["bonk", "pop", "whoosh", "boing"][randi() % 4], -6.0, 1.0, 0.25)
		_limb_t -= delta
		if _limb_t <= 0.0:
			_limb_t = randf_range(0.25, 0.6)
			_poke_limb()
	_update_flyers(delta)


func _poke_limb() -> void:
	var a := randf() * TAU
	_limb.visible = true
	var col: Color = _skin_cols[randi() % _skin_cols.size()] if not _skin_cols.is_empty() else Color("f0c4a0")
	_limb.material_override = Mats.soft(col, 0.7, 0.3)
	_limb.position = Vector3(cos(a) * 1.1, 0.9 + randf_range(-0.3, 0.4), sin(a) * 0.8)
	_limb.rotation = Vector3(0, -a, PI * 0.5)
	get_tree().create_timer(0.16).timeout.connect(_hide_limb)


func _hide_limb() -> void:
	if is_instance_valid(_limb):
		_limb.visible = false


func _spawn_word() -> void:
	var l := Label3D.new()
	l.text = words[randi() % words.size()]
	l.font = font
	l.font_size = randi_range(56, 96)
	l.outline_size = 18
	l.modulate = [Color("ffb627"), Color("e85d5d"), Color("2bb3a3"), Color("fbfaf6"), Color("8a6cff")][randi() % 5]
	l.outline_modulate = Color("1d2230")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.004
	l.no_depth_test = true
	l.render_priority = 10
	l.outline_render_priority = 9
	_launch(l, 1.1, false)


func _spawn_star() -> void:
	var s := MeshInstance3D.new()
	s.mesh = MeshLib.star(0.16, 0.07, 0.07)
	s.material_override = Mats.emissive(Color("ffd23f"), 1.4)
	_launch(s, 1.0, false)


func _spawn_prop() -> void:
	var kinds := ["stapler", "shoe", "tie", "mug", "note", "pen"]
	var k: String = kinds[randi() % kinds.size()]
	var p := MeshInstance3D.new()
	match k:
		"stapler":
			p.mesh = MeshLib.rounded_box(Vector3(0.22, 0.07, 0.06), 0.02)
			p.material_override = Mats.glossy(Color("e85d5d"), 0.3)
		"shoe":
			p.mesh = MeshLib.rounded_box(Vector3(0.14, 0.09, 0.28), 0.04)
			p.material_override = Mats.glossy(Color("3b2a20"), 0.3)
		"tie":
			p.mesh = MeshLib.rounded_box(Vector3(0.07, 0.36, 0.02), 0.01)
			p.material_override = Mats.glossy(Color("c0392b"), 0.3)
		"mug":
			p.mesh = MeshLib.cylinder(0.045, 0.042, 0.11, 16)
			p.material_override = Mats.glossy(Color.WHITE, 0.2)
		"note":
			p.mesh = MeshLib.rounded_box(Vector3(0.12, 0.005, 0.12), 0.002)
			p.material_override = Mats.solid(Color("ffe066"), 0.9)
		_:
			p.mesh = MeshLib.capsule(0.012, 0.16)
			p.material_override = Mats.glossy(Color("2b5fae"), 0.3)
	_launch(p, 0.0, true)


func _launch(n: Node3D, life: float, lands: bool) -> void:
	add_child(n)
	var a := randf() * TAU
	n.position = _cloud.position + Vector3(cos(a) * 0.6, 1.0, sin(a) * 0.4)
	var vel := Vector3(cos(a) * randf_range(1.5, 3.5), randf_range(2.5, 5.0), sin(a) * randf_range(1.0, 2.5))
	_flyers.append({"node": n, "vel": vel, "spin": Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)), "life": life, "lands": lands, "age": 0.0})


func _update_flyers(delta: float) -> void:
	var keep: Array = []
	for f in _flyers:
		var n: Node3D = f["node"]
		if not is_instance_valid(n):
			continue
		f["age"] += delta
		var vel: Vector3 = f["vel"]
		if f["lands"]:
			if n.position.y > 0.05 or vel.y > 0.0:
				vel.y -= 9.8 * delta
				n.position += vel * delta
				n.rotation += f["spin"] * delta
				if n.position.y < 0.04:
					n.position.y = 0.04
					vel = Vector3.ZERO
					n.rotation = Vector3(0, n.rotation.y, 0)
			f["vel"] = vel
			keep.append(f)
		else:
			vel.y -= 4.0 * delta
			n.position += vel * delta
			f["vel"] = vel
			if n is MeshInstance3D:
				n.rotation += f["spin"] * delta
			var life: float = f["life"]
			var k: float = f["age"] / life
			if k >= 1.0:
				n.queue_free()
				continue
			var s := 1.0 - maxf(0.0, (k - 0.7) / 0.3)
			n.scale = Vector3.ONE * maxf(0.01, s)
			keep.append(f)
	_flyers = keep
