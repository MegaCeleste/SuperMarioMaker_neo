class_name MenuBtn
extends TextureButton

@onready var _effect := ButtonHoverEffect.new(self,
		Rect2(Vector2.ZERO, size - Vector2(0, 6)))


func _ready() -> void:
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)


func _process(_delta: float) -> void:
	_effect.check_redraw()


func _draw() -> void:
	_effect.draw()


func _pressed() -> void:
	var tween = create_tween()
	pivot_offset = size / 2
	tween.tween_property(self, "scale", Vector2(0.93, 0.93), 0.08).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.10).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_callback(MainMenu.open)


func _mouse_entered() -> void:
	if not DisplayServer.is_touchscreen_available():
		UISoundPlayer.stream = preload("uid://bbc6fa1b5njqq")
		UISoundPlayer.play()
	_effect.start()


func _mouse_exited() -> void:
	_effect.stop()
