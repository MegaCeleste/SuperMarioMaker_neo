# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerGoalState
extends PlayerState
## SMW's goal walk and pose (obj_player_goal_smw), using normal body physics.

var finish_x := 0.0
var pose := false


func start() -> Script:
	super()
	pose = false
	player.velocity.x = 0
	player.invulnerability_left = 0
	player.sprite.modulate.a = 1
	player.sprite.speed_scale = 1
	# Goal actors no longer participate in enemy, coin or powerup triggers.
	player.set_deferred("collision_layer", 0)
	var gravity_component: GravityComponent = Utility.find_child_by_class(player, GravityComponent)
	gravity_component.gravity.y = player.gravity
	return null


func physics_process(delta: float) -> Script:
	if player.is_on_floor():
		if player.global_position.x < finish_x:
			player.direction = 1
			player.velocity.x = minf(player.velocity.x + 450.0 * delta, 90.0)
			player.velocity.x = minf(player.velocity.x, (finish_x - player.global_position.x) / delta)
			player.sprite.speed_scale = maxf(0.1, player.velocity.x / 90.0)
			player.sprite.play("walk")
		else:
			player.velocity.x = 0
			player.direction = -1
			player.sprite.speed_scale = 1
			player.sprite.play(player.get_helmet_goal_animation() if pose else &"idle")
	else:
		player.sprite.play("fall" if player.velocity.y > 0 else "jump")
	player.sprite.flip_h = player.direction < 0
	return null


func input(_event: InputEvent) -> Script:
	return null
