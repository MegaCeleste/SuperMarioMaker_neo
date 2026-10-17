class_name Mushroom
extends PowerUpPickup

func _visual_group() -> String:
	return "mushroom"


func _request_pickup(player: Player) -> bool:
	return player.collect_mushroom()
