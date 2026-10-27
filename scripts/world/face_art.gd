class_name FaceArt
extends RefCounted
## Draws the cartoon mouth shapes into small textures at startup.
## Eyes and brows are real 3D geometry; mouths are painted, which keeps them
## crisp and lets them be expressive without complex rigging.

const W := 256
const H := 128
const LIP := Color(0.36, 0.12, 0.12)
const DARK := Color(0.24, 0.06, 0.08)
const TEETH := Color(0.99, 0.98, 0.95)
const TONGUE := Color(0.93, 0.45, 0.47)

static var _cache: Dictionary = {}


static func mouth(kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match kind:
		"smile":
			_stroke(img, _bezier(Vector2(70, 52), Vector2(128, 92), Vector2(186, 52)), 8.0, LIP)
		"grin":
			var top := _bezier(Vector2(66, 46), Vector2(128, 58), Vector2(190, 46))
			var bottom := _bezier(Vector2(190, 46), Vector2(128, 120), Vector2(66, 46))
			var poly := PackedVector2Array()
			poly.append_array(top)
			poly.append_array(bottom)
			_fill(img, poly, DARK)
			_fill_clipped(img, poly, Rect2(0, 0, W, 66), TEETH)
			_ellipse(img, Vector2(128, 96), Vector2(30, 14), TONGUE, poly)
			_stroke(img, poly, 3.0, LIP)
		"flat":
			_stroke(img, _bezier(Vector2(86, 66), Vector2(128, 68), Vector2(170, 64)), 7.5, LIP)
		"frown":
			_stroke(img, _bezier(Vector2(80, 82), Vector2(128, 44), Vector2(176, 82)), 8.0, LIP)
		"open":
			var o := _ellipse_poly(Vector2(128, 66), Vector2(26, 36))
			_fill(img, o, DARK)
			_ellipse(img, Vector2(128, 88), Vector2(18, 12), TONGUE, o)
			_stroke(img, o, 3.0, LIP)
		"talk":
			var t := _ellipse_poly(Vector2(128, 66), Vector2(34, 20))
			_fill(img, t, DARK)
			_fill_clipped(img, t, Rect2(0, 0, W, 54), TEETH)
			_ellipse(img, Vector2(128, 80), Vector2(20, 9), TONGUE, t)
			_stroke(img, t, 3.0, LIP)
		"smirk":
			_stroke(img, _bezier(Vector2(84, 70), Vector2(140, 78), Vector2(182, 46)), 8.0, LIP)
		"grimace":
			var g := PackedVector2Array([Vector2(74, 50), Vector2(182, 50), Vector2(186, 84), Vector2(70, 84)])
			_fill(img, g, TEETH)
			for x in [101, 128, 155]:
				_stroke(img, PackedVector2Array([Vector2(x, 52), Vector2(x, 82)]), 2.0, Color(0.6, 0.55, 0.55))
			_stroke(img, PackedVector2Array([Vector2(74, 67), Vector2(182, 67)]), 2.0, Color(0.6, 0.55, 0.55))
			var outline := g.duplicate()
			outline.append(g[0])
			_stroke(img, outline, 4.5, LIP)
		"wobble":
			var pts := PackedVector2Array()
			for i in 41:
				var x := 76.0 + i * 2.6
				pts.append(Vector2(x, 68.0 + sin(i * 1.1) * 6.0))
			_stroke(img, pts, 6.5, LIP)
		_:
			_stroke(img, _bezier(Vector2(86, 66), Vector2(128, 68), Vector2(170, 64)), 7.5, LIP)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[kind] = tex
	return tex


static func _bezier(a: Vector2, c: Vector2, b: Vector2, steps := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return pts


static func _ellipse_poly(center: Vector2, radii: Vector2, steps := 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a := TAU * float(i) / steps
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts


## Stamps anti-aliased discs along a polyline.
static func _stroke(img: Image, pts: PackedVector2Array, width: float, col: Color) -> void:
	var r := width * 0.5
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := maxi(1, int(a.distance_to(b) / 1.5))
		for k in n + 1:
			_disc(img, a.lerp(b, float(k) / n), r, col)


static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	var x0 := maxi(0, int(c.x - r - 1.0))
	var x1 := mini(W - 1, int(c.x + r + 1.0))
	var y0 := maxi(0, int(c.y - r - 1.0))
	var y1 := mini(H - 1, int(c.y + r + 1.0))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var cov := clampf(r + 0.5 - d, 0.0, 1.0)
			if cov <= 0.0:
				continue
			var existing := img.get_pixel(x, y)
			var a := maxf(existing.a, cov * col.a)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a) if existing.a < 0.01 else existing.lerp(Color(col.r, col.g, col.b, a), cov))


static func _fill(img: Image, poly: PackedVector2Array, col: Color) -> void:
	_fill_clipped(img, poly, Rect2(0, 0, W, H), col)


static func _fill_clipped(img: Image, poly: PackedVector2Array, clip: Rect2, col: Color) -> void:
	var bounds := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		bounds = bounds.expand(p)
	bounds = bounds.intersection(clip)
	for y in range(int(bounds.position.y), int(bounds.end.y) + 1):
		for x in range(int(bounds.position.x), int(bounds.end.x) + 1):
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				img.set_pixel(x, y, col)


static func _ellipse(img: Image, center: Vector2, radii: Vector2, col: Color, inside: PackedVector2Array) -> void:
	var e := _ellipse_poly(center, radii)
	var bounds := Rect2(center - radii, radii * 2.0)
	for y in range(int(bounds.position.y), int(bounds.end.y) + 1):
		for x in range(int(bounds.position.x), int(bounds.end.x) + 1):
			if x < 0 or y < 0 or x >= W or y >= H:
				continue
			var p := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(p, e) and Geometry2D.is_point_in_polygon(p, inside):
				img.set_pixel(x, y, col)
