extends AnimatedSprite2D



func _on_airship_mouse_entered() -> void:
	play()

func _on_airship_mouse_exited() -> void:
	stop()
	frame = 0
	
