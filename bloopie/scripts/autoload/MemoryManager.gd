extends Node
## Polaroid album: captures a square snapshot of Bloopie, stores it as PNG under
## user://memories and keeps a JSON index with captions and dates.
## The album is always readable, including while Bloopie sleeps in the cryo-capsule.

signal memory_saved(entry: Dictionary)

const MEMORY_DIR := "user://memories"
const INDEX_PATH := "user://memories/index.json"
const PHOTO_SIZE := 512
const MAX_ENTRIES := 200

## Each entry: {"file": String, "caption": String, "unix": int}
var entries: Array[Dictionary] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(MEMORY_DIR)
	_load_index()


## Takes the snapshot around `focus_canvas_position` (viewport/canvas coordinates)
## with a square side of `side` canvas units. Returns the new entry; the photo
## file is omitted when the platform cannot read the framebuffer.
func capture(viewport: Viewport, focus_canvas_position: Vector2, side: float, caption: String) -> Dictionary:
	var unix := GameState.trusted_now()
	var entry := {"file": "", "caption": caption.strip_edges(), "unix": unix}
	var image := _grab(viewport, focus_canvas_position, side)
	if image != null:
		var path := "%s/polaroid_%d_%d.png" % [MEMORY_DIR, unix, Time.get_ticks_msec() % 1000]
		if image.save_png(path) == OK:
			entry["file"] = path
	entries.push_back(entry)
	while entries.size() > MAX_ENTRIES:
		var dropped: Dictionary = entries.pop_front()
		if not str(dropped["file"]).is_empty():
			DirAccess.remove_absolute(dropped["file"])
	_save_index()
	GameState.remember(entry["caption"])
	memory_saved.emit(entry)
	return entry


func load_photo(entry: Dictionary) -> Texture2D:
	var path := str(entry.get("file", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	return null if image == null else ImageTexture.create_from_image(image)


static func format_date(unix: int) -> String:
	var date := Time.get_datetime_dict_from_unix_time(unix + _utc_offset_seconds())
	return "%02d.%02d.%d" % [date.day, date.month, date.year]


static func _utc_offset_seconds() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func _grab(viewport: Viewport, focus: Vector2, side: float) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var texture := viewport.get_texture()
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	# Canvas units -> framebuffer pixels (the window may be scaled by the stretch mode).
	var canvas_size := viewport.get_visible_rect().size
	var pixel_scale := image.get_width() / maxf(canvas_size.x, 1.0)
	var pixel_side := int(side * pixel_scale)
	pixel_side = mini(pixel_side, mini(image.get_width(), image.get_height()))
	var origin := Vector2i((focus * pixel_scale).round()) - Vector2i(pixel_side, pixel_side) / 2
	origin.x = clampi(origin.x, 0, image.get_width() - pixel_side)
	origin.y = clampi(origin.y, 0, image.get_height() - pixel_side)
	var photo := image.get_region(Rect2i(origin, Vector2i(pixel_side, pixel_side)))
	photo.resize(PHOTO_SIZE, PHOTO_SIZE, Image.INTERPOLATE_LANCZOS)
	return photo


func _load_index() -> void:
	if not FileAccess.file_exists(INDEX_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		return
	for item: Variant in parsed:
		if typeof(item) == TYPE_DICTIONARY:
			entries.push_back({
				"file": str(item.get("file", "")),
				"caption": str(item.get("caption", "")),
				"unix": int(item.get("unix", 0)),
			})


func _save_index() -> void:
	var file := FileAccess.open(INDEX_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("MemoryManager: cannot write index (%s)" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(entries))
