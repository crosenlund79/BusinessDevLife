class_name PuppetData
extends RefCounted
## Loads a cardboard character's printed parts (art/sprites/characters/<id>/)
## and its parts.json manifest. All rig maths happens in "canvas units": the
## 512 x 1024 drawing space the art was authored in (feet at y = 1000).

const ROOT := "res://art/sprites/characters/%s/"
## World metres per canvas unit: 1000 canvas units ≈ 1.9 m.
const UNIT := 0.0019
const FEET := Vector2(256, 1000)

## expression -> [eyes, brows, mouth]
const EXPRESSIONS := {
	"neutral": ["eyes_open", "brows_neutral", "mouth_flat"],
	"happy": ["eyes_open", "brows_neutral", "mouth_smile"],
	"joy": ["eyes_happy", "brows_up", "mouth_grin"],
	"sad": ["eyes_open", "brows_worried", "mouth_frown"],
	"angry": ["eyes_open", "brows_angry", "mouth_frown"],
	"furious": ["eyes_wide", "brows_angry", "mouth_grin"],
	"shock": ["eyes_wide", "brows_up", "mouth_shock"],
	"smug": ["eyes_half", "brows_smug", "mouth_smirk"],
	"worried": ["eyes_side", "brows_worried", "mouth_wobble"],
	"deadpan": ["eyes_half", "brows_neutral", "mouth_flat"],
	"confused": ["eyes_side", "brows_smug", "mouth_wobble"],
	"talk": ["eyes_open", "brows_neutral", "mouth_talk"],
}

## Story ids that use another id's printed art.
const ART_ID := {"player": "alex"}

static var _cache: Dictionary = {}


static func get_data(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var art: String = ART_ID.get(id, id)
	var path := (ROOT % art) + "parts.json"
	if not FileAccess.file_exists(path):
		_cache[id] = {}
		return {}
	var man = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (man is Dictionary):
		_cache[id] = {}
		return {}
	var tex := {}
	for part in man["parts"]:
		var tp := (ROOT % art) + str(part) + ".png"
		if ResourceLoader.exists(tp):
			tex[part] = load(tp)
	var d := {"rig": man["rig"], "parts": man["parts"], "tex": tex, "scale": float(man.get("scale", 0.75))}
	_cache[id] = d
	return d


static func has_puppet(id: String) -> bool:
	return not get_data(id).is_empty()


static func pt(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


## Centre of a part's rect relative to `pivot`, in canvas units (y down).
static func rect_center(rect: Array) -> Vector2:
	return Vector2(float(rect[0]) + float(rect[2]) * 0.5, float(rect[1]) + float(rect[3]) * 0.5)


## Canvas point -> local 3D offset from a canvas pivot (y flipped, metres).
static func to_local(p: Vector2, pivot: Vector2) -> Vector3:
	return Vector3((p.x - pivot.x) * UNIT, (pivot.y - p.y) * UNIT, 0.0)


static func expression_parts(expr: String) -> Array:
	return EXPRESSIONS.get(expr, EXPRESSIONS["happy"])
