class_name PaintedArt
extends RefCounted
## Access to the painted art listed in res://art/painted/painted.json.
## Every entry of the manifest is optional: callers ask for a picture and fall
## back to what the game draws itself when it is not there, so art can be added
## one picture at a time with tools/art/import_render.py.

const DIR := "res://art/painted/"
const MANIFEST := DIR + "painted.json"
const SOURCE_WIDTH := 1124.0
const CANVAS_WIDTH := 1080.0
const TIMES: Array[String] = ["evening", "sunset", "night"]

static var _manifest := {}
static var _loaded := false
static var _textures := {}


static func manifest() -> Dictionary:
	if not _loaded:
		_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if typeof(parsed) == TYPE_DICTIONARY:
			_manifest = parsed
		else:
			push_warning("PaintedArt: %s is missing or broken" % MANIFEST)
	return _manifest


## Crop box of the base sprite in source painting pixels: [left, top, right, bottom].
static func sprite_box() -> Array:
	return manifest().get("sprite_box", [181, 565, 928, 1500])


## A manifest entry as {"file": String, "box": Array}, or {} when it is absent
## or its picture is missing. Entries without their own box use the base one.
static func entry(section: String, key: String) -> Dictionary:
	var group: Variant = manifest().get(section, {})
	if section == "capsule":
		group = {"capsule": group}
	if typeof(group) != TYPE_DICTIONARY or not group.has(key):
		return {}
	var raw: Variant = group[key]
	var result := {"file": "", "box": sprite_box()}
	if typeof(raw) == TYPE_STRING:
		result.file = raw
	elif typeof(raw) == TYPE_DICTIONARY:
		result.file = str(raw.get("file", ""))
		result.box = raw.get("box", sprite_box())
	if result.file == "" or texture(result.file) == null:
		return {}
	return result


static func texture(file: String) -> Texture2D:
	if not _textures.has(file):
		var path := DIR + file
		_textures[file] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[file]


## The room picture for an archetype and a time of day:
## {"file", "archetype", "exact"}. `exact` is false when the picture was painted
## for another time of day and needs colour grading.
static func room(archetype: String, time: String) -> Dictionary:
	var rooms: Dictionary = manifest().get("rooms", {})
	var owner := archetype if rooms.has(archetype) else "supporter"
	var pictures: Dictionary = rooms.get(owner, {})
	var order: Array[String] = [time]
	order.append_array(TIMES)
	for candidate in order:
		var file := str(pictures.get(candidate, ""))
		if file != "" and texture(file) != null:
			return {"file": file, "archetype": owner, "exact": candidate == time}
	return {"file": "", "archetype": owner, "exact": false}


## Fairy-light bulbs of a room picture, in canvas units.
static func bulbs(file: String) -> PackedVector2Array:
	var points := PackedVector2Array()
	var stored: Variant = manifest().get("bulbs", {}).get(file, [])
	if typeof(stored) == TYPE_ARRAY:
		for item: Variant in stored:
			points.push_back(Vector2(item[0], item[1]) * CANVAS_WIDTH / SOURCE_WIDTH)
	return points


## Puts `layer` (a top-left anchored sprite) where `box` sits in the room
## painting. `actor` is the BloopieActor the layer lives under.
static func place(layer: Node2D, box: Array, actor: Node2D) -> void:
	var to_canvas := CANVAS_WIDTH / SOURCE_WIDTH
	layer.position = (Vector2(box[0], box[1]) * to_canvas - actor.position) / actor.scale
	layer.scale = Vector2.ONE * to_canvas / actor.scale.x
