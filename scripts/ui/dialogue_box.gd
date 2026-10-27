class_name DialogueBox
extends Control
## Data-driven conversations with typewriter text, live 3D portraits,
## choices, inline branching, flags and story events.
##
## A conversation is an array of line dictionaries from data/text/<lang>.json:
##   {"s": "maggie", "t": "Hello!", "e": "joy", "g": "wave", "emote": "!"}
##   {"choice": [{"t": "...", "id": "x", "set": "flag", "then": [ ...lines ]}]}
##   {"event": "phone_buzz"}  {"wait": 1.0}  {"sfx": "crickets"}
##   {"if": "flag"} / {"if": "!flag"} on any line to make it conditional.

signal _advance
signal _picked(index: int)

## Either the 3D World or the paper Diorama: anything with npc(id), chars
## and shake_camera(amount).
var world: Node
var director: Node
## Portrait provider: a 3D PortraitStudio, or a 2D PaperPortrait.
var studio
var defs: Dictionary = {}
var active := false

var _panel: PanelContainer
var _name_tag: PanelContainer
var _name_label: Label
var _role_label: Label
var _text: RichTextLabel
var _portrait_frame: PanelContainer
var _portrait: TextureRect
var _arrow: Label
var _choices: VBoxContainer
var _skip_btn: Button
var _catcher: Control
var _typing := false
var _chars_shown := 0.0
var _blip_count := 0
var _fast := false
var _speaker := ""
var _waiting_choice := false
var _t := 0.0
var _hide_tween: Tween
var _tapes: Control


func build(character_defs: Dictionary, portrait_provider: Control = null) -> void:
	defs = character_defs
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_catcher = Control.new()
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_catcher_input)
	_catcher.visible = false
	add_child(_catcher)

	if portrait_provider == null:
		var ps := PortraitStudio.new()
		ps.font = UIKit.font(800)
		add_child(ps)
		ps.setup(320, defs)
		studio = ps
	else:
		studio = portrait_provider

	_panel = UIKit.panel(UIKit.PAPER, 22)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -560
	_panel.offset_right = 600
	_panel.offset_top = -236
	_panel.offset_bottom = -26
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_catcher_input)
	add_child(_panel)
	var row := UIKit.hbox(18)
	_panel.add_child(row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(170, 0)
	row.add_child(spacer)
	var col := UIKit.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var head := UIKit.hbox(10)
	col.add_child(head)
	_name_tag = PanelContainer.new()
	head.add_child(_name_tag)
	_name_label = UIKit.label("", 22, Color.WHITE, 800)
	_name_tag.add_child(_name_label)
	_role_label = UIKit.label("", 16, UIKit.MUTED, 600)
	_role_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_role_label)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(fill)
	_skip_btn = UIKit.button(Loc.t("ui.skip"), UIKit.PAPER_DARK, UIKit.MUTED, 15)
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.pressed.connect(_on_skip)
	head.add_child(_skip_btn)
	_text = UIKit.rich("", 23)
	_text.custom_minimum_size = Vector2(0, 110)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_text)
	_arrow = UIKit.label("▼", 18, UIKit.ORANGE, 800)
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_arrow)

	# portrait, overlapping the panel's top-left corner
	_portrait_frame = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f3e7d3")
	sb.set_corner_radius_all(110)
	sb.border_color = Color.WHITE
	sb.set_border_width_all(6)
	sb.shadow_color = UIKit.SHADOW
	sb.shadow_size = 12
	_portrait_frame.add_theme_stylebox_override("panel", sb)
	_portrait_frame.anchor_left = 0.5
	_portrait_frame.anchor_right = 0.5
	_portrait_frame.anchor_top = 1.0
	_portrait_frame.anchor_bottom = 1.0
	_portrait_frame.offset_left = -600
	_portrait_frame.offset_right = -390
	_portrait_frame.offset_top = -290
	_portrait_frame.offset_bottom = -80
	_portrait_frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_frame)
	if studio is PortraitStudio:
		_portrait = TextureRect.new()
		_portrait.texture = studio.get_texture()
		_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portrait_frame.add_child(_portrait)
	else:
		_portrait_frame.add_child(studio)

	_choices = UIKit.vbox(8)
	_choices.anchor_left = 0.5
	_choices.anchor_right = 0.5
	_choices.anchor_top = 1.0
	_choices.anchor_bottom = 1.0
	_choices.offset_left = -200
	_choices.offset_right = 600
	_choices.offset_top = -480
	_choices.offset_bottom = -250
	_choices.alignment = BoxContainer.ALIGNMENT_END
	add_child(_choices)
	# two strips of masking tape "holding" the dialogue card to the screen
	_tapes = Control.new()
	_tapes.anchor_left = 0.5
	_tapes.anchor_right = 0.5
	_tapes.anchor_top = 1.0
	_tapes.anchor_bottom = 1.0
	_tapes.offset_left = -560
	_tapes.offset_right = 600
	_tapes.offset_top = -236
	_tapes.offset_bottom = -26
	_tapes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tapes)
	for side in [-1.0, 1.0]:
		var tape := ColorRect.new()
		tape.color = Color(0.98, 0.9, 0.66, 0.8)
		tape.size = Vector2(96, 26)
		tape.position = Vector2(580 + side * 500 - 48, -13)
		tape.rotation = side * 0.08
		tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tapes.add_child(tape)
	_set_visible(false)


func _set_visible(on: bool) -> void:
	if _tapes:
		_tapes.visible = on
	_panel.visible = on
	_portrait_frame.visible = on and studio.current != ""
	_catcher.visible = on
	_choices.visible = on


# ================================================================ playback

## Plays a conversation by key. Returns the id of the last choice made.
func play(key: String) -> String:
	var lines = Loc.get_data("dialogue." + key)
	if not (lines is Array):
		push_warning("Dialogue: missing conversation '%s'" % key)
		return ""
	_kill_hide()
	active = true
	_fast = false
	_set_visible(true)
	_panel.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(_panel, "modulate", Color.WHITE, 0.18)
	var result: String = await run_lines(lines)
	_end()
	return result


## Plays a single ad-hoc line (used by the story for dynamic text).
func say(speaker: String, text: String, expr := "", gest := "") -> void:
	_kill_hide()
	active = true
	_set_visible(true)
	await _say({"s": speaker, "t": text, "e": expr, "g": gest})
	_end()


func run_lines(lines: Array) -> String:
	var last := ""
	for line in lines:
		if not (line is Dictionary):
			continue
		if line.has("if") and not _check(str(line["if"])):
			continue
		if line.has("set"):
			Game.set_flag(str(line["set"]))
		if line.has("stat"):
			var st: Dictionary = line["stat"]
			for k in st:
				Game.add_stat(k, st[k])
		if line.has("sfx"):
			Audio.sfx(str(line["sfx"]), -2.0)
		if line.has("event"):
			_set_visible(false)
			_catcher.visible = true
			if director:
				await director.on_event(str(line["event"]))
			if not line.has("t") and not line.has("choice"):
				continue
			_set_visible(true)
		if line.has("wait"):
			_panel.visible = false
			_portrait_frame.visible = false
			await get_tree().create_timer(float(line["wait"])).timeout
			_set_visible(true)
			if not line.has("t"):
				continue
		if line.has("choice"):
			var opts: Array = []
			for o in line["choice"]:
				if o is Dictionary and (not o.has("if") or _check(str(o["if"]))):
					opts.append(o)
			if line.has("t"):
				await _say(line, true)
			var idx: int = await _choose(opts)
			var picked: Dictionary = opts[idx]
			last = str(picked.get("id", str(idx)))
			Game.set_flag("picked_" + last)
			if picked.has("set"):
				Game.set_flag(str(picked["set"]))
			if picked.has("stat"):
				var pst: Dictionary = picked["stat"]
				for k in pst:
					Game.add_stat(k, pst[k])
			if picked.has("then"):
				await run_lines(picked["then"])
			continue
		if line.has("t"):
			await _say(line)
	return last


func _check(cond: String) -> bool:
	if cond.begins_with("!"):
		return not Game.has_flag(cond.substr(1))
	return Game.has_flag(cond)


func _say(line: Dictionary, keep_open := false) -> void:
	var speaker := str(line.get("s", "narrator"))
	var d: Dictionary = defs.get(speaker, {})
	_speaker = speaker
	# name tag
	var name_text := str(d.get("name", ""))
	if speaker == "player":
		name_text = Loc.t("ui.you", {"name": name_text})
	_name_tag.visible = name_text != ""
	_name_label.text = name_text
	_role_label.text = Loc.t("roles." + speaker) if Loc.has_key("roles." + speaker) else str(d.get("role", ""))
	var tag_sb := StyleBoxFlat.new()
	tag_sb.bg_color = Color(str(d.get("tag", "#6b7890")))
	tag_sb.set_corner_radius_all(12)
	tag_sb.content_margin_left = 14
	tag_sb.content_margin_right = 14
	tag_sb.content_margin_top = 4
	tag_sb.content_margin_bottom = 6
	_name_tag.add_theme_stylebox_override("panel", tag_sb)
	# portrait
	var pc = studio.show_char(speaker)
	_portrait_frame.visible = pc != null
	# text
	var text := str(line.get("t", ""))
	text = text.format({"player": str(defs.get("player", {}).get("name", "Alex"))})
	if speaker == "narrator":
		text = "[i]" + text + "[/i]"
	_text.text = text
	_text.visible_characters = 0
	_chars_shown = 0.0
	_typing = true
	_arrow.visible = false
	# 3D actor reactions
	var actor = world.npc(speaker) if world else null
	var expr := str(line.get("e", ""))
	for c in [actor, pc]:
		if c == null:
			continue
		if expr != "":
			c.set_expression(expr)
		if line.has("g") and str(line["g"]) != "":
			c.gesture(str(line["g"]), float(line.get("gd", 1.8)))
		c.set_talking(true)
	if actor and line.has("emote"):
		actor.emote(str(line["emote"]))
	if line.has("shake") and world:
		world.shake_camera(float(line["shake"]))
	if _fast:
		_complete_line()
	while _typing:
		await get_tree().process_frame
	for c in [actor, pc]:
		if c:
			c.set_talking(false)
	if keep_open:
		return
	_arrow.visible = true
	if _fast:
		await get_tree().create_timer(0.05).timeout
	else:
		await _advance
	if line.has("reset") and actor:
		actor.reset_expression()


func _choose(opts: Array) -> int:
	_fast = false
	for c in _choices.get_children():
		c.queue_free()
	_waiting_choice = true
	_arrow.visible = false
	for i in opts.size():
		var o: Dictionary = opts[i]
		var b := UIKit.button("%d.  %s" % [i + 1, str(o.get("t", "..."))], Color("fbfaf6"), UIKit.INK, 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(640, 0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.pressed.connect(func(): _picked.emit(i))
		_choices.add_child(b)
		b.modulate = Color(1, 1, 1, 0)
		b.position.x += 40
		var tw := create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(b, "modulate", Color.WHITE, 0.15)
	_choices.visible = true
	var idx: int = await _picked
	_waiting_choice = false
	for c in _choices.get_children():
		c.queue_free()
	return idx


func _end() -> void:
	active = false
	_typing = false
	_fast = false
	studio.show_char("")
	_hide_tween = create_tween()
	_hide_tween.tween_property(_panel, "modulate", Color(1, 1, 1, 0), 0.15)
	_hide_tween.tween_callback(_hide_if_inactive)
	if world:
		for id in world.chars:
			world.chars[id].set_talking(false)


func _kill_hide() -> void:
	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.kill()
	_hide_tween = null


func _hide_if_inactive() -> void:
	if not active:
		_set_visible(false)


func _on_skip() -> void:
	_fast = true
	_complete_line()
	_advance.emit()


func _complete_line() -> void:
	_text.visible_characters = -1
	_typing = false


func _process(delta: float) -> void:
	_t += delta
	if _arrow and _arrow.visible:
		_arrow.position.y = sin(_t * 6.0) * 3.0
	if not _typing:
		return
	var total := _text.get_total_character_count()
	var cps := 48.0 * float(Game.settings.get("text_speed", 1.0))
	_chars_shown += delta * cps
	var shown := int(_chars_shown)
	if shown >= total:
		_complete_line()
		return
	_text.visible_characters = shown
	if Game.settings.get("voice_blips", true) and shown / 3 != _blip_count:
		_blip_count = shown / 3
		var pitch := float(defs.get(_speaker, {}).get("blip", 1.0))
		if _speaker != "narrator":
			Audio.sfx("blip", -17.0, pitch, 0.08)


func _on_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_advance_pressed()


func _on_advance_pressed() -> void:
	if not active or _waiting_choice:
		return
	if _typing:
		_complete_line()
	else:
		_advance.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("ui_accept"):
		_on_advance_pressed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if _waiting_choice:
			var n: int = event.keycode - KEY_1
			if n >= 0 and n < _choices.get_child_count():
				_picked.emit(n)
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB:
			_on_skip()
			get_viewport().set_input_as_handled()
