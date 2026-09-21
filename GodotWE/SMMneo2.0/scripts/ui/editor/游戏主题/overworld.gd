extends AnimatedSprite2D




func _on_overworld_mouse_entered() -> void:
	play()
	



func _on_overworld_mouse_exited() -> void:
	stop()
	frame = 0
