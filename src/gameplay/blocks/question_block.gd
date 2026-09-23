extends InteractableBlock
@export var item_scene: PackedScene
@onready var bump: AudioStreamPlayer2D = $Bump

func _trigger_effect(player: Player) -> void:
	print("问号块被击中了")
	bump.play()
	if current_state == State.EMPTY:
		return

	current_state = State.EMPTY
	sprite.play("empty")

	if item_scene:
		var item = item_scene.instantiate()
		get_parent().add_child(item)

		item.global_position = global_position

		# 暂停物理处理
		item.set_physics_process(false)

		# 创建 Tween 动画平滑上升
		var tween = create_tween()
		var target_position = global_position + Vector2(0, -16)

		tween.tween_property(item, "global_position", target_position, 0.7)

		var on_complete = func():
			item.set_physics_process(true)

		tween.tween_callback(on_complete)
