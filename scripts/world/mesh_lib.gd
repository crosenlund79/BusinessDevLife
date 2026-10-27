class_name MeshLib
extends RefCounted
## Procedural meshes that Godot's primitives don't cover: rounded boxes (the
## backbone of the soft, toy-free furniture look), cartoon stars, and helpers.
## Meshes are cached so hundreds of desks share the same geometry.

static var _cache: Dictionary = {}


## A box with rounded edges/corners. Normals are smooth across the bevel.
static func rounded_box(size: Vector3, radius: float, steps: int = 3) -> ArrayMesh:
	var key := "rb|%.3f|%.3f|%.3f|%.3f|%d" % [size.x, size.y, size.z, radius, steps]
	if _cache.has(key):
		return _cache[key]
	var h := size * 0.5
	var r := clampf(radius, 0.0005, minf(h.x, minf(h.y, h.z)) - 0.0001)
	if r <= 0.0:
		r = 0.0005
	var inner := h - Vector3(r, r, r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 0
	for axis in 3:
		for s in [-1.0, 1.0]:
			var u_axis := (axis + 1) % 3
			var v_axis := (axis + 2) % 3
			var us := _samples(h[u_axis], r, steps)
			var vs := _samples(h[v_axis], r, steps)
			var face_n := Vector3.ZERO
			face_n[axis] = s
			for j in vs.size():
				for i in us.size():
					var p := Vector3.ZERO
					p[axis] = s * h[axis]
					p[u_axis] = us[i]
					p[v_axis] = vs[j]
					var c := Vector3(clampf(p.x, -inner.x, inner.x), clampf(p.y, -inner.y, inner.y), clampf(p.z, -inner.z, inner.z))
					var d := p - c
					var n := face_n if d.length() < 0.000001 else d.normalized()
					st.set_normal(n)
					st.set_uv(Vector2(float(i) / (us.size() - 1), float(j) / (vs.size() - 1)))
					st.add_vertex(c + n * r)
			# Godot treats clockwise triangles as front faces.
			var du := Vector3.ZERO
			du[u_axis] = 1.0
			var dv := Vector3.ZERO
			dv[v_axis] = 1.0
			var ccw_is_out := du.cross(dv).dot(face_n) > 0.0
			var w := us.size()
			for j in vs.size() - 1:
				for i in us.size() - 1:
					var a := base + j * w + i
					var b := a + 1
					var c2 := a + w + 1
					var d2 := a + w
					if ccw_is_out:
						st.add_index(a)
						st.add_index(c2)
						st.add_index(b)
						st.add_index(a)
						st.add_index(d2)
						st.add_index(c2)
					else:
						st.add_index(a)
						st.add_index(b)
						st.add_index(c2)
						st.add_index(a)
						st.add_index(c2)
						st.add_index(d2)
			base += us.size() * vs.size()
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func _samples(h: float, r: float, steps: int) -> PackedFloat32Array:
	var arr := PackedFloat32Array()
	for i in steps + 1:
		var a := PI * 0.5 * float(i) / steps
		arr.append(-(h - r) - r * cos(a))
	for i in range(steps, -1, -1):
		var a := PI * 0.5 * float(i) / steps
		arr.append((h - r) + r * cos(a))
	return arr


## A chunky five-pointed cartoon star, extruded along Z.
static func star(outer := 0.18, inner := 0.08, depth := 0.06) -> ArrayMesh:
	var key := "star|%.3f|%.3f|%.3f" % [outer, inner, depth]
	if _cache.has(key):
		return _cache[key]
	var pts: Array[Vector3] = []
	for i in 10:
		var a := PI * 0.5 + TAU * float(i) / 10.0
		var rad := outer if i % 2 == 0 else inner
		pts.append(Vector3(cos(a) * rad, sin(a) * rad, 0.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz := depth * 0.5
	for i in 10:
		var p0 := pts[i]
		var p1 := pts[(i + 1) % 10]
		# front and back fans (puffy: centre pushed out)
		_tri(st, Vector3(0, 0, hz * 1.6), p0 + Vector3(0, 0, hz), p1 + Vector3(0, 0, hz), Vector3(0, 0, 1))
		_tri(st, Vector3(0, 0, -hz * 1.6), p1 - Vector3(0, 0, hz), p0 - Vector3(0, 0, hz), Vector3(0, 0, -1))
		var side_n := (p0 + p1).normalized()
		_tri(st, p0 + Vector3(0, 0, hz), p0 - Vector3(0, 0, hz), p1 - Vector3(0, 0, hz), side_n)
		_tri(st, p0 + Vector3(0, 0, hz), p1 - Vector3(0, 0, hz), p1 + Vector3(0, 0, hz), side_n)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## Adds a flat-shaded triangle, fixing the winding so it faces along `n`.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp := b
		b = c
		c = tmp
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)


static func sphere(radius: float, segments := 24) -> SphereMesh:
	var key := "sph|%.3f|%d" % [radius, segments]
	if _cache.has(key):
		return _cache[key]
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(8, segments / 2)
	_cache[key] = m
	return m


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var key := "cap|%.3f|%.3f" % [radius, height]
	if _cache.has(key):
		return _cache[key]
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0 + 0.001)
	m.radial_segments = 20
	m.rings = 8
	_cache[key] = m
	return m


static func cylinder(top: float, bottom: float, height: float, segments := 24) -> CylinderMesh:
	var key := "cyl|%.3f|%.3f|%.3f|%d" % [top, bottom, height, segments]
	if _cache.has(key):
		return _cache[key]
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	_cache[key] = m
	return m


static func quad(size: Vector2) -> QuadMesh:
	var key := "quad|%.3f|%.3f" % [size.x, size.y]
	if _cache.has(key):
		return _cache[key]
	var m := QuadMesh.new()
	m.size = size
	_cache[key] = m
	return m


static func torus(inner: float, outer: float) -> TorusMesh:
	var key := "tor|%.3f|%.3f" % [inner, outer]
	if _cache.has(key):
		return _cache[key]
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 32
	m.ring_segments = 12
	_cache[key] = m
	return m
