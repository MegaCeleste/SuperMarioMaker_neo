class_name SmallPowerup
extends Powerup


func start(animate := false) -> void:
	player.set_powerup_hitbox(false)
	player.set_powerup_sprites(false, animate)
