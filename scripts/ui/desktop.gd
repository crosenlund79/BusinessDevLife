class_name Desktop
extends Control
## "NorthOS" — the player's laptop. Hosts three original fictional workplace
## apps: Pigeon (email), Natter (chat) and TaskPile (tickets).
## The story drives it: it adds mails/messages and awaits the player's replies.

signal closed
signal _choice_made(index: int)

const APP_COLORS := {"mail": Color("3d7be0"), "chat": Color("7a4fd1"), "tasks": Color("2fae5c")}

var closable := true
var is_open := false
var mails: Array = []
var threads: Dictionary = {}
var thread_order: Array = []
var current_app := "mail"
var current_mail := ""
var current_thread := ""
var _mail_choice_pending := false

var _window: PanelContainer
var _title: Label
var _clock: Label
var _close_btn: Button
var _rail_buttons: Dictionary = {}
var _badges: Dictionary = {}
var _views: Dictionary = {}
var _mail_list: VBoxContainer
var _mail_subject: Label
var _mail_from: Label
var _mail_body: RichTextLabel
var _mail_actions: VBoxContainer
var _thread_list: VBoxContainer
var _chat_title: Label
var _chat_scroll: ScrollContainer
var _chat_msgs: VBoxContainer
var _chat_typing: Label
var _chat_actions: VBoxContainer
var _task_board: HBoxContainer


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.1, 0.16, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_window = PanelContainer.new()
	var wsb := UIKit.panel_style(Color("f7f8fb"), 20, 30)
	wsb.set_content_margin_all(0)
	_window.add_theme_stylebox_override("panel", wsb)
	_window.custom_minimum_size = Vector2(1220, 720)
	center.add_child(_window)
	var outer := UIKit.vbox(0)
	_window.add_child(outer)
	# --- title bar
	var bar := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = UIKit.NAVY
	bsb.corner_radius_top_left = 20
	bsb.corner_radius_top_right = 20
	bsb.content_margin_left = 20
	bsb.content_margin_right = 12
	bsb.content_margin_top = 10
	bsb.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", bsb)
	outer.add_child(bar)
	var bar_row := UIKit.hbox(12)
	bar.add_child(bar_row)
	var logo := UIKit.label("◆ NorthOS", 20, UIKit.YELLOW, 900)
	bar_row.add_child(logo)
	_title = UIKit.label("", 18, Color(1, 1, 1, 0.85), 700)
	bar_row.add_child(_title)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(fill)
	_clock = UIKit.label(Game.clock, 18, Color.WHITE, 800)
	bar_row.add_child(_clock)
	Game.clock_changed.connect(func(t): _clock.text = t)
	_close_btn = UIKit.button("✕  " + Loc.t("ui.close"), UIKit.CORAL, Color.WHITE, 16)
	_close_btn.pressed.connect(close)
	bar_row.add_child(_close_btn)
	# --- body
	var body := UIKit.hbox(0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	var rail_bg := PanelContainer.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color("e9edf4")
	rsb.corner_radius_bottom_left = 20
	rsb.set_content_margin_all(12)
	rail_bg.add_theme_stylebox_override("panel", rsb)
	body.add_child(rail_bg)
	var rail := UIKit.vbox(10)
	rail_bg.add_child(rail)
	for app in ["mail", "chat", "tasks"]:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(150, 64)
		rail.add_child(holder)
		var b := UIKit.button(Loc.t("apps." + app), APP_COLORS[app], Color.WHITE, 17)
		b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.pressed.connect(open_app.bind(app))
		holder.add_child(b)
		_rail_buttons[app] = b
		var badge := UIKit.avatar("0", UIKit.CORAL, 26)
		badge.position = Vector2(132, -6)
		badge.visible = false
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(badge)
		_badges[app] = badge
	var rail_note := UIKit.label(Loc.t("apps.rail_note"), 13, UIKit.MUTED, 600)
	rail_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rail_note.custom_minimum_size = Vector2(150, 0)
	rail.add_child(rail_note)
	var content := Control.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	_views["mail"] = _build_mail_view()
	_views["chat"] = _build_chat_view()
	_views["tasks"] = _build_task_view()
	for k in _views:
		content.add_child(_views[k])
	visible = false


func _build_mail_view() -> Control:
	var root := UIKit.hbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(380, 0)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(list_scroll)
	_mail_list = UIKit.vbox(2)
	_mail_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_mail_list)
	var reader_bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.corner_radius_bottom_right = 20
	sb.set_content_margin_all(26)
	reader_bg.add_theme_stylebox_override("panel", sb)
	reader_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(reader_bg)
	var reader_scroll := ScrollContainer.new()
	reader_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reader_bg.add_child(reader_scroll)
	var reader := UIKit.vbox(10)
	reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reader_scroll.add_child(reader)
	_mail_subject = UIKit.label("", 28, UIKit.INK, 900)
	_mail_subject.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reader.add_child(_mail_subject)
	_mail_from = UIKit.label("", 16, UIKit.MUTED, 700)
	reader.add_child(_mail_from)
	reader.add_child(HSeparator.new())
	_mail_body = UIKit.rich("", 20)
	_mail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reader.add_child(_mail_body)
	_mail_actions = UIKit.vbox(8)
	reader.add_child(_mail_actions)
	return root


func _build_chat_view() -> Control:
	var root := UIKit.hbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tl_bg := PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color("f1eefa")
	tsb.set_content_margin_all(10)
	tl_bg.add_theme_stylebox_override("panel", tsb)
	tl_bg.custom_minimum_size = Vector2(300, 0)
	root.add_child(tl_bg)
	_thread_list = UIKit.vbox(6)
	tl_bg.add_child(_thread_list)
	var chat_bg := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color.WHITE
	csb.corner_radius_bottom_right = 20
	csb.set_content_margin_all(18)
	chat_bg.add_theme_stylebox_override("panel", csb)
	chat_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(chat_bg)
	var col := UIKit.vbox(8)
	chat_bg.add_child(col)
	_chat_title = UIKit.label("", 24, UIKit.INK, 900)
	col.add_child(_chat_title)
	col.add_child(HSeparator.new())
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_chat_scroll)
	_chat_msgs = UIKit.vbox(10)
	_chat_msgs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_scroll.add_child(_chat_msgs)
	_chat_typing = UIKit.label("", 15, UIKit.MUTED, 700)
	col.add_child(_chat_typing)
	_chat_actions = UIKit.vbox(6)
	col.add_child(_chat_actions)
	return root


func _build_task_view() -> Control:
	var root := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f4f7f2")
	sb.corner_radius_bottom_right = 20
	sb.set_content_margin_all(20)
	root.add_theme_stylebox_override("panel", sb)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := UIKit.vbox(12)
	root.add_child(col)
	col.add_child(UIKit.label(Loc.t("tasks.board_title"), 26, UIKit.INK, 900))
	col.add_child(UIKit.label(Loc.t("tasks.board_sub"), 15, UIKit.MUTED, 600))
	_task_board = UIKit.hbox(14)
	_task_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_task_board)
	refresh_tasks()
	return root


func refresh_tasks() -> void:
	for c in _task_board.get_children():
		c.queue_free()
	var cols = Loc.get_data("tasks.columns")
	if not (cols is Array):
		return
	for column in cols:
		var cp := UIKit.panel(Color("ffffff"), 14)
		cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_task_board.add_child(cp)
		var v := UIKit.vbox(8)
		cp.add_child(v)
		v.add_child(UIKit.label(str(column.get("name", "")), 18, UIKit.MUTED, 900))
		for card in column.get("cards", []):
			if card is Dictionary and card.has("if") and not Game.has_flag(str(card["if"])):
				continue
			if card is Dictionary and card.has("unless") and Game.has_flag(str(card["unless"])):
				continue
			var cc := UIKit.panel(Color(str(card.get("color", "#fff8ec"))), 10)
			var l := UIKit.label(str(card.get("t", "")), 15, UIKit.INK, 700)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(170, 0)
			cc.add_child(l)
			v.add_child(cc)


# ================================================================ open / close

func open(app := "mail") -> void:
	visible = true
	is_open = true
	_title.text = Loc.t("apps.title", {"name": "Alex"})
	_close_btn.disabled = not closable
	open_app(app)
	_window.scale = Vector2(0.92, 0.92)
	_window.pivot_offset = _window.size * 0.5
	_window.modulate = Color(1, 1, 1, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_window, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_window, "modulate", Color.WHITE, 0.15)
	Audio.sfx("whoosh", -8.0)


func close() -> void:
	if not closable:
		Audio.sfx("bonk", -8.0)
		return
	visible = false
	is_open = false
	closed.emit()


func set_closable(on: bool) -> void:
	closable = on
	if _close_btn:
		_close_btn.disabled = not on


func open_app(app: String) -> void:
	current_app = app
	for k in _views:
		_views[k].visible = k == app
	if app == "mail":
		_render_mail_list()
		if current_mail == "" and not mails.is_empty():
			show_mail(mails[0]["id"])
	elif app == "chat":
		_render_threads()
		if current_thread == "" and not thread_order.is_empty():
			show_thread(thread_order[0])
	elif app == "tasks":
		refresh_tasks()
	_update_badges()


# ================================================================ mail

func add_mail(m: Dictionary) -> void:
	var mail := m.duplicate()
	mail["unread"] = true
	mails.push_front(mail)
	if is_open and current_app == "mail":
		_render_mail_list()
	_update_badges()


func show_mail(id: String) -> void:
	current_mail = id
	for m in mails:
		if m["id"] == id:
			m["unread"] = false
			_mail_subject.text = ("⚠ " if m.get("urgent", false) else "") + str(m.get("subject", ""))
			_mail_subject.add_theme_color_override("font_color", UIKit.CORAL if m.get("urgent", false) else UIKit.INK)
			_mail_from.text = Loc.t("apps.mail_from", {"from": str(m.get("from_name", "")), "time": str(m.get("time", ""))})
			_mail_body.text = str(m.get("body", ""))
			break
	if not _mail_choice_pending:
		for c in _mail_actions.get_children():
			c.queue_free()
	_render_mail_list()
	_update_badges()


func mail_choice(options: Array) -> int:
	open_app("mail")
	for c in _mail_actions.get_children():
		c.queue_free()
	_mail_actions.add_child(UIKit.label(Loc.t("apps.reply_with"), 15, UIKit.MUTED, 800))
	for i in options.size():
		var b := UIKit.button("↩  " + str(options[i]), Color("e6efff"), UIKit.INK, 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): _choice_made.emit(i))
		_mail_actions.add_child(b)
	_mail_choice_pending = true
	var idx: int = await _choice_made
	_mail_choice_pending = false
	for c in _mail_actions.get_children():
		c.queue_free()
	Audio.sfx("whoosh", -8.0, 1.3)
	return idx


func _render_mail_list() -> void:
	if _mail_list == null:
		return
	for c in _mail_list.get_children():
		c.queue_free()
	for m in mails:
		var selected: bool = m["id"] == current_mail
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, 84)
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("dfe9ff") if selected else (Color("fffdf6") if m.get("unread", false) else Color("f7f8fb"))
		sb.border_color = UIKit.CORAL if m.get("urgent", false) else Color("3d7be0")
		sb.border_width_left = 6 if (m.get("unread", false) or selected) else 0
		sb.content_margin_left = 14
		row.add_theme_stylebox_override("normal", sb)
		row.add_theme_stylebox_override("hover", sb)
		row.add_theme_stylebox_override("pressed", sb)
		row.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		row.pressed.connect(show_mail.bind(str(m["id"])))
		_mail_list.add_child(row)
		var v := UIKit.vbox(2)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 16
		v.offset_top = 10
		v.offset_right = -10
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(v)
		var top := UIKit.hbox(6)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(top)
		var from := UIKit.label(str(m.get("from_name", "")), 16, UIKit.INK, 900 if m.get("unread", false) else 700)
		from.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		from.clip_text = true
		top.add_child(from)
		top.add_child(UIKit.label(str(m.get("time", "")), 14, UIKit.MUTED, 700))
		var subj := UIKit.label(str(m.get("subject", "")), 15, UIKit.CORAL if m.get("urgent", false) else UIKit.INK, 800)
		subj.clip_text = true
		subj.custom_minimum_size = Vector2(330, 0)
		v.add_child(subj)
		var prev := UIKit.label(str(m.get("preview", "")), 13, UIKit.MUTED, 600)
		prev.clip_text = true
		prev.custom_minimum_size = Vector2(330, 0)
		v.add_child(prev)


# ================================================================ chat

func ensure_thread(id: String, title: String, color: Color, initials: String) -> void:
	if threads.has(id):
		return
	threads[id] = {"title": title, "color": color, "initials": initials, "msgs": [], "unread": 0}
	thread_order.append(id)
	if is_open and current_app == "chat":
		_render_threads()


func add_chat(thread: String, from_name: String, text: String, mine := false, color := Color("7a4fd1")) -> void:
	if not threads.has(thread):
		return
	var t: Dictionary = threads[thread]
	t["msgs"].append({"from": from_name, "text": text, "mine": mine, "color": color})
	if not (is_open and current_app == "chat" and current_thread == thread) and not mine:
		t["unread"] += 1
	if is_open and current_app == "chat" and current_thread == thread:
		_append_bubble(from_name, text, mine, color)
	_update_badges()
	if is_open and current_app == "chat":
		_render_threads()


func typing(thread: String, who: String, seconds: float) -> void:
	if is_open and current_app == "chat" and current_thread == thread:
		_chat_typing.text = Loc.t("apps.typing", {"name": who})
	Audio.sfx("typing", -14.0)
	await get_tree().create_timer(seconds).timeout
	_chat_typing.text = ""


func chat_choice(thread: String, options: Array) -> int:
	open_app("chat")
	show_thread(thread)
	for c in _chat_actions.get_children():
		c.queue_free()
	for i in options.size():
		var b := UIKit.button(str(options[i]), Color("efe9ff"), UIKit.INK, 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): _choice_made.emit(i))
		_chat_actions.add_child(b)
	var idx: int = await _choice_made
	for c in _chat_actions.get_children():
		c.queue_free()
	return idx


func show_thread(id: String) -> void:
	if not threads.has(id):
		return
	current_thread = id
	var t: Dictionary = threads[id]
	t["unread"] = 0
	_chat_title.text = str(t["title"])
	for c in _chat_msgs.get_children():
		c.queue_free()
	for m in t["msgs"]:
		_append_bubble(str(m["from"]), str(m["text"]), bool(m["mine"]), m["color"])
	_render_threads()
	_update_badges()


func _append_bubble(from_name: String, text: String, mine: bool, color: Color) -> void:
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	_chat_msgs.add_child(row)
	if not mine:
		row.add_child(UIKit.avatar(from_name.substr(0, 1), color, 36))
	var bubble := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("3d7be0") if mine else Color("f1eefa")
	sb.set_corner_radius_all(16)
	if mine:
		sb.corner_radius_bottom_right = 4
	else:
		sb.corner_radius_bottom_left = 4
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	bubble.add_theme_stylebox_override("panel", sb)
	row.add_child(bubble)
	var v := UIKit.vbox(2)
	bubble.add_child(v)
	if not mine:
		v.add_child(UIKit.label(from_name, 13, color, 900))
	var l := UIKit.label(text, 18, Color.WHITE if mine else UIKit.INK, 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(560.0, 14.0 * text.length() + 20.0), 0)
	v.add_child(l)
	bubble.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(bubble, "modulate", Color.WHITE, 0.15)
	Audio.sfx("pop", -10.0, 1.4 if mine else 1.1)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_chat_scroll):
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)


func _render_threads() -> void:
	for c in _thread_list.get_children():
		c.queue_free()
	for id in thread_order:
		var t: Dictionary = threads[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 58)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("ffffff") if id == current_thread else Color(1, 1, 1, 0)
		sb.set_corner_radius_all(12)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(show_thread.bind(id))
		_thread_list.add_child(b)
		var row := UIKit.hbox(10)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.offset_top = 8
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var av := UIKit.avatar(str(t["initials"]), t["color"], 40)
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(av)
		var name_l := UIKit.label(str(t["title"]), 16, UIKit.INK, 800)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.clip_text = true
		row.add_child(name_l)
		if int(t["unread"]) > 0:
			row.add_child(UIKit.avatar(str(t["unread"]), UIKit.CORAL, 24))


func _update_badges() -> void:
	var mail_unread := 0
	for m in mails:
		if m.get("unread", false):
			mail_unread += 1
	var chat_unread := 0
	for id in threads:
		chat_unread += int(threads[id]["unread"])
	_set_badge("mail", mail_unread)
	_set_badge("chat", chat_unread)


func _set_badge(app: String, n: int) -> void:
	var b: PanelContainer = _badges.get(app)
	if b == null:
		return
	b.visible = n > 0
	var l: Label = b.get_child(0)
	l.text = str(n)


func total_unread() -> int:
	var n := 0
	for m in mails:
		if m.get("unread", false):
			n += 1
	for id in threads:
		n += int(threads[id]["unread"])
	return n
