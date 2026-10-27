class_name ScreenContent
extends Control
## 2D content rendered into in-world screens and presentation boards
## (meeting-room TV, war-room charts, monitors). Driven by a `spec` dictionary
## so the story can swap slides: {"kind": "bars", "title": ..., ...}

var spec: Dictionary = {}
var font: Font
var bold: Font
var _t := 0.0

const INK := Color("24324a")
const MUTED := Color("6b7890")
const PAPER := Color("fbfaf6")
const GREEN := Color("2fae5c")
const AMBER := Color("f2b134")
const RED := Color("e85d5d")
const BLUE := Color("3d7be0")


func show_spec(s: Dictionary) -> void:
	spec = s
	queue_redraw()


func _process(delta: float) -> void:
	if spec.get("animated", false):
		_t += delta
		queue_redraw()


func _draw() -> void:
	var f := font if font else ThemeDB.fallback_font
	var fb := bold if bold else f
	var w := size.x
	var h := size.y
	var bg := Color(str(spec.get("bg", "#fbfaf6")))
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	var kind := str(spec.get("kind", "slide"))
	var dark := bg.get_luminance() < 0.4
	var ink := Color.WHITE if dark else INK
	var title := str(spec.get("title", ""))
	if title != "" and kind != "slide":
		draw_string(fb, Vector2(36, 66), title, HORIZONTAL_ALIGNMENT_LEFT, w - 72, 40, ink)
		draw_rect(Rect2(36, 84, 90, 6), Color(str(spec.get("accent", "#f28c28"))))
	match kind:
		"slide":
			_draw_slide(f, fb, w, h, ink)
		"status":
			_draw_status(f, fb, w, h, ink)
		"bars":
			_draw_bars(f, fb, w, h, ink)
		"line":
			_draw_line(f, fb, w, h, ink)
		"risk":
			_draw_risk(f, fb, w, h, ink)
		"code":
			_draw_code(f, w, h)
		"ui":
			_draw_ui(f, fb, w, h)


func _draw_slide(f: Font, fb: Font, w: float, h: float, ink: Color) -> void:
	var accent := Color(str(spec.get("accent", "#f28c28")))
	draw_rect(Rect2(0, 0, w, 14), accent)
	var title := str(spec.get("title", ""))
	var y := h * 0.36
	if spec.has("kicker"):
		draw_string(fb, Vector2(0, y - 70), str(spec["kicker"]), HORIZONTAL_ALIGNMENT_CENTER, w, 30, accent)
	draw_string(fb, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, w, int(spec.get("title_size", 64)), ink)
	if spec.has("subtitle"):
		draw_string(f, Vector2(0, y + 60), str(spec["subtitle"]), HORIZONTAL_ALIGNMENT_CENTER, w, 32, ink.lerp(MUTED, 0.5))
	var bullets: Array = spec.get("bullets", [])
	var by := y + 130
	for b in bullets:
		draw_circle(Vector2(w * 0.22, by - 10), 7, accent)
		draw_string(f, Vector2(w * 0.22 + 22, by), str(b), HORIZONTAL_ALIGNMENT_LEFT, w * 0.6, 30, ink)
		by += 48
	if spec.has("footer"):
		draw_string(f, Vector2(0, h - 28), str(spec["footer"]), HORIZONTAL_ALIGNMENT_CENTER, w, 22, ink.lerp(MUTED, 0.6))


func _draw_status(f: Font, fb: Font, w: float, h: float, ink: Color) -> void:
	var status := str(spec.get("status", "green"))
	var col := GREEN
	if status == "amber":
		col = AMBER
	elif status == "red":
		col = RED
	var c := Vector2(w * 0.5, h * 0.5 + 10)
	var pulse := 1.0 + sin(_t * 3.0) * 0.03
	draw_circle(c, 118 * pulse, col.lightened(0.55))
	draw_circle(c, 96 * pulse, col)
	draw_string(fb, Vector2(c.x - 150, c.y + 20), str(spec.get("big", "ON TRACK")), HORIZONTAL_ALIGNMENT_CENTER, 300, 40, Color.WHITE)
	draw_string(f, Vector2(0, h - 70), str(spec.get("caption", "")), HORIZONTAL_ALIGNMENT_CENTER, w, 26, ink)
	draw_string(f, Vector2(0, h - 34), str(spec.get("footnote", "")), HORIZONTAL_ALIGNMENT_CENTER, w, 20, MUTED)


func _draw_bars(f: Font, fb: Font, w: float, h: float, ink: Color) -> void:
	var values: Array = spec.get("values", [])
	var labels: Array = spec.get("labels", [])
	var budget := float(spec.get("budget", 100))
	var vmax := budget * 1.2
	for v in values:
		vmax = maxf(vmax, float(v) * 1.1)
	var x0 := 90.0
	var y0 := h - 90.0
	var gh := h - 230.0
	var gw := w - 150.0
	draw_line(Vector2(x0, y0), Vector2(x0 + gw, y0), MUTED, 3)
	draw_line(Vector2(x0, y0), Vector2(x0, y0 - gh), MUTED, 3)
	var n := maxi(1, values.size())
	var bw := gw / n * 0.6
	for i in values.size():
		var v := float(values[i])
		var bh := gh * v / vmax
		var bx := x0 + gw / n * (i + 0.2)
		var col := BLUE if v <= budget else RED
		draw_rect(Rect2(bx, y0 - bh, bw, bh), col)
		draw_string(fb, Vector2(bx - 20, y0 - bh - 12), str(int(v)), HORIZONTAL_ALIGNMENT_CENTER, bw + 40, 24, ink)
		if i < labels.size():
			draw_string(f, Vector2(bx - 30, y0 + 34), str(labels[i]), HORIZONTAL_ALIGNMENT_CENTER, bw + 60, 22, MUTED)
	var by := y0 - gh * budget / vmax
	var dash := 0.0
	while dash < gw:
		draw_line(Vector2(x0 + dash, by), Vector2(x0 + minf(dash + 18, gw), by), GREEN, 4)
		dash += 30
	draw_string(fb, Vector2(x0 + gw - 220, by - 12), str(spec.get("budget_label", "Budget")), HORIZONTAL_ALIGNMENT_RIGHT, 220, 22, GREEN)
	if spec.has("note"):
		_sticky(f, Vector2(w - 330, 110), str(spec["note"]))


func _draw_line(f: Font, fb: Font, w: float, h: float, ink: Color) -> void:
	var values: Array = spec.get("values", [])
	var labels: Array = spec.get("labels", [])
	var vmin := 0.0
	var vmax := 1.0
	for v in values:
		vmin = minf(vmin, float(v))
		vmax = maxf(vmax, float(v))
	vmax += 5.0
	vmin -= 5.0
	var x0 := 100.0
	var y_top := 130.0
	var y_bot := h - 90.0
	var gw := w - 160.0
	var zero_y := lerpf(y_bot, y_top, (0.0 - vmin) / (vmax - vmin))
	draw_line(Vector2(x0, zero_y), Vector2(x0 + gw, zero_y), MUTED, 2)
	draw_string(f, Vector2(20, zero_y + 8), "0%", HORIZONTAL_ALIGNMENT_RIGHT, 70, 20, MUTED)
	var pts := PackedVector2Array()
	for i in values.size():
		var x := x0 + gw * float(i) / maxf(1.0, values.size() - 1)
		var y := lerpf(y_bot, y_top, (float(values[i]) - vmin) / (vmax - vmin))
		pts.append(Vector2(x, y))
		if i < labels.size():
			draw_string(f, Vector2(x - 40, h - 50), str(labels[i]), HORIZONTAL_ALIGNMENT_CENTER, 80, 20, MUTED)
	if pts.size() > 1:
		draw_polyline(pts, RED, 7, true)
	for i in pts.size():
		draw_circle(pts[i], 9, RED)
		draw_string(fb, pts[i] + Vector2(-40, -18), "%d%%" % int(values[i]), HORIZONTAL_ALIGNMENT_CENTER, 80, 22, ink)
	if spec.has("note"):
		_sticky(f, Vector2(w - 330, 110), str(spec["note"]))
	if spec.has("arrow_note"):
		# the manager's hand-drawn optimism
		var a := Vector2(w * 0.32, h * 0.62)
		draw_line(a, a + Vector2(70, -150), GREEN, 8)
		draw_line(a + Vector2(70, -150), a + Vector2(40, -120), GREEN, 8)
		draw_line(a + Vector2(70, -150), a + Vector2(92, -114), GREEN, 8)
		draw_string(fb, a + Vector2(90, -150), str(spec["arrow_note"]), HORIZONTAL_ALIGNMENT_LEFT, 260, 30, GREEN)


func _draw_risk(f: Font, fb: Font, w: float, h: float, ink: Color) -> void:
	var rows: Array = spec.get("rows", [])
	var y := 140.0
	for row in rows:
		var sev := str(row.get("sev", "low"))
		var col := GREEN
		if sev == "med":
			col = AMBER
		elif sev == "high":
			col = RED
		draw_rect(Rect2(36, y - 26, w - 72, 50), Color(0, 0, 0, 0.04))
		draw_rect(Rect2(36, y - 26, 12, 50), col)
		draw_string(f, Vector2(64, y + 8), str(row.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, w - 260, 24, ink)
		draw_string(fb, Vector2(w - 190, y + 8), sev.to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, 140, 22, col)
		y += 62


func _draw_code(f: Font, w: float, h: float) -> void:
	var cols := [Color("7fd1ff"), Color("ffb86c"), Color("8be28b"), Color("ff7eb6"), Color("c6c6d0")]
	var y := 30.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", 3))
	while y < h - 10:
		var x := 24.0 + rng.randi_range(0, 4) * 24.0
		var segs := rng.randi_range(1, 4)
		for s in segs:
			var seg_len := rng.randf_range(30, 140)
			draw_rect(Rect2(x, y, seg_len, 10), cols[rng.randi_range(0, cols.size() - 1)])
			x += seg_len + 14
		y += 22
	if spec.has("caption"):
		draw_rect(Rect2(0, h - 60, w, 60), Color(0, 0, 0, 0.55))
		draw_string(f, Vector2(0, h - 22), str(spec["caption"]), HORIZONTAL_ALIGNMENT_CENTER, w, 26, Color.WHITE)


func _draw_ui(f: Font, fb: Font, w: float, h: float) -> void:
	var accent := Color(str(spec.get("accent", "#3d7be0")))
	draw_rect(Rect2(0, 0, w, 50), accent)
	draw_string(fb, Vector2(20, 34), str(spec.get("app", "Monolith ERP")), HORIZONTAL_ALIGNMENT_LEFT, w, 24, Color.WHITE)
	draw_rect(Rect2(0, 50, 150, h - 50), Color("e9edf3"))
	for i in 7:
		draw_rect(Rect2(16, 76 + i * 40, 110, 14), Color("c3cbd8"))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", 7))
	for r in 9:
		var y := 80.0 + r * 42.0
		draw_rect(Rect2(170, y, w - 200, 30), Color(1, 1, 1) if r % 2 == 0 else Color("f4f6f9"))
		for c in 4:
			draw_rect(Rect2(180 + c * (w - 220) / 4.0, y + 9, rng.randf_range(40, 120), 12), Color("9aa6b8"))
	if spec.has("caption"):
		draw_string(fb, Vector2(170, h - 20), str(spec["caption"]), HORIZONTAL_ALIGNMENT_LEFT, w - 180, 22, Color("e85d5d"))


func _sticky(f: Font, pos: Vector2, text: String) -> void:
	var r := Rect2(pos, Vector2(290, 150))
	draw_rect(Rect2(pos + Vector2(6, 8), r.size), Color(0, 0, 0, 0.15))
	draw_rect(r, Color("ffe066"))
	var lines := text.split("\n")
	var y := pos.y + 46
	for l in lines:
		draw_string(f, Vector2(pos.x + 18, y), l, HORIZONTAL_ALIGNMENT_LEFT, 260, 26, Color("5a4a10"))
		y += 34
