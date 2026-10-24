# SPDX-License-Identifier: AGPL-3.0-or-later
class_name FirePowerup
extends Powerup
## SMW fire input/pose and the two alternating spin-jump alarms.

var _firing_ticks := 0
var _spin_alarm := -1
var _second_spin_shot := false


func start(animate := true) -> void:
	player.set_powerup_hitbox(true)
	player.set_powerup_sprites(true, animate, &"fire")
	if player.state_machine.current_state is PlayerSpinJumpingState:
		begin_spin()
	if animate:
		player.sounds.stream = preload("uid://b20440v3vqlik")
		player.sounds.play()


func begin_spin(first_ticks := 10) -> void:
	_spin_alarm = first_ticks
	_second_spin_shot = false


func physics_process(_delta: float) -> void:
	if player.is_dead() or player.is_frozen() or player.level.status != Level.Status.PLAYING \
			or player.state_machine.current_state is PlayerStunnedState:
		_firing_ticks = 0
		_spin_alarm = -1
		return
	var spinning := player.state_machine.current_state is PlayerSpinJumpingState
	if not spinning:
		_spin_alarm = -1
	elif _spin_alarm > 0:
		_spin_alarm -= 1
		if _spin_alarm == 0:
			if player.held_item == null:
				shoot(-1 if _second_spin_shot else 1, true)
			_spin_alarm = -1 if _second_spin_shot else 10
			_second_spin_shot = true
	if Input.is_action_just_pressed("player_run") and not spinning and not player.is_ducking() \
			and player.held_item == null and player.sprite.animation != &"skid":
		if shoot(player.direction):
			_firing_ticks = 9
	if _firing_ticks > 0:
		if not spinning and not player.is_ducking() and player.held_item == null \
				and player.sprite.animation != &"skid":
			player.sprite.play(&"shoot")
			player.sprite.speed_scale = 1
			player.sprite.pause()
			player.sprite.frame = mini(1 if _firing_ticks in [4, 5] else 0,
					player.sprite.sprite_frames.get_frame_count(&"shoot") - 1)
			player.sprite.flip_h = player.direction < 0
		_firing_ticks -= 1


func shoot(direction: int, spin := false) -> bool:
	var area := player.sub_area
	var count := 0
	for body in area.get_foreground().get_children():
		if body is PlayerFireball and not body.is_queued_for_deletion():
			count += 1
	for pending in area._pending_spawns.values():
		if pending.node is PlayerFireball:
			count += 1
	if count >= 2:
		return false
	var shot := PlayerFireball.new()
	# Source Mario's origin is32px above native feet. Spin alarms use the
	# current facing for the8px spawn offset, even for the leftward shot.
	shot.position = area.get_foreground().to_local(player.global_position) \
			+ Vector2((8 if spin else 14) * player.direction, -20)
	shot.velocity = Vector2((270 if spin else 180) * direction, 0)
	area.add_deferred(shot)
	return true
