# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerSlopeSlideState
extends PlayerState

var _dust_clock := 0
var combo := 0


func start() -> Script:
	super()
	combo = 0
	_dust_clock = 0
	return null


func physics_process(delta: float) -> Script:
	var jump := ground_jump_check()
	if jump != null:
		return jump
	if not player.is_on_floor():
		return PlayerFallingState
	if not Input.is_action_pressed("player_down") or Input.is_action_pressed("player_up") or player.held_item != null:
		return PlayerMovingState if Input.get_axis("player_left", "player_right") != 0 else PlayerIdleState
	var slope := player.slope_direction()
	if slope != 0:
		player.velocity.x = move_toward(player.velocity.x, slope * 180, 360 * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, 360 * delta)
		if absf(player.velocity.x) < 3:
			return PlayerIdleState
	if not is_zero_approx(player.velocity.x):
		player.direction = int(signf(player.velocity.x))
	player.sprite.speed_scale = 1
	player.sprite.play(&"slide")
	player.sprite.flip_h = player.direction < 0
	_dust_clock += 1
	if _dust_clock >= 8 and absf(player.velocity.x) > 30:
		_dust_clock = 0
		var smoke: SkidSmoke = load("res://scenes/particles/skid_smoke.tscn").instantiate()
		player.sub_area.add(smoke)
		smoke.position = player.position + SlopeBody.visual_floor_offset(player) + Vector2(-player.direction * 5, 1)
	return null


func input(event: InputEvent) -> Script:
	super(event)
	if event.is_action_pressed("player_jump"):
		return PlayerJumpingState
	return null


func hit(enemy: Enemy) -> bool:
	if enemy.hardness >= 99 or enemy.is_queued_for_deletion() or absf(player.velocity.x) < 3:
		return false
	if not enemy.hit_by_actor(&"slide", player, signf(player.velocity.x)):
		return false
	var scores := [200, 400, 800, 1000, 2000, 4000, 8000]
	if combo < scores.size():
		player.score += scores[combo]
	else:
		player.extra_lives += 1
	EnemyEffect.sound_once(player.sub_area, "res://assets/openwe/sounds/snd_kick%s.ogg" % ("" if combo == 0 else str(combo + 1) if combo < 7 else "_1up"))
	combo += 1
	return true
