# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Real overlaps and solid collisions for coins, blocks, powers and enemies.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level: Level = await LevelProcessor.from_swe("res://tests/fixtures/port_slice.swe")
	check(level != null, "Fixture failed to load")
	if level == null:
		await finish("INTERACTIONS_RESULT")
		return
	add_child(level)
	await ticks(8)
	var player := level.hud.player
	var foreground := level.current_sub_area.get_foreground()
	var enemy: Galoomba
	var turn: TurnBlockTile
	for node in foreground.get_children():
		if node is Galoomba:
			enemy = node
		if node is TurnBlockTile:
			turn = node
	var enemy_x := enemy.position.x
	await ticks(12)
	check(enemy.position.x < enemy_x - 4, "Goomba did not walk left after landing")
	enemy.process_mode = Node.PROCESS_MODE_DISABLED

	player.position = Vector2(136, -32)
	player.velocity = Vector2.ZERO
	await ticks(4)
	check(player.coins == 1 and player.score == 200, "Loose coin did not increment coins/score exactly once")
	check(level.hud.coins_label.text == "01" and level.hud.score_label.text == "000000200",
			"HUD did not display coins and score")

	player.position = Vector2(200, -16)
	player.velocity = Vector2.ZERO
	await ticks(4)
	Input.action_press("player_jump")
	await ticks(20)
	Input.action_release("player_jump")
	check(player.coins == 2 and player.score == 400, "Question block head bump did not sprout one coin")
	await ticks(25)
	player.position = Vector2(200, -16)
	player.velocity = Vector2.ZERO
	await ticks(4)
	Input.action_press("player_jump")
	await ticks(20)
	Input.action_release("player_jump")
	check(player.coins == 2, "Empty question block produced another coin")
	await ticks(25)

	player.position = Vector2(232, -16)
	player.velocity = Vector2.ZERO
	await ticks(4)
	Input.action_press("player_jump")
	await ticks(20)
	Input.action_release("player_jump")
	check(turn.turning and turn.get_node("CollShape").disabled, "Turn block did not spin and disable solidity after bump")

	# The second question block's SWE sprout=1 must build and eject a mushroom.
	player.position = Vector2(648, -16)
	player.velocity = Vector2.ZERO
	await ticks(8)
	Input.action_press("player_jump")
	await ticks(20)
	Input.action_release("player_jump")
	await ticks(45)
	var mushroom: Mushroom
	for node in foreground.get_children():
		if node is Mushroom:
			mushroom = node
	check(mushroom != null, "Stored sprout=1 did not eject a mushroom from its block")
	if mushroom != null:
		player.position = mushroom.position
		player.velocity = Vector2.ZERO
	await ticks(45)
	check(player.get_powerup() is SuperPowerup, "Mushroom overlap did not grant Super")
	check(player.get_node("CollShape").shape.size == Vector2(12, 27), "Super power did not enlarge hitbox")
	check(player.sprite == player.get_node("%Sprite"), "Powerup replaced the stable Sprite node")
	check(player.sprite.sprite_frames.get_frame_texture("idle", 0).resource_path.contains("spr_mario_big"),
			"Super sprite set was not loaded")

	# Side contact shrinks Super; repeated contact within two seconds is safe.
	enemy.position = player.position + Vector2(8, 0)
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	await ticks(45)
	check(player.get_powerup() is SmallPowerup and not player.is_dead(), "Enemy side contact did not shrink Super")
	check(player.invulnerability_left > 0, "Damage did not grant temporary invulnerability")
	check(player.get_node("CollShape").shape.size == Vector2(12, 15), "Damage did not restore small hitbox")
	player.damage()
	check(not player.is_dead(), "Repeated contact bypassed invulnerability")
	enemy.position = Vector2(700, -16)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	await ticks(150)
	check(not turn.turning and not turn.get_node("CollShape").disabled, "Turn block never restored solidity")
	check(player.invulnerability_left == 0, "Damage invulnerability did not expire")

	# A normal stomp flips an SMW Galoomba into a carryable body.
	enemy.position = Vector2(520, -16)
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	player.position = Vector2(520, -70)
	player.velocity = Vector2(0, 120)
	player.state_machine.switch(PlayerFallingState)
	await ticks(20)
	var stomped: StompedGaloomba
	for node in foreground.get_children():
		if node is StompedGaloomba:
			stomped = node
	check(stomped != null and player.velocity.y < 0, "Normal stomp did not flip the Galoomba and bounce the player")
	if stomped != null:
		check(Utility.find_child_by_class(stomped, PickupComponent) != null, "Flipped Galoomba is not carryable")
		player.position = stomped.position
		player.velocity = Vector2.ZERO
		Input.action_press("player_run")
		# A newly flipped Galoomba inherits alarm3=15 before it can be held.
		await ticks(20)
		check(player.held_item == stomped, "Holding Run on contact did not pick up the flipped Galoomba")
		Input.action_release("player_run")
		player.drop_item()
		await ticks(2)
		check(player.held_item == null and stomped.velocity.x != 0, "Releasing the carried Galoomba did not kick it")
		release_input()
		stomped.queue_free()
	check(player.score == 1600, "A normal stomp awarded score more than once")

	var spin_enemy := preload("res://scenes/level/entities/galoomba.tscn").instantiate()
	spin_enemy.position = Vector2(600, -16)
	level.current_sub_area.add(spin_enemy)
	player.position = Vector2(600, -90)
	player.velocity = Vector2(0, 120)
	player.state_machine.switch(PlayerFallingState)
	await ticks(2)
	player.state_machine.switch(PlayerSpinJumpingState)
	player.velocity.y = 120
	await ticks(18)
	check(not is_instance_valid(spin_enemy), "Spin stomp did not destroy the Galoomba")
	check(player.score == 1800 and not player.is_dead(), "Spin stomp did not reward a living player once")

	player.damage()
	check(player.is_dead(), "Unprotected small Mario did not die")
	level.complete(player)
	check(not level.is_completed, "A dead player completed the course")
	await ticks(165)
	check(level.hud.player != player and not level.hud.player.is_dead(), "Death did not restart the local level")
	check(level.hud.player.coins == 0 and level.hud.player.score == 0, "Retry did not reset HUD stats")
	level.get_node("%LevelTimer").start(0.02)
	await ticks(4)
	check(level.hud.player.is_dead() and level.get_current_time() == 0, "Timer expiry did not kill the player")
	await finish("INTERACTIONS_RESULT", level)
