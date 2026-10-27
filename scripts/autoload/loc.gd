extends Node
## Localisation-ready string tables.
##
## Every player-facing string (UI labels, dialogue, emails, chats) lives in
## res://data/text/<language>.json, so adding Danish ("da"), Flemish ("nl_BE")
## or Belgian French ("fr_BE") is a matter of translating one file.
## Keys are dotted paths: Loc.t("ui.start") or Loc.get_data("dialogue.arrival").

signal language_changed

const FALLBACK := "en"

var language := FALLBACK
var _table: Dictionary = {}
var _fallback: Dictionary = {}


func _ready() -> void:
	_fallback = _load(FALLBACK)
	_table = _fallback


func set_language(lang: String) -> void:
	var table := _load(lang)
	if table.is_empty():
		push_warning("Loc: no text table for '%s', keeping '%s'." % [lang, language])
		return
	language = lang
	_table = table
	language_changed.emit()


## Returns a formatted string. Missing keys return the key itself so gaps are visible.
func t(key: String, args: Dictionary = {}) -> String:
	var value = get_data(key)
	if value == null:
		return key
	var text := str(value)
	if not args.is_empty():
		text = text.format(args)
	return text


## Returns raw data (arrays of dialogue lines, email dictionaries, ...).
func get_data(key: String):
	var value = _lookup(_table, key)
	if value == null and _table != _fallback:
		value = _lookup(_fallback, key)
	return value


func has_key(key: String) -> bool:
	return get_data(key) != null


func _lookup(table: Dictionary, key: String):
	var node = table
	for part in key.split("."):
		if node is Dictionary and node.has(part):
			node = node[part]
		else:
			return null
	return node


func _load(lang: String) -> Dictionary:
	var path := "res://data/text/%s.json" % lang
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("Loc: could not parse %s" % path)
	return {}
