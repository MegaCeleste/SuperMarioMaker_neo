extends State

var is_hovering: bool = true

func enter() -> void:

	# 时停
	get_tree().paused = true

	player.process_mode = Node.PROCESS_MODE_ALWAYS

	var bgm_node = player.get_node_or_null("../BGM")
	if bgm_node:
		bgm_node.set_deferred("stream_paused", true)

	player.dead_sound.play()
	is_hovering = true
	player.animated_sprite.play("dead")
	player.velocity = Vector2.ZERO
	
	player.standing_shape.set_deferred("disabled", true)
	if player.duck_shape:
		player.duck_shape.set_deferred("disabled", true)

	# === 等待 1 秒 ===
	await get_tree().create_timer(0.5).timeout

	player.velocity.y = -300
	is_hovering = false

	
func physics_update(_delta: float) -> void:
	if is_hovering:
		return

	# 重力已在 Player._physics_process 统一处理

func can_apply_gravity() -> bool:
	return not is_hovering
