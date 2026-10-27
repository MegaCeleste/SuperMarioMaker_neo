class_name NightModeBtn
extends BaseButton

const HOVER = preload("uid://bbc6fa1b5njqq")
const DAY = preload("uid://dv6oae3myu24m")
const NIGHT = preload("uid://kba5wv1bfgwf")
const CHANGE_NIGHT_DAY = preload("uid://wujt66l1ojvt")

@onready var effect := ButtonHoverEffect.new(self)


func _ready() -> void:
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)


func _process(_delta: float) -> void:
	effect.check_redraw()


func _draw() -> void:
	if %Editor.level != null:
		var texture
		if %Editor.level.current_sub_area.night_mode:
			texture = NIGHT
		else:
			texture = DAY
		draw_texture(texture, Vector2(-18, -66))
	effect.draw()


func _pressed() -> void:
	%Editor.level.current_sub_area.night_mode = \
			!%Editor.level.current_sub_area.night_mode
	%LevelThemePanel.close_sound = CHANGE_NIGHT_DAY
	%LevelThemePanel.close()


func _mouse_entered() -> void:
	UISoundPlayer.stream = HOVER
	UISoundPlayer.play()
	effect.start()


func _mouse_exited() -> void:
	effect.stop()
