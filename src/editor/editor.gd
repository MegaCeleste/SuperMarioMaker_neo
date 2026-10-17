class_name MakerEditor
extends Control
## 场景控制器：连接 UI 请求与局部状态，不承担关卡编辑或游戏生命周期。

const TEXT_PATH: String = "res://data/i18n/strings.csv"
const TOOL_TEXT: Array[StringName] = [&"MAKER_DRAW", &"MAKER_ERASE", &"MAKER_SELECT"]
const CATEGORIES: Array[String] = ["terrain", "item", "enemy", "gizmo"]
const REFERENCE_SIZE: Vector2 = Vector2(1920, 1080)

@onready var maker_viewport: MakerViewport = %MakerViewport
@onready var wheel: PaletteWheel = %Wheel
@onready var overlay: Control = %ModalOverlay
@onready var palette_panel: Control = %PalettePanel
@onready var view_panel: Control = %ViewPanel
@onready var position_slider: HSlider = %PositionSlider
@onready var grid_button: Button = %GridButton
@onready var coordinates_label: Label = %CoordinatesLabel
@onready var reference_ui: Control = %ReferenceUI
@onready var tool_buttons: Array[Button] = [%DrawButton, %EraseButton, %SelectButton]
@onready var category_buttons: Array[Button] = [%TerrainCategory, %ItemCategory, %EnemyCategory, %GizmoCategory]

var state: EditorState = EditorState.new()
var catalog: EditorCatalog = EditorCatalog.new()
var _palette_buttons: Dictionary[String, Button] = {}
var _category: String = "terrain"
var _previous_scale_size: Vector2i
var _previous_scale_mode: Window.ContentScaleMode
var _previous_min_size: Vector2i
var _previous_msaa_2d: Viewport.MSAA
var _previous_oversampling: float


func _ready() -> void:
	_install_translations()
	_localize_controls(self)
	_previous_scale_size = get_window().content_scale_size
	_previous_scale_mode = get_window().content_scale_mode
	_previous_min_size = get_window().min_size
	_previous_msaa_2d = get_window().msaa_2d
	_previous_oversampling = get_window().oversampling_override
	# This independent editor uses actual window space for container layout.
	get_window().content_scale_size = Vector2i.ZERO
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().min_size = Vector2i(960, 540)
	# Smooth vector geometry in the UI viewport; the pixel-art SubViewport stays separate.
	get_window().msaa_2d = Viewport.MSAA_4X
	_build_palette()
	_connect_controls()
	maker_viewport.bind(state, catalog)
	state.changed.connect(_sync_state)
	state.view_changed.connect(_sync_view)
	maker_viewport.resized.connect(_sync_view)
	get_viewport().size_changed.connect(_resize_reference_ui)
	_resize_reference_ui()
	_sync_state()
	_sync_view()
	_on_hovered_cell(Vector2i(-1, -1))


func _build_palette() -> void:
	for entry: Dictionary in EditorCatalog.QUICK_PARTS:
		var object_id: String = String(entry.get("id", ""))
		var button: MakerArtButton = %PaletteItems.get_node(String(entry["icon"])) as MakerArtButton
		button.disabled = object_id.is_empty()
		if button.disabled:
			button.art = EditorCatalog.load_optional(EditorCatalog.ICON_ROOT + String(entry["icon"]) + ".png")
		else:
			button.art = catalog.icon_for(object_id)
			button.pressed.connect(_choose_object.bind(object_id))
			_palette_buttons[object_id] = button


func _connect_controls() -> void:
	%PaletteButton.pressed.connect(_toggle_panel.bind(EditorState.PanelKind.PALETTE))
	%MenuButton.pressed.connect(_toggle_panel.bind(EditorState.PanelKind.MENU))
	for button: Button in [%CoursebotButton, %StyleButton, %ThemeButton, %TimeButton, %ScrollButton, %ClearButton]:
		button.disabled = true
	var tool_group: ButtonGroup = ButtonGroup.new()
	tool_group.allow_unpress = false
	for index: int in tool_buttons.size():
		tool_buttons[index].button_group = tool_group
		tool_buttons[index].pressed.connect(_choose_tool.bind(index))
	for index: int in category_buttons.size():
		category_buttons[index].pressed.connect(_choose_category.bind(CATEGORIES[index]))
	%CloseButton.pressed.connect(state.close_panel)
	%Shade.gui_input.connect(_on_shade_input)
	wheel.object_chosen.connect(_choose_object)
	%PreviousPage.pressed.connect(wheel.turn_page.bind(-1))
	%NextPage.pressed.connect(wheel.turn_page.bind(1))
	grid_button.toggled.connect(state.set_grid_visible)
	position_slider.value_changed.connect(func(value: float) -> void: maker_viewport.pan_horizontal(value, true))
	maker_viewport.hovered_cell_changed.connect(_on_hovered_cell)
	_connect_toolbar_input(reference_ui)


func _connect_toolbar_input(node: Node) -> void:
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		node.gui_input.connect(func(_event: InputEvent) -> void: maker_viewport.suspend_pointer())
	for child: Node in node.get_children():
		_connect_toolbar_input(child)


func _choose_tool(value: int) -> void:
	state.select_tool(value as EditorState.Tool)


func _choose_object(object_id: String) -> void:
	if Registry.has_object(object_id):
		state.select_object(object_id)


func _choose_category(value: String) -> void:
	_category = value
	wheel.configure(catalog, _category, state.object_id)
	for index: int in category_buttons.size():
		category_buttons[index].set_pressed_no_signal(CATEGORIES[index] == value)
		(category_buttons[index] as PaletteCategoryButton)._update_width(CATEGORIES[index] == value)


func _toggle_panel(value: EditorState.PanelKind) -> void:
	if value == EditorState.PanelKind.PALETTE:
		_category = String(Registry.get_object(state.object_id).get("category", "terrain"))
		if _category == "block":
			_category = "terrain"
	state.toggle_panel(value)


func _sync_state() -> void:
	for index: int in tool_buttons.size():
		tool_buttons[index].set_pressed_no_signal(index == state.tool)
	for object_id: String in _palette_buttons:
		_palette_buttons[object_id].set_pressed_no_signal(object_id == state.object_id)
	grid_button.set_pressed_no_signal(state.grid_visible)
	overlay.visible = state.panel != EditorState.PanelKind.NONE
	palette_panel.visible = state.panel == EditorState.PanelKind.PALETTE
	view_panel.visible = state.panel == EditorState.PanelKind.MENU
	reference_ui.visible = state.panel != EditorState.PanelKind.PALETTE
	%Shade.color = Color(1, 1, 1, 0.60) if palette_panel.visible else Color(0, 0, 0, 0.15)
	maker_viewport.set_input_blocked(overlay.visible)
	if state.panel == EditorState.PanelKind.PALETTE:
		_choose_category(_category)


func _sync_view() -> void:
	if is_queued_for_deletion() or not is_instance_valid(position_slider):
		return
	var half_width: float = maker_viewport.size.x * 0.5 / maker_viewport.view_scale
	# Range bound changes can emit value_changed before set_value_no_signal.
	position_slider.set_block_signals(true)
	position_slider.min_value = half_width
	position_slider.max_value = EditorState.AREA_SIZE.x * EditorState.CELL_SIZE - half_width
	position_slider.set_value_no_signal(state.view_center.x)
	position_slider.set_block_signals(false)
	%ZoomLabel.text = "%d%%" % roundi(state.zoom * 100)


func _resize_reference_ui() -> void:
	if is_queued_for_deletion() or not is_instance_valid(reference_ui):
		return
	var extent: Vector2 = get_viewport_rect().size
	var factor: float = minf(extent.x / REFERENCE_SIZE.x, extent.y / REFERENCE_SIZE.y)
	# Window stretching is disabled here, so explicitly rerasterize SVGs for our UI scale.
	# Two samples per reference pixel smooth vector edges without filtering the world.
	get_window().oversampling_override = maxf(1.0, factor * 2.0)
	reference_ui.scale = Vector2.ONE * factor
	reference_ui.size = extent / factor
	palette_panel.scale = Vector2.ONE * factor
	palette_panel.position = (extent - REFERENCE_SIZE * factor) * 0.5
	view_panel.scale = Vector2.ONE * factor
	view_panel.position = Vector2(extent.x - 750 * factor, 220 * factor)


func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		state.close_panel()
		%Shade.accept_event()


func _on_hovered_cell(cell: Vector2i) -> void:
	if is_queued_for_deletion() or not is_instance_valid(coordinates_label):
		return
	coordinates_label.text = tr("MAKER_CELL") % [cell.x, cell.y] if cell.x >= 0 else tr("MAKER_CANVAS_HINT")


func _input(event: InputEvent) -> void:
	# Tab must be handled before built-in GUI focus navigation. Text fields keep it.
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if event.is_action_pressed(&"editor_close_panel"):
		state.close_panel()
	elif event.is_action_pressed(&"editor_palette"):
		_toggle_panel(EditorState.PanelKind.PALETTE)
	elif state.panel != EditorState.PanelKind.NONE:
		return
	elif event.is_action_pressed(&"editor_draw"):
		state.select_tool(EditorState.Tool.DRAW)
	elif event.is_action_pressed(&"editor_erase"):
		state.select_tool(EditorState.Tool.ERASE)
	elif event.is_action_pressed(&"editor_select"):
		state.select_tool(EditorState.Tool.SELECT)
	elif event.is_action_pressed(&"editor_toggle_grid"):
		state.set_grid_visible(not state.grid_visible)
	else:
		return
	get_viewport().set_input_as_handled()


func _install_translations() -> void:
	var file: FileAccess = FileAccess.open(TEXT_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing editor translation table")
		return
	var english: Translation = Translation.new()
	english.locale = "en_US"
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 3 and not row[0].is_empty():
			english.add_message(row[0], row[1])
	TranslationServer.add_translation(english)
	TranslationServer.set_locale("en_US")


func _localize_controls(node: Node) -> void:
	# CSV is installed after children enter the tree, so translate initial keys explicitly.
	if node is Label or node is Button:
		var original: String = String(node.get("text"))
		if original.begins_with("MAKER_"):
			node.set("text", tr(original))
	if node is Control:
		var control: Control = node as Control
		control.tooltip_text = ""
	for child: Node in node.get_children():
		_localize_controls(child)


func _exit_tree() -> void:
	get_viewport().size_changed.disconnect(_resize_reference_ui)
	get_window().content_scale_size = _previous_scale_size
	get_window().content_scale_mode = _previous_scale_mode
	get_window().min_size = _previous_min_size
	get_window().msaa_2d = _previous_msaa_2d
	get_window().oversampling_override = _previous_oversampling
