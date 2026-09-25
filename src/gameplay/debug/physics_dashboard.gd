extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/player/player.tscn")
const QUESTION_BLOCK_SCENE: PackedScene = preload("res://src/gameplay/blocks/question_block.tscn")
const MUSHROOM_SCENE: PackedScene = preload("res://src/gameplay/entities/mushroom.tscn")
const GRAPH_SCRIPT: Script = preload("res://src/gameplay/debug/velocity_graph.gd")
const TEXT_PATH := "res://data/i18n/strings.csv"
const TILE := 16.0
const GROUND_Y := 192.0
const GROUND_WIDTH := 1536.0
const WALL_SIZE := Vector2(16.0, 64.0)
const FLOOR_COLOR := Color(0.32, 0.52, 0.36)
const BLOCK_COLOR := Color(0.58, 0.65, 0.75)

var _player: Player
var _stats: Label
var _meter: Label
var _animation: Label
var _graph: Control
var _camera: Camera2D
var _apex_y: float
var _jump_start_y: float
var _jump_apex: float = 0.0


func _ready() -> void:
	_install_translations()
	_build_world()
	_build_hud()


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	if _player.velocity.y < 0.0 and _player.global_position.y < _apex_y:
		_apex_y = _player.global_position.y
		_jump_apex = _jump_start_y - _apex_y
	_stats.text = (tr("DASH_STATS") % [
		_player.velocity.x, _player.velocity.y,
		_player.global_position.x, _player.global_position.y,
		Player.MovementState.keys()[_player.movement_state],
		_jump_apex,
	]).replace("\\n", "\n")
	_meter.text = tr("DASH_METER_STATS") % [
		_player.p_meter, _player.physics_profile.p_meter_max,
		tr("DASH_P_READY") if _player.is_p_running() else (tr("DASH_P_CHARGING") if _player.has_ability("p_meter") else tr("DASH_P_UNAVAILABLE")),
	]
	_animation.text = tr("DASH_ANIMATION") % [String(_player.animated_sprite.animation), _player.get_current_animation_fps()]
	_camera.position.x = maxf(272.0, _player.global_position.x + 192.0)
	_graph.call("push_sample", _player.velocity.x)


func _build_world() -> void:
	_add_solid(Vector2(GROUND_WIDTH / 2.0, GROUND_Y + TILE / 2.0), Vector2(GROUND_WIDTH, TILE), FLOOR_COLOR)
	_add_solid(Vector2(640.0, GROUND_Y - WALL_SIZE.y / 2.0), WALL_SIZE, BLOCK_COLOR)
	_add_solid(Vector2(736.0, GROUND_Y - TILE * 3.0), Vector2(TILE * 6.0, TILE), BLOCK_COLOR)
	_add_solid(Vector2(864.0, GROUND_Y - TILE * 5.0), Vector2(TILE * 6.0, TILE), BLOCK_COLOR)
	var block: Node2D = QUESTION_BLOCK_SCENE.instantiate() as Node2D
	block.position = Vector2(208.0, GROUND_Y - TILE * 4.0)
	add_child(block)
	var mushroom: Node2D = MUSHROOM_SCENE.instantiate() as Node2D
	mushroom.position = Vector2(160.0, GROUND_Y - TILE / 2.0)
	add_child(mushroom)
	mushroom.set_physics_process(false)
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = Vector2(80.0, GROUND_Y - _player_feet_y())
	add_child(_player)
	_player.movement_state_changed.connect(_on_movement_state_changed)
	_camera = Camera2D.new()
	_camera.position = Vector2(272.0, 112.0)
	_camera.zoom = Vector2(2.0, 2.0)
	add_child(_camera)
	_camera.make_current()
	_jump_start_y = _player.global_position.y
	_apex_y = _jump_start_y


func _player_feet_y() -> float:
	var profile: PlayerPhysicsProfile = preload("res://data/physics/base_physics.tres")
	return profile.feet_y


func _add_solid(center: Vector2, dimensions: Vector2, tint: Color) -> void:
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
	var half_size: Vector2 = dimensions / 2.0
	visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y),
	])
	visual.color = tint
	body.add_child(visual)
	add_child(body)


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(12.0, 12.0)
	panel.custom_minimum_size = Vector2(360.0, 230.0)
	layer.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)
	var title: Label = Label.new()
	title.text = tr("DASH_TITLE")
	column.add_child(title)
	_stats = Label.new()
	column.add_child(_stats)
	_meter = Label.new()
	column.add_child(_meter)
	_animation = Label.new()
	column.add_child(_animation)
	var controls: Label = Label.new()
	controls.text = tr("DASH_CONTROLS")
	column.add_child(controls)
	var graph_title: Label = Label.new()
	graph_title.text = tr("DASH_GRAPH")
	column.add_child(graph_title)
	_graph = Control.new()
	_graph.set_script(GRAPH_SCRIPT)
	_graph.custom_minimum_size = Vector2(350.0, 80.0)
	_graph.set("speed_limit", _player.physics_profile.p_speed)
	column.add_child(_graph)


func _on_movement_state_changed(_previous: Player.MovementState, current: Player.MovementState) -> void:
	if current == Player.MovementState.AIR and _player.velocity.y < 0.0:
		_jump_start_y = _player.global_position.y
		_apex_y = _jump_start_y
		_jump_apex = 0.0


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
