# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerState
extends State

var player: Player


func _init() -> void:
	intended_class = Player


func start() -> Script:
	player = node as Player
	player.item_dropped.connect(item_dropped)
	if player.held_item != null:
		player.held_item.position = Vector2(
			Player.HELD_ITEM_OFFSET.x * player.direction,
			Player.HELD_ITEM_OFFSET.y)
	return


func end() -> void:
	player.item_dropped.disconnect(item_dropped)
	return


func input(event: InputEvent) -> Script:
	if event.is_action("player_run") and not event.is_pressed():
		player.drop_item()
	return


## Called when the player drops an item.
func item_dropped(held_item: Entity) -> void:
	player.sounds.stream = preload("uid://c345xnns7om3m")
	player.sounds.play()
	player.spawn_spin_thump(
			player.global_position.lerp(held_item.global_position, 0.5))
	player.sprite.speed_scale = 1
	player.sprite.play("kick")


## Checks what floor state the player should be in.
func move_check(event: InputEvent) -> Script:
	if event.is_action_pressed("player_jump"):
		return PlayerJumpingState
	
	if event.is_action_pressed("player_spin_jump") and not player.is_ducking() \
			and not Input.is_action_pressed("player_down"):
		player.just_fell = true
		return PlayerSpinJumpingState
	
	if event.is_action_pressed("player_left"):
		if Input.is_action_pressed("player_right"):
			return PlayerIdleState
		else:
			return PlayerMovingState
	
	if event.is_action_pressed("player_right"):
		if Input.is_action_pressed("player_left"):
			return PlayerIdleState
		else:
			return PlayerMovingState
	
	if event.is_action_released("player_left"):
		if Input.is_action_pressed("player_right"):
			return PlayerMovingState
		else:
			return PlayerIdleState
	
	if event.is_action_released("player_right"):
		if Input.is_action_pressed("player_left"):
			return PlayerMovingState
		else:
			return PlayerIdleState
	
	return null


## Polling keeps scripted input and controller input on the same physics path.
func ground_jump_check() -> Script:
	if Input.is_action_just_pressed("player_jump"):
		return PlayerJumpingState
	if Input.is_action_just_pressed("player_spin_jump") and not player.is_ducking():
		return PlayerSpinJumpingState
	return null


## Ported from obj_mario/Other_12.gml. Airborne momentum survives releasing
## Run; on ground, excess speed decays at 0.025 px/frame².
func apply_horizontal_motion(direction: float, delta: float) -> void:
	var ice := player.is_on_ice()
	var deceleration := player.ice_deceleration if ice else player.deceleration
	if player.crouching and player.is_on_floor():
		if direction != 0:
			player.direction = int(signf(direction))
		player.velocity.x = move_toward(player.velocity.x, 0,
				(player.physics.ice_duck_deceleration if ice else deceleration) * delta)
		return
	var limit := player.max_run_speed if Input.is_action_pressed("player_run") else player.max_walk_speed
	# Source Other12 adds1px/tick to either horizontal cap while starred.
	if player.has_star():
		limit += 60
	if direction == 0:
		if player.is_on_floor():
			player.velocity.x = move_toward(player.velocity.x, 0, deceleration * delta)
		return
	player.direction = int(signf(direction))
	if direction * player.velocity.x < 0:
		player.velocity.x = move_toward(player.velocity.x, direction * limit,
				(player.physics.ice_skid_deceleration if ice else player.skid_deceleration) * delta)
	elif absf(player.velocity.x) < limit:
		player.velocity.x = move_toward(player.velocity.x, direction * limit,
				(player.ice_acceleration if ice else player.acceleration) * delta)
	elif player.is_on_floor():
		player.velocity.x = move_toward(player.velocity.x, direction * limit,
				player.physics.overspeed_deceleration * delta)


## Transitions the held item between directions, if there is one. Must be called
## before [member Player.direction] is assigned so the method can compare the
## old value with the new one. [param direction] may be specified to not
## recalculate the new direction value.
func position_held_item(
		direction := Input.get_axis("player_left", "player_right")) -> void:
	if player.held_item == null:
		return
	if direction == 0:
		return
	if player.direction != direction:
		player.stop_held_item_turn()
		var tween := player.create_tween()
		player.held_item_tween = tween
		tween.tween_property(player.held_item, "position:x", 0, 0)
		tween.tween_interval(2/15.0)
		tween.tween_property(player.held_item, "position:x",
				Player.HELD_ITEM_OFFSET.x * direction, 0)
