# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerMovingState
extends PlayerState
## Provides idle, walking and running behavior to the player.

var _skidding := false
var _dust_left := 0.0
## Latched for one running brake, including its slower final steps.
var running_skid_dust := false
## The loop belongs only to braking; never share Mario's general sound voice.
var skid_sound: AudioStreamPlayer


## Ends the movement state's effects before a state change or power pause.
func stop_skid() -> void:
	_skidding = false
	_dust_left = 0
	running_skid_dust = false
	if is_instance_valid(skid_sound):
		skid_sound.stop()


func end() -> void:
	super()
	player.sprite.speed_scale = 1
	stop_skid()


func physics_process(delta: float) -> Script:
	super(delta)
	
	var direction := Input.get_axis("player_left", "player_right")
	
	if not player.is_on_floor():
		player.just_fell = true
		return PlayerFallingState
	var jump := ground_jump_check()
	if jump != null:
		return jump
	if player.slope_slide_check():
		return PlayerSlopeSlideState
	if direction == 0:
		return PlayerIdleState
	
	position_held_item(direction)
	
	var incoming_speed := absf(player.velocity.x)
	apply_horizontal_motion(direction, delta)
	var braking := direction * player.velocity.x < 0 and not player.is_ducking()
	if not braking:
		running_skid_dust = false
	elif incoming_speed > player.max_walk_speed:
		running_skid_dust = true
	# Walking reversals retain the walking art. The source skid pose requires
	# the full-run meter, while dust has its own lower speed threshold.
	_skidding = braking and player.p_meter > 5 and player.held_item == null
	_update_skid_sound()
	_dust_left = maxf(0, _dust_left - delta)
	if braking and (running_skid_dust or incoming_speed >= player.animation_rules.skid_dust_min_speed):
		if _dust_left <= 0.00001:
			_do_skid_smoke()
			_dust_left = (player.animation_rules.running_skid_dust_interval if running_skid_dust
					else player.animation_rules.skid_dust_interval)
	else:
		_dust_left = 0
	
	# animations
	if player.can_change_sprite():
		if _skidding and player.sprite.sprite_frames.has_animation(&"skid"):
			player.sprite.speed_scale = 1
			player.sprite.play("skid")
		elif player.is_on_wall():
			if player.held_item == null:
				player.sprite.play("idle")
			else:
				player.sprite.play("hold_idle")
		else:
			if player.held_item != null:
				player.play_ground_animation(&"hold_walk")
			elif player.p_meter > 5:
				player.play_ground_animation(&"run")
			else:
				player.play_ground_animation(&"walk")
	if direction < 0:
		player.sprite.flip_h = true
	elif direction > 0:
		player.sprite.flip_h = false
	
	return null


func input(event: InputEvent) -> Script:
	super(event)
	return move_check(event)


func _do_skid_smoke() -> void:
	var smoke: SkidSmoke = preload("uid://bde0tltjb5047").instantiate()
	smoke.direction = float(player.direction)
	var offset := Vector2(4 * player.direction, 1)
	if running_skid_dust:
		offset.x = 2 * player.direction
		smoke.lifetime = player.animation_rules.running_skid_dust_lifetime
	player.add_sibling(smoke)
	# Both modes leave clouds at their emission point; no cloud follows Mario.
	smoke.global_position = player.global_position + offset
	player.get_parent().move_child(smoke, player.get_index())


func _update_skid_sound() -> void:
	if not _skidding:
		if is_instance_valid(skid_sound):
			skid_sound.stop()
		return
	if not is_instance_valid(skid_sound):
		skid_sound = AudioStreamPlayer.new()
		skid_sound.name = "SkidSound"
		skid_sound.stream = preload("res://audio/smw/player/skid.wav")
		add_child(skid_sound)
	if not skid_sound.playing:
		skid_sound.play()
