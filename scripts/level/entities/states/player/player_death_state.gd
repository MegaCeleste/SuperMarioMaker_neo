# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerDeathState
extends PlayerState

var _hold_left := 0.0
var _retry_left := 0.0
var _launched := false
var _retry_requested := false
var _revision := 0


func start() -> Script:
	player = node as Player
	for animation in player.sprite.get_children():
		if animation is PowerupAnimation:
			animation.cancel()
	player.level.start_player_death()
	player._star.cancel(false)
	player.collision_mask = 0
	player.collision_layer = 0
	player.velocity = Vector2.ZERO
	player.invulnerability_left = 0
	player.detach_held_item()
	
	player.sprite.speed_scale = 1
	player.sprite.flip_h = false
	player.sprite.flip_v = false
	player.sprite.rotation = 0
	if player.global_position.y > player.VOID_LEVEL:
		player.sprite.hide()
	else:
		player.sprite.play("dead", 0)
		player.sprite.frame = 0
	MusicPlayer.stop()
	UISoundPlayer.stream = preload("uid://cpvqy2k0d2cju")
	UISoundPlayer.play()
	
	var grav_comp: GravityComponent = Utility.find_child_by_class(player,
			GravityComponent)
	grav_comp.gravity = Vector2.ZERO
	
	_hold_left = player.physics.death_hold_time
	_retry_left = player.physics.death_retry_time
	_launched = false
	_retry_requested = false
	_revision = player.sub_area._runtime_revision
	return super()


func _fall() -> void:
	player.sprite.play("dead")
	player._gravity.gravity = Vector2(0, player.physics.death_gravity)
	player._gravity.max_fall_speed = INF
	player.velocity = Vector2(0, -player.physics.death_launch_speed)
	_launched = true


func physics_process(delta: float) -> Script:
	if not _launched:
		_hold_left = maxf(0, _hold_left - delta)
		if _hold_left <= 0.00001:
			_fall()
		return null
	var liquid := player.sub_area.liquid
	var water := player.sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (player.sub_area.night_mode and player.sub_area.level_theme in [Level.LevelTheme.SKY, Level.LevelTheme.AIRSHIP]) \
			or (is_instance_valid(liquid) and player.sub_area.level_theme == Level.LevelTheme.FOREST \
			and not player.sub_area.night_mode and player.global_position.y - 32 > liquid.global_position.y + 16)
	var cap := player.physics.death_water_fall_speed if water else player.physics.fall_speed
	if player.velocity.y > cap:
		player.velocity.y = cap
		player._gravity.gravity = Vector2.ZERO
	_retry_left = maxf(0, _retry_left - delta)
	if _retry_left <= 0.00001 and not _retry_requested:
		_retry_requested = true
		_retry.call_deferred()
	return null


func input(_event: InputEvent) -> Script:
	return null


func _retry() -> void:
	if not is_instance_valid(player) or not player.is_inside_tree() or player.is_queued_for_deletion() \
			or not player.is_dead() or player.sub_area._runtime_revision != _revision:
		return
	if player.level.editor == null:
		player.level.reload()
	else:
		player.level.edit()
