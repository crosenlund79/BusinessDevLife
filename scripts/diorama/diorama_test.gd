extends Node3D
## Prototype 002 — visual benchmark scene for the Illustrated Diorama style.
##
## One room, three cardboard characters, illustrated props, point-and-click,
## the shared dialogue/HUD/phone UI, and four comedy beats from Day 1 re-staged
## in paper: Maggie's cake celebration, Chad's awkward silence, the escalation
## phone and the cake-related dust-cloud brawl.
##
## F3 toggles a live performance overlay. Run with `-- --benchmark` to print
## frame-time statistics for 20 s of idle animation and quit.

var diorama: Diorama
var ui: UIRoot
var _done := {}
var _busy := false
var _perf: Label
var _bench := false
var _bench_t := 0.0
var _frame_times: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	randomize()
	var defs := _load_defs()
	diorama = Diorama.new()
	diorama.name = "Diorama"
	add_child(diorama)
	diorama.setup(UIKit.font(800), defs)
	diorama.spawn("maggie", Vector3(3.6, 0, -0.2))
	diorama.spawn("chad", Vector3(-1.95, 0, -1.05))
	diorama.spawn("player", Vector3(0.2, 0, 1.0))
	diorama.npc("chad").face_point(Vector3(-3.5, 0, -1.1))
	ui = UIRoot.new()
	ui.name = "UIRoot"
	add_child(ui)
	ui.build(diorama, defs, true)
	ui.dialogue.director = self
	ui.show_title(false)
	ui.set_hud_visible(true)
	ui.set_controls_hint(Loc.t("diorama.controls_hint"))
	_add_vignette()
	_add_perf_overlay()
	diorama.interacted.connect(_on_interact)
	ui.restart_requested.connect(func(): get_tree().reload_current_scene())
	Audio.play_music("office")
	_bench = "--benchmark" in OS.get_cmdline_user_args()
	Game.reset()
	Game.set_clock("09:12")
	Game.input_locked = true
	if _bench:
		return
	await ui.caption(Loc.t("diorama.caption_big"), Loc.t("diorama.caption_small"), 2.0)
	Game.set_objective(Loc.t("diorama.objective"))
	diorama.set_markers(["maggie", "chad", "desk"])
	Game.input_locked = false
	diorama.npc("maggie").gesture("wave", 2.0)
	diorama.npc("maggie").emote("!")


func _load_defs() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	return parsed if parsed is Dictionary else {}


# ================================================================ interactions

func _on_interact(id: String) -> void:
	if _busy or Game.input_locked:
		return
	_busy = true
	diorama.clear_hover()
	match id:
		"maggie":
			await _talk("diorama_maggie" if not _done.has("maggie") else "chat_maggie", ["maggie"])
		"chad":
			await _talk("diorama_chad" if not _done.has("chad") else "chat_chad", ["chad"])
		"desk":
			await _talk("diorama_phone" if not _done.has("desk") else "flavor_duck", [])
		"whiteboard":
			await _talk("diorama_brawl" if not _done.has("whiteboard") else "flavor_whiteboard", ["chad"])
		_:
			var key := "flavor_" + id
			if Loc.has_key("dialogue." + key):
				await _talk(key, [])
	_done[id] = true
	var left: Array = []
	for t in ["maggie", "chad", "desk"]:
		if not _done.has(t):
			left.append(t)
	if left.is_empty() and not _done.has("whiteboard"):
		left = ["whiteboard"]
		Game.set_objective(Loc.t("diorama.objective_brawl"))
	elif left.is_empty():
		Game.set_objective(Loc.t("diorama.objective_done"))
	diorama.set_markers(left)
	_busy = false


func _talk(key: String, focus: Array) -> void:
	Game.input_locked = true
	diorama.ambient = false
	for id in focus:
		var c = diorama.npc(id)
		if c:
			diorama.player.face_point(c.global_position)
			c.face_point(diorama.player.global_position)
	await ui.dialogue.play(key)
	for id in diorama.chars:
		diorama.chars[id].reset_expression()
	diorama.ambient = true
	Game.input_locked = false


## Dialogue lines with {"event": "..."} land here.
func on_event(ev: String) -> void:
	var parts := ev.split(":")
	var maggie: PaperPuppet = diorama.npc("maggie")
	var chad: PaperPuppet = diorama.npc("chad")
	var alex: PaperPuppet = diorama.player
	match parts[0]:
		"gesture":
			var c = diorama.npc(parts[1])
			if c:
				c.gesture(parts[2], 1.8)
		"emote":
			var c = diorama.npc(parts[1])
			if c:
				c.emote(parts[2])
		"sfx":
			Audio.sfx(parts[1], -2.0)
		"wait":
			await get_tree().create_timer(float(parts[1]), false).timeout
		"celebrate":
			Audio.sfx("tada", -4.0)
			for p in [maggie, alex]:
				p.set_expression("joy")
				p.gesture("cheer", 2.2)
			diorama.fx.burst(Vector3(2.6, 1.3, -0.4), ["heart", "sparkle", "heart", "star"], 16, 1.4, 1.6, 1.6)
			await get_tree().create_timer(1.6, false).timeout
		"awkward":
			Audio.duck(-24.0, 0.3)
			Audio.sfx("crickets", -4.0)
			chad.freeze(true)
			alex.freeze(true)
			chad.set_expression("deadpan")
			alex.set_expression("worried")
			diorama.set_clock_speed(-12.0)   # time slows down. Visibly.
			await get_tree().create_timer(0.6, false).timeout
			diorama.fx.pop("dots", chad.head_top() + Vector3(0.3, 0.05, 0.1), 0.9, 2.0)
			await get_tree().create_timer(0.7, false).timeout
			diorama.fx.pop("sweat", alex.head_top() + Vector3(0.25, -0.2, 0.1), 0.8, 1.6)
			await get_tree().create_timer(1.3, false).timeout
			chad.freeze(false)
			alex.freeze(false)
			diorama.set_clock_speed(1.0)
			Audio.unduck()
		"phone_1":
			ui.set_phone_level(1)
			Audio.sfx("buzz", -2.0)
			await get_tree().create_timer(0.8, false).timeout
		"phone_2":
			ui.set_phone_level(2)
			Audio.sfx("buzz", 0.0)
			ui.toast(Loc.t("apps.mail"), Loc.t("names.gerald"), Loc.t("toasts.gerald_urgent"), Color("3d7be0"), true)
			await get_tree().create_timer(0.9, false).timeout
		"phone_3":
			ui.set_phone_level(3)
			Audio.sfx("alarm", -8.0)
			diorama.shake_camera(0.35)
			alex.set_expression("shock")
			alex.gesture("shock", 1.2)
			alex.emote("!!")
			ui.toast(Loc.t("apps.mail"), Loc.t("names.gerald"), Loc.t("toasts.gerald_panic_1"), Color("3d7be0"), true)
			await get_tree().create_timer(1.0, false).timeout
		"phone_calm":
			ui.set_phone_level(0)
		"maggie_arrives":
			maggie.set_expression("angry")
			await diorama.walk("maggie", Vector3(-1.05, 0, -0.75))
			maggie.face_point(chad.global_position)
			chad.face_point(maggie.global_position)
			maggie.emote("anger")
		"brawl_start":
			chad.set_expression("furious")
			maggie.set_expression("furious")
			chad.gesture("rage", 0.8)
			await get_tree().create_timer(0.6, false).timeout
			diorama.fx.start_brawl(Vector3(-1.45, 0, -0.85), [chad, maggie])
			diorama.shake_camera(0.5)
			Audio.play_music("brawl", 0.3)
			await get_tree().create_timer(2.5, false).timeout
		"brawl_grow":
			diorama.fx.grow_brawl()
			diorama.shake_camera(0.4)
		"brawl_stop":
			diorama.fx.stop_brawl([chad, maggie])
			chad.position = Vector3(-2.05, 0, -1.0)
			maggie.position = Vector3(-1.05, 0, -0.75)
			chad.set_disheveled(true)
			chad.set_expression("worried")
			maggie.set_expression("smug")
			maggie.carry(_cake_slice())
			Audio.play_stream_path("res://audio/generated/sting_happy_ending.wav", -2.0)
			ui.flash(Color(1, 1, 1, 0.5))
			await get_tree().create_timer(1.2, false).timeout
			Audio.play_music("office", 1.5)
		"tidy":
			chad.set_disheveled(false)
			maggie.carry(null)
			diorama.walk("maggie", Vector3(3.6, 0, -0.2))
		_:
			push_warning("Diorama: unknown event '%s'" % ev)


func _cake_slice() -> Node3D:
	var s := diorama.fx.make_sprite("cake_slice", Vector3.ZERO, 0.8)
	diorama.fx.remove_child(s)
	return s


# ================================================================ presentation

func _add_vignette() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.add_point(0.62, Color(0.12, 0.06, 0.02, 0.0))
	g.set_color(g.get_point_count() - 1, Color(0.16, 0.08, 0.03, 0.42))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.45)
	t.fill_to = Vector2(1.05, 0.45)
	t.width = 256
	t.height = 256
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var r := TextureRect.new()
	r.texture = t
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)


func _add_perf_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_perf = Label.new()
	_perf.position = Vector2(16, 120)
	_perf.add_theme_font_override("font", UIKit.font(700))
	_perf.add_theme_font_size_override("font_size", 15)
	_perf.add_theme_color_override("font_color", Color.WHITE)
	_perf.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_perf.add_theme_constant_override("outline_size", 5)
	_perf.visible = false
	layer.add_child(_perf)


func _process(delta: float) -> void:
	if _perf.visible:
		_perf.text = "FPS %d   frame %.2f ms\ndraw calls %d   objects %d   primitives %d\nvideo mem %.1f MB   texture mem %.1f MB\nrenderer: %s" % [
			Engine.get_frames_per_second(), delta * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
			str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		]
	if _bench:
		_bench_t += delta
		if _bench_t > 2.0:   # skip warm-up
			_frame_times.append(delta * 1000.0)
		if _bench_t > 22.0:
			_report_benchmark()


func _report_benchmark() -> void:
	_bench = false
	var arr := Array(_frame_times)
	arr.sort()
	var total := 0.0
	for v in arr:
		total += v
	var avg := total / maxf(1.0, arr.size())
	var p99: float = arr[int(arr.size() * 0.99)] if not arr.is_empty() else 0.0
	print("BENCHMARK diorama_test: frames=%d avg=%.2fms (%.0f fps) p99=%.2fms draw_calls=%d objects=%d primitives=%d video_mem=%.1fMB" % [
		arr.size(), avg, 1000.0 / maxf(0.001, avg), p99,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_perf.visible = not _perf.visible
