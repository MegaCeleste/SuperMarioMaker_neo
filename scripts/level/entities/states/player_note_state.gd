# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerNoteState
extends PlayerState
## A brief source compression hold; native movement still checks other solids.

var block: NoteBlock


func start() -> Script:
	super()
	player.velocity = Vector2.ZERO
	player.add_collision_exception_with(block)
	player._gravity.gravity = Vector2.ZERO
	return null


func end() -> void:
	player._gravity.gravity = Vector2(0, player.gravity)
	if is_instance_valid(block):
		player.remove_collision_exception_with(block)
		block.detach_rider(player)
	block = null
	super()


func physics_process(delta: float) -> Script:
	if not is_instance_valid(block) or block.is_queued_for_deletion() or not block.active:
		return PlayerFallingState
	var bounds := Utility.get_bounding_box(player)
	if bounds.end.x <= block.global_position.x or bounds.position.x >= block.global_position.x + 16:
		return PlayerFallingState
	if block.age >= 10:
		var spin := not Input.is_action_pressed("player_jump") and Input.is_action_pressed("player_spin_jump") \
				and player.held_item == null and not player.is_ducking()
		var next: Script = PlayerSpinJumpingState if spin else PlayerJumpingState
		var state: PlayerState = Utility.find_child_by_class(player.state_machine, next)
		state.set("external_launch_speed", 180.0 if player.sub_area.level_theme == Level.LevelTheme.UNDERWATER else 300.0)
		player.position.y -= 1
		EnemyEffect.sound_once(player.sub_area, "res://assets/openwe/sounds/snd_spring.ogg")
		return next
	var direction := Input.get_axis("player_left", "player_right")
	position_held_item(direction)
	apply_horizontal_motion(direction, delta)
	player.velocity.y = (block.global_position.y - 0.08 - player.global_position.y) / delta
	player.sprite.play(&"hold_idle" if player.held_item != null else &"idle")
	return null
