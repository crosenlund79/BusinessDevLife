class_name OfficeBuilder
extends RefCounted
## Builds the Northbound Consulting office out of art-directed procedural
## geometry. Layout (camera looks north, -Z):
##
##   z -10 ┌────────────┬──────────┬──────────┬──────────────┐ windows
##         │ Meeting rm │ War room │ Chad's   │ Server nook  │
##   z  -4 ├────────────┴──────────┴──────────┴──────────────┤ glass
##         │ Kitchen    │      Open-plan desks    │ Reception│
##   z   8 └──────────────────────────────────────┴───door───┘
##        x -15        -6         2          8               15

var root: Node3D
var nav: NavGrid
var font: Font
var interactables: Dictionary = {}
var screens: Dictionary = {}
var points: Dictionary = {}
var seats: Dictionary = {}
var props: Dictionary = {}


func build(parent: Node3D, grid: NavGrid, ui_font: Font) -> void:
	root = Node3D.new()
	root.name = "Office"
	parent.add_child(root)
	nav = grid
	font = ui_font
	_floors()
	_outer_walls()
	_partitions()
	_meeting_room()
	_war_room()
	_chad_office()
	_server_nook()
	_kitchen()
	_open_plan()
	_reception()
	_lights()


# ======================================================================= helpers

func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, radius := 0.03, rot_y := 0.0, block := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshLib.rounded_box(size, radius, 2 if radius < 0.05 else 3)
	mi.position = pos
	mi.rotation.y = rot_y
	mi.material_override = mat
	parent.add_child(mi)
	if block:
		var foot := Vector2(size.x, size.z)
		if absf(sin(rot_y)) > 0.7:
			foot = Vector2(size.z, size.x)
		nav.block_rect(parent.global_transform * pos if parent.is_inside_tree() else pos, foot)
	return mi


func mesh(parent: Node3D, m: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func node(parent: Node3D, n: String, pos := Vector3.ZERO, rot_y := 0.0) -> Node3D:
	var nd := Node3D.new()
	nd.name = n
	nd.position = pos
	nd.rotation.y = rot_y
	parent.add_child(nd)
	return nd


func label(parent: Node3D, text: String, pos: Vector3, size := 48, color := Color("24324a"), rot := Vector3.ZERO, px := 0.004, outline := 0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size
	l.modulate = color
	l.outline_size = outline
	l.outline_modulate = Color(1, 1, 1, 0.9)
	l.pixel_size = px
	l.position = pos
	l.rotation = rot
	l.double_sided = false
	l.shaded = false
	parent.add_child(l)
	return l


func screen(parent: Node3D, screen_id: String, px_size: Vector2i, quad_size: Vector2, pos: Vector3, rot: Vector3, spec: Dictionary) -> ScreenContent:
	var vp := SubViewport.new()
	vp.size = px_size
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(vp)
	var content := ScreenContent.new()
	content.size = Vector2(px_size)
	content.font = font
	content.bold = font
	vp.add_child(content)
	content.show_spec(spec)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshLib.quad(quad_size)
	mi.position = pos
	mi.rotation = rot
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = vp.get_texture()
	mat.emission_enabled = true
	mat.emission_texture = vp.get_texture()
	mat.emission = Color.WHITE
	mat.emission_energy_multiplier = 0.35
	mat.roughness = 0.3
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	screens[screen_id] = content
	return content


func interact(obj_id: String, label_key: String, center: Vector3, size: Vector3, approach: Vector3) -> Interactable:
	var it := Interactable.create(root, obj_id, label_key, center, size, approach)
	interactables[obj_id] = it
	return it


func plant(pos: Vector3, tall := 1.0, leafy := true) -> Node3D:
	var p := node(root, "Plant", pos)
	var pot_col: Color = [Mats.TERRACOTTA, Mats.CREAM, Color("e9e2d4"), Mats.NAVY_LIGHT][int(absf(pos.x * 7.0 + pos.z * 3.0)) % 4]
	mesh(p, MeshLib.cylinder(0.26 * tall, 0.2 * tall, 0.5 * tall), Vector3(0, 0.25 * tall, 0), Mats.glossy(pot_col, 0.4))
	mesh(p, MeshLib.cylinder(0.24 * tall, 0.24 * tall, 0.02), Vector3(0, 0.49 * tall, 0), Mats.solid(Color("4a3426"), 0.9))
	if leafy:
		var leaves := [Mats.soft(Mats.LEAF, 0.6, 0.2), Mats.soft(Mats.LEAF_DARK, 0.6, 0.2), Mats.soft(Mats.LEAF_LIGHT, 0.6, 0.2)]
		var n := 9
		for i in n:
			var a := TAU * float(i) / n + pos.x
			var lift := 0.55 + (i % 3) * 0.22
			var leaf := mesh(p, MeshLib.sphere(0.2 * tall, 16), Vector3(cos(a) * 0.22 * tall, (0.5 + lift) * tall, sin(a) * 0.22 * tall), leaves[i % 3])
			leaf.scale = Vector3(0.55, 0.16, 1.25)
			leaf.rotation = Vector3(-0.45 - (i % 2) * 0.3, PI * 0.5 - a, 0.0)
		mesh(p, MeshLib.sphere(0.2 * tall, 16), Vector3(0, 1.05 * tall, 0), leaves[0], Vector3.ZERO, Vector3(1.0, 0.9, 1.0))
	else:
		# ficus: trunk + leafy clusters
		mesh(p, MeshLib.cylinder(0.03, 0.05, 1.3 * tall), Vector3(0, 1.1 * tall, 0), Mats.solid(Mats.WOOD_DARK, 0.8))
		for i in 6:
			var a := TAU * float(i) / 6.0
			mesh(p, MeshLib.sphere(0.28 * tall, 16), Vector3(cos(a) * 0.22, (1.5 + (i % 2) * 0.3) * tall, sin(a) * 0.22), Mats.soft([Mats.LEAF, Mats.LEAF_DARK, Mats.LEAF_LIGHT][i % 3], 0.65, 0.2))
	nav.block_rect(pos, Vector2(0.5, 0.5) * tall)
	return p


func chair(pos: Vector3, yaw: float, color := Mats.NAVY) -> Node3D:
	var c := node(root, "Chair", pos, yaw)
	var fabric := Mats.soft(color, 0.9, 0.1)
	var dark := Mats.glossy(Mats.CHARCOAL, 0.4)
	box(c, Vector3(0.5, 0.1, 0.48), Vector3(0, 0.48, 0), fabric, 0.045)
	box(c, Vector3(0.48, 0.55, 0.08), Vector3(0, 0.85, -0.23), fabric, 0.04)
	mesh(c, MeshLib.cylinder(0.03, 0.03, 0.36), Vector3(0, 0.26, 0), dark)
	for i in 5:
		var a := TAU * i / 5.0
		var leg := mesh(c, MeshLib.capsule(0.022, 0.32), Vector3(cos(a) * 0.14, 0.07, sin(a) * 0.14), dark)
		leg.rotation = Vector3(0, -a, PI * 0.5)
		mesh(c, MeshLib.sphere(0.035, 10), Vector3(cos(a) * 0.28, 0.035, sin(a) * 0.28), dark)
	return c


func monitor(parent: Node3D, pos: Vector3, yaw: float, spec: Dictionary, screen_id := "", w := 0.6) -> void:
	var m := node(parent, "Monitor", pos, yaw)
	var dark := Mats.glossy(Mats.CHARCOAL, 0.3)
	box(m, Vector3(0.18, 0.015, 0.14), Vector3(0, 0.008, 0), dark, 0.006)
	box(m, Vector3(0.035, 0.26, 0.03), Vector3(0, 0.14, -0.02), dark, 0.01)
	box(m, Vector3(w, w * 0.6, 0.035), Vector3(0, 0.36, 0), dark, 0.012)
	if screen_id != "":
		screen(m, screen_id, Vector2i(480, 290), Vector2(w - 0.04, w * 0.6 - 0.04), Vector3(0, 0.36, 0.019), Vector3.ZERO, spec)
	else:
		var col := Color(str(spec.get("color", "#4aa8ff")))
		mesh(m, MeshLib.quad(Vector2(w - 0.04, w * 0.6 - 0.04)), Vector3(0, 0.36, 0.019), Mats.emissive(col, 0.9))


func desk(center: Vector3, faces_south: bool, top_col := Mats.WOOD_LIGHT) -> Node3D:
	# The sitter sits on the far side and faces the desk.
	var yaw := 0.0 if faces_south else PI
	var d := node(root, "Desk", center, yaw)
	var top := Mats.solid(top_col, 0.45)
	var frame := Mats.glossy(Mats.WHITE, 0.3)
	box(d, Vector3(1.5, 0.05, 0.75), Vector3(0, 0.74, 0), top, 0.02)
	for sx in [-0.68, 0.68]:
		box(d, Vector3(0.05, 0.72, 0.6), Vector3(sx, 0.36, 0), frame, 0.02)
	box(d, Vector3(1.3, 0.3, 0.02), Vector3(0, 0.55, 0.3), frame, 0.008)
	# drawer pedestal
	box(d, Vector3(0.4, 0.58, 0.55), Vector3(0.45, 0.29, 0.0), Mats.glossy(Color("eef0f2"), 0.35), 0.03)
	box(d, Vector3(0.12, 0.02, 0.02), Vector3(0.45, 0.48, 0.285), Mats.solid(Mats.STEEL, 0.3, 0.6), 0.005)
	box(d, Vector3(0.12, 0.02, 0.02), Vector3(0.45, 0.28, 0.285), Mats.solid(Mats.STEEL, 0.3, 0.6), 0.005)
	nav.block_rect(center, Vector2(1.5, 0.75), 0.05)
	return d


# ======================================================================= structure

func _floors() -> void:
	var wood := Mats.shader_material("wood_floor", Mats.WOOD_FLOOR_SHADER)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(30, 18)
	mesh(root, floor_mesh, Vector3(0, 0, -1), wood)
	# ground beyond the office, so the cutaway never shows the void
	var ground := PlaneMesh.new()
	ground.size = Vector2(120, 80)
	mesh(root, ground, Vector3(0, -0.06, 0), Mats.solid(Color("e8dcc6"), 0.95))
	# meeting room carpet
	var carpet := Mats.shader_material("carpet", Mats.CARPET_SHADER)
	_floor_patch(Vector2(-10.5, -7.0), Vector2(9.0, 6.0), carpet)
	# kitchen tiles
	var tiles := Mats.shader_material("carpet", Mats.CARPET_SHADER)
	tiles.set_shader_parameter("color_a", Color("f3ead8"))
	tiles.set_shader_parameter("color_b", Color("e3d6bd"))
	tiles.set_shader_parameter("tile_size", 0.6)
	tiles.set_shader_parameter("rough", 0.35)
	_floor_patch(Vector2(-11.0, 2.0), Vector2(8.0, 12.0), tiles)
	# server nook
	var raised := Mats.shader_material("carpet", Mats.CARPET_SHADER)
	raised.set_shader_parameter("color_a", Color("c9ced6"))
	raised.set_shader_parameter("color_b", Color("bfc5ce"))
	raised.set_shader_parameter("tile_size", 0.6)
	raised.set_shader_parameter("rough", 0.5)
	_floor_patch(Vector2(11.5, -7.0), Vector2(7.0, 6.0), raised)
	# war room
	var war := Mats.shader_material("carpet", Mats.CARPET_SHADER)
	war.set_shader_parameter("color_a", Color("6b4a3a"))
	war.set_shader_parameter("color_b", Color("72503f"))
	_floor_patch(Vector2(-2.0, -7.0), Vector2(8.0, 6.0), war)
	# reception rug
	mesh(root, MeshLib.cylinder(2.0, 2.0, 0.02, 48), Vector3(12.6, 0.01, 5.0), Mats.soft(Color("2bb3a3"), 0.95, 0.0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	mesh(root, MeshLib.cylinder(1.7, 1.7, 0.022, 48), Vector3(12.6, 0.012, 5.0), Mats.soft(Color("f6eedf"), 0.95, 0.0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	# open plan rug under the desks
	_floor_patch(Vector2(0.0, 1.6), Vector2(12.0, 4.6), Mats.soft(Color("d9cdb7"), 0.95, 0.0))


func _floor_patch(c: Vector2, size: Vector2, mat: Material) -> void:
	var m := PlaneMesh.new()
	m.size = size
	mesh(root, m, Vector3(c.x, 0.006, c.y), mat)


func _outer_walls() -> void:
	var wall := Mats.solid(Mats.WALL, 0.85)
	var trim := Mats.solid(Color("dccfb8"), 0.7)
	var frame := Mats.glossy(Mats.CHARCOAL, 0.35)
	# North: floor-to-ceiling windows with the city behind.
	box(root, Vector3(30.4, 0.6, 0.3), Vector3(0, 0.3, -10.15), wall, 0.04)
	box(root, Vector3(30.4, 0.5, 0.3), Vector3(0, 3.25, -10.15), wall, 0.04)
	var x := -15.0
	while x <= 15.01:
		box(root, Vector3(0.12, 2.5, 0.16), Vector3(x, 1.85, -10.1), frame, 0.03)
		x += 2.5
	box(root, Vector3(30.2, 0.06, 0.12), Vector3(0, 1.0, -10.08), frame, 0.02)
	var glass := mesh(root, MeshLib.quad(Vector2(30.0, 2.4)), Vector3(0, 1.85, -10.05), Mats.glass())
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sky := Mats.shader_material("skyline", Mats.SKYLINE_SHADER)
	var city := mesh(root, MeshLib.quad(Vector2(36.0, 3.6)), Vector3(0, 1.75, -10.6), sky)
	city.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nav.block_rect(Vector3(0, 0, -10.0), Vector2(30.5, 0.4), 0.0)
	# West and east walls (full height), skirting trim.
	box(root, Vector3(0.3, 3.5, 18.4), Vector3(-15.15, 1.75, -1.0), wall, 0.04)
	box(root, Vector3(0.3, 3.5, 18.4), Vector3(15.15, 1.75, -1.0), wall, 0.04)
	box(root, Vector3(0.06, 0.12, 18.0), Vector3(-14.98, 0.06, -1.0), trim, 0.02)
	box(root, Vector3(0.06, 0.12, 18.0), Vector3(14.98, 0.06, -1.0), trim, 0.02)
	nav.block_rect(Vector3(-15.0, 0, -1.0), Vector2(0.4, 18.5), 0.0)
	nav.block_rect(Vector3(15.0, 0, -1.0), Vector2(0.4, 18.5), 0.0)
	# South: cutaway half-wall with the entrance gap (x 10..12).
	box(root, Vector3(25.0, 0.45, 0.25), Vector3(-2.5, 0.225, 8.1), wall, 0.06)
	box(root, Vector3(3.0, 0.45, 0.25), Vector3(13.5, 0.225, 8.1), wall, 0.06)
	box(root, Vector3(25.0, 0.04, 0.3), Vector3(-2.5, 0.46, 8.1), Mats.solid(Mats.WOOD, 0.5), 0.015)
	box(root, Vector3(3.0, 0.04, 0.3), Vector3(13.5, 0.46, 8.1), Mats.solid(Mats.WOOD, 0.5), 0.015)
	nav.block_rect(Vector3(-2.5, 0, 8.1), Vector2(25.0, 0.4), 0.0)
	nav.block_rect(Vector3(13.5, 0, 8.1), Vector2(3.0, 0.4), 0.0)
	# entrance door frame + open sliding doors
	for dx in [9.95, 12.05]:
		box(root, Vector3(0.14, 2.6, 0.2), Vector3(dx, 1.3, 8.1), frame, 0.03)
	box(root, Vector3(2.3, 0.18, 0.22), Vector3(11.0, 2.6, 8.1), frame, 0.03)
	for dx in [9.3, 12.7]:
		var door := mesh(root, MeshLib.quad(Vector2(1.0, 2.4)), Vector3(dx, 1.25, 8.2), Mats.glass())
		door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# doormat
	box(root, Vector3(1.8, 0.02, 0.9), Vector3(11.0, 0.012, 7.35), Mats.soft(Color("3b3f48"), 0.95, 0.0), 0.01)
	label(root, Loc.t("world.doormat"), Vector3(11.0, 0.03, 7.35), 48, Color("f2b134"), Vector3(-PI * 0.5, 0, 0), 0.004)
	# framed art on the side walls (angled towards the camera a little)
	_art(Vector3(-14.95, 1.9, 2.5), PI * 0.5, Color("f28c28"), Loc.t("world.art_west"))
	_art(Vector3(14.95, 1.9, 4.5), -PI * 0.5, Color("2bb3a3"), Loc.t("world.art_east"))


func _art(pos: Vector3, yaw: float, col: Color, text: String) -> void:
	var a := node(root, "Art", pos, yaw)
	box(a, Vector3(1.6, 1.1, 0.05), Vector3.ZERO, Mats.solid(Mats.WOOD_DARK, 0.5), 0.02)
	box(a, Vector3(1.45, 0.95, 0.02), Vector3(0, 0, 0.02), Mats.solid(Color("fbf6ea"), 0.8), 0.01)
	mesh(a, MeshLib.sphere(0.25), Vector3(-0.3, 0.05, 0.03), Mats.solid(col, 0.6), Vector3.ZERO, Vector3(1, 1, 0.1))
	box(a, Vector3(0.5, 0.08, 0.02), Vector3(0.25, 0.2, 0.035), Mats.solid(Mats.NAVY, 0.6), 0.01)
	box(a, Vector3(0.4, 0.08, 0.02), Vector3(0.2, 0.0, 0.035), Mats.solid(Mats.MUSTARD, 0.6), 0.01)
	label(a, text, Vector3(0, -0.36, 0.04), 22, Mats.NAVY)


## Glass partition from a to b (axis aligned), with optional door gap [g0, g1].
func _glass_wall(a: Vector3, b: Vector3, gap := Vector2(INF, INF), height := 2.6) -> void:
	var frame := Mats.glossy(Color("d6dbe1"), 0.3)
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var start := a.x if along_x else a.z
	var end := b.x if along_x else b.z
	if start > end:
		var tmp := start
		start = end
		end = tmp
	var segments: Array = []
	if gap.x != INF:
		segments.append(Vector2(start, gap.x))
		segments.append(Vector2(gap.y, end))
	else:
		segments.append(Vector2(start, end))
	for seg in segments:
		var s0: float = seg.x
		var s1: float = seg.y
		var length := s1 - s0
		if length <= 0.05:
			continue
		var mid := (s0 + s1) * 0.5
		var c := Vector3(mid, 0, a.z) if along_x else Vector3(a.x, 0, mid)
		var rot := 0.0 if along_x else PI * 0.5
		var g := node(root, "Glass", c, rot)
		var pane := mesh(g, MeshLib.quad(Vector2(length, height - 0.1)), Vector3(0, height * 0.5, 0), Mats.glass())
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box(g, Vector3(length, 0.08, 0.08), Vector3(0, 0.04, 0), frame, 0.02)
		box(g, Vector3(length, 0.07, 0.08), Vector3(0, height, 0), frame, 0.02)
		# frosted privacy band
		mesh(g, MeshLib.quad(Vector2(length, 0.3)), Vector3(0, 1.35, 0.005), Mats.unshaded(Color(1, 1, 1, 0.35)))
		var p := s0
		while p <= s1 + 0.01:
			box(g, Vector3(0.06, height, 0.08), Vector3(p - mid, height * 0.5, 0), frame, 0.02)
			p += maxf(1.0, length / ceilf(length / 2.2))
		var foot := Vector2(length, 0.25) if along_x else Vector2(0.25, length)
		nav.block_rect(c, foot, 0.0)


func _partitions() -> void:
	_glass_wall(Vector3(-15, 0, -4), Vector3(-6, 0, -4), Vector2(-8.6, -7.2))
	_glass_wall(Vector3(-6, 0, -10), Vector3(-6, 0, -4))
	_glass_wall(Vector3(-6, 0, -4), Vector3(2, 0, -4), Vector2(-2.7, -1.3))
	_glass_wall(Vector3(2, 0, -10), Vector3(2, 0, -4))
	_glass_wall(Vector3(2, 0, -4), Vector3(8, 0, -4), Vector2(4.3, 5.7))
	_glass_wall(Vector3(8, 0, -10), Vector3(8, 0, -4))
	# room name plates on the glass, facing the open plan
	label(root, Loc.t("world.room_meeting"), Vector3(-10.5, 2.35, -3.95), 56, Mats.NAVY)
	label(root, Loc.t("world.room_war"), Vector3(-2.0, 2.35, -3.95), 56, Color("b03a2e"))
	label(root, Loc.t("world.room_chad"), Vector3(5.0, 2.35, -3.95), 48, Mats.NAVY)
	label(root, Loc.t("world.room_servers"), Vector3(11.5, 2.75, -9.0), 48, Color("2bb3a3"))
	points["meeting_door"] = Vector3(-7.9, 0, -3.2)
	points["war_door"] = Vector3(-2.0, 0, -3.2)
	points["chad_door"] = Vector3(5.0, 0, -3.2)


# ======================================================================= rooms

func _meeting_room() -> void:
	var table_c := Vector3(-10.5, 0, -7.0)
	var wood := Mats.solid(Mats.WOOD, 0.4)
	box(root, Vector3(4.4, 0.07, 1.6), table_c + Vector3(0, 0.75, 0), wood, 0.03)
	for sx in [-1.6, 1.6]:
		box(root, Vector3(0.12, 0.72, 1.0), table_c + Vector3(sx, 0.37, 0), Mats.glossy(Mats.CHARCOAL, 0.4), 0.03)
	nav.block_rect(table_c, Vector2(4.4, 1.6), 0.05)
	var seat_names := ["m_n1", "m_n2", "m_n3", "m_s1", "m_s2", "m_s3"]
	var xs := [-11.9, -10.5, -9.1]
	for i in 3:
		var pn := Vector3(xs[i], 0, -8.25)
		var ps := Vector3(xs[i], 0, -5.75)
		chair(pn, 0.0, Mats.NAVY)
		chair(ps, PI, Mats.NAVY)
		seats[seat_names[i]] = [pn, 0.0]
		seats[seat_names[i + 3]] = [ps, PI]
	# props on the table
	for i in 4:
		box(root, Vector3(0.3, 0.02, 0.22), table_c + Vector3(-1.4 + i * 0.9, 0.795, 0.3 - (i % 2) * 0.6), Mats.solid(Color.WHITE, 0.8), 0.005)
	mesh(root, MeshLib.cylinder(0.05, 0.04, 0.1), table_c + Vector3(0.6, 0.84, 0.15), Mats.glossy(Mats.CORAL, 0.3))
	# speakerphone (the conference starfish)
	var star := mesh(root, MeshLib.cylinder(0.16, 0.2, 0.05, 3), table_c + Vector3(0, 0.81, 0), Mats.glossy(Mats.CHARCOAL, 0.3))
	star.name = "Speakerphone"
	props["speakerphone"] = star
	# TV on a stand at the west end, angled to the room and the camera
	var tv := node(root, "TV", Vector3(-13.9, 0, -6.6), 1.0)
	box(tv, Vector3(0.5, 0.05, 0.5), Vector3(0, 0.025, 0), Mats.glossy(Mats.CHARCOAL, 0.4), 0.02)
	box(tv, Vector3(0.08, 1.2, 0.08), Vector3(0, 0.6, 0), Mats.glossy(Mats.CHARCOAL, 0.4), 0.02)
	box(tv, Vector3(2.0, 1.15, 0.07), Vector3(0, 1.6, 0), Mats.glossy(Color("1a1c22"), 0.25), 0.03)
	screen(tv, "meeting_tv", Vector2i(1024, 576), Vector2(1.9, 1.06), Vector3(0, 1.6, 0.037), Vector3.ZERO,
		{"kind": "slide", "kicker": Loc.t("screens.meeting_idle_kicker"), "title": Loc.t("screens.meeting_idle_title"), "subtitle": Loc.t("screens.meeting_idle_sub"), "accent": "#2bb3a3"})
	nav.block_rect(Vector3(-13.9, 0, -6.6), Vector2(1.2, 1.2), 0.0)
	points["meeting_present"] = Vector3(-13.0, 0, -5.6)
	points["meeting_player"] = Vector3(-8.0, 0, -5.2)
	interact("meeting_table", "hover.meeting", table_c, Vector3(4.4, 0.9, 1.6), Vector3(-8.0, 0, -5.2))
	plant(Vector3(-14.4, 0, -9.4), 1.1, false)
	plant(Vector3(-6.6, 0, -9.4), 0.9, true)


func _war_room() -> void:
	var specs := [
		{"id": "war_status", "x": -4.6, "spec": {"kind": "status", "title": Loc.t("screens.war_status_title"), "status": "green", "big": Loc.t("screens.war_status_big"), "caption": Loc.t("screens.war_status_caption"), "footnote": Loc.t("screens.war_status_foot"), "animated": true, "accent": "#2fae5c"}},
		{"id": "war_budget", "x": -2.0, "spec": {"kind": "bars", "title": Loc.t("screens.war_budget_title"), "values": [40, 85, 160, 290], "labels": [Loc.t("screens.q1"), Loc.t("screens.q2"), Loc.t("screens.q3"), Loc.t("screens.q4")], "budget": 120, "budget_label": Loc.t("screens.budget"), "note": Loc.t("screens.war_budget_note"), "accent": "#3d7be0"}},
		{"id": "war_margin", "x": 0.6, "spec": {"kind": "line", "title": Loc.t("screens.war_margin_title"), "values": [22, 14, 3, -9, -14], "labels": ["Jan", "Mar", "May", "Jul", "Sep"], "arrow_note": Loc.t("screens.war_margin_arrow"), "accent": "#e85d5d"}},
	]
	for s in specs:
		var pos := Vector3(float(s["x"]), 0, -8.7)
		var e := node(root, "Easel", pos, 0.0)
		var leg := Mats.solid(Mats.WOOD_DARK, 0.6)
		for lx in [-0.45, 0.45]:
			var l := mesh(e, MeshLib.capsule(0.03, 1.9), Vector3(lx, 0.95, 0.12), leg)
			l.rotation.x = -0.1
		var back := mesh(e, MeshLib.capsule(0.03, 1.9), Vector3(0, 0.95, -0.25), leg)
		back.rotation.x = 0.25
		box(e, Vector3(1.75, 1.2, 0.05), Vector3(0, 1.55, 0.12), Mats.glossy(Color.WHITE, 0.3), 0.025)
		screen(e, s["id"], Vector2i(900, 620), Vector2(1.65, 1.12), Vector3(0, 1.55, 0.15), Vector3(-0.08, 0, 0), s["spec"])
		nav.block_rect(pos, Vector2(1.6, 0.8), 0.0)
		interact(s["id"], "hover." + str(s["id"]), pos, Vector3(1.7, 2.2, 0.6), pos + Vector3(0, 0, 1.4))
	# risk register on a rolling whiteboard
	var rw := node(root, "RiskBoard", Vector3(-5.2, 0, -5.4), 0.85)
	box(rw, Vector3(1.6, 1.1, 0.05), Vector3(0, 1.45, 0), Mats.glossy(Color.WHITE, 0.3), 0.03)
	for lx in [-0.72, 0.72]:
		box(rw, Vector3(0.05, 1.4, 0.05), Vector3(lx, 0.7, 0), Mats.solid(Mats.STEEL, 0.3, 0.6), 0.015)
		box(rw, Vector3(0.06, 0.04, 0.6), Vector3(lx, 0.05, 0), Mats.solid(Mats.STEEL, 0.3, 0.6), 0.015)
	screen(rw, "war_risk", Vector2i(900, 620), Vector2(1.52, 1.03), Vector3(0, 1.45, 0.03), Vector3.ZERO,
		{"kind": "risk", "title": Loc.t("screens.risk_title"), "accent": "#e85d5d", "rows": [
			{"text": Loc.t("screens.risk_1"), "sev": "high"},
			{"text": Loc.t("screens.risk_2"), "sev": "high"},
			{"text": Loc.t("screens.risk_3"), "sev": "low"},
			{"text": Loc.t("screens.risk_4"), "sev": "med"},
			{"text": Loc.t("screens.risk_5"), "sev": "high"},
		]})
	nav.block_rect(Vector3(-5.2, 0, -5.4), Vector2(1.2, 1.2), 0.0)
	interact("war_risk", "hover.war_risk", Vector3(-5.2, 0, -5.4), Vector3(1.6, 2.0, 0.6), Vector3(-4.3, 0, -4.7))
	# high table in the middle
	var ht := Vector3(-1.6, 0, -6.3)
	mesh(root, MeshLib.cylinder(0.55, 0.55, 0.05, 32), ht + Vector3(0, 1.05, 0), Mats.solid(Mats.WOOD, 0.4))
	mesh(root, MeshLib.cylinder(0.05, 0.05, 1.0), ht + Vector3(0, 0.52, 0), Mats.glossy(Mats.CHARCOAL, 0.4))
	mesh(root, MeshLib.cylinder(0.3, 0.32, 0.03, 24), ht + Vector3(0, 0.015, 0), Mats.glossy(Mats.CHARCOAL, 0.4))
	nav.block_rect(ht, Vector2(1.0, 1.0), 0.0)
	points["war_center"] = Vector3(-2.0, 0, -5.4)
	for i in 5:
		points["war_spot_%d" % i] = Vector3(-4.0 + i * 1.1, 0, -7.4 + (i % 2) * 0.5)


func _chad_office() -> void:
	var dc := Vector3(5.0, 0, -7.6)
	var dark_wood := Mats.glossy(Color("5b3a26"), 0.25)
	box(root, Vector3(2.2, 0.08, 0.95), dc + Vector3(0, 0.76, 0), dark_wood, 0.03)
	box(root, Vector3(2.1, 0.7, 0.08), dc + Vector3(0, 0.38, 0.38), dark_wood, 0.02)
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.08, 0.72, 0.85), dc + Vector3(sx * 1.0, 0.37, 0), dark_wood, 0.02)
	nav.block_rect(dc, Vector2(2.2, 0.95), 0.05)
	# the executive chair (taller, leather)
	var c := chair(dc + Vector3(0, 0, -0.95), 0.0, Color("3a2a22"))
	c.scale = Vector3(1.15, 1.25, 1.15)
	seats["chad_desk"] = [dc + Vector3(0, 0, -0.95), 0.0]
	monitor(root, dc + Vector3(-0.35, 0.8, -0.15), PI, {"color": "#7fd1ff"}, "", 0.75)
	# desk props: trophy, nameplate, tiny zen garden
	var trophy := node(root, "Trophy", dc + Vector3(0.75, 0.8, 0.1))
	mesh(trophy, MeshLib.cylinder(0.07, 0.09, 0.06), Vector3(0, 0.03, 0), Mats.solid(Mats.CHARCOAL, 0.4))
	mesh(trophy, MeshLib.cylinder(0.025, 0.025, 0.14), Vector3(0, 0.13, 0), Mats.glossy(Color("f2b134"), 0.15))
	mesh(trophy, MeshLib.cylinder(0.1, 0.03, 0.12), Vector3(0, 0.26, 0), Mats.glossy(Color("f2b134"), 0.15))
	label(root, Loc.t("world.trophy"), dc + Vector3(0.75, 0.88, 0.2), 18, Mats.NAVY, Vector3(-0.5, 0, 0), 0.0035)
	box(root, Vector3(0.5, 0.08, 0.06), dc + Vector3(0.0, 0.84, 0.42), Mats.glossy(Color("f2b134"), 0.2), 0.02)
	label(root, Loc.t("world.chad_nameplate"), dc + Vector3(0.0, 0.84, 0.455), 16, Mats.NAVY, Vector3.ZERO, 0.0032)
	interact("trophy", "hover.trophy", dc + Vector3(0.75, 0.75, 0.1), Vector3(0.4, 0.5, 0.4), dc + Vector3(1.4, 0, 1.0))
	# guest chairs
	chair(dc + Vector3(-0.6, 0, 1.15), PI, Mats.CORAL)
	chair(dc + Vector3(0.6, 0, 1.15), PI, Mats.CORAL)
	# inspirational poster on a floor frame and the yacht photo
	var poster := node(root, "Poster", Vector3(2.7, 0, -9.3), 0.6)
	box(poster, Vector3(1.2, 1.7, 0.06), Vector3(0, 1.25, 0), Mats.solid(Color("1b2433"), 0.4), 0.02)
	box(poster, Vector3(1.05, 1.0, 0.02), Vector3(0, 1.45, 0.03), Mats.solid(Color("ff9a3c"), 0.6), 0.01)
	mesh(poster, MeshLib.sphere(0.22), Vector3(0, 1.38, 0.04), Mats.emissive(Color("ffe08a"), 0.6), Vector3.ZERO, Vector3(1, 1, 0.1))
	box(poster, Vector3(1.05, 0.25, 0.02), Vector3(0, 1.1, 0.035), Mats.solid(Color("2b3a55"), 0.6), 0.01)
	label(poster, Loc.t("world.poster_title"), Vector3(0, 0.78, 0.04), 40, Color.WHITE)
	label(poster, Loc.t("world.poster_sub"), Vector3(0, 0.58, 0.04), 12, Color("ffd9a8"))
	nav.block_rect(Vector3(2.7, 0, -9.3), Vector2(1.0, 0.6), 0.0)
	interact("poster", "hover.poster", Vector3(2.7, 0, -9.3), Vector3(1.2, 2.2, 0.4), Vector3(3.4, 0, -8.2))
	var yacht := node(root, "Yacht", dc + Vector3(-0.8, 0.8, 0.05), -0.3)
	box(yacht, Vector3(0.36, 0.28, 0.03), Vector3(0, 0.14, 0), Mats.glossy(Color("f2b134"), 0.2), 0.01)
	box(yacht, Vector3(0.3, 0.22, 0.02), Vector3(0, 0.14, 0.012), Mats.solid(Color("8fc7f2"), 0.5), 0.005)
	box(yacht, Vector3(0.2, 0.04, 0.01), Vector3(0, 0.07, 0.025), Mats.solid(Color.WHITE, 0.5), 0.005)
	box(yacht, Vector3(0.015, 0.12, 0.01), Vector3(0.01, 0.15, 0.025), Mats.solid(Color.WHITE, 0.5), 0.003)
	interact("yacht", "hover.yacht", dc + Vector3(-0.8, 0.75, 0.05), Vector3(0.45, 0.5, 0.4), dc + Vector3(-1.5, 0, 1.0))
	# putting green
	box(root, Vector3(0.6, 0.02, 2.8), Vector3(7.2, 0.012, -6.6), Mats.soft(Color("4caf50"), 0.95, 0.0), 0.01, 0.4)
	mesh(root, MeshLib.sphere(0.03, 12), Vector3(7.0, 0.04, -5.6), Mats.glossy(Color.WHITE, 0.2))
	mesh(root, MeshLib.cylinder(0.006, 0.006, 0.55, 6), Vector3(7.6, 0.28, -7.7), Mats.solid(Mats.STEEL, 0.3, 0.6))
	box(root, Vector3(0.18, 0.12, 0.01), Vector3(7.69, 0.5, -7.7), Mats.solid(Mats.CORAL, 0.6), 0.005)
	interact("golf", "hover.golf", Vector3(7.2, 0, -6.6), Vector3(0.8, 0.3, 2.6), Vector3(6.4, 0, -5.4))
	plant(Vector3(7.4, 0, -9.4), 1.0, false)


func _server_nook() -> void:
	var rack_mat := Mats.glossy(Color("23262d"), 0.3)
	for i in 4:
		var x := 9.3 + i * 1.25
		var r := node(root, "Rack", Vector3(x, 0, -9.35))
		box(r, Vector3(1.05, 2.25, 0.95), Vector3(0, 1.125, 0), rack_mat, 0.03)
		var leds := Mats.shader_material("leds", Mats.LED_SHADER)
		leds.set_shader_parameter("seed", float(i) * 13.0)
		var panel := mesh(r, MeshLib.quad(Vector2(0.85, 1.9)), Vector3(0, 1.15, 0.48), leds)
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for k in 5:
			box(r, Vector3(0.95, 0.02, 0.02), Vector3(0, 0.3 + k * 0.42, 0.485), Mats.solid(Mats.STEEL, 0.3, 0.6), 0.005)
		nav.block_rect(Vector3(x, 0, -9.35), Vector2(1.05, 0.95), 0.05)
	# the sign
	var sign_node := node(root, "Sign", Vector3(11.2, 2.35, -8.85))
	box(sign_node, Vector3(2.2, 0.36, 0.03), Vector3.ZERO, Mats.solid(Mats.MUSTARD, 0.6), 0.02)
	label(sign_node, Loc.t("world.network_sign"), Vector3(0, 0, 0.02), 48, Mats.CHARCOAL, Vector3.ZERO, 0.0035)
	interact("servers", "hover.servers", Vector3(11.2, 0, -9.35), Vector3(5.0, 2.3, 1.0), Vector3(11.2, 0, -8.0))
	# Bogdan's desk with a wall of monitors
	var dc := Vector3(11.6, 0, -6.4)
	desk(dc, true, Color("cfd5dc"))
	for k in 4:
		monitor(root, dc + Vector3(-0.6 + k * 0.4, 0.765, 0.18), PI, {"color": ["#29d17d", "#4aa8ff", "#29d17d", "#ffb627"][k]}, "", 0.42)
	chair(dc + Vector3(0, 0, -0.62), 0.0, Mats.CHARCOAL)
	seats["bogdan_desk"] = [dc + Vector3(0, 0, -0.62), 0.0]
	# cable spaghetti and a fire extinguisher
	var cable_cols := [Color("e85d5d"), Color("2bb3a3"), Color("f2b134"), Color("3d7be0")]
	for i in 7:
		var cable := mesh(root, MeshLib.torus(0.18 + i * 0.03, 0.2 + i * 0.03), Vector3(9.4 + i * 0.25, 0.02, -8.3 + (i % 2) * 0.12), Mats.glossy(cable_cols[i % 4], 0.4))
		cable.scale = Vector3(1.6, 0.4, 0.7)
	mesh(root, MeshLib.capsule(0.11, 0.6), Vector3(14.6, 0.32, -5.0), Mats.glossy(Color("d33a2c"), 0.25))
	nav.block_rect(Vector3(14.6, 0, -5.0), Vector2(0.4, 0.4), 0.0)
	plant(Vector3(14.4, 0, -4.6), 0.8, true)


func _kitchen() -> void:
	var counter_top := Mats.glossy(Color("fbfaf6"), 0.15)
	var cabinet := Mats.glossy(Color("8fd3c7"), 0.35)
	var cz0 := -3.4
	var cz1 := 4.2
	var cl := cz1 - cz0
	var cc := Vector3(-14.6, 0, (cz0 + cz1) * 0.5)
	box(root, Vector3(0.7, 0.86, cl), cc + Vector3(0, 0.43, 0), cabinet, 0.03)
	box(root, Vector3(0.76, 0.06, cl + 0.04), cc + Vector3(0, 0.89, 0), counter_top, 0.02)
	var z := cz0 + 0.45
	while z < cz1:
		box(root, Vector3(0.02, 0.02, 0.18), Vector3(-14.24, 0.72, z), Mats.solid(Mats.STEEL, 0.3, 0.7), 0.005)
		z += 0.6
	box(root, Vector3(0.4, 0.7, cl), cc + Vector3(-0.12, 2.0, 0), cabinet, 0.03)
	nav.block_rect(cc, Vector2(0.8, cl), 0.05)
	# coffee machine (on the Wi-Fi, unfortunately)
	var cm := node(root, "CoffeeMachine", Vector3(-14.55, 0.92, -1.6), PI * 0.5)
	box(cm, Vector3(0.42, 0.5, 0.4), Vector3(0, 0.25, 0), Mats.glossy(Color("2e3138"), 0.2), 0.05)
	box(cm, Vector3(0.36, 0.12, 0.05), Vector3(0, 0.38, 0.2), Mats.emissive(Color("7fd1ff"), 1.2), 0.02)
	mesh(cm, MeshLib.cylinder(0.04, 0.035, 0.08), Vector3(0, 0.1, 0.12), Mats.glossy(Color.WHITE, 0.3))
	mesh(cm, MeshLib.sphere(0.035, 10), Vector3(0.13, 0.48, 0.2), Mats.emissive(Color("29d17d"), 2.0))
	label(cm, Loc.t("world.coffee_sign"), Vector3(0, 0.6, 0.05), 16, Mats.CORAL, Vector3(-0.3, 0, 0), 0.003, 6)
	interact("coffee", "hover.coffee", Vector3(-14.55, 0.8, -1.6), Vector3(0.6, 0.8, 0.6), Vector3(-13.6, 0, -1.6))
	# fruit bowl & kettle
	mesh(root, MeshLib.sphere(0.18, 20), Vector3(-14.55, 0.98, 1.6), Mats.glossy(Color("fbfaf6"), 0.2), Vector3.ZERO, Vector3(1, 0.4, 1))
	for i in 4:
		mesh(root, MeshLib.sphere(0.06, 12), Vector3(-14.55 + cos(i * 1.7) * 0.07, 1.04, 1.6 + sin(i * 1.7) * 0.07), Mats.glossy([Color("f2b134"), Color("e85d5d"), Color("7cc35a"), Color("f2b134")][i], 0.3))
	# fridge
	var fr := node(root, "Fridge", Vector3(-14.5, 0, 5.4))
	box(fr, Vector3(0.8, 2.0, 0.8), Vector3(0, 1.0, 0), Mats.glossy(Color("dfe4ea"), 0.2), 0.06)
	box(fr, Vector3(0.04, 0.5, 0.05), Vector3(0.42, 1.25, 0.3), Mats.solid(Mats.STEEL, 0.25, 0.8), 0.015)
	box(fr, Vector3(0.02, 0.24, 0.2), Vector3(0.41, 1.6, -0.1), Mats.solid(Color("fff6a8"), 0.8), 0.005)
	nav.block_rect(Vector3(-14.5, 0, 5.4), Vector2(0.9, 0.9), 0.0)
	interact("fridge", "hover.fridge", Vector3(-14.5, 0, 5.4), Vector3(0.9, 2.0, 0.9), Vector3(-13.5, 0, 5.4))
	# cake table: the emotional centre of the company
	var ct := Vector3(-11.0, 0, 0.6)
	mesh(root, MeshLib.cylinder(0.75, 0.75, 0.05, 40), ct + Vector3(0, 0.76, 0), Mats.solid(Mats.WOOD_LIGHT, 0.4))
	mesh(root, MeshLib.cylinder(0.05, 0.06, 0.74), ct + Vector3(0, 0.37, 0), Mats.glossy(Mats.CHARCOAL, 0.4))
	mesh(root, MeshLib.cylinder(0.35, 0.38, 0.03, 24), ct + Vector3(0, 0.015, 0), Mats.glossy(Mats.CHARCOAL, 0.4))
	nav.block_rect(ct, Vector2(1.5, 1.5), 0.0)
	var cake := make_cake()
	cake.position = ct + Vector3(0, 0.79, 0)
	root.add_child(cake)
	props["cake_table_cake"] = cake
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		mesh(root, MeshLib.cylinder(0.11, 0.1, 0.012, 20), ct + Vector3(cos(a) * 0.5, 0.79, sin(a) * 0.5), Mats.glossy(Color.WHITE, 0.2))
	for i in 3:
		var a := TAU * i / 3.0
		chair(ct + Vector3(cos(a) * 1.15, 0, sin(a) * 1.15), -a - PI * 0.5, Mats.MUSTARD)
	interact("cake_table", "hover.cake", ct, Vector3(1.4, 1.1, 1.4), ct + Vector3(1.0, 0, 1.3))
	points["cake_spot"] = ct + Vector3(1.0, 0, 1.3)
	points["maggie_cake_spot"] = ct + Vector3(-0.2, 0, 1.4)
	# chalkboard A-frame
	var ab := node(root, "ChalkSign", Vector3(-8.0, 0, -2.8), -0.35)
	var board := box(ab, Vector3(0.9, 1.2, 0.05), Vector3(0, 0.62, 0.1), Mats.solid(Color("2d3a33"), 0.9), 0.03)
	board.rotation.x = -0.15
	var board_back := box(ab, Vector3(0.9, 1.2, 0.05), Vector3(0, 0.62, -0.1), Mats.solid(Mats.WOOD, 0.6), 0.03)
	board_back.rotation.x = 0.15
	label(ab, Loc.t("world.chalk_title"), Vector3(0, 1.0, 0.15), 30, Color("ffe8b0"), Vector3(-0.15, 0, 0), 0.003)
	label(ab, Loc.t("world.chalk_body"), Vector3(0, 0.62, 0.19), 22, Color.WHITE, Vector3(-0.15, 0, 0), 0.003)
	nav.block_rect(Vector3(-8.0, 0, -2.8), Vector2(0.9, 0.5), 0.0)
	interact("chalkboard", "hover.chalkboard", Vector3(-8.0, 0, -2.8), Vector3(0.9, 1.3, 0.4), Vector3(-8.0, 0, -1.8))
	# bar table + stools
	var bt := Vector3(-10.4, 0, 5.4)
	box(root, Vector3(2.2, 0.06, 0.7), bt + Vector3(0, 1.05, 0), Mats.solid(Mats.WOOD, 0.4), 0.025)
	box(root, Vector3(2.0, 1.0, 0.1), bt + Vector3(0, 0.5, 0), Mats.glossy(Color("8fd3c7"), 0.35), 0.03)
	nav.block_rect(bt, Vector2(2.2, 0.7), 0.05)
	for i in 3:
		var sp := bt + Vector3(-0.7 + i * 0.7, 0, 0.75)
		mesh(root, MeshLib.cylinder(0.2, 0.2, 0.07, 24), sp + Vector3(0, 0.75, 0), Mats.soft(Mats.CORAL, 0.8, 0.1))
		mesh(root, MeshLib.cylinder(0.03, 0.03, 0.72), sp + Vector3(0, 0.37, 0), Mats.solid(Mats.STEEL, 0.3, 0.7))
	# planter divider between kitchen and open plan
	var pz := -0.5
	box(root, Vector3(0.6, 0.6, 6.0), Vector3(-7.0, 0.3, pz + 3.0), Mats.solid(Mats.WOOD, 0.55), 0.05)
	for i in 6:
		var leaf := mesh(root, MeshLib.sphere(0.32, 16), Vector3(-7.0, 0.75, pz + 0.6 + i * 1.0), Mats.soft([Mats.LEAF, Mats.LEAF_DARK, Mats.LEAF_LIGHT][i % 3], 0.65, 0.2))
		leaf.scale = Vector3(1.0, 0.7, 1.4)
	nav.block_rect(Vector3(-7.0, 0, pz + 3.0), Vector2(0.6, 6.0), 0.05)
	plant(Vector3(-14.3, 0, 7.4), 1.2, false)
	plant(Vector3(-7.8, 0, 7.4), 0.9, true)


func _open_plan() -> void:
	# Cluster A (west) and cluster B (east): north rows face south (towards camera).
	var clusters := [Vector3(-3.4, 0, 1.5), Vector3(3.4, 0, 1.5)]
	var names := [["tobias", "kevin", "hot_a1", "hot_a2"], ["pia", "sanne", "player", "parental"]]
	for ci in 2:
		var c: Vector3 = clusters[ci]
		var spots := [
			[c + Vector3(-0.76, 0, -0.38), true],
			[c + Vector3(0.76, 0, -0.38), true],
			[c + Vector3(-0.76, 0, 0.38), false],
			[c + Vector3(0.76, 0, 0.38), false],
		]
		# privacy divider
		box(root, Vector3(3.1, 0.38, 0.04), c + Vector3(0, 0.95, 0), Mats.soft(Color("4e6a8f"), 0.95, 0.0), 0.02)
		for k in 4:
			var dc: Vector3 = spots[k][0]
			var south: bool = spots[k][1]
			desk(dc, south)
			var seat_pos := dc + Vector3(0, 0, -0.62 if south else 0.62)
			var yaw := 0.0 if south else PI
			chair(seat_pos, yaw, Mats.NAVY if k % 2 == 0 else Mats.NAVY_LIGHT)
			seats[names[ci][k]] = [seat_pos, yaw]
			var mon_off := Vector3(0, 0.765, 0.16 if south else -0.16)
			var mon_yaw := PI if south else 0.0
			var who: String = names[ci][k]
			match who:
				"sanne":
					for m in 3:
						monitor(root, dc + mon_off + Vector3(-0.48 + m * 0.48, 0, 0), mon_yaw + (m - 1) * 0.25, {"color": "#1e2430"}, "", 0.46)
				"player":
					pass
				_:
					monitor(root, dc + mon_off, mon_yaw, {"color": ["#4aa8ff", "#7fd1ff", "#29d17d", "#ffb627"][k]}, "", 0.58)
			# keyboard
			box(root, Vector3(0.42, 0.02, 0.14), dc + Vector3(0, 0.775, -0.05 if south else 0.05), Mats.glossy(Color("eceef1"), 0.4), 0.01)
	_desk_props()
	# whiteboard: PEOPLE / PROJECTS / PROGRESS / PROFIT / AND A BIT OF CHAOS
	var wb := node(root, "Whiteboard", Vector3(6.3, 0, -2.7), -0.5)
	box(wb, Vector3(2.0, 1.3, 0.05), Vector3(0, 1.55, 0), Mats.glossy(Color.WHITE, 0.15), 0.03)
	box(wb, Vector3(2.08, 1.38, 0.03), Vector3(0, 1.55, -0.02), Mats.solid(Mats.STEEL, 0.3, 0.6), 0.03)
	for lx in [-0.9, 0.9]:
		box(wb, Vector3(0.05, 1.6, 0.05), Vector3(lx, 0.8, -0.04), Mats.solid(Mats.STEEL, 0.3, 0.6), 0.015)
		box(wb, Vector3(0.06, 0.04, 0.7), Vector3(lx, 0.05, -0.04), Mats.solid(Mats.STEEL, 0.3, 0.6), 0.015)
	label(wb, Loc.t("world.whiteboard"), Vector3(0, 1.55, 0.03), 46, Color("2a3550"), Vector3.ZERO, 0.0032)
	box(wb, Vector3(1.4, 0.03, 0.06), Vector3(0, 0.88, 0.05), Mats.solid(Mats.STEEL, 0.3, 0.6), 0.01)
	nav.block_rect(Vector3(6.3, 0, -2.7), Vector2(1.6, 1.0), 0.0)
	interact("whiteboard", "hover.whiteboard", Vector3(6.3, 0, -2.7), Vector3(2.0, 2.3, 0.5), Vector3(5.6, 0, -1.6))
	# printer
	var pr := node(root, "Printer", Vector3(-6.0, 0, 7.2))
	box(pr, Vector3(0.9, 0.75, 0.7), Vector3(0, 0.375, 0), Mats.glossy(Color("eceef1"), 0.35), 0.05)
	box(pr, Vector3(0.7, 0.08, 0.5), Vector3(0, 0.8, 0), Mats.glossy(Color("2e3138"), 0.35), 0.03)
	box(pr, Vector3(0.12, 0.05, 0.02), Vector3(0.25, 0.65, 0.36), Mats.emissive(Color("ff5a4a"), 2.0), 0.01)
	nav.block_rect(Vector3(-6.0, 0, 7.2), Vector2(0.9, 0.7), 0.05)
	interact("printer", "hover.printer", Vector3(-6.0, 0, 7.2), Vector3(0.9, 0.9, 0.7), Vector3(-6.0, 0, 6.2))
	plant(Vector3(-6.4, 0, -3.3), 1.2, false)
	plant(Vector3(6.6, 0, 7.4), 1.0, true)
	plant(Vector3(0.0, 0, 7.4), 0.8, true)
	plant(Vector3(0.0, 0, -3.3), 1.0, true)
	points["olu_a"] = Vector3(-5.5, 0, 4.6)
	points["olu_b"] = Vector3(5.5, 0, 4.6)
	points["olu_c"] = Vector3(0.0, 0, -1.5)
	points["olu_d"] = Vector3(-9.0, 0, -2.0)


func _desk_props() -> void:
	# --- player's desk (cluster B, south-west) -------------------------------
	var pd := Vector3(3.4 - 0.76, 0, 1.5 + 0.38)
	var laptop := node(root, "Laptop", pd + Vector3(-0.15, 0.765, -0.05), 0.0)
	box(laptop, Vector3(0.42, 0.02, 0.3), Vector3(0, 0.01, 0), Mats.solid(Color("c4cad3"), 0.3, 0.5), 0.01)
	var lid := node(laptop, "Lid", Vector3(0, 0.02, -0.15))
	lid.rotation.x = -0.25
	box(lid, Vector3(0.42, 0.28, 0.015), Vector3(0, 0.14, 0), Mats.solid(Color("c4cad3"), 0.3, 0.5), 0.01)
	var lscreen := mesh(lid, MeshLib.quad(Vector2(0.38, 0.24)), Vector3(0, 0.14, 0.009), Mats.emissive(Color("7fd1ff"), 0.9))
	lscreen.name = "Screen"
	props["laptop_screen"] = lscreen
	interact("laptop", "hover.laptop", pd + Vector3(0, 0.6, 0), Vector3(1.4, 0.6, 0.7), pd + Vector3(-0.3, 0, 0.75))
	# rubber duck — the senior architect of this desk
	var duck := node(root, "Duck", pd + Vector3(0.45, 0.765, 0.1), PI + 0.6)
	var yellow := Mats.glossy(Color("ffd23f"), 0.2)
	mesh(duck, MeshLib.sphere(0.07, 16), Vector3(0, 0.055, 0), yellow, Vector3.ZERO, Vector3(1.2, 0.85, 1.0))
	mesh(duck, MeshLib.sphere(0.045, 16), Vector3(0.04, 0.12, 0), yellow)
	mesh(duck, MeshLib.sphere(0.022, 10), Vector3(0.085, 0.115, 0), Mats.glossy(Color("f28c28"), 0.3), Vector3.ZERO, Vector3(1.4, 0.6, 1.0))
	for sz in [-0.02, 0.02]:
		mesh(duck, MeshLib.sphere(0.008, 8), Vector3(0.07, 0.135, sz), Mats.solid(Color.BLACK, 0.3))
	props["duck"] = duck
	interact("duck", "hover.duck", pd + Vector3(0.45, 0.76, 0.1), Vector3(0.2, 0.2, 0.2), pd + Vector3(0.45, 0, 0.75))
	# mug: GOOD IDEAS (USUALLY)
	var mug := node(root, "Mug", pd + Vector3(0.18, 0.765, 0.15))
	mesh(mug, MeshLib.cylinder(0.045, 0.042, 0.11, 20), Vector3(0, 0.055, 0), Mats.glossy(Color.WHITE, 0.2))
	var handle := mesh(mug, MeshLib.torus(0.022, 0.035), Vector3(0.05, 0.055, 0), Mats.glossy(Color.WHITE, 0.2))
	handle.rotation.x = PI * 0.5
	label(mug, Loc.t("world.mug"), Vector3(0, 0.06, 0.046), 12, Mats.NAVY, Vector3.ZERO, 0.0025)
	# desk sign: PLAN / PROGRESS / PROFIT / REPEAT
	var ds := node(root, "DeskSign", pd + Vector3(-0.6, 0.765, 0.12), 0.25)
	var plank := box(ds, Vector3(0.36, 0.26, 0.025), Vector3(0, 0.13, 0), Mats.solid(Color("d8b48a"), 0.7), 0.01)
	plank.rotation.x = -0.25
	label(ds, Loc.t("world.desk_sign"), Vector3(0, 0.13, 0.03), 18, Color("4a3020"), Vector3(-0.25, 0, 0), 0.0025)
	# the phone that will later vibrate across the desk
	var phone := node(root, "Phone", pd + Vector3(0.0, 0.775, 0.22))
	box(phone, Vector3(0.08, 0.012, 0.16), Vector3.ZERO, Mats.glossy(Color("1d1f24"), 0.2), 0.008)
	var glow := mesh(phone, MeshLib.quad(Vector2(0.07, 0.14)), Vector3(0, 0.008, 0), Mats.emissive(Color("4aa8ff"), 0.5), Vector3(-PI * 0.5, 0, 0))
	glow.name = "Glow"
	props["phone"] = phone
	# paper stacks
	for i in 3:
		box(root, Vector3(0.24, 0.03 + i * 0.01, 0.3), pd + Vector3(-0.55 + i * 0.02, 0.78 + i * 0.03, -0.18), Mats.solid(Color("fbfaf6"), 0.9), 0.004)
	mesh(root, MeshLib.cylinder(0.05, 0.04, 0.08), pd + Vector3(0.6, 0.805, -0.2), Mats.glossy(Mats.TERRACOTTA, 0.4))
	mesh(root, MeshLib.sphere(0.07, 12), pd + Vector3(0.6, 0.88, -0.2), Mats.soft(Mats.LEAF, 0.6, 0.2))

	# --- Tobias: sticky notes & cold coffees -----------------------------------
	var td := Vector3(-3.4 - 0.76, 0, 1.5 - 0.38)
	for i in 9:
		var note := box(root, Vector3(0.08, 0.004, 0.08), td + Vector3(-0.55 + (i % 5) * 0.2, 0.768, -0.25 + (i / 5) * 0.14), Mats.solid([Color("ffe066"), Color("ff9ecb"), Color("8fe3ff")][i % 3], 0.9), 0.002)
		note.rotation.y = randf_range(-0.4, 0.4)
	for i in 3:
		mesh(root, MeshLib.cylinder(0.04, 0.035, 0.1, 16), td + Vector3(0.35 + i * 0.09, 0.82, -0.1 + i * 0.05), Mats.glossy([Color.WHITE, Mats.CORAL, Mats.TEAL][i], 0.3))
	# --- Sanne: do-not-disturb sign, facing the room ------------------------------
	var sd := Vector3(3.4 + 0.76, 0, 1.5 - 0.38)
	var sg := node(root, "SanneSign", sd + Vector3(0.0, 0.765, -0.32), 0.0)
	box(sg, Vector3(0.72, 0.16, 0.02), Vector3(0, 0.08, 0), Mats.solid(Mats.CORAL, 0.7), 0.01)
	label(sg, Loc.t("world.sanne_sign"), Vector3(0, 0.08, 0.012), 14, Color.WHITE, Vector3.ZERO, 0.0028)
	for i in 4:
		mesh(root, MeshLib.cylinder(0.03, 0.03, 0.12, 12), sd + Vector3(0.62, 0.83, 0.1 - i * 0.07), Mats.glossy(Color("29d17d"), 0.2))
	# --- Kevin: calculator & a cactus ------------------------------------------------
	var kd := Vector3(-3.4 + 0.76, 0, 1.5 - 0.38)
	box(root, Vector3(0.14, 0.03, 0.2), kd + Vector3(0.4, 0.78, -0.05), Mats.glossy(Color("3a3f48"), 0.4), 0.01)
	mesh(root, MeshLib.capsule(0.04, 0.16), kd + Vector3(-0.5, 0.85, -0.1), Mats.soft(Mats.LEAF_DARK, 0.7, 0.2))
	# --- Pia: the deal bell ------------------------------------------------------------
	var pia_d := Vector3(3.4 - 0.76, 0, 1.5 - 0.38)
	mesh(root, MeshLib.sphere(0.07, 16), pia_d + Vector3(-0.5, 0.78, -0.1), Mats.glossy(Color("f2b134"), 0.15), Vector3.ZERO, Vector3(1, 0.7, 1))
	interact("pia_bell", "hover.pia_bell", pia_d + Vector3(-0.5, 0.75, -0.1), Vector3(0.3, 0.3, 0.3), pia_d + Vector3(-0.5, 0, -0.9))
	# --- the parental-leave desk: a plant that has taken over -------------------------
	var ld := Vector3(3.4 + 0.76, 0, 1.5 + 0.38)
	for i in 7:
		var leaf := mesh(root, MeshLib.sphere(0.16, 12), ld + Vector3(-0.4 + i * 0.14, 0.9 + (i % 2) * 0.12, 0.0), Mats.soft([Mats.LEAF, Mats.LEAF_LIGHT][i % 2], 0.6, 0.2))
		leaf.scale = Vector3(1.0, 0.6, 1.5)
	mesh(root, MeshLib.cylinder(0.12, 0.09, 0.16), ld + Vector3(0, 0.845, 0), Mats.glossy(Mats.TERRACOTTA, 0.4))
	interact("parental", "hover.parental", ld + Vector3(0, 0.6, 0), Vector3(1.4, 0.8, 0.7), ld + Vector3(0.3, 0, 0.8))


func _reception() -> void:
	# feature wall with wood slats and the logo
	var wall_c := Vector3(11.5, 0, -0.6)
	box(root, Vector3(5.2, 2.9, 0.22), wall_c + Vector3(0, 1.45, 0), Mats.solid(Color("f3ece0"), 0.8), 0.04)
	var sx := -2.45
	while sx <= 2.46:
		box(root, Vector3(0.09, 2.8, 0.06), wall_c + Vector3(sx, 1.42, 0.13), Mats.solid(Mats.WOOD, 0.5), 0.02)
		sx += 0.18
	nav.block_rect(wall_c, Vector2(5.2, 0.4), 0.0)
	var plate := node(root, "Logo", wall_c + Vector3(0, 1.95, 0.2))
	box(plate, Vector3(3.6, 0.95, 0.06), Vector3.ZERO, Mats.glossy(Mats.NAVY, 0.3), 0.05)
	# compass-arrow logo mark
	mesh(plate, MeshLib.cylinder(0.3, 0.3, 0.05, 40), Vector3(-1.35, 0, 0.04), Mats.glossy(Color("fbfaf6"), 0.2), Vector3(PI * 0.5, 0, 0))
	var arrow := mesh(plate, MeshLib.cylinder(0.0, 0.14, 0.38, 3), Vector3(-1.35, 0.03, 0.08), Mats.glossy(Color("f28c28"), 0.25), Vector3(0, 0, -0.5))
	arrow.scale = Vector3(1.0, 1.0, 0.25)
	label(plate, Loc.t("world.logo"), Vector3(0.35, 0.1, 0.035), 120, Color("fbfaf6"), Vector3.ZERO, 0.0035)
	label(plate, Loc.t("world.logo_tag"), Vector3(0.35, -0.24, 0.035), 28, Color("f2b134"), Vector3.ZERO, 0.0035)
	# reception desk
	var dc := Vector3(11.5, 0, 1.6)
	box(root, Vector3(3.4, 1.05, 0.75), dc + Vector3(0, 0.525, 0), Mats.solid(Mats.WOOD, 0.45), 0.08)
	box(root, Vector3(3.5, 0.06, 0.45), dc + Vector3(0, 1.1, 0.2), Mats.glossy(Color("fbfaf6"), 0.2), 0.02)
	box(root, Vector3(3.3, 0.06, 0.6), dc + Vector3(0, 0.78, -0.2), Mats.glossy(Color("fbfaf6"), 0.2), 0.02)
	box(root, Vector3(3.2, 0.12, 0.02), dc + Vector3(0, 0.3, 0.38), Mats.emissive(Color("f2b134"), 0.8), 0.01)
	nav.block_rect(dc, Vector2(3.4, 0.75), 0.05)
	monitor(root, dc + Vector3(-0.8, 0.81, -0.1), 0.0 + PI, {"color": "#7fd1ff"}, "", 0.5)
	# bell
	var bell := node(root, "Bell", dc + Vector3(0.7, 1.13, 0.25))
	mesh(bell, MeshLib.cylinder(0.07, 0.08, 0.02, 20), Vector3(0, 0.01, 0), Mats.solid(Mats.CHARCOAL, 0.4))
	mesh(bell, MeshLib.sphere(0.065, 20), Vector3(0, 0.02, 0), Mats.solid(Color("f2c14e"), 0.15, 0.9), Vector3.ZERO, Vector3(1, 0.8, 1))
	interact("bell", "hover.bell", dc + Vector3(0.7, 1.0, 0.25), Vector3(0.3, 0.3, 0.3), dc + Vector3(0.7, 0, 1.0))
	# flowers
	mesh(root, MeshLib.cylinder(0.06, 0.05, 0.22, 16), dc + Vector3(-1.3, 1.24, 0.2), Mats.glass())
	for i in 5:
		var a := TAU * i / 5.0
		mesh(root, MeshLib.sphere(0.05, 10), dc + Vector3(-1.3 + cos(a) * 0.06, 1.42 + (i % 2) * 0.04, 0.2 + sin(a) * 0.06), Mats.soft([Mats.CORAL, Mats.MUSTARD, Color("ff9ecb")][i % 3], 0.6, 0.2))
	points["maggie_desk"] = dc + Vector3(0, 0, -0.75)
	points["reception_front"] = dc + Vector3(0, 0, 1.0)
	# waiting area
	var sofa := node(root, "Sofa", Vector3(13.9, 0, 5.0), -PI * 0.5)
	var fabric := Mats.soft(Mats.MUSTARD, 0.9, 0.15)
	box(sofa, Vector3(2.4, 0.42, 0.9), Vector3(0, 0.3, 0), fabric, 0.12)
	box(sofa, Vector3(2.4, 0.6, 0.25), Vector3(0, 0.62, -0.36), fabric, 0.12)
	for ax in [-1.15, 1.15]:
		box(sofa, Vector3(0.25, 0.55, 0.9), Vector3(ax, 0.42, 0), fabric, 0.11)
	for cx in [-0.55, 0.55]:
		box(sofa, Vector3(1.05, 0.14, 0.7), Vector3(cx, 0.55, 0.05), Mats.soft(Mats.MUSTARD.lightened(0.1), 0.9, 0.15), 0.07)
	var cushion := box(sofa, Vector3(0.45, 0.4, 0.14), Vector3(-0.7, 0.8, -0.18), Mats.soft(Mats.TEAL, 0.9, 0.1), 0.07)
	cushion.rotation.z = 0.15
	nav.block_rect(Vector3(13.9, 0, 5.0), Vector2(0.9, 2.4), 0.05)
	interact("sofa", "hover.sofa", Vector3(13.9, 0, 5.0), Vector3(0.9, 0.9, 2.4), Vector3(12.8, 0, 5.0))
	var tbl := Vector3(12.4, 0, 5.0)
	mesh(root, MeshLib.cylinder(0.55, 0.55, 0.05, 40), tbl + Vector3(0, 0.42, 0), Mats.solid(Mats.WOOD_LIGHT, 0.4))
	for i in 3:
		var a := TAU * i / 3.0
		var leg := mesh(root, MeshLib.capsule(0.025, 0.46), tbl + Vector3(cos(a) * 0.32, 0.2, sin(a) * 0.32), Mats.solid(Mats.WOOD_DARK, 0.5))
		leg.rotation = Vector3(sin(a) * 0.15, 0, -cos(a) * 0.15)
	box(root, Vector3(0.3, 0.015, 0.4), tbl + Vector3(-0.1, 0.455, 0.05), Mats.solid(Color("2bb3a3"), 0.6), 0.004, 0.3)
	label(root, Loc.t("world.magazine"), tbl + Vector3(-0.1, 0.47, 0.05), 20, Color.WHITE, Vector3(-PI * 0.5, 0.3, 0), 0.0028)
	nav.block_rect(tbl, Vector2(1.1, 1.1), 0.0)
	interact("magazines", "hover.magazines", tbl, Vector3(1.0, 0.6, 1.0), tbl + Vector3(-0.9, 0, 0.6))
	plant(Vector3(14.4, 0, 7.4), 1.3, false)
	plant(Vector3(8.3, 0, 7.4), 1.0, true)
	plant(Vector3(14.4, 0, 0.0), 1.1, true)
	points["entrance"] = Vector3(11.0, 0, 7.2)
	points["outside"] = Vector3(11.0, 0, 10.0)
	points["delivery_origin"] = Vector3(11.0, 1.2, 9.5)


func _lights() -> void:
	var warm := Color(1.0, 0.86, 0.68)
	var spots := [
		[Vector3(-11.0, 2.8, 1.5), warm, 0.9],
		[Vector3(-3.4, 2.8, 2.0), warm, 0.8],
		[Vector3(3.4, 2.8, 2.0), warm, 0.8],
		[Vector3(11.5, 2.8, 3.0), warm, 1.0],
		[Vector3(-10.5, 2.6, -7.0), Color(1.0, 0.92, 0.82), 0.7],
		[Vector3(-2.0, 2.6, -7.0), Color(1.0, 0.8, 0.6), 0.8],
		[Vector3(5.0, 2.6, -7.0), warm, 0.7],
		[Vector3(11.5, 2.4, -7.0), Color(0.6, 0.85, 1.0), 0.9],
	]
	for s in spots:
		var l := OmniLight3D.new()
		l.position = s[0]
		l.light_color = s[1]
		l.light_energy = s[2]
		l.omni_range = 7.5
		l.omni_attenuation = 1.2
		l.shadow_enabled = false
		root.add_child(l)


## A lemon drizzle cake on a stand. Used on the table and carried by Maggie.
func make_cake() -> Node3D:
	var c := Node3D.new()
	c.name = "Cake"
	mesh(c, MeshLib.cylinder(0.24, 0.26, 0.02, 32), Vector3(0, 0.01, 0), Mats.glossy(Color.WHITE, 0.15))
	mesh(c, MeshLib.cylinder(0.04, 0.06, 0.08, 16), Vector3(0, -0.03, 0), Mats.glossy(Color.WHITE, 0.15))
	mesh(c, MeshLib.cylinder(0.19, 0.19, 0.14, 32), Vector3(0, 0.09, 0), Mats.soft(Color("f5cf6b"), 0.7, 0.2))
	mesh(c, MeshLib.cylinder(0.195, 0.195, 0.03, 32), Vector3(0, 0.17, 0), Mats.glossy(Color("fffaf0"), 0.25))
	for i in 10:
		var a := TAU * i / 10.0
		mesh(c, MeshLib.capsule(0.018, 0.08), Vector3(cos(a) * 0.19, 0.14, sin(a) * 0.19), Mats.glossy(Color("fffaf0"), 0.25))
	for i in 5:
		var a := TAU * i / 5.0
		var slice := mesh(c, MeshLib.cylinder(0.035, 0.035, 0.012, 16), Vector3(cos(a) * 0.1, 0.19, sin(a) * 0.1), Mats.glossy(Color("ffe14d"), 0.2))
		slice.rotation.z = 0.3
	return c
