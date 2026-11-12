extends PanelContainer
## Care panel from the mock-up: a happiness bar on top, then four cream tiles:
## cocoa, berry tart, themes and hats. Emits `action_requested`;
## MainRoom decides what each action does.

signal action_requested(action: String)

const COCOA_PRICE := 5
const TART_PRICE := 10
const ACTIONS := [
	{"id": "cocoa", "title": "Какао", "icon": "res://art/painted/icon_cocoa.png"},
	{"id": "tart", "title": "Тарт", "icon": "res://art/painted/icon_tart.png"},
	{"id": "theme", "title": "Темы", "icon": "res://art/painted/icon_theme.png"},
	{"id": "hat", "title": "Шапочки", "icon": "res://art/painted/icon_hat.png"},
]

var _happiness: ProgressBar
var _happiness_label: Label
var _slide: Tween


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.frame(60))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	add_child(column)

	_happiness = ProgressBar.new()
	_happiness.custom_minimum_size = Vector2(0, 58)
	_happiness.show_percentage = false
	UIStyle.progress_bar(_happiness, Color("#F0667E"))
	column.add_child(_happiness)
	_happiness_label = Label.new()
	_happiness_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_happiness_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_happiness_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIStyle.label(_happiness_label, 34, Color.WHITE)
	_happiness_label.add_theme_color_override("font_outline_color", Color("#B63A55"))
	_happiness_label.add_theme_constant_override("outline_size", 10)
	_happiness.add_child(_happiness_label)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	column.add_child(grid)
	for action: Dictionary in ACTIONS:
		var button := Button.new()
		button.text = action.title
		button.icon = load(action.icon)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 190)
		UIStyle.tile(button, 30, 104)
		button.pressed.connect(func() -> void: action_requested.emit(action.id))
		grid.add_child(button)

	GameState.stats_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var happiness := GameState.get_happiness()
	_happiness.value = happiness
	_happiness_label.text = "Счастье %d%%" % happiness


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
