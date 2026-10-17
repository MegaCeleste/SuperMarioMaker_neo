class_name SuperStar
extends PowerUpPickup

func _config_section() -> String:
	return "star"

func _visual_group() -> String:
	return "star"

func _request_pickup(player: Player) -> bool:
	return player.collect_star()

func _move_pickup(delta: float) -> void:
	velocity.y = minf(velocity.y, float(_config["max_fall"])) + float(_config["gravity"]) * delta
	velocity.x = dir * float(_config["speed"])
	move_and_slide()
	if is_on_floor():
		velocity.y = float(_config["bounce_initial"])
	if is_on_wall():
		dir *= -1.0
