class_name UIRoot
extends CanvasLayer
## Owns every 2D layer: HUD (objective, clock, reputation, phone), hover
## tooltip, notifications, dialogue, laptop, work panels, video calls,
## captions, title screen, settings and pause menu.

signal start_pressed
signal restart_requested

var world: Node   # World (3D prototype) or Diorama (paper prototype)
var paper := false
var defs: Dictionary = {}
var dialogue: DialogueBox
var desktop: Desktop
var work: WorkPanels

var _hud: Control
var _objective_card: PanelContainer
var _objective_label: Label
var _clock_label: Label
var _rep_label: Label
var _phone_btn: Button
var _phone_badge: PanelContainer
var _phone_level := 0
var _phone_t := 0.0
var _embers: CPUParticles2D
var _phone_glow: Panel
var _tooltip: PanelContainer
var _tooltip_label: Label
var _toasts: VBoxContainer
var _caption: Control
var _fade: ColorRect
var _title: Control
var _settings: Control
var _pause: Control
var _call: Control
var _call_studio: PortraitStudio
var _call_name: Label
var _notifications: Array = []
var _phone_panel: PanelContainer
var _phone_list: VBoxContainer
var _hint: Label


func build(w: Node, character_defs: Dictionary, paper_mode := false) -> void:
	world = w
	defs = character_defs
	paper = paper_mode
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.name = "UI"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.make_theme()
	add_child(root)
	_build_hud(root)
	_build_tooltip(root)
	_build_toasts(root)
	dialogue = DialogueBox.new()
	root.add_child(dialogue)
	dialogue.world = world
	if paper:
		var pp := PaperPortrait.new()
		dialogue.build(defs, pp)
	else:
		dialogue.build(defs)
	desktop = Desktop.new()
	root.add_child(desktop)
	desktop.build()
	work = WorkPanels.new()
	root.add_child(work)
	work.build()
	if not paper:
		_build_call(root)   # the 3D video-call studio is only needed by the 3D prototype
	_build_caption(root)
	_build_title(root)
	_build_settings(root)
	_build_pause(root)
	_fade = ColorRect.new()
	_fade.color = Color(0.06, 0.07, 0.1, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	world.hover_changed.connect(_on_hover)
	Game.objective_changed.connect(_on_objective)
	Game.clock_changed.connect(func(t): _clock_label.text = Loc.t("ui.clock", {"time": t}))
	Game.stats_changed.connect(_refresh_rep)
	_refresh_rep()
	set_hud_visible(false)


# ================================================================== HUD

func _build_hud(root: Control) -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hud)
	# objective card (top-left)
	_objective_card = UIKit.panel(UIKit.PAPER, 16)
	_objective_card.position = Vector2(24, 22)
	_objective_card.custom_minimum_size = Vector2(380, 0)
	_hud.add_child(_objective_card)
	var ov := UIKit.vbox(2)
	_objective_card.add_child(ov)
	ov.add_child(UIKit.label(Loc.t("ui.today"), 14, UIKit.ORANGE, 900))
	_objective_label = UIKit.label("", 20, UIKit.INK, 800)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size = Vector2(350, 0)
	ov.add_child(_objective_label)
	# clock + reputation (top-right)
	var status_card := UIKit.panel(UIKit.NAVY, 16)
	status_card.anchor_left = 1.0
	status_card.anchor_right = 1.0
	status_card.offset_left = -330
	status_card.offset_right = -24
	status_card.offset_top = 22
	_hud.add_child(status_card)
	var tv := UIKit.vbox(0)
	status_card.add_child(tv)
	_clock_label = UIKit.label(Loc.t("ui.clock", {"time": Game.clock}), 20, Color.WHITE, 900)
	tv.add_child(_clock_label)
	_rep_label = UIKit.label("", 17, UIKit.YELLOW, 800)
	tv.add_child(_rep_label)
	# menu hint (bottom-left)
	var hint := UIKit.label(Loc.t("ui.controls_hint"), 14, Color(1, 1, 1, 0.9), 700)
	_hint = hint
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	hint.add_theme_constant_override("shadow_offset_y", 2)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 24
	hint.offset_top = -40
	_hud.add_child(hint)
	# phone (bottom-right)
	_phone_glow = Panel.new()
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(1, 0.3, 0.1, 0.0)
	gsb.set_corner_radius_all(40)
	gsb.shadow_color = Color(1, 0.25, 0.05, 0.0)
	gsb.shadow_size = 40
	_phone_glow.add_theme_stylebox_override("panel", gsb)
	_phone_glow.anchor_left = 1.0
	_phone_glow.anchor_right = 1.0
	_phone_glow.anchor_top = 1.0
	_phone_glow.anchor_bottom = 1.0
	_phone_glow.offset_left = -126
	_phone_glow.offset_right = -36
	_phone_glow.offset_top = -176
	_phone_glow.offset_bottom = -36
	_phone_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_phone_glow)
	_phone_btn = Button.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color("1d2230")
	psb.set_corner_radius_all(18)
	psb.border_color = Color("3b4458")
	psb.set_border_width_all(4)
	psb.shadow_color = UIKit.SHADOW
	psb.shadow_size = 10
	_phone_btn.add_theme_stylebox_override("normal", psb)
	var psh: StyleBoxFlat = psb.duplicate()
	psh.border_color = UIKit.YELLOW
	_phone_btn.add_theme_stylebox_override("hover", psh)
	_phone_btn.add_theme_stylebox_override("pressed", psh)
	_phone_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_phone_btn.anchor_left = 1.0
	_phone_btn.anchor_right = 1.0
	_phone_btn.anchor_top = 1.0
	_phone_btn.anchor_bottom = 1.0
	_phone_btn.offset_left = -120
	_phone_btn.offset_right = -42
	_phone_btn.offset_top = -170
	_phone_btn.offset_bottom = -42
	_phone_btn.pivot_offset = Vector2(39, 64)
	_phone_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_phone_btn.tooltip_text = Loc.t("ui.phone_tip")
	_phone_btn.pressed.connect(_toggle_phone_panel)
	_hud.add_child(_phone_btn)
	var screen := ColorRect.new()
	screen.color = Color("4aa8ff")
	screen.position = Vector2(12, 14)
	screen.size = Vector2(54, 92)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone_btn.add_child(screen)
	var logo := UIKit.label("◆", 26, Color.WHITE, 900)
	logo.position = Vector2(26, 36)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone_btn.add_child(logo)
	_phone_btn.text = ""
	_phone_badge = UIKit.avatar("0", UIKit.CORAL, 30)
	_phone_badge.position = Vector2(58, -12)
	_phone_badge.visible = false
	_phone_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone_btn.add_child(_phone_badge)
	_embers = CPUParticles2D.new()
	_embers.amount = 40
	_embers.lifetime = 1.2
	_embers.emitting = false
	_embers.position = Vector2(39, 20)
	_embers.direction = Vector2(0, -1)
	_embers.spread = 60.0
	_embers.gravity = Vector2(0, -120)
	_embers.initial_velocity_min = 60.0
	_embers.initial_velocity_max = 160.0
	_embers.scale_amount_min = 3.0
	_embers.scale_amount_max = 7.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	grad.set_color(1, Color(1.0, 0.2, 0.05, 0.0))
	_embers.color_ramp = grad
	_phone_btn.add_child(_embers)
	# phone notification list
	_phone_panel = UIKit.panel(Color("1d2230"), 18)
	_phone_panel.anchor_left = 1.0
	_phone_panel.anchor_right = 1.0
	_phone_panel.anchor_top = 1.0
	_phone_panel.anchor_bottom = 1.0
	_phone_panel.offset_left = -470
	_phone_panel.offset_right = -140
	_phone_panel.offset_top = -470
	_phone_panel.offset_bottom = -42
	_phone_panel.visible = false
	_hud.add_child(_phone_panel)
	var pv := UIKit.vbox(8)
	_phone_panel.add_child(pv)
	pv.add_child(UIKit.label(Loc.t("ui.phone_title"), 18, Color.WHITE, 900))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pv.add_child(scroll)
	_phone_list = UIKit.vbox(6)
	_phone_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_phone_list)


func set_controls_hint(text: String) -> void:
	_hint.text = text


func set_hud_visible(on: bool) -> void:
	_hud.visible = on


func _on_objective(text: String) -> void:
	if text == "":
		_objective_card.visible = false
		return
	_objective_card.visible = true
	_objective_label.text = text
	_objective_card.pivot_offset = Vector2(0, 30)
	_objective_card.scale = Vector2(1.08, 1.08)
	_objective_card.modulate = Color(1.0, 0.9, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_objective_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_objective_card, "modulate", Color.WHITE, 0.6)
	Audio.sfx("notify", -10.0, 0.8)


func _refresh_rep() -> void:
	var r := int(Game.stats.get("reputation", 1))
	var s := ""
	for i in 5:
		s += "★" if i < r else "☆"
	_rep_label.text = Loc.t("ui.reputation") + "  " + s


## Escalation phone: 0 calm, 1 buzzing, 2 hot, 3 on fire.
func set_phone_level(level: int) -> void:
	_phone_level = level
	_embers.emitting = level >= 3
	var sb: StyleBoxFlat = _phone_glow.get_theme_stylebox("panel")
	var a: float = [0.0, 0.0, 0.35, 0.8][clampi(level, 0, 3)]
	sb.shadow_color = Color(1, 0.25, 0.05, a)
	sb.bg_color = Color(1, 0.3, 0.1, a * 0.4)
	var screen: ColorRect = _phone_btn.get_child(0)
	screen.color = Color("4aa8ff") if level < 2 else (Color("ff8a3d") if level == 2 else Color("ff3b2f"))
	if world:
		world.phone_buzz(level)


func _process(delta: float) -> void:
	if _phone_level > 0:
		_phone_t += delta
		var amp := 0.04 * _phone_level
		_phone_btn.rotation = sin(_phone_t * (30.0 + _phone_level * 10.0)) * amp
		_phone_btn.scale = Vector2.ONE * (1.0 + absf(sin(_phone_t * 4.0)) * 0.04 * _phone_level)
	else:
		_phone_btn.rotation = lerpf(_phone_btn.rotation, 0.0, minf(1.0, delta * 8.0))
		_phone_btn.scale = Vector2.ONE
	if _tooltip.visible:
		_tooltip.position = get_viewport().get_mouse_position() + Vector2(22, 18)


func _toggle_phone_panel() -> void:
	_phone_panel.visible = not _phone_panel.visible
	if _phone_panel.visible:
		for c in _phone_list.get_children():
			c.queue_free()
		if _notifications.is_empty():
			_phone_list.add_child(UIKit.label(Loc.t("ui.phone_empty"), 15, Color("a9b4c7"), 700))
		for n in _notifications:
			var card := UIKit.panel(Color("2a3142"), 12)
			var v := UIKit.vbox(2)
			card.add_child(v)
			v.add_child(UIKit.label(str(n["app"]) + " · " + str(n["from"]), 13, n["color"], 900))
			var l := UIKit.label(str(n["text"]), 15, Color.WHITE, 700)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(280, 0)
			v.add_child(l)
			_phone_list.add_child(card)
		_phone_badge.visible = false


# ================================================================== tooltip & toasts

func _build_tooltip(root: Control) -> void:
	_tooltip = UIKit.panel(UIKit.NAVY, 10)
	var sb := UIKit.panel_style(UIKit.NAVY, 10, 6)
	sb.set_content_margin_all(10)
	_tooltip.add_theme_stylebox_override("panel", sb)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	root.add_child(_tooltip)
	_tooltip_label = UIKit.label("", 17, Color.WHITE, 800)
	_tooltip.add_child(_tooltip_label)


func _on_hover(text: String) -> void:
	_tooltip.visible = text != "" and not Game.input_locked
	_tooltip_label.text = text
	_tooltip.size = Vector2.ZERO


func _build_toasts(root: Control) -> void:
	_toasts = UIKit.vbox(10)
	_toasts.anchor_left = 1.0
	_toasts.anchor_right = 1.0
	_toasts.offset_left = -440
	_toasts.offset_right = -24
	_toasts.offset_top = 120
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)


## A slide-in notification from one of the fictional apps.
func toast(app: String, from: String, text: String, color := Color("3d7be0"), urgent := false) -> void:
	_notifications.push_front({"app": app, "from": from, "text": text, "color": color})
	if not _phone_panel.visible:
		_phone_badge.visible = true
		var l: Label = _phone_badge.get_child(0)
		l.text = str(mini(99, _notifications.size()))
	var card := PanelContainer.new()
	var sb := UIKit.panel_style(Color.WHITE, 14, 10)
	sb.border_color = UIKit.CORAL if urgent else color
	sb.border_width_left = 8
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(2)
	card.add_child(v)
	v.add_child(UIKit.label(app.to_upper() + "  ·  " + from, 13, UIKit.CORAL if urgent else color, 900))
	var t := UIKit.label(text, 17, UIKit.INK, 700)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(380, 0)
	v.add_child(t)
	_toasts.add_child(card)
	card.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(card, "modulate", Color.WHITE, 0.2)
	tw.tween_interval(5.0)
	tw.tween_property(card, "modulate", Color(1, 1, 1, 0), 0.4)
	tw.tween_callback(card.queue_free)
	Audio.sfx("notify", -4.0)


# ================================================================== video call

func _build_call(root: Control) -> void:
	_call = Control.new()
	_call.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_call.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_call.visible = false
	root.add_child(_call)
	var p := UIKit.panel(Color("1d2230"), 22)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.offset_left = -330
	p.offset_right = 330
	p.offset_top = 40
	p.offset_bottom = 560
	_call.add_child(p)
	var v := UIKit.vbox(8)
	p.add_child(v)
	var top := UIKit.hbox(10)
	v.add_child(top)
	var live := UIKit.panel(UIKit.CORAL, 8)
	live.add_child(UIKit.label("● " + Loc.t("call.live"), 14, Color.WHITE, 900))
	top.add_child(live)
	_call_name = UIKit.label("", 18, Color.WHITE, 900)
	_call_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_call_name)
	top.add_child(UIKit.label(Loc.t("call.quality"), 13, Color("a9b4c7"), 700))
	_call_studio = PortraitStudio.new()
	_call_studio.font = UIKit.font(800)
	_call.add_child(_call_studio)
	_call_studio.setup(560, defs, true, Color("d9c7a8"))
	_call_studio.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color.BLACK
	fsb.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.custom_minimum_size = Vector2(620, 380)
	v.add_child(frame)
	var tex := TextureRect.new()
	tex.texture = _call_studio.get_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.add_child(tex)
	var row := UIKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	row.add_child(UIKit.button("🎤  " + Loc.t("call.mute"), Color("2e3646"), Color.WHITE, 15))
	var hang := UIKit.button(Loc.t("call.hangup"), UIKit.CORAL, Color.WHITE, 15)
	hang.pressed.connect(func(): toast("Natter", Loc.t("call.system"), Loc.t("call.no_hangup"), Color("7a4fd1")))
	row.add_child(hang)


func show_call(id: String) -> Character:
	if _call == null:
		return null
	_call_studio.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_call.visible = true
	_call_name.text = Loc.t("call.with", {"name": str(defs.get(id, {}).get("name", id))})
	var c := _call_studio.show_char(id)
	_call.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(_call, "modulate", Color.WHITE, 0.3)
	Audio.sfx("bell", -6.0, 0.8)
	return c


func call_char(id: String) -> Character:
	return _call_studio.get_char(id) if _call_studio else null


func call_shake(amount: float) -> void:
	if _call_studio:
		_call_studio.shake = amount


func hide_call() -> void:
	if _call == null:
		return
	var tw := create_tween()
	tw.tween_property(_call, "modulate", Color(1, 1, 1, 0), 0.3)
	tw.tween_callback(_on_call_hidden)


func _on_call_hidden() -> void:
	_call.visible = false
	_call_studio.render_target_update_mode = SubViewport.UPDATE_DISABLED


# ================================================================== captions & fades

func _build_caption(root: Control) -> void:
	_caption = Control.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.visible = false
	root.add_child(_caption)


## Big centred time/scene card, e.g. "Monday, 08:57".
func caption(big: String, small := "", hold := 2.2) -> void:
	for c in _caption.get_children():
		c.queue_free()
	_caption.visible = true
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_child(center)
	var v := UIKit.vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var b := UIKit.title_label(big, 64, Color.WHITE, UIKit.NAVY)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	if small != "":
		var chip := UIKit.panel(UIKit.YELLOW, 12)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var s := UIKit.label(small, 24, UIKit.NAVY, 900)
		chip.add_child(s)
		v.add_child(chip)
	_caption.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_caption, "modulate", Color.WHITE, 0.35)
	tw.tween_interval(hold)
	tw.tween_property(_caption, "modulate", Color(1, 1, 1, 0), 0.4)
	await tw.finished
	_caption.visible = false


func fade_out(time := 0.5) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, time)
	await tw.finished


func fade_in(time := 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, time)
	await tw.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func flash(color := Color(1, 1, 1, 0.8)) -> void:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.get_parent().add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.5)
	tw.tween_callback(r.queue_free)


# ================================================================== title screen

func _build_title(root: Control) -> void:
	_title = Control.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_title)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.1, 0.12, 0.2, 0.25)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(shade)
	var v := UIKit.vbox(0)
	v.anchor_left = 0.0
	v.anchor_top = 0.0
	v.offset_left = 80
	v.offset_top = 70
	_title.add_child(v)
	var l1 := UIKit.title_label(Loc.t("title.line1"), 110, Color.WHITE, UIKit.NAVY)
	v.add_child(l1)
	var l2 := UIKit.title_label(Loc.t("title.line2"), 120, UIKit.YELLOW, UIKit.NAVY)
	l2.add_theme_color_override("font_color", Color("ffc233"))
	v.add_child(l2)
	var chip := UIKit.panel(Color("ffe8a3"), 10)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.rotation = -0.03
	chip.add_child(UIKit.label(Loc.t("title.chip"), 30, UIKit.NAVY, 800))
	v.add_child(chip)
	v.add_child(UIKit.spacer(30))
	var buttons := UIKit.vbox(12)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(buttons)
	var start := UIKit.button(Loc.t("title.start"), UIKit.ORANGE, Color.WHITE, 26)
	start.custom_minimum_size = Vector2(380, 64)
	start.pressed.connect(func(): start_pressed.emit())
	buttons.add_child(start)
	var settings := UIKit.button(Loc.t("title.settings"), UIKit.PAPER, UIKit.INK, 22)
	settings.custom_minimum_size = Vector2(380, 54)
	settings.pressed.connect(open_settings)
	buttons.add_child(settings)
	var quit := UIKit.button(Loc.t("title.quit"), UIKit.PAPER_DARK, UIKit.INK, 22)
	quit.custom_minimum_size = Vector2(380, 54)
	quit.pressed.connect(func(): get_tree().quit())
	buttons.add_child(quit)
	var foot := UIKit.label(Loc.t("title.footer"), 15, Color(1, 1, 1, 0.92), 700)
	foot.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	foot.add_theme_constant_override("shadow_offset_y", 2)
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 80
	foot.offset_top = -50
	_title.add_child(foot)
	# a whiteboard-style tagline, nodding to the concept art
	var board := UIKit.panel(Color("fbfaf6"), 8)
	board.anchor_left = 1.0
	board.anchor_right = 1.0
	board.offset_left = -400
	board.offset_right = -80
	board.offset_top = 90
	board.rotation = 0.03
	var bl := UIKit.label(Loc.t("title.board"), 28, Color("2a3550"), 900)
	board.add_child(bl)
	_title.add_child(board)


func show_title(on: bool) -> void:
	_title.visible = on
	if on:
		_title.modulate = Color(1, 1, 1, 0)
		create_tween().tween_property(_title, "modulate", Color.WHITE, 0.8)


# ================================================================== settings & pause

func _build_settings(root: Control) -> void:
	_settings = Control.new()
	_settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings.visible = false
	root.add_child(_settings)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.1, 0.16, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings.add_child(center)
	var p := UIKit.panel(UIKit.PAPER, 22)
	p.custom_minimum_size = Vector2(560, 0)
	center.add_child(p)
	var v := UIKit.vbox(14)
	p.add_child(v)
	v.add_child(UIKit.title_label(Loc.t("settings.title"), 40, UIKit.NAVY, UIKit.PAPER))
	_slider_row(v, Loc.t("settings.music"), "music")
	_slider_row(v, Loc.t("settings.sfx"), "sfx")
	_slider_row(v, Loc.t("settings.text_speed"), "text_speed", 0.4, 2.5)
	var blips := CheckButton.new()
	blips.text = Loc.t("settings.blips")
	blips.button_pressed = bool(Game.settings.get("voice_blips", true))
	blips.toggled.connect(func(on): Game.set_setting("voice_blips", on))
	v.add_child(blips)
	var fs := CheckButton.new()
	fs.text = Loc.t("settings.fullscreen")
	fs.button_pressed = bool(Game.settings.get("fullscreen", false))
	fs.toggled.connect(func(on): Game.set_setting("fullscreen", on))
	v.add_child(fs)
	var lang := UIKit.label(Loc.t("settings.language"), 15, UIKit.MUTED, 700)
	lang.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(lang)
	var close := UIKit.button(Loc.t("ui.close"), UIKit.ORANGE, Color.WHITE, 20)
	close.pressed.connect(func(): _settings.visible = false)
	v.add_child(close)


func _slider_row(v: VBoxContainer, text: String, key: String, lo := 0.0, hi := 1.0) -> void:
	var row := UIKit.hbox(14)
	v.add_child(row)
	var l := UIKit.label(text, 18, UIKit.INK, 800)
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = float(Game.settings.get(key, 1.0))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(val): Game.set_setting(key, val))
	row.add_child(s)


func open_settings() -> void:
	_settings.visible = true


func _build_pause(root: Control) -> void:
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.1, 0.16, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var p := UIKit.panel(UIKit.PAPER, 22)
	p.custom_minimum_size = Vector2(440, 0)
	center.add_child(p)
	var v := UIKit.vbox(12)
	p.add_child(v)
	v.add_child(UIKit.title_label(Loc.t("pause.title"), 40, UIKit.NAVY, UIKit.PAPER))
	var sub := UIKit.label(Loc.t("pause.sub"), 15, UIKit.MUTED, 700)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	var resume := UIKit.button(Loc.t("pause.resume"), UIKit.ORANGE, Color.WHITE, 20)
	resume.pressed.connect(toggle_pause)
	v.add_child(resume)
	var settings := UIKit.button(Loc.t("title.settings"), UIKit.PAPER_DARK, UIKit.INK, 20)
	settings.pressed.connect(open_settings)
	v.add_child(settings)
	var restart := UIKit.button(Loc.t("pause.restart"), UIKit.PAPER_DARK, UIKit.INK, 20)
	restart.pressed.connect(func():
		toggle_pause()
		restart_requested.emit()
	)
	v.add_child(restart)
	var quit := UIKit.button(Loc.t("title.quit"), UIKit.PAPER_DARK, UIKit.INK, 20)
	quit.pressed.connect(func(): get_tree().quit())
	v.add_child(quit)


func toggle_pause() -> void:
	if _title.visible:
		return
	_pause.visible = not _pause.visible
	get_tree().paused = _pause.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _settings.visible:
			_settings.visible = false
		elif desktop.visible and desktop.closable:
			desktop.close()
		elif _phone_panel.visible:
			_phone_panel.visible = false
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
