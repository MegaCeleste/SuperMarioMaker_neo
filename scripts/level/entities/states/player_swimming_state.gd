# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerSwimmingState
extends PlayerState
## One state for swimming and walking along the submerged floor. Grounded
## jump/Run input must never enter the ordinary air/skid/spin controllers.

var rules: PlayerSwimRules = preload("res://resources/content/smw_player_swim.tres")
var _stroke := -1.0
var _bubble_ticks := 0
var stroke_count := 0


func start() -> Script:
	super()
	_stroke = -1
	_bubble_ticks = randi_range(24, 119)
	stroke_count = 0
	player.just_fell = false
	player.p_meter = 0
	player._gravity.gravity.y = rules.gravity
	# Source clamps BEFORE the stroke, so its impulse may exceed the steady
	# rise cap for one tick. Gravity is applied once afterward by Player.
	player._gravity.max_fall_speed = INF
	player.sprite.speed_scale = 1
	return null


func end() -> void:
	super()
	player._gravity.gravity.y = player.gravity
	player._gravity.max_fall_speed = player.max_fall_speed
	player.sprite.speed_scale = 1


func input(event: InputEvent) -> Script:
	super(event) # Preserve native release/throw input, without air jumps.
	return null


func physics_process(delta: float) -> Script:
	var axis := Input.get_axis("player_left", "player_right")
	position_held_item(signf(axis))
	var holding := player.held_item != null
	var floor := player.is_on_floor() and player.velocity.y >= 0
	var can_steer := not player.is_ducking() or not floor
	if axis != 0 and can_steer:
		player.direction = int(signf(axis))
		player.velocity.x += axis * rules.acceleration * delta
	elif holding:
		player.velocity.x += player.direction * rules.acceleration * delta
		player.velocity.x = clampf(player.velocity.x, -rules.floor_speed, rules.floor_speed)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, rules.acceleration * delta)
	player.velocity.x = clampf(player.velocity.x, -rules.floor_speed if floor else -rules.speed,
			rules.floor_speed if floor else rules.speed)
	player.velocity.y = clampf(player.velocity.y - (rules.carry_buoyancy * delta if holding else 0),
			-rules.carry_rise_speed if holding else -rules.rise_speed, rules.sink_speed)
	if holding:
		if Input.is_action_pressed("player_down"):
			player.velocity.y = -player.velocity.y + rules.reversal_extra if player.velocity.y < 0 \
					else player.velocity.y + rules.stroke_extra
			if Input.is_action_just_pressed("player_down"):
				_swim_sound()
	elif Input.is_action_just_pressed("player_jump"):
		if floor:
			player.velocity.y = -rules.floor_stroke_speed
		elif player.velocity.y > 0:
			player.velocity.y = -player.velocity.y - rules.reversal_extra
		else:
			player.velocity.y -= rules.stroke_extra
		_stroke = 0
		stroke_count += 1
		player.crouching = false
		player.set_powerup_hitbox(not player.get_powerup() is SmallPowerup)
		_swim_sound()
		floor = false
	player._gravity.gravity.y = rules.gravity
	player.sprite.flip_h = player.direction < 0
	_animate(floor, holding, delta)
	_bubble_ticks -= 1
	if _bubble_ticks <= 0:
		_bubble_ticks = randi_range(30, 60)
		var bubble := PlayerBubble.new()
		bubble.sub_area = player.sub_area
		bubble.position = player.sub_area.get_foreground().to_local(Vector2(
				player.global_position.x, Utility.get_bounding_box(player).position.y))
		player.sub_area.add_deferred(bubble)
	return null


func _swim_sound() -> void:
	player.sounds.stop()
	player.sounds.stream = load("res://assets/openwe/sounds/snd_swim.ogg")
	player.sounds.play()


func _animate(floor: bool, holding: bool, delta: float) -> void:
	if not player.can_change_sprite():
		return
	player.sprite.speed_scale = 1
	if floor:
		_stroke = -1
		if not is_zero_approx(player.velocity.x):
			player.play_ground_animation(&"hold_walk" if holding else &"walk")
		else:
			player.sprite.play((&"hold_look_up" if holding else &"look_up") \
					if Input.is_action_pressed("player_up") else (&"hold_idle" if holding else &"idle"))
	elif holding:
		_stroke = -1
		player.sprite.play(&"swim_float")
		if player.velocity.y <= 0:
			player.sprite.pause()
			player.sprite.frame = 0
		else:
			player.sprite.speed_scale = rules.carry_sink_fps / rules.stroke_fps
	elif _stroke >= 0 and _stroke < rules.stroke_end_frame:
		# Physics-clock pose survives power changes and cannot skip a frame at
		# high render rates. Idle float uses the original separate source art.
		player.sprite.play(&"swim")
		player.sprite.pause()
		player.sprite.set_frame_and_progress(int(_stroke), fmod(_stroke, 1))
		_stroke += rules.stroke_fps * delta
	else:
		_stroke = -1
		player.sprite.play(&"swim_float")
