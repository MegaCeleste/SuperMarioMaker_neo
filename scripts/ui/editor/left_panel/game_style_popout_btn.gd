class_name GameStylePopoutBtn
extends TextureButton

const HOVER = preload("uid://bbc6fa1b5njqq")
const CHANGE_STYLE = preload("uid://dnblg2whmhj7t")

@export var game_style: Level.GameStyle:
	set = _set_game_style

@onready var effect := ButtonHoverEffect.new(self)


func _ready() -> void:
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)


func _process(_delta: float) -> void:
	effect.check_redraw()


func _draw() -> void:
	if %Editor.level != null:
		draw_texture(GameStyleBtn.STYLE_CARDS[game_style], Vector2(0, 0))
	effect.draw()


func _pressed() -> void:
	%Editor.level.game_style = game_style
	%GameStylePanel.close_sound = CHANGE_STYLE
	%GameStylePanel.close()


func _mouse_entered() -> void:
	UISoundPlayer.stream = HOVER
	UISoundPlayer.play()
	effect.start()


func _mouse_exited() -> void:
	effect.stop()


func _set_game_style(v: Level.GameStyle) -> void:
	game_style = v
	queue_redraw()
