class_name LevelActionBtn
extends Button

@onready var _effect: ButtonHoverEffect

@export var action: LevelView.Action

var _level: Level


func _enter_tree() -> void:
	if get_parent() is Container:
		await get_parent().sort_children
	_effect = ButtonHoverEffect.new(self)
	mouse_entered.connect(_effect.start)
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_effect.stop)


func _process(_delta: float) -> void:
	_effect.check_redraw()


func _draw() -> void:
	_effect.draw()


func _toggled(toggled_on: bool) -> void:
	if not toggled_on:
		return
	match action:
		LevelView.Action.EDIT, LevelView.Action.PLAY:
			if owner.get_meta("opening_level", false):
				set_pressed_no_signal(false)
				return
			owner.set_meta("opening_level", true)
			disabled = true
			UISoundPlayer.stream = preload("uid://e1c77rl0cw86") if action == LevelView.Action.PLAY else preload("uid://xgqdhf77bhmt")
			UISoundPlayer.play()
			var status := Level.Status.PLAYING if action == LevelView.Action.PLAY else Level.Status.EDITING
			_level = await prepare_level(owner.path, status)
			disabled = false
			owner.set_meta("opening_level", false)
			if _level == null:
				set_pressed_no_signal(false)
				var dialog := AcceptDialog.new()
				dialog.dialog_text = "This level could not be opened."
				add_child(dialog)
				dialog.confirmed.connect(dialog.queue_free)
				dialog.popup_centered()
				return
			SceneManager.fade_to_node(_level)
			return
		LevelView.Action.EXPORT:
			UISoundPlayer.stream = preload("uid://xgqdhf77bhmt")
		LevelView.Action.RENAME:
			UISoundPlayer.stream = preload("uid://xgqdhf77bhmt")
	UISoundPlayer.play()


## Shared by Coursebot actions and the editor-flow regression.
static func prepare_level(path: String, status: Level.Status) -> Level:
	var level: Level = await LevelProcessor.from_swe(path)
	if level != null:
		level.status = status
		level.return_to_coursebot = status == Level.Status.PLAYING
	return level


func _mouse_entered() -> void:
	UISoundPlayer.stream = preload("uid://bbc6fa1b5njqq")
	UISoundPlayer.play()
