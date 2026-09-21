class_name CoursebotPopoutBtn
extends Button

enum Type {
	SAVE_NEW,
	SAVE_CHANGES,
	LOAD,
}

@export var type: Type

@onready var _effect := ButtonHoverEffect.new(self)


func _ready() -> void:
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)


func _process(_delta: float) -> void:
	_effect.check_redraw()


func _draw() -> void:
	_effect.draw()


func _pressed() -> void:
	%CoursebotPanel.close()
	%CoursebotPanel.sound_player.stream = preload("uid://c7niodexb50qw")
	%CoursebotPanel.sound_player.play()
	match type:
		Type.SAVE_NEW:
			_save_level(false)
		Type.SAVE_CHANGES:
			_save_level(true)
		Type.LOAD:
			SceneManager.fade_to("uid://nc2x1hq5ysrg")


func _save_level(overwrite: bool) -> void:
	var level: Level = get_tree().current_scene as Level
	if level == null:
		return

	# Determine file path
	var path := level.file_path
	if path.is_empty() or not overwrite:
		var safe_name := level.level_name.strip_edges().replace(" ", "_")
		if safe_name.is_empty():
			safe_name = "unnamed"
		path = LevelCodec.LEVELS_DIR.path_join(safe_name + ".neo")

	LevelCodec.save(level, path)


func _mouse_entered() -> void:
	if not DisplayServer.is_touchscreen_available():
		UISoundPlayer.stream = preload("uid://bbc6fa1b5njqq")
		UISoundPlayer.play()
	_effect.start()


func _mouse_exited() -> void:
	_effect.stop()
