extends Node
## Music with cross-fades plus a small pool of sound-effect players.
##
## Licensed tracks dropped into res://audio/music/ take priority over the
## generated fallbacks (see audio/music/README.md for the expected file names).

const MUSIC_TRACKS := {
	"office": [
		"res://audio/music/scope_creep.ogg",
		"res://audio/music/scope_creep.mp3",
		"res://audio/music/scope_creep.wav",
		"res://audio/generated/music_office_theme.wav",
	],
	"brawl": [
		"res://audio/music/epic_meltdown_happy_ending.ogg",
		"res://audio/music/epic_meltdown_happy_ending.mp3",
		"res://audio/music/epic_meltdown_happy_ending.wav",
		"res://audio/generated/music_brawl.wav",
	],
}
const SFX_DIR := "res://audio/generated/sfx_%s.wav"
const MUSIC_DB := -6.0

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current_track := ""
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _cache: Dictionary = {}
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in 2:
		var p := _make_player("Music")
		p.finished.connect(_on_music_finished.bind(p))
		_players.append(p)
	for i in 12:
		_sfx_pool.append(_make_player("SFX"))
	apply_volumes()
	Game.settings_changed.connect(apply_volumes)


func apply_volumes() -> void:
	_set_bus_linear("Music", float(Game.settings.get("music", 0.6)))
	_set_bus_linear("SFX", float(Game.settings.get("sfx", 0.8)))


func play_music(track: String, fade_time := 1.2) -> void:
	if track == _current_track:
		return
	var stream := _resolve_music(track)
	_current_track = track
	var old := _players[_active]
	_active = 1 - _active
	var new := _players[_active]
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	if stream:
		new.stream = stream
		new.volume_db = -40.0
		new.play()
		_fade.tween_property(new, "volume_db", MUSIC_DB, fade_time)
	if old.playing:
		_fade.tween_property(old, "volume_db", -60.0, fade_time)
		_fade.chain().tween_callback(old.stop)


func stop_music(fade_time := 1.0) -> void:
	_current_track = ""
	var p := _players[_active]
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, fade_time)
	tw.tween_callback(p.stop)


## Temporarily ducks the music (e.g. for the awkward silence gag).
func duck(amount_db := -18.0, time := 0.4) -> void:
	var p := _players[_active]
	create_tween().tween_property(p, "volume_db", MUSIC_DB + amount_db, time)


func unduck(time := 0.8) -> void:
	var p := _players[_active]
	create_tween().tween_property(p, "volume_db", MUSIC_DB, time)


func sfx(sfx_name: String, volume_db := 0.0, pitch := 1.0, pitch_variance := 0.0) -> void:
	var stream: AudioStream = _load_stream(SFX_DIR % sfx_name)
	if stream == null:
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.1, pitch + randf_range(-pitch_variance, pitch_variance))
	p.play()


func play_stream_path(path: String, volume_db := 0.0) -> void:
	var stream: AudioStream = _load_stream(path)
	if stream == null:
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0
	p.play()


func _on_music_finished(p: AudioStreamPlayer) -> void:
	# Loop whatever is currently active (works for wav/ogg/mp3 alike).
	if p == _players[_active] and _current_track != "":
		p.play()


func _resolve_music(track: String) -> AudioStream:
	for path in MUSIC_TRACKS.get(track, []):
		var s := _load_stream(path)
		if s:
			return s
	return null


func _load_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	_cache[path] = stream
	return stream


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _set_bus_linear(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(idx, value <= 0.001)
