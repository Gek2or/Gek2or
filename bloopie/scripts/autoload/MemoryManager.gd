extends Node
## Polaroid camera. When the AI returns a non-empty `save_to_memory`, the room
## flashes white, the viewport is photographed without the HUD, the PNG goes to
## user://memories/polaroid_<timestamp>.png and a card is added to
## GameState.album_cards. The album stays readable even in cryo-stasis.

signal memory_saved(card: Dictionary)

const MEMORY_DIR := "user://memories"
const PHOTO_SIZE := 512
const FLASH_SECONDS := 0.55

var _hud: CanvasLayer
var _flash: ColorRect
var _busy := false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(MEMORY_DIR)


## MainRoom hands over the HUD layer (hidden for the shot) and the flash rect.
func register_camera(hud: CanvasLayer, flash: ColorRect) -> void:
	_hud = hud
	_flash = flash


## Photographs a square of `side` canvas units centred on `focus` (canvas
## coordinates) and files it under `caption`. The card is saved even when the
## platform cannot read the framebuffer; it then simply has no picture.
func take_polaroid(caption: String, focus: Vector2, side: float) -> void:
	if _busy or caption.strip_edges().is_empty():
		return
	_busy = true
	if is_instance_valid(_hud):
		_hud.visible = false
	await RenderingServer.frame_post_draw
	var image := _grab(get_viewport(), focus, side)
	if is_instance_valid(_hud):
		_hud.visible = true
	_play_flash()

	var timestamp := GameState.trusted_now()
	var card := {
		"timestamp": timestamp,
		"date_string": format_date(timestamp),
		"caption": caption.strip_edges(),
		"image_path": "",
	}
	if image != null:
		var path := "%s/polaroid_%d.png" % [MEMORY_DIR, timestamp]
		if FileAccess.file_exists(path):
			path = "%s/polaroid_%d_%d.png" % [MEMORY_DIR, timestamp, Time.get_ticks_msec() % 1000]
		if image.save_png(path) == OK:
			card["image_path"] = path
	for dropped: Dictionary in GameState.add_album_card(card):
		var old_path := str(dropped.get("image_path", ""))
		if not old_path.is_empty():
			DirAccess.remove_absolute(old_path)
	GameState.remember(card["caption"])
	_busy = false
	memory_saved.emit(card)


func load_photo(card: Dictionary) -> Texture2D:
	var path := str(card.get("image_path", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	return null if image == null else ImageTexture.create_from_image(image)


static func format_date(unix: int) -> String:
	var bias_seconds := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var date := Time.get_datetime_dict_from_unix_time(unix + bias_seconds)
	return "%02d.%02d" % [date.day, date.month]


func _play_flash() -> void:
	if not is_instance_valid(_flash):
		return
	_flash.visible = true
	_flash.modulate.a = 1.0
	var fade := _flash.create_tween()
	fade.tween_property(_flash, "modulate:a", 0.0, FLASH_SECONDS)
	fade.tween_callback(func() -> void: _flash.visible = false)


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
	photo.convert(Image.FORMAT_RGB8)
	photo.resize(PHOTO_SIZE, PHOTO_SIZE, Image.INTERPOLATE_LANCZOS)
	return photo
