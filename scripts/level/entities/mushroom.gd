# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Mushroom
extends CharacterBodyExt

var _collected := false


func uses_source_deactivation() -> bool:
	return true


func uses_source_death_stop() -> bool:
	return true


func _ready() -> void:
	if SpriteLibrary.has_sprite(&"spr_mushroom"):
		$Sprite.texture = SpriteLibrary.get_frames(&"spr_mushroom").get_frame_texture(&"default", 0)


func _physics_process(_delta: float) -> void:
	var contacts := ActorContacts.for_actor(self)
	if contacts != null:
		contacts.turn_item(self, _delta)
	move_source_and_slide()


func _body_entered(body: Node2D) -> void:
	body = body as Player
	if body == null or _collected or body.is_dead():
		return
	_collected = true
	body.score += 1000
	if body.get_powerup() is SmallPowerup:
		body.set_powerup(SuperPowerup.new(), true)
	else:
		body.sounds.stream = preload("uid://b20440v3vqlik")
		body.sounds.play()
	queue_free()
