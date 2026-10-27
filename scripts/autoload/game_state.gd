extends Node
## Global game state: story flags, light-weight stats, objective text and settings.

signal objective_changed(text: String)
signal stats_changed
signal clock_changed(text: String)
signal settings_changed

const CURRENCY_SYMBOL := "¤"
const CURRENCY_NAME := "Bix"
const SETTINGS_PATH := "user://settings.cfg"

var flags: Dictionary = {}
var stats: Dictionary = {}
var objective := ""
var clock := "08:57"
## True while a cutscene / dialogue / app owns the input.
var input_locked := false

var settings := {
	"music": 0.6,
	"sfx": 0.8,
	"text_speed": 1.0,
	"voice_blips": true,
	"fullscreen": false,
}


func _ready() -> void:
	reset()
	_load_settings()


func reset() -> void:
	flags.clear()
	stats = {
		"reputation": 1,      # 0..5 stars
		"team": 0,            # how the colleagues feel about you
		"chad": 0,            # how the Ambitious Manager feels about you
		"spec_score": 0,      # quality of the handover you wrote
		"billed_hours": 0.0,
		"biscuits_kg": 0,
	}
	objective = ""
	clock = "08:57"
	input_locked = false


func set_flag(flag: String, value = true) -> void:
	flags[flag] = value


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func get_flag(flag: String, default = null):
	return flags.get(flag, default)


func add_stat(stat: String, amount) -> void:
	stats[stat] = stats.get(stat, 0) + amount
	if stat == "reputation":
		stats[stat] = clampi(int(stats[stat]), 0, 5)
	stats_changed.emit()


func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


func set_clock(text: String) -> void:
	clock = text
	clock_changed.emit(text)


## Formats an amount in the in-game currency, e.g. "¤ 12,500".
func money(amount: int) -> String:
	var negative := amount < 0
	var digits := str(absi(amount))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if negative else "") + CURRENCY_SYMBOL + " " + out


func set_setting(key: String, value) -> void:
	settings[key] = value
	if key == "fullscreen":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)
	settings_changed.emit()
	_save_settings()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key in settings.keys():
		settings[key] = cfg.get_value("settings", key, settings[key])
	if settings["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
