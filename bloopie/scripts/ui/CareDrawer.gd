extends PanelContainer
## Slide-up care panel: treats, a bubble bath, and customization (theme, hat,
## window mood). Emits `action_requested`; MainRoom decides what each action does.

signal action_requested(action: String)

const ACTIONS := [
	{"id": "cocoa", "title": "Какао", "icon": "res://art/icons/cocoa.svg", "color": UIStyle.BUTTER},
	{"id": "tart", "title": "Тарт", "icon": "res://art/icons/tart.svg", "color": UIStyle.ROSE},
	{"id": "wash", "title": "Умыть", "icon": "res://art/icons/wash.svg", "color": UIStyle.SKY},
	{"id": "theme", "title": "Тема", "icon": "res://art/icons/theme.svg", "color": UIStyle.LILAC},
	{"id": "hat", "title": "Шапочка", "icon": "res://art/icons/hat.svg", "color": UIStyle.MINT},
	{"id": "weather", "title": "Погода", "icon": "res://art/icons/weather.svg", "color": UIStyle.BUTTER},
]

var _status: Label
var _slide: Tween


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.card(UIStyle.CREAM, 56))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	add_child(column)

	var title := Label.new()
	title.text = "Забота"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.label(title, 46)
	column.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	column.add_child(grid)
	for action: Dictionary in ACTIONS:
		var button := Button.new()
		button.text = action.title
		button.icon = load(action.icon)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.expand_icon = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 170)
		UIStyle.button(button, action.color, 36)
		button.add_theme_font_size_override("font_size", 32)
		button.pressed.connect(func() -> void: action_requested.emit(action.id))
		grid.add_child(button)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.label(_status, 28, Color(UIStyle.INK, 0.75))
	column.add_child(_status)

	GameState.theme_changed.connect(func(_id: String) -> void: refresh())
	GameState.hat_changed.connect(func(_id: String) -> void: refresh())
	GameState.level_changed.connect(func(_level: int) -> void: refresh())
	TimeWeatherSystem.atmosphere_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var text := "Тема: %s  ·  Шапочка: %s\nЗа окном: %s" % [
		GameState.THEMES[GameState.theme_id].title,
		GameState.HATS[GameState.hat_id].title.to_lower(),
		TimeWeatherSystem.MODE_TITLES[GameState.window_mode].to_lower(),
	]
	var locked := GameState.next_locked_hat()
	if not locked.is_empty():
		text += "\n«%s» откроется на Lv.%d" % [GameState.HATS[locked].title, GameState.HATS[locked].level]
	_status.text = text


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	refresh()
	visible = true
	modulate.a = 0.0
	_restart_slide()
	_slide.tween_property(self, "modulate:a", 1.0, 0.18)


func close() -> void:
	if not visible:
		return
	_restart_slide()
	_slide.tween_property(self, "modulate:a", 0.0, 0.15)
	_slide.tween_callback(func() -> void: visible = false)


func _restart_slide() -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = create_tween()
