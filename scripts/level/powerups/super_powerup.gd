class_name SuperPowerup
extends Powerup


func start(animate := true) -> void:
	player.set_powerup_hitbox(true)
	player.set_powerup_sprites(true, animate)
	if animate:
		player.sounds.stream = preload("uid://b20440v3vqlik")
		player.sounds.play()
