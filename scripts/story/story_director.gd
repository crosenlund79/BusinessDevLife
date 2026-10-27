class_name StoryDirector
extends Node
## Day 1 at Northbound Consulting.
##
##   Arrival → meet the team → the meeting about meetings → URGENT email →
##   find the real requirement (Dagmar) → write the handover → test →
##   deploy → cake → FloorLink disaster → biscuit avalanche → war-room brawl
##   → Maggie's cake ends the fight → the twist → first-day review.
##
## All text lives in data/text/<lang>.json; this file only sequences it.

var world: World
var ui: UIRoot
var stage := "title"
var met := {}
var _busy := false
var _flood: BiscuitFlood

const THREAD_COLORS := {
	"dagmar": Color("2b8a7e"),
	"tobias": Color("2b8a7e"),
	"general": Color("7a4fd1"),
	"bogdan": Color("3a7d44"),
}


func setup(w: World, u: UIRoot) -> void:
	world = w
	ui = u
	ui.dialogue.director = self
	world.interacted.connect(on_interact)
	ui.start_pressed.connect(_on_start)
	ui.restart_requested.connect(_restart)


# ====================================================================== flow

func show_title() -> void:
	stage = "title"
	Game.input_locked = true
	world.ambient = true
	world.rig.orbit = true
	world.set_markers([])
	ui.set_hud_visible(false)
	ui.show_title(true)
	Audio.play_music("office")


func _on_start() -> void:
	if stage != "title":
		return
	stage = "intro"
	Audio.sfx("tada", -6.0)
	ui.show_title(false)
	await ui.fade_out(0.4)
	Game.reset()
	Game.set_objective("")
	met.clear()
	world.reset_positions()
	world.rig.orbit = false
	world.rig.snap()
	_setup_desktop()
	await ui.fade_in(0.6)
	ui.set_hud_visible(true)
	Game.set_clock("08:57")
	await ui.caption(Loc.t("captions.day1_big"), Loc.t("captions.day1_small"), 2.4)
	Game.input_locked = true
	await world.walk("player", Vector3(11.0, 0, 4.4))
	world.npc("maggie").emote("!", Color("ffb627"))
	world.npc("maggie").gesture("wave", 2.0)
	stage = "arrival"
	Game.set_objective(Loc.t("obj.reception"))
	world.set_markers(["maggie"])
	Game.input_locked = false


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func on_interact(id: String) -> void:
	if _busy or Game.input_locked:
		return
	_busy = true
	world.clear_hover()
	await _handle(id)
	_busy = false


func _handle(id: String) -> void:
	match stage:
		"arrival":
			if id == "maggie":
				await _talk("maggie_arrival", ["maggie"])
				_begin_meet()
				return
		"meet":
			if id in ["tobias", "sanne", "bogdan"] and not met.has(id):
				await _talk(id + "_meet", [id])
				met[id] = true
				_update_meet_objective()
				return
		"meeting":
			if id in ["meeting_table", "chad"]:
				await _meeting()
				return
		"email":
			if id == "laptop":
				await _email_sequence()
				return
		"spec":
			if id == "tobias":
				await _spec_sequence()
				return
		"handover":
			if id == "sanne":
				await _handover_sequence()
				return
		"test":
			if id == "sanne":
				await _test_sequence()
				return
		"deploy":
			if id == "bogdan":
				await _deploy_sequence()
				return
		"celebrate":
			if id in ["cake_table", "maggie"]:
				await _disaster_sequence()
				return
	await _flavor(id)


## Plays flavour dialogue: tries "<prefix>_<id>_<stage>", then "<prefix>_<id>".
func _flavor(id: String) -> void:
	var is_char := world.chars.has(id)
	var prefix := "chat_" if is_char else "flavor_"
	for key in [prefix + id + "_" + stage, prefix + id]:
		if Loc.has_key("dialogue." + key):
			await _talk(key, [id] if is_char else [])
			return
	if is_char:
		world.npc(id).emote("?", Color("8fc7f2"))


## Runs a conversation with input locked and the camera moving in.
func _talk(key: String, focus_ids: Array = []) -> String:
	Game.input_locked = true
	world.ambient = false
	var pts: Array = [world.player.global_position]
	for fid in focus_ids:
		var c := world.npc(fid)
		if c:
			pts.append(c.global_position)
			if not c.seated:
				c.face_point(world.player.global_position)
			world.player.face_point(c.global_position)
	var mid := Vector3.ZERO
	for p in pts:
		mid += p
	mid /= pts.size()
	world.rig.focus_on(mid, 7.0, -30.0)
	var result: String = await ui.dialogue.play(key)
	world.rig.release_focus()
	for fid in focus_ids:
		var c := world.npc(fid)
		if c:
			c.reset_expression()
	world.player.reset_expression()
	world.ambient = true
	Game.input_locked = false
	return result


# ====================================================================== act 1

func _begin_meet() -> void:
	stage = "meet"
	Game.set_clock("09:04")
	_update_meet_objective()
	world.set_markers(["tobias", "sanne", "bogdan"])
	await get_tree().create_timer(4.0, false).timeout
	ui.toast(Loc.t("apps.calendar"), Loc.t("names.chad"), Loc.t("toasts.invite"), Color("e0862f"))
	world.npc("chad").bark(Loc.t("barks_special.chad_invite"), 3.0)


func _update_meet_objective() -> void:
	var n := met.size()
	if n < 3:
		Game.set_objective(Loc.t("obj.meet", {"n": n}))
		var left: Array = []
		for id in ["tobias", "sanne", "bogdan"]:
			if not met.has(id):
				left.append(id)
		world.set_markers(left)
		return
	stage = "meeting"
	Game.set_clock("09:58")
	Game.set_objective(Loc.t("obj.meeting"))
	world.set_markers(["meeting_table"])
	ui.toast(Loc.t("apps.calendar"), Loc.t("names.chad"), Loc.t("toasts.meeting_soon"), Color("e0862f"))
	# the team drifts towards the meeting room in the background
	world.walk_many({
		"tobias": world.seat_pos("m_n1"),
		"sanne": world.seat_pos("m_n2"),
		"bogdan": world.seat_pos("m_n3"),
		"maggie": world.seat_pos("m_s1"),
		"chad": world.point("meeting_present"),
	})


func _meeting() -> void:
	stage = "meeting_live"
	Game.input_locked = true
	world.set_markers([])
	await ui.fade_out(0.4)
	world.seat("tobias", "m_n1", false)
	world.seat("sanne", "m_n2", true)
	world.seat("bogdan", "m_n3", false)
	world.seat("maggie", "m_s1", false)
	world.seat("player", "m_s2", false)
	world.place("chad", world.point("meeting_present"), 0.9)
	world.screen("meeting_tv").show_spec({"kind": "slide", "kicker": Loc.t("screens.align_kicker"), "title": Loc.t("screens.align_title"), "subtitle": Loc.t("screens.align_sub"), "accent": "#f28c28", "bullets": Loc.get_data("screens.align_bullets")})
	world.rig.focus_on(Vector3(-11.0, 0, -7.0), 8.5, -34.0)
	world.rig.snap()
	await ui.fade_in(0.5)
	await ui.dialogue.play("meeting")
	await ui.fade_out(0.5)
	# the 10-minute meeting
	ui.set_phone_level(0)
	world.rig.release_focus()
	world.reset_positions()
	world.place("player", world.point("meeting_door") + Vector3(0, 0, 0.8), 0.0)
	world.screen("meeting_tv").show_spec({"kind": "slide", "kicker": Loc.t("screens.meeting_idle_kicker"), "title": Loc.t("screens.meeting_after_title"), "subtitle": Loc.t("screens.meeting_after_sub"), "accent": "#2bb3a3"})
	world.rig.snap()
	Game.set_clock("10:47")
	await ui.fade_in(0.4)
	await ui.caption(Loc.t("captions.after_meeting_big"), Loc.t("captions.after_meeting_small"), 2.6)
	_deliver_urgent_mail()
	stage = "email"
	Game.set_objective(Loc.t("obj.email"))
	world.set_markers(["laptop"])
	Game.input_locked = false


# ====================================================================== act 2

func _setup_desktop() -> void:
	var d := ui.desktop
	d.mails.clear()
	d.threads.clear()
	d.thread_order.clear()
	for key in ["maggie_cake", "chad_buzzword", "security", "vendor"]:
		_add_mail(key)
	for m in d.mails:
		m["unread"] = false
	d.ensure_thread("general", Loc.t("threads.general"), THREAD_COLORS["general"], "#")
	d.add_chat("general", Loc.t("names.chad"), Loc.t("chat.general_1"), false, Color("c0392b"))
	d.add_chat("general", Loc.t("names.maggie"), Loc.t("chat.general_2"), false, Color("e0862f"))
	d.add_chat("general", Loc.t("names.kevin"), Loc.t("chat.general_3"), false, Color("4e6a8f"))
	d.threads["general"]["unread"] = 0


func _add_mail(key: String) -> void:
	var m = Loc.get_data("mails." + key)
	if m is Dictionary:
		var mail: Dictionary = m.duplicate()
		mail["id"] = key
		ui.desktop.add_mail(mail)


func _deliver_urgent_mail() -> void:
	_add_mail("gerald_urgent")
	ui.toast(Loc.t("apps.mail"), Loc.t("names.gerald"), Loc.t("toasts.gerald_urgent"), Color("3d7be0"), true)


func _email_sequence() -> void:
	Game.input_locked = true
	world.set_markers([])
	var d := ui.desktop
	d.set_closable(false)
	d.current_mail = ""
	d.open("mail")
	d.show_mail("gerald_urgent")
	Audio.sfx("page", -6.0)
	var opts: Array = Loc.get_data("replies.gerald_1")
	var pick: int = await d.mail_choice(opts)
	Game.set_flag("gerald_reply_%d" % pick)
	await get_tree().create_timer(1.4, false).timeout
	_add_mail(["gerald_reply_which", "gerald_reply_screenshot", "gerald_reply_clever"][pick])
	Audio.sfx("notify", -6.0)
	d.show_mail(["gerald_reply_which", "gerald_reply_screenshot", "gerald_reply_clever"][pick])
	await get_tree().create_timer(2.0, false).timeout
	# Tobias to the rescue (sort of)
	d.ensure_thread("tobias", Loc.t("names.tobias"), THREAD_COLORS["tobias"], "T")
	d.add_chat("tobias", Loc.t("names.tobias_short"), Loc.t("chat.tobias_tip_1"), false, THREAD_COLORS["tobias"])
	d.add_chat("tobias", Loc.t("names.tobias_short"), Loc.t("chat.tobias_tip_2"), false, THREAD_COLORS["tobias"])
	ui.toast("Natter", Loc.t("names.tobias"), Loc.t("chat.tobias_tip_1"), Color("7a4fd1"))
	await get_tree().create_timer(1.2, false).timeout
	d.ensure_thread("dagmar", Loc.t("threads.dagmar"), THREAD_COLORS["dagmar"], "D")
	d.open_app("chat")
	d.show_thread("dagmar")
	await _chat_script("dagmar", "chatscript.dagmar")
	await get_tree().create_timer(1.0, false).timeout
	_add_mail("gerald_followup")
	ui.toast(Loc.t("apps.mail"), Loc.t("names.gerald"), Loc.t("toasts.gerald_followup"), Color("3d7be0"), true)
	Game.set_flag("req_pop")
	Game.set_flag("req_ai")
	d.set_closable(true)
	ui.toast("NorthOS", Loc.t("names.system"), Loc.t("toasts.close_laptop"), UIKit.NAVY)
	await d.closed
	stage = "spec"
	Game.set_clock("11:32")
	Game.set_objective(Loc.t("obj.spec"))
	world.set_markers(["tobias"])
	Game.input_locked = false


## Plays a scripted chat: [{"s": "dagmar"|"me", "t": ...}, {"choice": [...]}, {"set": flag}]
func _chat_script(thread: String, key: String) -> void:
	var lines = Loc.get_data(key)
	if not (lines is Array):
		return
	await _chat_lines(thread, lines)


func _chat_lines(thread: String, lines: Array) -> void:
	var d := ui.desktop
	for line in lines:
		if line.has("set"):
			Game.set_flag(str(line["set"]))
		if line.has("choice"):
			var opts: Array = line["choice"]
			var labels: Array = []
			for o in opts:
				labels.append(str(o["t"]))
			var idx: int = await d.chat_choice(thread, labels)
			var picked: Dictionary = opts[idx]
			d.add_chat(thread, Loc.t("ui.me"), str(picked["t"]), true)
			if picked.has("set"):
				Game.set_flag(str(picked["set"]))
			if picked.has("then"):
				await _chat_lines(thread, picked["then"])
			continue
		if line.has("t"):
			var who := str(line.get("s", thread))
			if who == "me":
				d.add_chat(thread, Loc.t("ui.me"), str(line["t"]), true)
				await get_tree().create_timer(0.5, false).timeout
			else:
				var nm := Loc.t("names." + who + "_short")
				await d.typing(thread, nm, clampf(str(line["t"]).length() * 0.025, 0.6, 2.2))
				d.add_chat(thread, nm, str(line["t"]), false, THREAD_COLORS.get(thread, Color("7a4fd1")))
				await get_tree().create_timer(0.35, false).timeout


func _spec_sequence() -> void:
	var who: String = await _talk("tobias_spec", ["tobias"])
	Game.input_locked = true
	if who == "tobias_writes":
		Game.set_flag("spec_tobias")
		Game.set_flag("spec_bad")
		Game.stats["spec_score"] = 0
	else:
		var notes: Array = []
		for n in Loc.get_data("spec.notes_list"):
			var need := str(n.get("needs", ""))
			if need == "" or Game.has_flag(need):
				notes.append(n)
		var result: Dictionary = await ui.work.spec_builder(notes, Loc.get_data("spec.estimates"))
		var good := 0
		var bad := 0
		for n in notes:
			if str(n["id"]) in result["selected"]:
				if n.get("good", false):
					good += 1
				else:
					bad += 1
				Game.set_flag("spec_has_" + str(n["id"]))
		Game.set_flag("estimate_" + str(result["estimate"]))
		Game.stats["spec_score"] = good - bad
		if good >= 3 and bad == 0:
			Game.set_flag("spec_great")
			Game.add_stat("reputation", 1)
		elif good >= 2:
			Game.set_flag("spec_ok")
		else:
			Game.set_flag("spec_bad")
		Game.input_locked = false
		await _talk("tobias_spec_done", ["tobias"])
	stage = "handover"
	Game.set_objective(Loc.t("obj.handover"))
	world.set_markers(["sanne"])
	Game.input_locked = false


func _handover_sequence() -> void:
	await _talk("sanne_handover", ["sanne"])
	Game.input_locked = true
	world.set_markers([])
	await ui.fade_out(0.5)
	Game.set_clock("14:10")
	world.reset_positions()
	world.place("player", world.seat_pos("sanne") + Vector3(0.9, 0, 0.1), -PI * 0.5)
	world.rig.snap()
	await ui.fade_in(0.4)
	await ui.caption(Loc.t("captions.after_lunch_big"), Loc.t("captions.after_lunch_small"), 2.2)
	stage = "test"
	Game.set_objective(Loc.t("obj.test"))
	world.set_markers(["sanne"])
	Game.input_locked = false


func _test_sequence() -> void:
	await _talk("sanne_test_intro", ["sanne"])
	Game.input_locked = true
	var variant := "good" if Game.has_flag("spec_has_green") else "bad"
	Game.set_flag("variant_" + variant)
	var res: Dictionary = await ui.work.erp_test(variant, Game.has_flag("spec_has_ai"))
	if res["approve"] and res["delete"]:
		Game.set_flag("tested_well")
	if res["warning"]:
		Game.set_flag("saw_warning")
	if res["flagged"]:
		Game.set_flag("flagged_floorlink")
		Game.add_stat("reputation", 1)
	Game.input_locked = false
	await _talk("sanne_test_done", ["sanne"])
	# the client performs "acceptance testing"
	await get_tree().create_timer(1.2, false).timeout
	ui.set_phone_level(1)
	_add_mail("gerald_uat")
	ui.toast(Loc.t("apps.mail"), Loc.t("names.gerald"), Loc.t("toasts.gerald_uat"), Color("3d7be0"), true)
	await get_tree().create_timer(2.0, false).timeout
	ui.set_phone_level(0)
	stage = "deploy"
	Game.set_clock("15:20")
	Game.set_objective(Loc.t("obj.deploy"))
	world.set_markers(["bogdan"])


func _deploy_sequence() -> void:
	await _talk("bogdan_deploy", ["bogdan"])
	Game.input_locked = true
	world.set_markers([])
	await ui.work.deploy()
	Game.add_stat("billed_hours", 7.5)
	world.npc("bogdan").gesture("fist", 1.5)
	world.npc("bogdan").emote("✓", Color("2fae5c"))
	await get_tree().create_timer(0.4, false).timeout
	for id in ["tobias", "sanne", "kevin", "pia", "olu"]:
		var c := world.npc(id)
		if c:
			c.gesture("cheer", 1.8)
			c.set_expression("joy")
	world.npc("chad").bark(Loc.t("barks_special.chad_synergy"), 3.0)
	world.npc("pia").bark(Loc.t("barks_special.pia_deploy"), 3.0)
	Audio.sfx("bell", -4.0)
	await get_tree().create_timer(1.0, false).timeout
	ui.toast("Natter", Loc.t("threads.general"), Loc.t("toasts.chad_general"), Color("7a4fd1"))
	ui.desktop.add_chat("general", Loc.t("names.chad"), Loc.t("toasts.chad_general"), false, Color("c0392b"))
	for id in ["tobias", "sanne", "kevin", "pia", "olu"]:
		var c := world.npc(id)
		if c:
			c.reset_expression()
	Game.add_stat("reputation", 1)
	stage = "celebrate"
	Game.set_clock("16:05")
	Game.set_objective(Loc.t("obj.cake"))
	world.set_markers(["cake_table"])
	world.walk("maggie", world.point("maggie_cake_spot"))
	Game.input_locked = false


# ====================================================================== act 3

func _disaster_sequence() -> void:
	stage = "disaster"
	Game.input_locked = true
	world.set_markers([])
	await world.walk("player", world.point("cake_spot"))
	world.face_each_other("player", "maggie")
	await _talk("cake_celebration", ["maggie"])
	Game.input_locked = true
	# --- Gerald on video
	var g := ui.show_call("gerald")
	if g:
		g.set_expression("furious")
		g.set_redness(0.55)
	ui.call_shake(1.0)
	await ui.dialogue.play("gerald_call")
	ui.hide_call()
	ui.set_phone_level(2)
	# --- War room
	await ui.fade_out(0.5)
	_place_war_room(false)
	world.screen("war_status").show_spec({"kind": "status", "title": Loc.t("screens.war_status_title"), "status": "green", "big": Loc.t("screens.war_status_big2"), "caption": Loc.t("screens.war_status_caption2"), "footnote": Loc.t("screens.war_status_foot2"), "animated": true})
	world.rig.focus_on(world.point("war_center") + Vector3(0, 0, -1.2), 9.0, -36.0)
	world.rig.snap()
	await ui.fade_in(0.5)
	await ui.dialogue.play("war_room")
	await get_tree().create_timer(0.6, false).timeout
	await ui.dialogue.play("twist")
	await _ending()


func _place_war_room(after_brawl: bool) -> void:
	var c := world.point("war_center")
	var spots := {
		"chad": [c + Vector3(-1.6, 0, -1.6), 0.6],
		"tobias": [c + Vector3(-0.6, 0, -2.1), 0.2],
		"sanne": [c + Vector3(0.6, 0, -2.1), -0.2],
		"bogdan": [c + Vector3(1.6, 0, -1.6), -0.6],
		"player": [c + Vector3(0.3, 0, 0.3), PI],
		"maggie": [world.point("war_door") + Vector3(0, 0, 1.4), PI],
	}
	for id in spots:
		if after_brawl and id in ["player", "maggie"]:
			continue
		world.place(id, spots[id][0], spots[id][1])


func _ending() -> void:
	await ui.fade_out(0.6)
	world.rig.release_focus()
	Game.set_clock("17:30")
	world.reset_positions()
	for id in ["tobias", "sanne", "bogdan", "chad"]:
		world.npc(id).set_disheveled(true)
	world.place("player", world.seat_pos("player") + Vector3(0, 0, 0.6), PI)
	world.rig.snap()
	ui.set_phone_level(0)
	await ui.fade_in(0.5)
	await ui.dialogue.play("final_email")
	await ui.caption(Loc.t("captions.end_big"), Loc.t("captions.end_small"), 2.4)
	var choice: String = await ui.work.review(_review_data())
	if choice == "again":
		_restart()
	else:
		get_tree().quit()


func _review_data() -> Dictionary:
	var spec_key := "review.spec_bad"
	if Game.has_flag("spec_tobias"):
		spec_key = "review.spec_tobias"
	elif Game.has_flag("spec_great"):
		spec_key = "review.spec_great"
	elif Game.has_flag("spec_ok"):
		spec_key = "review.spec_ok"
	var hours := float(Game.stats.get("billed_hours", 7.5))
	var rate := 120
	var stars := 2
	if Game.has_flag("spec_great"):
		stars += 1
	if Game.has_flag("tested_well"):
		stars += 1
	if Game.has_flag("flagged_floorlink"):
		stars += 1
	stars = clampi(stars, 2, 5)
	var rows: Array = [
		[Loc.t("review.r_spec"), Loc.t(spec_key + "_v"), Loc.t(spec_key + "_c")],
		[Loc.t("review.r_test"), Loc.t("review.test_good_v" if Game.has_flag("tested_well") else "review.test_bad_v"), Loc.t("review.test_good_c" if Game.has_flag("tested_well") else "review.test_bad_c")],
		[Loc.t("review.r_risk"), Loc.t("review.risk_yes_v" if Game.has_flag("flagged_floorlink") else "review.risk_no_v"), Loc.t("review.risk_yes_c" if Game.has_flag("flagged_floorlink") else "review.risk_no_c")],
		[Loc.t("review.r_client"), Loc.t("review.client_v"), Loc.t("review.client_c")],
		[Loc.t("review.r_biscuits"), Loc.t("review.biscuits_v"), Loc.t("review.biscuits_c")],
		[Loc.t("review.r_billed"), Game.money(int(hours * rate)), Loc.t("review.billed_c", {"hours": "%.1f" % hours, "rate": Game.money(rate), "cr": Game.money(31000)})],
		[Loc.t("review.r_chad"), Loc.t("review.chad_bold_v" if Game.has_flag("picked_replace") else "review.chad_v"), Loc.t("review.chad_bold_c" if Game.has_flag("picked_replace") else "review.chad_c")],
	]
	return {
		"rows": rows,
		"stars": stars,
		"stamp": Loc.t("review.stamp"),
		"title": Loc.t("review.promo"),
		"unlock": Loc.t("review.unlock"),
	}


# ====================================================================== events
## Called by dialogue lines with {"event": "..."}.

func on_event(ev: String) -> void:
	var parts := ev.split(":")
	match parts[0]:
		"gesture":
			var c := _actor(parts[1])
			if c:
				c.gesture(parts[2], 1.8)
		"expr":
			var c := _actor(parts[1])
			if c:
				c.set_expression(parts[2])
		"emote":
			var c := _actor(parts[1])
			if c:
				c.emote(parts[2])
		"sfx":
			Audio.sfx(parts[1], -2.0)
		"wait":
			await get_tree().create_timer(float(parts[1]), false).timeout
		"tv_synergia":
			world.screen("meeting_tv").show_spec({"kind": "slide", "kicker": Loc.t("screens.syn_kicker"), "title": Loc.t("screens.syn_title"), "title_size": 96, "subtitle": Loc.t("screens.syn_sub"), "accent": "#8a6cff", "bg": "#151a2b", "footer": Loc.t("screens.syn_footer")})
			Audio.sfx("tada", -6.0)
		"tv_roadmap":
			world.screen("meeting_tv").show_spec({"kind": "slide", "kicker": Loc.t("screens.road_kicker"), "title": Loc.t("screens.road_title"), "accent": "#8a6cff", "bg": "#151a2b", "bullets": Loc.get_data("screens.road_bullets")})
		"awkward":
			Audio.duck(-24.0, 0.3)
			Audio.sfx("crickets", -4.0)
			await get_tree().create_timer(2.4, false).timeout
			Audio.unduck()
		"phone_buzz":
			ui.set_phone_level(1)
			Audio.sfx("buzz", -2.0)
			ui.toast(Loc.t("apps.mail"), Loc.t("names.gerald"), Loc.t("toasts.gerald_urgent"), Color("3d7be0"), true)
			await get_tree().create_timer(1.2, false).timeout
		"phone_calm":
			ui.set_phone_level(0)
		"disaster_1":
			ui.set_phone_level(1)
			Audio.sfx("buzz", -2.0)
			ui.desktop.ensure_thread("dagmar", Loc.t("threads.dagmar"), THREAD_COLORS["dagmar"], "D")
			ui.desktop.add_chat("dagmar", Loc.t("names.dagmar_short"), Loc.t("toasts.dagmar_1"), false, THREAD_COLORS["dagmar"])
			ui.toast("Natter", Loc.t("names.dagmar"), Loc.t("toasts.dagmar_1"), Color("7a4fd1"))
			await get_tree().create_timer(1.6, false).timeout
		"disaster_2":
			ui.set_phone_level(2)
			Audio.sfx("buzz", 0.0)
			ui.desktop.add_chat("dagmar", Loc.t("names.dagmar_short"), Loc.t("toasts.dagmar_2"), false, THREAD_COLORS["dagmar"])
			ui.toast("Natter", Loc.t("names.dagmar"), Loc.t("toasts.dagmar_2"), Color("7a4fd1"))
			await get_tree().create_timer(1.0, false).timeout
			ui.toast(Loc.t("apps.mail"), Loc.t("names.gerald"), Loc.t("toasts.gerald_panic_1"), Color("3d7be0"), true)
			await get_tree().create_timer(1.2, false).timeout
		"disaster_3":
			ui.set_phone_level(3)
			Audio.sfx("alarm", -6.0)
			world.rig.shake(0.4)
			ui.toast(Loc.t("apps.mail"), Loc.t("names.gerald"), Loc.t("toasts.gerald_panic_2"), Color("3d7be0"), true)
			await get_tree().create_timer(0.6, false).timeout
			ui.toast(Loc.t("apps.mail"), Loc.t("names.gerald"), Loc.t("toasts.gerald_panic_3"), Color("3d7be0"), true)
			await get_tree().create_timer(1.2, false).timeout
		"call_shake":
			ui.call_shake(float(parts[1]) if parts.size() > 1 else 1.0)
		"call_calm":
			var g := ui.call_char("gerald")
			if g:
				g.set_expression("worried")
		"biscuits":
			await _biscuit_avalanche()
		"war_brawl":
			await _brawl()
		"brawl_grow":
			if world._brawl:
				world._brawl.intensity = 2.2
				world._brawl.scale = Vector3.ONE * 1.35
			world.rig.shake(0.5)
		"maggie_arrives":
			await _maggie_arrives()
		"brawl_stop":
			await _brawl_stop()
		"me_chorus":
			for id in ["chad", "tobias", "sanne", "bogdan"]:
				var c := world.npc(id)
				c.bark(Loc.t("barks_special.me"), 1.6)
				c.gesture("nod", 0.6)
				Audio.sfx("pop", -8.0, 1.0 + randf() * 0.3)
				await get_tree().create_timer(0.45, false).timeout
		"war_twist":
			ui.set_phone_level(1)
			Audio.sfx("notify", -2.0)
			ui.toast("Natter", Loc.t("names.dagmar"), Loc.t("toasts.dagmar_twist"), Color("7a4fd1"))
			ui.desktop.add_chat("dagmar", Loc.t("names.dagmar_short"), Loc.t("toasts.dagmar_twist"), false, THREAD_COLORS["dagmar"])
			await get_tree().create_timer(1.0, false).timeout
			ui.toast(Loc.t("apps.mail"), Loc.t("names.gerald"), Loc.t("toasts.gerald_thanks"), Color("3d7be0"), true)
			_add_mail("gerald_thanks")
			world.screen("war_margin").show_spec({"kind": "line", "title": Loc.t("screens.war_margin_title"), "values": [22, 14, 3, -9, -14, 38], "labels": ["Jan", "Mar", "May", "Jul", "Sep", Loc.t("screens.today")], "arrow_note": Loc.t("screens.war_margin_arrow2"), "accent": "#2fae5c"})
			await get_tree().create_timer(1.0, false).timeout
			ui.set_phone_level(0)
		"final_buzz":
			ui.set_phone_level(2)
			Audio.sfx("buzz", 0.0)
			_add_mail("gerald_final")
			ui.toast(Loc.t("apps.mail"), Loc.t("names.gerald"), Loc.t("toasts.gerald_final"), Color("3d7be0"), true)
			await get_tree().create_timer(1.5, false).timeout
			ui.set_phone_level(0)
		"sad_trombone":
			Audio.duck(-20.0, 0.2)
			Audio.sfx("sad_trombone", 0.0)
			await get_tree().create_timer(2.4, false).timeout
			Audio.unduck()
		"flash":
			ui.flash()
		_:
			push_warning("Story: unknown event '%s'" % ev)


func _actor(id: String) -> Character:
	return world.npc(id)


func _biscuit_avalanche() -> void:
	ui.hide_call()
	world.rig.focus_on(world.point("entrance") + Vector3(0, 0, -3.5), 13.0, -42.0)
	Audio.duck(-14.0, 0.5)
	Audio.sfx("rumble", 0.0)
	world.rig.shake(0.6)
	await get_tree().create_timer(1.0, false).timeout
	_flood = world.start_biscuits()
	for id in ["maggie", "player", "kevin", "pia", "olu", "tobias", "sanne"]:
		var c := world.npc(id)
		if c:
			c.set_expression("shock")
			c.gesture("shock", 1.4)
			c.emote("!!", Color("e85d5d"))
	await get_tree().create_timer(2.2, false).timeout
	Audio.sfx("rumble", -2.0)
	world.rig.shake(0.5)
	await get_tree().create_timer(3.0, false).timeout
	Game.stats["biscuits_kg"] = 2400
	Audio.unduck()
	world.rig.focus_on(world.player.global_position, 7.0, -30.0)
	ui.show_call("gerald")
	var g := ui.call_char("gerald")
	if g:
		g.set_expression("furious")
		g.set_redness(0.8)


func _brawl() -> void:
	var ids := ["chad", "tobias", "sanne", "bogdan"]
	for id in ids:
		var c := world.npc(id)
		c.set_expression("furious")
		c.gesture("rage", 1.0)
	world.rig.shake(0.3)
	await get_tree().create_timer(0.8, false).timeout
	Audio.sfx("whoosh", 0.0, 0.7)
	world.start_brawl(world.point("war_center") + Vector3(0, 0, -1.6), ids)
	world.rig.shake(0.6)
	Audio.play_music("brawl", 0.3)
	await get_tree().create_timer(3.0, false).timeout


func _maggie_arrives() -> void:
	var m := world.npc("maggie")
	world.place("maggie", world.point("war_door") + Vector3(0, 0, 1.6), PI)
	m.carry(world.make_cake())
	m.set_expression("happy")
	await world.walk("maggie", world.point("war_center") + Vector3(-0.6, 0, -0.2))
	m.face_point(world.point("war_center") + Vector3(0, 0, -1.6))


func _brawl_stop() -> void:
	var ids := ["chad", "tobias", "sanne", "bogdan"]
	var c := world.point("war_center")
	world.stop_brawl(ids, {
		"chad": [c + Vector3(-1.6, 0, -1.4), 0.6],
		"tobias": [c + Vector3(-0.6, 0, -1.9), 0.2],
		"sanne": [c + Vector3(0.6, 0, -1.9), -0.2],
		"bogdan": [c + Vector3(1.6, 0, -1.4), -0.6],
	})
	for id in ids:
		var ch := world.npc(id)
		ch.set_expression("joy")
		ch.face_point(world.npc("maggie").global_position)
	# Chad's tie never came back.
	var tie := world.npc("chad").torso.find_child("Tie", true, false)
	if tie:
		tie.visible = false
	Audio.stop_music(0.2)
	Audio.play_stream_path("res://audio/generated/sting_happy_ending.wav", -2.0)
	ui.flash(Color(1, 1, 1, 0.6))
	await get_tree().create_timer(3.2, false).timeout
	Audio.play_music("office", 1.5)
