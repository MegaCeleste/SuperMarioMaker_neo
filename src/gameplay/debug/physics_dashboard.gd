extends Node2D
## REQ-PHYS-108/116/119. This scene never overwrites the checked-in baseline.

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/player/player.tscn")
const QUESTION_BLOCK_SCENE: PackedScene = preload("res://src/gameplay/blocks/question_block.tscn")
const MUSHROOM_SCENE: PackedScene = preload("res://src/gameplay/entities/mushroom.tscn")
const ENEMY_SCENE: PackedScene = preload("res://src/gameplay/enemies/goomba.tscn")
const GRAPH_SCRIPT: Script = preload("res://src/gameplay/debug/velocity_graph.gd")
const CONFIG_PATH: String = "res://data/debug/physics_dashboard.json"
const EVIDENCE_PATH: String = "res://data/physics/player_parameter_evidence.json"
const EXPORT_DIR: String = "user://physics_tuning"
const TEXT_PATH: String = "res://data/i18n/strings.csv"
const PHYSICS_PRESETS: PackedStringArray = ["res://data/physics/base_physics.tres", "res://data/physics/pre_smmwe_physics.tres"]
const REFERENCE_PARAMETERS: PackedStringArray = ["air_reverse_accel", "ground_overspeed_decel", "moving_jump_initial", "moving_jump_threshold", "run_jump_threshold", "apex_gravity_threshold"]
const PLAYGROUND_PATH: String = "res://src/gameplay/debug/basic_entities_playground.tscn"
const TILE: float = 16.0
const MAX_SAMPLES: int = 7200
const PANEL_WIDTH: float = 350.0
const MARGIN: float = 12.0
const CSV_FIELDS: PackedStringArray = ["sample", "frame", "scenario", "x", "y", "vx", "vy", "state", "form", "power_phase", "transition_frames", "style", "grounded", "crouched", "jump_kind", "coyote", "buffer", "p_meter", "frozen", "invulnerability", "animation", "animation_frame", "animation_fps", "terrain_height", "hurt_height", "axis", "run", "down", "up", "jump", "spin", "jump_pressed", "spin_pressed", "run_pressed", "jump_released", "spin_released", "run_released"]

var _config: Dictionary = {}
var _world: Node2D
var _block: InteractableBlock
var _enemy: Enemy
var _probes: Array[CarryableProbe] = []
var _player: Player
var _camera: Camera2D
var _stats: Label
var _metrics: Label
var _status: Label
var _tuner: PanelContainer
var _readout: PanelContainer
var _velocity_graph: Control
var _height_graph: Control
var _style_select: OptionButton
var _physics_select: OptionButton
var _form_select: OptionButton
var _scenario_select: OptionButton
var _scenario_hint: Label
var _scenario_index: int = 0
var _pause_button: Button
var _samples: Array[Dictionary] = []
var _parameter_changes: Array[Dictionary] = []
var _parameter_controls: Dictionary[String, SpinBox] = {}
var _last_snapshot: Dictionary = {}
var _recording_profile: Dictionary = {}
var _pause_after_step: bool = false
var _jump_tracking: bool = false
var _jump_has_moved: bool = false
var _jump_start_y: float = 0.0
var _jump_apex_y: float = 0.0
var _jump_frames: int = 0
var _jump_apex_frame: int = 0
var _last_jump_height: float = 0.0
var _last_jump_frames: int = 0
var _last_jump_apex_frame: int = 0
var _accel_tracking: bool = false
var _accel_frames: int = 0
var _last_accel_frames: int = 0
var _accel_direction: float = 0.0
var _skid_tracking: bool = false
var _skid_start_x: float = 0.0
var _skid_frames: int = 0
var _skid_direction: float = 0.0
var _last_skid_frames: int = 0
var _last_skid_distance: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 1000
	_install_translations()
	_config = _read_dictionary(CONFIG_PATH)
	_build_world()
	_build_hud()
	get_viewport().size_changed.connect(_layout_panels)
	_layout_panels()
	_player.physics_stepped.connect(_on_snapshot)
	_player.jump_started.connect(_on_jump_started)
	_player.landed.connect(_on_landed)
	_player.movement_state_changed.connect(_on_movement_state_changed)
	_reset_measurements()
	_update_camera()


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	_player.input_enabled = not focus is LineEdit
	_update_camera()
	if _pause_after_step:
		_pause_after_step = false
		var step_end: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		step_end.tween_callback(_finish_single_step)
	_update_hud()


func _update_camera() -> void:
	_camera.position = Vector2(_player.global_position.x + float(_config["camera_lead"]), float(_config["ground_y"]) - float(_config["camera_height"]))
	_camera.force_update_scroll()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_reset"):
		_reset_player()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"debug_pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"debug_step"):
		_step()
		get_viewport().set_input_as_handled()
	elif get_tree().paused:
		_player.record_input_event(event)
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().gui_release_focus()


func _build_world() -> void:
	_world = Node2D.new()
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	var ground: float = float(_config["ground_y"])
	var width: float = float(_config["track_width"])
	_add_solid(Vector2(width / 2.0 - TILE * 8.0, ground + TILE / 2.0), Vector2(width, TILE), Color(0.3, 0.5, 0.36))
	for solid: Dictionary in _config["solids"]:
		_add_solid(_vector_from_array(solid["center"] as Array), _vector_from_array(solid["size"] as Array))
	_spawn_interactions()
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = _spawn_position()
	_player.show_collision_shapes = true
	_world.add_child(_player)
	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * float(_config["camera_zoom"])
	add_child(_camera)
	_camera.make_current()


func _vector_from_array(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


func _spawn_interactions() -> void:
	var ground: float = float(_config["ground_y"])
	_block = QUESTION_BLOCK_SCENE.instantiate() as InteractableBlock
	_block.position = Vector2(TILE * 64.0, ground - TILE * 4.0)
	_block.set("contained_item", "smm.item.super_mushroom")
	_world.add_child(_block)
	_enemy = ENEMY_SCENE.instantiate() as Enemy
	_enemy.position = Vector2(TILE * 92.0, ground - TILE / 2.0)
	_world.add_child(_enemy)


func _reset_interactions() -> void:
	for actor: Node2D in [_block, _enemy]:
		if is_instance_valid(actor):
			_world.remove_child(actor)
			actor.queue_free()
	for probe: CarryableProbe in _probes:
		if is_instance_valid(probe):
			_world.remove_child(probe)
			probe.queue_free()
	_probes.clear()
	for child: Node in _world.get_children():
		if child is PowerUpPickup or child is Coin:
			_world.remove_child(child)
			child.queue_free()
	_spawn_interactions()


func _add_solid(center: Vector2, dimensions: Vector2, tint: Color = Color(0.58, 0.65, 0.75)) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = center
	body.collision_layer = CollisionConfig.layer("solids")
	body.collision_mask = CollisionConfig.layer("player")
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = dimensions
	shape.shape = rectangle
	body.add_child(shape)
	var visual: Polygon2D = Polygon2D.new()
	var half: Vector2 = dimensions / 2.0
	visual.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	visual.color = tint
	body.add_child(visual)
	_world.add_child(body)


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	_readout = panel
	panel.position = Vector2.ONE * MARGIN
	panel.custom_minimum_size.x = PANEL_WIDTH
	layer.add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var title: Label = Label.new()
	title.text = tr("DASH_TITLE")
	column.add_child(title)
	_scenario_select = OptionButton.new()
	_scenario_select.focus_mode = Control.FOCUS_NONE
	for scenario: Dictionary in _config["scenarios"]:
		_scenario_select.add_item(tr(String(scenario["label"])))
	_scenario_select.item_selected.connect(_on_scenario_selected)
	column.add_child(_scenario_select)
	_scenario_hint = Label.new()
	_scenario_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scenario_hint.custom_minimum_size.x = PANEL_WIDTH - MARGIN * 2.0
	_scenario_hint.text = tr(String(_current_scenario()["hint"]))
	column.add_child(_scenario_hint)
	_stats = Label.new()
	column.add_child(_stats)
	_metrics = Label.new()
	column.add_child(_metrics)
	var selectors: HBoxContainer = HBoxContainer.new()
	column.add_child(selectors)
	_style_select = OptionButton.new()
	_style_select.focus_mode = Control.FOCUS_NONE
	for style: String in ["SMB1", "SMB3", "SMW"]:
		_style_select.add_item(style)
	_style_select.select(2)
	_style_select.item_selected.connect(_on_style_selected)
	selectors.add_child(_style_select)
	_form_select = OptionButton.new()
	_form_select.focus_mode = Control.FOCUS_NONE
	for key: String in ["DASH_SMALL", "DASH_SUPER", "DASH_FIRE"]:
		_form_select.add_item(tr(key))
	_form_select.item_selected.connect(_on_form_selected)
	selectors.add_child(_form_select)
	_physics_select = OptionButton.new()
	_physics_select.focus_mode = Control.FOCUS_NONE
	_physics_select.add_item(tr("DASH_PHYSICS_SMMWE"))
	_physics_select.add_item(tr("DASH_PHYSICS_PREVIOUS"))
	_physics_select.item_selected.connect(_on_physics_selected)
	column.add_child(_physics_select)
	var controls: HBoxContainer = HBoxContainer.new()
	column.add_child(controls)
	_add_button(controls, "DASH_RESET", _reset_player)
	_pause_button = _add_button(controls, "DASH_PAUSE", _toggle_pause)
	_add_button(controls, "DASH_STEP", _step)
	_add_button(controls, "DASH_TUNER", _toggle_tuner)
	var interactions: GridContainer = GridContainer.new()
	interactions.columns = 2
	column.add_child(interactions)
	_add_button(interactions, "DASH_MUSHROOM", _player.collect_mushroom)
	_add_button(interactions, "DASH_FLOWER", _player.collect_fire_flower)
	_add_button(interactions, "DASH_DAMAGE", _player.take_damage)
	_add_button(interactions, "DASH_KILL", _player.die)
	_add_button(interactions, "DASH_CARRY", _spawn_carry_probe)
	_add_button(interactions, "PLAY_TITLE", _open_playground)
	var actions: HBoxContainer = HBoxContainer.new()
	column.add_child(actions)
	_add_button(actions, "DASH_EXPORT", _export_run)
	_add_button(actions, "DASH_BASELINE", _restore_baseline)
	var bounds: CheckButton = CheckButton.new()
	bounds.text = tr("DASH_BOUNDS")
	bounds.button_pressed = true
	bounds.focus_mode = Control.FOCUS_NONE
	bounds.toggled.connect(_on_bounds_toggled)
	actions.add_child(bounds)
	var explanation: Label = Label.new()
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.custom_minimum_size.x = PANEL_WIDTH - MARGIN * 2.0
	explanation.text = tr("DASH_PREVIEW_NOTE").replace("\\n", "\n")
	column.add_child(explanation)
	var graph_title: Label = Label.new()
	graph_title.text = tr("DASH_GRAPH")
	column.add_child(graph_title)
	_velocity_graph = _add_graph(column, true)
	var height_title: Label = Label.new()
	height_title.text = tr("DASH_HEIGHT_GRAPH")
	column.add_child(height_title)
	_height_graph = _add_graph(column, false)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = PANEL_WIDTH - MARGIN * 2.0
	column.add_child(_status)
	var footer: Label = Label.new()
	footer.text = tr("DASH_CONTROLS").replace("\\n", "\n")
	column.add_child(footer)
	_build_tuner(layer)


func _add_button(parent: Control, key: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = tr(key)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_graph(parent: Control, second_curve: bool) -> Control:
	var graph: Control = Control.new()
	graph.set_script(GRAPH_SCRIPT)
	graph.custom_minimum_size = Vector2(PANEL_WIDTH - MARGIN * 2.0, 64.0)
	graph.set("show_second_curve", second_curve)
	parent.add_child(graph)
	return graph


func _build_tuner(layer: CanvasLayer) -> void:
	_tuner = PanelContainer.new()
	layer.add_child(_tuner)
	var column: VBoxContainer = VBoxContainer.new()
	_tuner.add_child(column)
	var heading: Label = Label.new()
	heading.text = tr("DASH_TUNING_TITLE")
	column.add_child(heading)
	var comparison: HBoxContainer = HBoxContainer.new()
	column.add_child(comparison)
	_add_button(comparison, "DASH_SKID_400", _select_skid.bind(400.0))
	_add_button(comparison, "DASH_SKID_468", _select_skid.bind(468.0))
	_add_button(comparison, "DASH_SKID_540", _select_skid.bind(540.0))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for parameter: Dictionary in _config["parameters"]:
		var field: String = String(parameter["field"])
		var label: Label = Label.new()
		label.text = tr(String(parameter["label"]))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		var control: SpinBox = SpinBox.new()
		control.min_value = float(parameter["min"])
		control.max_value = float(parameter["max"])
		control.step = float(parameter["step"])
		control.value = float(_player.physics_profile.get(field))
		control.editable = field not in REFERENCE_PARAMETERS or _player.physics_profile.motion_model == PlayerPhysicsProfile.MotionModel.SMMWE
		control.custom_minimum_size.x = 100.0
		control.value_changed.connect(_on_parameter_changed.bind(field))
		control.get_line_edit().focus_entered.connect(_on_tuning_focus_entered)
		control.get_line_edit().focus_exited.connect(_on_tuning_focus_exited)
		grid.add_child(control)
		_parameter_controls[field] = control


func _layout_panels() -> void:
	if _tuner == null:
		return
	var viewport: Vector2 = get_viewport_rect().size
	_tuner.position = Vector2(viewport.x - PANEL_WIDTH - MARGIN, MARGIN)
	_tuner.size = Vector2(PANEL_WIDTH, viewport.y - MARGIN * 2.0)
	_readout.size = Vector2(PANEL_WIDTH, viewport.y - MARGIN * 2.0)


func _update_hud() -> void:
	var profile: PlayerPhysicsProfile = _player.physics_profile
	var frozen: bool = GameManager.is_gameplay_frozen
	_stats.text = (tr("DASH_STATS_V3") % [_player.velocity.x, _player.velocity.y, _player.global_position.x, _player.global_position.y,
		PlayerMovementStateMachine.State.keys()[_player.movement_state], PowerUpManager.Form.keys()[_player.power_form],
		PowerUpManager.Phase.keys()[_player.power_phase], tr("DASH_FROZEN") if frozen else tr("DASH_ACTIVE"),
		_player.powerups.transition_left, _player.motion.coyote_left, _player.motion.buffer_left,
		String(_player.animated_sprite.animation), _player.animated_sprite.frame, _player.get_current_animation_fps(),
		_player.collisions.terrain_height, _player.collisions.hurt_height, _player.powerups.invulnerability_left,
		_player.p_meter, profile.p_meter_max]).replace("\\n", "\n")
	_metrics.text = (tr("DASH_METRICS") % [_last_accel_frames, _last_skid_frames, _last_skid_distance,
		_last_jump_height, _last_jump_apex_frame, _last_jump_frames]).replace("\\n", "\n")
	_metrics.text += "\n" + tr("PLAY_COINS") % GameManager.coins
	_pause_button.text = tr("DASH_RESUME") if get_tree().paused else tr("DASH_PAUSE")
	_velocity_graph.set("speed_limit", maxf(profile.max_fall, absf(profile.run_jump_initial)))
	_height_graph.set("speed_limit", maxf(_last_jump_height, TILE * 8.0))


func _on_snapshot(value: Dictionary) -> void:
	var row: Dictionary = value.duplicate(true)
	row["sample"] = _next_sample_index()
	row["scenario"] = String(_current_scenario()["id"])
	_samples.append(row)
	if _samples.size() > MAX_SAMPLES:
		_samples.remove_at(0)
	if not bool(row["frozen"]):
		_update_motion_measurements(row)
		if _jump_tracking:
			_jump_has_moved = _jump_has_moved or not is_equal_approx(float(row["y"]), _jump_start_y)
			if _jump_has_moved:
				_jump_frames += 1
			if float(row["y"]) < _jump_apex_y:
				_jump_apex_y = float(row["y"])
				_jump_apex_frame = _jump_frames
	_velocity_graph.call("push_sample", float(row["vx"]), float(row["vy"]))
	_height_graph.call("push_sample", float(_config["ground_y"]) - _player.feet_y(), 0.0)
	_last_snapshot = row


func _update_motion_measurements(row: Dictionary) -> void:
	var input: Dictionary = row["input"] as Dictionary
	var speed: float = float(row["vx"])
	var previous_speed: float = float(_last_snapshot.get("vx", 0.0))
	var axis: float = float(input["axis"])
	var grounded: bool = bool(row["grounded"])
	var started_accel: bool = false
	if not _accel_tracking and grounded and bool(input["run"]) and absf(previous_speed) <= _player.physics_profile.speed_epsilon and absf(speed) > _player.physics_profile.speed_epsilon:
		_accel_tracking = true
		_accel_frames = 0
		_accel_direction = signf(axis)
		started_accel = true
	if _accel_tracking:
		if not grounded or not bool(input["run"]) or signf(axis) != _accel_direction:
			_accel_tracking = false
		else:
			_accel_frames += 1
			if _player.physics_profile.is_full_speed(speed):
				_last_accel_frames = _accel_frames
				_accel_tracking = false
	if not _skid_tracking and String(row["state"]) == "SKID" and absf(previous_speed) >= _player.physics_profile.skid_threshold:
		_skid_tracking = true
		_skid_frames = 0
		_skid_start_x = float(_last_snapshot.get("x", row["x"]))
		_skid_direction = signf(previous_speed)
	if _skid_tracking:
		if not grounded or is_zero_approx(axis) or signf(axis) == _skid_direction:
			_skid_tracking = false
		else:
			_skid_frames += 1
			if absf(speed) <= _player.physics_profile.speed_epsilon or signf(speed) != _skid_direction:
				_last_skid_frames = _skid_frames
				_last_skid_distance = absf(float(row["x"]) - _skid_start_x)
				_skid_tracking = false
	if started_accel:
		_status.text = tr("DASH_MEASURING")


func _on_jump_started(_kind: PlayerMotion.JumpKind, _horizontal_speed: float, _vertical_speed: float) -> void:
	_jump_tracking = true
	_jump_has_moved = false
	_jump_start_y = _player.global_position.y
	_jump_apex_y = _jump_start_y
	_jump_frames = 0
	_jump_apex_frame = 0


func _on_landed(_incoming_speed: float) -> void:
	if _jump_tracking:
		_last_jump_height = _jump_start_y - _jump_apex_y
		_last_jump_frames = _jump_frames + 1
		_last_jump_apex_frame = _jump_apex_frame
	_jump_tracking = false


func _on_movement_state_changed(_previous: PlayerMovementStateMachine.State, current: PlayerMovementStateMachine.State) -> void:
	if current == PlayerMovementStateMachine.State.DEAD:
		_jump_tracking = false
		_accel_tracking = false
		_skid_tracking = false


func _current_scenario() -> Dictionary:
	return (_config["scenarios"] as Array)[_scenario_index] as Dictionary


func _on_scenario_selected(index: int) -> void:
	_scenario_index = index
	var scenario: Dictionary = _current_scenario()
	if scenario.has("initial_form"):
		var forms: Array[String] = ["small", "super", "fire"]
		var form_index: int = forms.find(String(scenario["initial_form"]))
		if form_index >= 0:
			_form_select.select(form_index)
	_scenario_hint.text = tr(String(scenario["hint"]))
	get_tree().paused = bool(scenario.get("pause_on_start", false))
	_reset_player()


func _on_style_selected(index: int) -> void:
	var styles: Array[String] = ["smb1", "smb3", "smw"]
	_player.set_style(styles[index])
	_status.text = tr("DASH_STYLE_NOTE") % styles[index].to_upper()


func _selected_form() -> PowerUpManager.Form:
	match _form_select.selected:
		1: return PowerUpManager.Form.SUPER
		2: return PowerUpManager.Form.FIRE
	return PowerUpManager.Form.SMALL


func _on_form_selected(_index: int) -> void:
	_reset_player()


func _reset_player() -> void:
	_pause_after_step = false
	_player.reset_to(_spawn_position(), _selected_form())
	_reset_interactions()
	_reset_measurements()
	if bool(_current_scenario().get("pause_on_start", false)):
		get_tree().paused = true
	_update_camera()
	_update_hud()


func _spawn_position() -> Vector2:
	var feet: Vector2 = _vector_from_array(_current_scenario()["feet_position"] as Array)
	return feet - Vector2(0.0, _player.physics_profile.feet_y)


func _reset_measurements() -> void:
	GameManager.reset_coins()
	_samples.clear()
	_parameter_changes.clear()
	_recording_profile = _capture_profile()
	_last_snapshot.clear()
	_jump_tracking = false
	_accel_tracking = false
	_skid_tracking = false
	_last_accel_frames = 0
	_last_skid_frames = 0
	_last_skid_distance = 0.0
	_last_jump_height = 0.0
	_last_jump_frames = 0
	_last_jump_apex_frame = 0
	_velocity_graph.call("clear")
	_height_graph.call("clear")
	_status.text = tr("DASH_READY")


func _next_sample_index() -> int:
	return 0 if _samples.is_empty() else int(_samples.back()["sample"]) + 1


func _toggle_pause() -> void:
	_pause_after_step = false
	get_tree().paused = not get_tree().paused


func _step() -> void:
	get_tree().paused = false
	_pause_after_step = true


func _finish_single_step() -> void:
	get_tree().paused = true
	_update_hud()


func _toggle_tuner() -> void:
	_tuner.visible = not _tuner.visible


func _open_playground() -> void:
	_pause_after_step = false
	get_tree().paused = false
	GameManager.clear_gameplay_freeze()
	get_tree().change_scene_to_file(PLAYGROUND_PATH)


func _on_bounds_toggled(enabled: bool) -> void:
	_player.show_collision_shapes = enabled
	_player.queue_redraw()


func _spawn_carry_probe() -> void:
	var probe: CarryableProbe = CarryableProbe.new(_player.physics_profile)
	probe.position = Vector2(_player.global_position.x + TILE * 2.0, float(_config["ground_y"]) - _player.physics_profile.hitbox_width / 2.0)
	_world.add_child(probe)
	_probes.append(probe)


func _on_tuning_focus_entered() -> void:
	_player.input_enabled = false
	_player.clear_input_edges()


func _on_tuning_focus_exited() -> void:
	_player.input_enabled = true


func _select_skid(value: float) -> void:
	_parameter_controls["skid_decel"].value = value


func _on_parameter_changed(value: float, field: String) -> void:
	var old: Variant = _player.physics_profile.get(field)
	_player.physics_profile.set(field, int(value) if old is int else value)
	var errors: PackedStringArray = _player.physics_profile.validation_errors()
	if not errors.is_empty():
		_player.physics_profile.set(field, old)
		_parameter_controls[field].set_value_no_signal(float(old))
		_status.text = tr("DASH_INVALID") + "; ".join(errors)
		return
	_parameter_changes.append({"sample": _next_sample_index(), "field": field, "from": old, "to": _player.physics_profile.get(field)})
	_status.text = tr("DASH_CANDIDATE_EDIT")


func _restore_baseline() -> void:
	_on_physics_selected(0)


func _on_physics_selected(index: int) -> void:
	_physics_select.select(index)
	var baseline: PlayerPhysicsProfile = load(PHYSICS_PRESETS[index]) as PlayerPhysicsProfile
	for property: Dictionary in baseline.get_property_list():
		var field: String = String(property["name"])
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			_player.physics_profile.set(field, baseline.get(field))
	for field: String in _parameter_controls:
		_parameter_controls[field].set_value_no_signal(float(_player.physics_profile.get(field)))
		_parameter_controls[field].editable = field not in REFERENCE_PARAMETERS or _player.physics_profile.motion_model == PlayerPhysicsProfile.MotionModel.SMMWE
	_reset_player()


func _export_run() -> void:
	var error: Error = DirAccess.make_dir_recursive_absolute(EXPORT_DIR)
	if error != OK:
		_status.text = tr("DASH_EXPORT_FAILED") % error_string(error)
		return
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-") + "-" + str(Time.get_ticks_msec())
	var prefix: String = EXPORT_DIR.path_join(stamp)
	error = ResourceSaver.save(_player.physics_profile, prefix + ".tres")
	if error != OK:
		_status.text = tr("DASH_EXPORT_FAILED") % error_string(error)
		return
	var file: FileAccess = FileAccess.open(prefix + ".csv", FileAccess.WRITE)
	if file == null:
		_status.text = tr("DASH_EXPORT_FAILED") % error_string(FileAccess.get_open_error())
		return
	file.store_csv_line(CSV_FIELDS)
	for sample: Dictionary in _samples:
		var flattened: Dictionary = sample.duplicate()
		flattened.merge(sample["input"] as Dictionary)
		var cells: PackedStringArray = PackedStringArray()
		for field: String in CSV_FIELDS:
			cells.append(str(flattened.get(field, "")))
		file.store_csv_line(cells)
	file.close()
	var metadata: FileAccess = FileAccess.open(prefix + ".json", FileAccess.WRITE)
	if metadata == null:
		_status.text = tr("DASH_EXPORT_FAILED") % error_string(FileAccess.get_open_error())
		return
	metadata.store_string(JSON.stringify({"schema_version": 2, "captured_at": Time.get_datetime_string_from_system(),
		"profile": stamp + ".tres", "trace": stamp + ".csv", "calibration_state": "CANDIDATE",
		"scenario": _current_scenario().duplicate(true), "recording_start_profile": _recording_profile,
		"style_rules": _player.style_id, "visual_style": "smw", "parameter_changes": _parameter_changes,
		"physics_preset": PHYSICS_PRESETS[_physics_select.selected],
		"baseline_evidence": _read_dictionary(EVIDENCE_PATH), "profile_snapshot": _capture_profile(),
		"engine_version": Engine.get_version_info(), "sample_count": _samples.size(),
		"first_sample": int(_samples.front()["sample"]) if not _samples.is_empty() else null,
		"last_sample": int(_samples.back()["sample"]) if not _samples.is_empty() else null,
		"metrics": {"accel_frames": _last_accel_frames, "skid_frames": _last_skid_frames, "skid_distance_px": _last_skid_distance,
			"jump_height_px": _last_jump_height, "jump_frames": _last_jump_frames, "jump_apex_frame": _last_jump_apex_frame}}, "\t"))
	metadata.close()
	_status.text = tr("DASH_EXPORTED") % ProjectSettings.globalize_path(EXPORT_DIR)


func _capture_profile() -> Dictionary:
	var profile_snapshot: Dictionary = {}
	for property: Dictionary in _player.physics_profile.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var field: String = String(property["name"])
			var value: Variant = _player.physics_profile.get(field)
			profile_snapshot[field] = [value.x, value.y] if value is Vector2 else value
	return profile_snapshot


func _read_dictionary(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file != null:
		var document: Variant = JSON.parse_string(file.get_as_text())
		if document is Dictionary:
			return document as Dictionary
	push_error("Missing dashboard configuration: " + path)
	return {}


func _install_translations() -> void:
	var file: FileAccess = FileAccess.open(TEXT_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing dashboard translation table")
		return
	var english: Translation = Translation.new()
	english.locale = "en_US"
	var chinese: Translation = Translation.new()
	chinese.locale = "zh_CN"
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 3 and row[0] != "":
			english.add_message(row[0], row[1])
			chinese.add_message(row[0], row[2])
	TranslationServer.add_translation(english)
	TranslationServer.add_translation(chinese)
