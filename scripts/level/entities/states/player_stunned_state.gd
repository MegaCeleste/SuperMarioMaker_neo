# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerStunnedState
extends PlayerState
## obj_sledgebro landing: 80 ticks without movement controls, gravity retained.

var rules: PlayerStunRules = preload("res://resources/content/smw_player_stun.tres")
var remaining := 80.0 / 60
var _effect: AnimatedSprite2D


func start() -> Script:
	player = node as Player
	player.velocity.x = 0
	player.detach_held_item(PickupComponent.ReleaseType.STUNNED)
	super()
	remaining = rules.duration
	player.velocity.x = 0
	player.sprite.speed_scale = 1
	player.sprite.play(&"idle")
	_effect = SpriteLibrary.make_sprite(rules.effect_sprite)
	SpriteLibrary.configure_sprite(_effect, rules.effect_sprite, &"stun", rules.effect_fps, rules.effect_offset)
	_effect.z_index = -1
	player.add_child(_effect)
	return null


func refresh() -> void:
	# The source reuses obj_shake_mario while resetting stuntime, so its
	# animation phase does not restart on another impact.
	remaining = rules.duration
	player.velocity.x = 0


func end() -> void:
	_dispose_effect()
	super()


func _dispose_effect() -> void:
	if is_instance_valid(_effect):
		_effect.queue_free()
		_effect = null


func _exit_tree() -> void:
	_dispose_effect()


func physics_process(delta: float) -> Script:
	player.velocity.x = 0
	remaining -= delta
	if remaining <= 0.00001:
		return PlayerIdleState if player.is_on_floor() else PlayerFallingState
	return null


func input(_event: InputEvent) -> Script:
	return null
