class_name FireFlower
extends PowerUpPickup
## REQ-PWR-014.


func _config_section() -> String:
	return "flower"


func _visual_group() -> String:
	return "fire_flower"


func _request_pickup(player: Player) -> bool:
	return player.collect_fire_flower()
