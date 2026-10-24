# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerSpringState
extends PlayerState

var spring: Spring

func start() -> Script:
	super()
	player.velocity = Vector2.ZERO
	player._gravity.gravity = Vector2.ZERO
	player.add_collision_exception_with(spring._surface)
	return null

func end() -> void:
	player._gravity.gravity = Vector2(0, player.gravity)
	if is_instance_valid(spring):
		player.remove_collision_exception_with(spring._surface)
		spring.detach_rider(player)
	spring = null
	super()

func physics_process(delta: float) -> Script:
	if not is_instance_valid(spring) or spring.is_queued_for_deletion() or not spring.active:
		return PlayerFallingState
	var bounds := Utility.get_bounding_box(player)
	if bounds.end.x <= spring.global_position.x - 8 or bounds.position.x >= spring.global_position.x + 8:
		return PlayerFallingState
	if spring.age >= 9:
		var spin := Input.is_action_pressed("player_spin_jump") and not Input.is_action_pressed("player_jump") \
				and player.held_item == null and not player.is_ducking()
		var next: Script = PlayerSpinJumpingState if spin else PlayerJumpingState
		var state: PlayerState = Utility.find_child_by_class(player.state_machine, next)
		state.set("external_launch_speed", spring.player_launch_speed())
		player.position.y -= 1
		EnemyEffect.sound_once(player.sub_area, "res://assets/openwe/sounds/snd_spring.ogg")
		return next
	position_held_item()
	player.velocity.x = 0
	player.velocity.y = (spring.top_y() - 0.08 - player.global_position.y) / delta
	player.sprite.play(&"hold_idle" if player.held_item != null else &"idle")
	return null
