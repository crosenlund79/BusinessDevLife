class_name UIKit
extends RefCounted
## Shared look & feel: warm paper panels, navy ink, rounded corners, soft
## shadows and chunky friendly buttons. Builds the global Theme in code so the
## whole UI stays consistent and easy to restyle.

const PAPER := Color("fff8ec")
const PAPER_DARK := Color("f3e7d3")
const INK := Color("24324a")
const MUTED := Color("6b7890")
const NAVY := Color("2b3a55")
const ORANGE := Color("f28c28")
const YELLOW := Color("ffb627")
const TEAL := Color("2bb3a3")
const CORAL := Color("e85d5d")
const GREEN := Color("2fae5c")
const SHADOW := Color(0.1, 0.08, 0.05, 0.28)

const FONT_FAMILIES := ["Nunito", "Nunito Sans", "Quicksand", "Baloo 2", "Fredoka", "Poppins", "Segoe UI", "Helvetica Neue", "Arial", "Liberation Sans", "DejaVu Sans", "sans-serif"]
const DISPLAY_FAMILIES := ["Fredoka One", "Fredoka", "Baloo 2", "Lilita One", "Luckiest Guy", "Arial Rounded MT Bold", "Nunito", "Segoe UI Black", "Arial Black", "DejaVu Sans", "sans-serif"]

static var _fonts: Dictionary = {}


static func font(weight := 600) -> Font:
	var key := "ui%d" % weight
	if not _fonts.has(key):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(FONT_FAMILIES)
		f.font_weight = weight
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.allow_system_fallback = true
		_fonts[key] = f
	return _fonts[key]


static func display_font() -> Font:
	if not _fonts.has("display"):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(DISPLAY_FAMILIES)
		f.font_weight = 900
		f.allow_system_fallback = true
		_fonts["display"] = f
	return _fonts["display"]


static func panel_style(bg := PAPER, radius := 18, shadow := 14, border := Color(0, 0, 0, 0), border_w := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.shadow_color = SHADOW
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(0, 5)
	sb.set_content_margin_all(16)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.anti_aliasing = true
	return sb


static func button_style(bg: Color, radius := 14, pressed := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	sb.border_color = bg.darkened(0.25)
	sb.border_width_bottom = 1 if pressed else 4
	sb.shadow_color = Color(0, 0, 0, 0.12)
	sb.shadow_size = 0 if pressed else 4
	sb.shadow_offset = Vector2(0, 2)
	return sb


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(600)
	t.default_font_size = 20
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	_style_button(t, "Button", PAPER_DARK, INK)
	t.set_color("font_color", "RichTextLabel", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("normal_font", "RichTextLabel", font(600))
	t.set_font("bold_font", "RichTextLabel", font(800))
	t.set_font_size("normal_font_size", "RichTextLabel", 20)
	t.set_font_size("bold_font_size", "RichTextLabel", 20)
	# sliders
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color("e2d4bd")
	groove.set_corner_radius_all(6)
	groove.content_margin_top = 4
	groove.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", groove)
	var fill: StyleBoxFlat = groove.duplicate()
	fill.bg_color = ORANGE
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _dot_icon(ORANGE.darkened(0.1), 13))
	t.set_icon("grabber_highlight", "HSlider", _dot_icon(YELLOW, 14))
	# scroll bars
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color(0, 0, 0, 0.05)
	sbg.set_corner_radius_all(6)
	t.set_stylebox("scroll", "VScrollBar", sbg)
	var sgr := StyleBoxFlat.new()
	sgr.bg_color = Color(0.2, 0.25, 0.35, 0.35)
	sgr.set_corner_radius_all(6)
	sgr.content_margin_left = 5
	sgr.content_margin_right = 5
	t.set_stylebox("grabber", "VScrollBar", sgr)
	t.set_stylebox("grabber_highlight", "VScrollBar", sgr)
	t.set_stylebox("grabber_pressed", "VScrollBar", sgr)
	# tooltip
	t.set_stylebox("panel", "TooltipPanel", panel_style(NAVY, 10, 6))
	t.set_color("font_color", "TooltipLabel", Color.WHITE)
	return t


static func _style_button(t: Theme, type: String, bg: Color, fg: Color) -> void:
	t.set_stylebox("normal", type, button_style(bg))
	t.set_stylebox("hover", type, button_style(bg.lightened(0.12)))
	t.set_stylebox("pressed", type, button_style(bg.darkened(0.08), 14, true))
	t.set_stylebox("disabled", type, button_style(bg.lerp(Color.GRAY, 0.5)))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(14)
	focus.border_color = ORANGE
	focus.set_border_width_all(3)
	t.set_stylebox("focus", type, focus)
	t.set_color("font_color", type, fg)
	t.set_color("font_hover_color", type, fg)
	t.set_color("font_pressed_color", type, fg)
	t.set_color("font_focus_color", type, fg)
	t.set_font_size("font_size", type, 20)


static func _dot_icon(col: Color, r: int) -> ImageTexture:
	var img := Image.create(r * 2 + 2, r * 2 + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(r + 1, r + 1)
	for y in img.get_height():
		for x in img.get_width():
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r:
				var edge := clampf(r - d, 0.0, 1.0)
				var cc := col if d < r - 3 else Color.WHITE
				img.set_pixel(x, y, Color(cc.r, cc.g, cc.b, edge))
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- factories

static func label(text: String, size := 20, color := INK, weight := 600) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if weight != 600:
		l.add_theme_font_override("font", font(weight))
	return l


static func title_label(text: String, size := 48, color := Color.WHITE, outline := NAVY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", display_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", int(size * 0.22))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", int(size * 0.08))
	return l


static func button(text: String, bg := PAPER_DARK, fg := INK, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_stylebox_override("normal", button_style(bg))
	b.add_theme_stylebox_override("hover", button_style(bg.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", button_style(bg.darkened(0.08), 14, true))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font(800))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.mouse_entered.connect(func(): Audio.sfx("hover", -10.0, 1.0, 0.1))
	b.pressed.connect(func(): Audio.sfx("click", -4.0, 1.0, 0.05))
	return b


static func panel(bg := PAPER, radius := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, radius))
	return p


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func rich(text: String, size := 20) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_override("normal_font", font(600))
	r.add_theme_font_override("bold_font", font(800))
	r.add_theme_color_override("default_color", INK)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


## Small coloured circle with initials, used as chat/email avatars.
static func avatar(initials: String, col: Color, size := 40) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(size / 2)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(size, size)
	var l := label(initials, int(size * 0.4), Color.WHITE, 800)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static func spacer(h := 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
