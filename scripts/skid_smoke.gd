extends AnimatedSprite2D

func _ready() -> void:
	scale = Vector2(0.1, 0.1)
	play("skid")

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)

func _on_animation_finished() -> void:
	queue_free()

