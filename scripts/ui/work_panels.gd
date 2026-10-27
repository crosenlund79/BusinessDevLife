class_name WorkPanels
extends Control
## The "actual work" mini-interactions, deliberately accessible:
##  • TaskPile handover builder (the requirement → specification step)
##  • Monolith ERP test environment (verification)
##  • The production deploy button (release)
##  • The first-day performance review (consequences & progression)

signal _done(result)

var _layer: Control


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _open_modal(min_size: Vector2, bg := UIKit.PAPER) -> VBoxContainer:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.1, 0.16, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(center)
	var p := UIKit.panel(bg, 22)
	p.custom_minimum_size = min_size
	center.add_child(p)
	var v := UIKit.vbox(12)
	p.add_child(v)
	p.pivot_offset = min_size * 0.5
	p.scale = Vector2(0.94, 0.94)
	p.modulate = Color(1, 1, 1, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate", Color.WHITE, 0.15)
	Audio.sfx("whoosh", -8.0)
	return v


func _close_modal() -> void:
	if _layer:
		_layer.queue_free()
		_layer = null
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _header(v: VBoxContainer, app: String, title: String, sub: String, color: Color) -> void:
	var row := UIKit.hbox(12)
	v.add_child(row)
	var chip := UIKit.panel(color, 10)
	chip.add_child(UIKit.label(app, 16, Color.WHITE, 900))
	row.add_child(chip)
	row.add_child(UIKit.label(title, 26, UIKit.INK, 900))
	var s := UIKit.label(sub, 16, UIKit.MUTED, 600)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(s)


# ============================================================ handover builder

## notes: [{id, t, src, color, good}] → returns {"selected": [...], "estimate": "..."}
func spec_builder(notes: Array, estimates: Array) -> Dictionary:
	var v := _open_modal(Vector2(1180, 680))
	_header(v, "TaskPile", Loc.t("spec.title"), Loc.t("spec.sub"), Color("2fae5c"))
	var cols := UIKit.hbox(18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	# left: collected notes
	var left := UIKit.vbox(8)
	left.custom_minimum_size = Vector2(540, 0)
	cols.add_child(left)
	left.add_child(UIKit.label(Loc.t("spec.notes"), 18, UIKit.MUTED, 900))
	var selected := {}
	var preview := UIKit.vbox(6)
	var toggles: Array = []
	for n in notes:
		var b := Button.new()
		b.toggle_mode = true
		b.text = "  " + str(n["t"]) + "   — " + str(n["src"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UIKit.font(700))
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_stylebox_override("normal", UIKit.button_style(Color("fffdf6")))
		b.add_theme_stylebox_override("hover", UIKit.button_style(Color("fff3d6")))
		b.add_theme_stylebox_override("pressed", UIKit.button_style(Color("c9f0d5"), 14, true))
		b.add_theme_stylebox_override("hover_pressed", UIKit.button_style(Color("b9e8c8"), 14, true))
		b.add_theme_color_override("font_color", UIKit.INK)
		b.add_theme_color_override("font_pressed_color", UIKit.INK)
		b.add_theme_color_override("font_hover_color", UIKit.INK)
		b.add_theme_color_override("font_hover_pressed_color", UIKit.INK)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var nid := str(n["id"])
		b.toggled.connect(func(on):
			if on:
				selected[nid] = n
			else:
				selected.erase(nid)
			Audio.sfx("page" if on else "click", -6.0)
			_render_preview(preview, selected)
		)
		left.add_child(b)
		toggles.append(b)
	# right: the specification document
	var doc := UIKit.panel(Color.WHITE, 12)
	doc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(doc)
	var dv := UIKit.vbox(8)
	doc.add_child(dv)
	dv.add_child(UIKit.label(Loc.t("spec.doc_title"), 20, UIKit.INK, 900))
	dv.add_child(UIKit.label(Loc.t("spec.doc_meta"), 14, UIKit.MUTED, 700))
	dv.add_child(HSeparator.new())
	dv.add_child(UIKit.label(Loc.t("spec.doc_requirements"), 16, UIKit.MUTED, 900))
	dv.add_child(preview)
	_render_preview(preview, selected)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(fill)
	dv.add_child(UIKit.label(Loc.t("spec.estimate"), 16, UIKit.MUTED, 900))
	var est_row := UIKit.hbox(8)
	dv.add_child(est_row)
	var est_group := ButtonGroup.new()
	var chosen := {"estimate": str(estimates[0]["id"])}
	for e in estimates:
		var eb := UIKit.button(str(e["t"]), Color("eef3fb"), UIKit.INK, 15)
		eb.toggle_mode = true
		eb.button_group = est_group
		eb.add_theme_stylebox_override("pressed", UIKit.button_style(Color("ffd98a"), 14, true))
		var eid := str(e["id"])
		eb.pressed.connect(func(): chosen["estimate"] = eid)
		if eid == chosen["estimate"]:
			eb.button_pressed = true
		est_row.add_child(eb)
	var bottom := UIKit.hbox(10)
	v.add_child(bottom)
	var hint := UIKit.label(Loc.t("spec.hint"), 15, UIKit.MUTED, 600)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(hint)
	var submit := UIKit.button(Loc.t("spec.submit"), UIKit.GREEN, Color.WHITE, 20)
	submit.pressed.connect(func():
		if selected.is_empty():
			Audio.sfx("bonk", -6.0)
			hint.text = Loc.t("spec.empty")
			hint.add_theme_color_override("font_color", UIKit.CORAL)
			return
		_done.emit({"selected": selected.keys(), "estimate": chosen["estimate"]})
	)
	bottom.add_child(submit)
	var result: Dictionary = await _done
	Audio.sfx("kaching", -6.0)
	_close_modal()
	return result


func _render_preview(box: VBoxContainer, selected: Dictionary) -> void:
	for c in box.get_children():
		c.queue_free()
	if selected.is_empty():
		box.add_child(UIKit.label(Loc.t("spec.doc_empty"), 16, Color("b0b8c4"), 600))
		return
	var i := 1
	for k in selected:
		var l := UIKit.label("%d.  %s" % [i, str(selected[k]["t"])], 17, UIKit.INK, 700)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
		i += 1


# ============================================================ ERP test environment

## variant: "good" | "bad". Returns what the player tested and noticed.
func erp_test(variant: String, ai_tooltip: bool) -> Dictionary:
	var v := _open_modal(Vector2(1180, 700), Color("f7f8fb"))
	var res := {"approve": false, "delete": false, "warning": false, "flagged": false}
	_header(v, "Monolith ERP 11", Loc.t("erp.title"), Loc.t("erp.sub"), Color("3d7be0"))
	var cols := UIKit.hbox(18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	# --- fake ERP screen
	var screen := UIKit.panel(Color.WHITE, 12)
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(screen)
	var sv := UIKit.vbox(10)
	screen.add_child(sv)
	var banner := UIKit.panel(Color("ffe8a3"), 8)
	banner.add_child(UIKit.label(Loc.t("erp.test_banner"), 15, Color("6a4a00"), 900))
	sv.add_child(banner)
	sv.add_child(UIKit.label(Loc.t("erp.screen_title"), 22, UIKit.INK, 900))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	sv.add_child(grid)
	for pair in Loc.get_data("erp.fields"):
		grid.add_child(UIKit.label(str(pair[0]), 16, UIKit.MUTED, 800))
		var field := UIKit.panel(Color("f2f4f8"), 6)
		field.custom_minimum_size = Vector2(320, 0)
		field.add_child(UIKit.label(str(pair[1]), 16, UIKit.INK, 700))
		grid.add_child(field)
	sv.add_child(UIKit.spacer(10))
	var status := UIKit.label(Loc.t("erp.status_idle"), 17, UIKit.MUTED, 800)
	var btn_row := UIKit.hbox(8)
	sv.add_child(btn_row)
	var green := Color("2fae5c")
	var red := Color("d64545")
	var approve := UIKit.button(Loc.t("erp.approve"), green, Color.WHITE, 18)
	var delete := UIKit.button(Loc.t("erp.delete"), green if variant == "bad" else red, Color.WHITE, 18)
	var print_btn := UIKit.button(Loc.t("erp.print"), green if variant == "bad" else Color("8a94a6"), Color.WHITE, 18)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(4 if variant == "bad" else 0, 0)
	if variant == "bad":
		btn_row.add_child(approve)
		btn_row.add_child(delete)
		btn_row.add_child(print_btn)
	else:
		btn_row.add_child(approve)
		btn_row.add_child(print_btn)
		var push := Control.new()
		push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_row.add_child(push)
		btn_row.add_child(delete)
	if ai_tooltip:
		approve.tooltip_text = Loc.t("erp.ai_tooltip")
		approve.text += "  ✨"
	sv.add_child(status)
	# warnings chip (collapsed)
	var warn_btn := UIKit.button(Loc.t("erp.warn_chip"), Color("fff3d6"), Color("8a5a00"), 15)
	sv.add_child(warn_btn)
	var warn_text := UIKit.rich(Loc.t("erp.warn_text"), 16)
	warn_text.visible = false
	sv.add_child(warn_text)
	# --- right: test checklist
	var side := UIKit.vbox(10)
	side.custom_minimum_size = Vector2(340, 0)
	cols.add_child(side)
	side.add_child(UIKit.label(Loc.t("erp.checklist"), 18, UIKit.MUTED, 900))
	var c1 := UIKit.label("☐  " + Loc.t("erp.check_approve"), 17, UIKit.INK, 700)
	var c2 := UIKit.label("☐  " + Loc.t("erp.check_delete"), 17, UIKit.INK, 700)
	var c3 := UIKit.label("☐  " + Loc.t("erp.check_warn"), 17, UIKit.INK, 700)
	for c in [c1, c2, c3]:
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.custom_minimum_size = Vector2(320, 0)
		side.add_child(c)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(fill)
	var flag_btn := UIKit.button(Loc.t("erp.flag"), Color("ffd98a"), UIKit.INK, 17)
	flag_btn.visible = false
	side.add_child(flag_btn)
	var release := UIKit.button(Loc.t("erp.release"), UIKit.NAVY, Color.WHITE, 19)
	side.add_child(release)

	approve.pressed.connect(func():
		res["approve"] = true
		c1.text = "☑  " + Loc.t("erp.check_approve")
		c1.add_theme_color_override("font_color", UIKit.GREEN)
		status.text = Loc.t("erp.status_approved")
		status.add_theme_color_override("font_color", UIKit.GREEN)
		Audio.sfx("tada", -10.0)
	)
	delete.pressed.connect(func():
		res["delete"] = true
		c2.text = "☑  " + Loc.t("erp.check_delete")
		c2.add_theme_color_override("font_color", UIKit.GREEN)
		status.text = Loc.t("erp.status_deleted_bad" if variant == "bad" else "erp.status_deleted")
		status.add_theme_color_override("font_color", UIKit.CORAL)
		Audio.sfx("sad_trombone" if variant == "bad" else "pop", -8.0)
	)
	print_btn.pressed.connect(func():
		status.text = Loc.t("erp.status_print")
		status.add_theme_color_override("font_color", UIKit.MUTED)
	)
	warn_btn.pressed.connect(func():
		res["warning"] = true
		warn_text.visible = true
		flag_btn.visible = true
		c3.text = "☑  " + Loc.t("erp.check_warn")
		c3.add_theme_color_override("font_color", UIKit.GREEN)
		Audio.sfx("page", -6.0)
	)
	flag_btn.pressed.connect(func():
		res["flagged"] = true
		flag_btn.disabled = true
		flag_btn.text = Loc.t("erp.flagged")
	)
	release.pressed.connect(func(): _done.emit(res))
	var result: Dictionary = await _done
	_close_modal()
	return result


# ============================================================ deploy

func deploy() -> void:
	var v := _open_modal(Vector2(760, 520), Color("1e2430"))
	var title := UIKit.title_label(Loc.t("deploy.title"), 40, Color.WHITE, Color("0d1118"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UIKit.label(Loc.t("deploy.sub"), 17, Color("a9b4c7"), 700)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(0, 220)
	v.add_child(center)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(260, 200)
	center.add_child(holder)
	var big := Button.new()
	big.text = Loc.t("deploy.button")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("e23b3b")
	sb.set_corner_radius_all(100)
	sb.border_color = Color("8f1d1d")
	sb.border_width_bottom = 12
	sb.shadow_color = Color(1, 0.2, 0.2, 0.45)
	sb.shadow_size = 24
	big.add_theme_stylebox_override("normal", sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color("f04a4a")
	big.add_theme_stylebox_override("hover", sbh)
	var sbp: StyleBoxFlat = sb.duplicate()
	sbp.border_width_bottom = 3
	big.add_theme_stylebox_override("pressed", sbp)
	big.add_theme_font_override("font", UIKit.display_font())
	big.add_theme_font_size_override("font_size", 30)
	big.add_theme_color_override("font_color", Color.WHITE)
	big.position = Vector2(30, 0)
	big.size = Vector2(200, 200)
	big.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	big.disabled = true
	holder.add_child(big)
	# the safety cover (click to lift)
	var cover := Button.new()
	cover.text = Loc.t("deploy.cover")
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.75, 0.85, 1.0, 0.55)
	csb.set_corner_radius_all(30)
	csb.border_color = Color(1, 1, 1, 0.8)
	csb.set_border_width_all(3)
	cover.add_theme_stylebox_override("normal", csb)
	cover.add_theme_stylebox_override("hover", csb)
	cover.add_theme_stylebox_override("pressed", csb)
	cover.add_theme_color_override("font_color", Color("1e2430"))
	cover.add_theme_font_size_override("font_size", 17)
	cover.position = Vector2(10, -10)
	cover.size = Vector2(240, 220)
	cover.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	holder.add_child(cover)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 26)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("2e3646")
	bg.set_corner_radius_all(13)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("2fae5c")
	fg.set_corner_radius_all(13)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	bar.visible = false
	v.add_child(bar)
	var step := UIKit.label("", 18, Color("d6dde9"), 700)
	step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(step)
	cover.pressed.connect(func():
		Audio.sfx("slide_whistle", -8.0)
		var tw := create_tween()
		tw.tween_property(cover, "position", Vector2(10, -260), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(cover.hide)
		big.disabled = false
	)
	big.pressed.connect(func(): _done.emit(true))
	await _done
	Audio.sfx("deploy", -4.0)
	big.disabled = true
	bar.visible = true
	var steps = Loc.get_data("deploy.steps")
	if not (steps is Array):
		steps = ["..."]
	for i in steps.size():
		step.text = str(steps[i])
		var tw := create_tween()
		tw.tween_property(bar, "value", 100.0 * (i + 1) / steps.size(), 0.55)
		Audio.sfx("typing", -16.0)
		await get_tree().create_timer(0.75).timeout
	step.text = Loc.t("deploy.done")
	step.add_theme_color_override("font_color", Color("6ee69a"))
	Audio.sfx("tada", -4.0)
	await get_tree().create_timer(1.4).timeout
	_close_modal()


# ============================================================ performance review

## Returns "again" or "quit".
func review(data: Dictionary) -> String:
	var v := _open_modal(Vector2(1000, 760), Color("fffaf0"))
	var top := UIKit.hbox(14)
	v.add_child(top)
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(col)
	col.add_child(UIKit.label(Loc.t("review.kicker"), 16, UIKit.ORANGE, 900))
	col.add_child(UIKit.title_label(Loc.t("review.title"), 40, UIKit.NAVY, Color("fffaf0")))
	col.add_child(UIKit.label(Loc.t("review.sub"), 15, UIKit.MUTED, 700))
	var stamp := UIKit.panel(Color("2fae5c"), 12)
	stamp.rotation = -0.12
	stamp.add_child(UIKit.label(str(data.get("stamp", "SURVIVED")), 22, Color.WHITE, 900))
	top.add_child(stamp)
	v.add_child(HSeparator.new())
	var rows_box := UIKit.vbox(6)
	v.add_child(rows_box)
	var rows: Array = data.get("rows", [])
	var row_nodes: Array = []
	for r in rows:
		var row := UIKit.hbox(12)
		var a := UIKit.label(str(r[0]), 18, UIKit.MUTED, 800)
		a.custom_minimum_size = Vector2(300, 0)
		row.add_child(a)
		var b := UIKit.label(str(r[1]), 19, UIKit.INK, 900)
		b.custom_minimum_size = Vector2(230, 0)
		row.add_child(b)
		var c := UIKit.label(str(r[2]), 16, UIKit.MUTED, 600)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(c)
		row.modulate = Color(1, 1, 1, 0)
		rows_box.add_child(row)
		row_nodes.append(row)
	v.add_child(HSeparator.new())
	var stars := int(data.get("stars", 3))
	var star_text := ""
	for i in 5:
		star_text += "★" if i < stars else "☆"
	var star_label := UIKit.title_label(star_text, 44, UIKit.YELLOW, UIKit.NAVY)
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_label.modulate = Color(1, 1, 1, 0)
	v.add_child(star_label)
	var promo := UIKit.label(str(data.get("title", "")), 22, UIKit.NAVY, 900)
	promo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	promo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	promo.modulate = Color(1, 1, 1, 0)
	v.add_child(promo)
	var unlock := UIKit.label(str(data.get("unlock", "")), 16, UIKit.TEAL, 800)
	unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unlock.modulate = Color(1, 1, 1, 0)
	v.add_child(unlock)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	var btns := UIKit.hbox(12)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(btns)
	var again := UIKit.button(Loc.t("review.again"), UIKit.ORANGE, Color.WHITE, 20)
	var quit := UIKit.button(Loc.t("review.quit"), UIKit.PAPER_DARK, UIKit.INK, 20)
	again.pressed.connect(func(): _done.emit("again"))
	quit.pressed.connect(func(): _done.emit("quit"))
	btns.add_child(again)
	btns.add_child(quit)
	btns.modulate = Color(1, 1, 1, 0)
	# reveal row by row, like a manager reading slowly from a printout
	for rn in row_nodes:
		await get_tree().create_timer(0.35).timeout
		create_tween().tween_property(rn, "modulate", Color.WHITE, 0.25)
		Audio.sfx("page", -8.0)
	await get_tree().create_timer(0.5).timeout
	create_tween().tween_property(star_label, "modulate", Color.WHITE, 0.3)
	Audio.sfx("kaching", -4.0)
	await get_tree().create_timer(0.5).timeout
	create_tween().tween_property(promo, "modulate", Color.WHITE, 0.3)
	create_tween().tween_property(unlock, "modulate", Color.WHITE, 0.3)
	Audio.sfx("tada", -4.0)
	create_tween().tween_property(btns, "modulate", Color.WHITE, 0.3)
	var choice: String = await _done
	_close_modal()
	return choice
