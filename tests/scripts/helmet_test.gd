extends "res://tests/scripts/port_test.gd"
## Empty shell pickup, falling equip, armor, head deflection and SMW goal art.

const EMPTY: BuzzyVariant = preload("res://resources/content/smw_buzzy_empty.tres")
const BEETLE: BuzzyVariant = preload("res://resources/content/smw_buzzy_beetle.tres")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await check_falling_equip_and_damage()
	await check_carried_equip_and_head()
	await check_goal()
	await finish("HELMET_RESULT")


func make_level() -> Level:
	var level: Level = await LevelProcessor.from_swe("res://tests/fixtures/port_slice.swe")
	for part in level.current_sub_area.get_parts().get_children():
		if part is GoombaPart:
			part.free()
	add_child(level)
	await ticks(8)
	return level


func park(player: Player, pos := Vector2(400, -16)) -> void:
	player.position = pos
	player.previous_position = player.global_position
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)


func shell_at(level: Level, pos: Vector2, variant := EMPTY) -> KoopaShell:
	var shell: KoopaShell = load("res://scenes/entities/koopa_shell.tscn").instantiate()
	shell.variant = variant
	shell.position = pos
	level.current_sub_area.add(shell)
	return shell


func check_falling_equip_and_damage() -> void:
	var level := await make_level()
	var player := level.hud.player
	park(player)
	var shell := shell_at(level, Vector2(400, -96))
	await ticks(45)
	check(not is_instance_valid(shell) and player.has_helmet() and not player.is_dead(),
			"Falling empty Buzzy shell did not equip safely on Mario's head")
	check(player.get_powerup() is SmallPowerup and player.score == 0, "Helmet equip changed Mario's power or score")
	check(player.get_node("BuzzyHelmet/Sprite").sprite_frames.get_frame_texture(&"helmet", 0)
			.resource_path.contains("spr_helmet"), "Helmet uses a placeholder sprite")
	player.damage()
	check(not player.has_helmet() and not player.is_dead() and player.get_powerup() is SmallPowerup
			and player.invulnerability_left > 1.9, "Helmet did not absorb one hit independently of small Mario")
	player.damage()
	check(not player.is_dead(), "Helmet loss failed to grant damage immunity")
	await ticks(125)
	player.damage()
	check(player.is_dead(), "Unprotected small Mario incorrectly survived after helmet immunity expired")
	level.queue_free()
	await ticks(2)


func check_carried_equip_and_head() -> void:
	var level := await make_level()
	var player := level.hud.player
	player.set_powerup(SuperPowerup.new(), false)
	var shell := shell_at(level, Vector2(400, -16))
	await ticks(20)
	Input.action_press("player_run")
	park(player, Vector2(390, -16))
	await ticks(5)
	check(player.held_item == shell, "Empty Buzzy shell could not be carried")
	Input.action_press("player_down")
	await ticks(3)
	check(player.has_helmet() and player.held_item == null and not is_instance_valid(shell),
			"Down while carrying failed to wear the shell and clear held ownership")
	release_input()
	park(player)
	await ticks(3)
	check(player.get_node("BuzzyHelmet").position.y == -23, "Super Mario's helmet does not use its source head offset")
	shell = shell_at(level, Vector2(400, -100), BEETLE)
	await ticks(32)
	check(player.has_helmet() and not player.is_dead() and is_instance_valid(shell) and shell.velocity.y < 0,
			"Helmet failed to deflect a real falling occupied shell from above")
	shell.queue_free()
	var block := QuestionBlockPart.create()
	block.position = Vector2(392, -96)
	level.current_sub_area.add_part(block)
	block.load()
	block.build()
	Input.action_press("player_jump")
	await ticks(22)
	Input.action_release("player_jump")
	check(player.coins == 1 and player.score == 200 and player.has_helmet(),
			"Helmet head contact failed to activate a real question block once")
	park(player)
	await ticks(10)
	player.damage()
	check(not player.has_helmet() and player.get_powerup() is SuperPowerup and not player.is_dead(),
			"Helmet armor incorrectly shrank super Mario")
	level.reload()
	await ticks(6)
	check(not level.hud.player.has_helmet(), "Helmet leaked into a fresh course retry")
	level.queue_free()
	await ticks(2)


func check_goal() -> void:
	var level := await make_level()
	var player := level.hud.player
	check(player.equip_buzzy_helmet(), "Could not equip a helmet before the course clear")
	park(player, Vector2(866, -16))
	await ticks(450)
	check(level.is_completed and player.sprite.animation == &"goal_buzzy",
			"Course clear did not choose SMW's helmet-specific victory frame")
	check(player.sprite.sprite_frames.get_frame_texture(&"goal_buzzy", 0).resource_path.ends_with("frame_001.png")
			and not player.get_node("BuzzyHelmet").visible, "Victory frame duplicated the worn helmet overlay")
	level.queue_free()
	await ticks(2)
