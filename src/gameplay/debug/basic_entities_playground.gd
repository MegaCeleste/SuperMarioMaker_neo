extends Node2D
## REQ-PHYS-123. Repeatable entity course with no changes to the main terrain.

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/player/player.tscn")
const CONFIG_PATH: String = "res://data/debug/basic_entities_playground.json"
const TEXT_PATH: String = "res://data/i18n/strings.csv"
const DASHBOARD_PATH: String = "res://src/gameplay/debug/physics_dashboard.tscn"
const MARGIN: float = 12.0
const PANEL_WIDTH: float = 340.0

var _config: Dictionary = {}
var _world: Node2D
var _player: Player
var _camera: Camera2D
var _form_select: OptionButton
var _spawn_select: OptionButton
var _pause_button: Button
var _stats: Label
var _spawn_index: int = 0
var _bounds: bool = false
var _pause_after_step: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 1000
	_install_translations()
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing entity playground configuration")
		return
	_config = JSON.parse_string(file.get_as_text()) as Dictionary
	_build_hud()
	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * float(_config["camera_zoom"])
	add_child(_camera)
	_camera.make_current()
	_reset_playground()


func _build_world() -> void:
	_world = Node2D.new()
	_world.name = "World"
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	for solid: Dictionary in _config["solids"]:
		_add_solid(_vector(solid["center"] as Array), _vector(solid["size"] as Array))
	for entry: Dictionary in _config["objects"]:
		var actor: Node2D = Registry.instantiate_object(String(entry["id"]), entry.get("properties", {}) as Dictionary)
		if actor == null:
			continue
		actor.position = _vector(entry["position"] as Array)
		_world.add_child(actor)
		if entry.has("label"):
			_add_caption(actor.position + Vector2(0.0, -32.0), String(entry["label"]))
	for caption: Dictionary in _config["captions"]:
		_add_caption(_vector(caption["position"] as Array), String(caption["key"]))
	_player = PLAYER_SCENE.instantiate() as Player
	var spawn: Dictionary = (_config["spawns"] as Array)[_spawn_index] as Dictionary
	_player.position = _vector(spawn["feet_position"] as Array) - Vector2(0.0, _player.physics_profile.feet_y)
	_player.show_collision_shapes = _bounds
	_world.add_child(_player)
	_player.reset_to(_player.global_position, _selected_form())


func _add_solid(center: Vector2, dimensions: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = center
	body.collision_layer = CollisionConfig.layer("solids")
	body.collision_mask = CollisionConfig.mask(["player", "enemies", "pickups", "projectiles"])
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = dimensions
	shape.shape = rectangle
	body.add_child(shape)
	var visual: Polygon2D = Polygon2D.new()
	var half: Vector2 = dimensions / 2.0
	visual.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	visual.color = Color(0.3, 0.5, 0.36)
	body.add_child(visual)
	_world.add_child(body)


func _add_caption(at: Vector2, key: String) -> void:
	var label: Label = Label.new()
	label.position = at - Vector2(48.0, 0.0)
	label.custom_minimum_size.x = 96.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.text = tr(key)
	_world.add_child(label)


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2.ONE * MARGIN
	panel.custom_minimum_size.x = PANEL_WIDTH
	layer.add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.size = Vector2(PANEL_WIDTH + 20.0, minf(420.0, get_viewport_rect().size.y - MARGIN * 2.0))
	panel.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size.x = PANEL_WIDTH
	scroll.add_child(column)
	var title: Label = Label.new()
	title.text = tr("PLAY_TITLE")
	column.add_child(title)
	var selectors: HBoxContainer = HBoxContainer.new()
	column.add_child(selectors)
	_spawn_select = OptionButton.new()
	_spawn_select.focus_mode = Control.FOCUS_NONE
	for spawn: Dictionary in _config["spawns"]:
		_spawn_select.add_item(tr(String(spawn["label"])))
	_spawn_select.item_selected.connect(_on_spawn_selected)
	selectors.add_child(_spawn_select)
	_form_select = OptionButton.new()
	_form_select.focus_mode = Control.FOCUS_NONE
	for key: String in ["DASH_SMALL", "DASH_SUPER", "DASH_FIRE"]:
		_form_select.add_item(tr(key))
	_form_select.item_selected.connect(_on_form_selected)
	selectors.add_child(_form_select)
	var controls: HBoxContainer = HBoxContainer.new()
	column.add_child(controls)
	_add_button(controls, "DASH_RESET", _reset_playground)
	_pause_button = _add_button(controls, "DASH_PAUSE", _toggle_pause)
	_add_button(controls, "DASH_STEP", _step)
	var actions: HBoxContainer = HBoxContainer.new()
	column.add_child(actions)
	_add_button(actions, "DASH_TITLE", _open_dashboard)
	var bounds: CheckButton = CheckButton.new()
	bounds.text = tr("DASH_BOUNDS")
	bounds.focus_mode = Control.FOCUS_NONE
	bounds.toggled.connect(_on_bounds_toggled)
	actions.add_child(bounds)
	_stats = Label.new()
	column.add_child(_stats)
	var help: Label = Label.new()
	help.custom_minimum_size.x = PANEL_WIDTH
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = tr("PLAY_HELP").replace("\\n", "\n")
	column.add_child(help)
	var controls_hint: Label = Label.new()
	controls_hint.text = tr("DASH_CONTROLS").replace("\\n", "\n")
	column.add_child(controls_hint)


func _add_button(parent: Control, key: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = tr(key)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _reset_playground() -> void:
	_pause_after_step = false
	GameManager.clear_gameplay_freeze()
	GameManager.reset_coins()
	if is_instance_valid(_player):
		_player.reset_to(_player.global_position, _selected_form())
	if is_instance_valid(_world):
		remove_child(_world)
		_world.queue_free()
	_build_world()
	_update_camera()
	_update_hud()


func _on_spawn_selected(index: int) -> void:
	_spawn_index = index
	_reset_playground()


func _on_form_selected(_index: int) -> void:
	_reset_playground()


func _selected_form() -> PowerUpManager.Form:
	match _form_select.selected:
		1: return PowerUpManager.Form.SUPER
		2: return PowerUpManager.Form.FIRE
	return PowerUpManager.Form.SMALL


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_update_camera()
	_update_hud()
	if _pause_after_step:
		_pause_after_step = false
		var step_end: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		step_end.tween_callback(_finish_single_step)


func _update_camera() -> void:
	_camera.position = Vector2(_player.global_position.x + float(_config["camera_lead"]), float(_config["ground_y"]) - float(_config["camera_height"]))
	_camera.force_update_scroll()


func _update_hud() -> void:
	_stats.text = (tr("PLAY_STATS") % [GameManager.coins, PlayerMovementStateMachine.State.keys()[_player.movement_state],
		PowerUpManager.Form.keys()[_player.power_form], PowerUpManager.Phase.keys()[_player.power_phase],
		tr("PLAY_YES") if _player.carry.is_carrying() else tr("PLAY_NO")]).replace("\\n", "\n")
	_stats.text += "\n" + tr("PLAY_REWARDS") % [GameManager.extra_lives, _player.effects.star_left]
	_pause_button.text = tr("DASH_RESUME") if get_tree().paused else tr("DASH_PAUSE")


func _toggle_pause() -> void:
	_pause_after_step = false
	get_tree().paused = not get_tree().paused


func _step() -> void:
	get_tree().paused = false
	_pause_after_step = true


func _finish_single_step() -> void:
	get_tree().paused = true
	_update_hud()


func _on_bounds_toggled(enabled: bool) -> void:
	_bounds = enabled
	_player.show_collision_shapes = enabled
	_player.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_reset"):
		_reset_playground()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"debug_pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"debug_step"):
		_step()
		get_viewport().set_input_as_handled()
	elif get_tree().paused and is_instance_valid(_player):
		_player.record_input_event(event)
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().gui_release_focus()


func _open_dashboard() -> void:
	_pause_after_step = false
	get_tree().paused = false
	GameManager.clear_gameplay_freeze()
	get_tree().change_scene_to_file(DASHBOARD_PATH)


func _vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


func _install_translations() -> void:
	var file: FileAccess = FileAccess.open(TEXT_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing entity translation table")
		return
	var english: Translation = Translation.new()
	english.locale = "en_US"
	var chinese: Translation = Translation.new()
	chinese.locale = "zh_CN"
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 3 and not row[0].is_empty():
			english.add_message(row[0], row[1])
			chinese.add_message(row[0], row[2])
	TranslationServer.add_translation(english)
	TranslationServer.add_translation(chinese)
