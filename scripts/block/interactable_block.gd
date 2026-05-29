extends AnimatableBody2D
class_name InteractableBlock

enum State {
	EMPTY,
	ACTIVE
}
var current_state = State.ACTIVE

@onready var sprite: AnimatedSprite2D = $Sprite

func hit_by_player(player: Player) -> void:
	print("父类 hit_by_player 被成功调用！当前状态是: ", current_state)
	if current_state == State.EMPTY:
		print("被击中了，但是空的")
		return
	print("被击中了")
	bounce_animation()

	_trigger_effect(player)

func bounce_animation() -> void:
	var tween = create_tween()
	var start_y = position.y

	var original_scale = sprite.scale
	var peak_scale = original_scale * 1.4

	tween.tween_property(self, "position:y", start_y - 6, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", peak_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "position:y", start_y, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "scale", original_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
func _trigger_effect(player: Player) -> void:
	# 子类重写此方法以实现不同的效果
	pass
