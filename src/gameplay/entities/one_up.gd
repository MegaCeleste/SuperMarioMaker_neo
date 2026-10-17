class_name OneUp
extends PowerUpPickup

func _config_section() -> String:
	return "one_up"

func _visual_group() -> String:
	return "one_up"

func _request_pickup(player: Player) -> bool:
	return player.collect_reward(1, true)
