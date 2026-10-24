# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/bro_projectile_test.gd"
## Source event boundaries that the older generic projectile tests missed.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--capture-bro-environment" in OS.get_cmdline_user_args():
		await capture_environment()
		return
	for spiny in [false, true]:
		for kind in [BroProjectile.Kind.HAMMER, BroProjectile.Kind.FIRE, BroProjectile.Kind.ICE]:
			await check_head_shot(kind, spiny)
		await check_boomerang_armor(spiny)
	for kind in [BroProjectile.Kind.HAMMER, BroProjectile.Kind.FIRE, BroProjectile.Kind.BOOMERANG]:
		await check_carried_shell(kind)
	await check_water_shots()
	await check_shot_liquid_boundaries()
	await check_ice_supported_above_liquid()
	await check_bro_sinking()
	await check_frozen_contacts()
	for small in [false, true]:
		await check_frozen_melting(small)
		for held_kind in [&"shell", &"buzzy", &"spiny", &"galoomba"]:
			await check_frozen_held_item(small, held_kind)
	await check_frozen_low_ceiling()
	await check_spawn_ownership()
	await finish("BRO_ENVIRONMENT_RESULT")


func add_liquid(level: Level, theme: Level.LevelTheme, y: float, night := false) -> LiquidSurface:
	var area := level.current_sub_area
	area.level_theme = theme
	area.night_mode = night
	area.water_start_y = y - 12
	area.water_limit_y = y - 12
	var liquid := LiquidSurface.new()
	liquid.sub_area = area
	area.liquid = liquid
	area.add_child(liquid)
	liquid.set_physics_process(false)
	return liquid


func effects(area: SubArea, art: StringName) -> Array[AnimatedSprite2D]:
	var found: Array[AnimatedSprite2D] = []
	for node in area.get_foreground().get_children():
		if node is AnimatedSprite2D and node.sprite_frames.get_frame_texture(node.animation, 0) \
				.resource_path.contains("/" + String(art) + "/"):
			found.append(node)
	return found


func live_nodes(area: SubArea, type: Script) -> Array[Node]:
	var found: Array[Node] = []
	for node in area.get_foreground().get_children():
		if is_instance_of(node, type) and not node.is_queued_for_deletion():
			found.append(node)
	return found


func check_head_shot(kind: BroProjectile.Kind, spiny: bool) -> void:
	var level := await make_level()
	var player := level.hud.player
	player.equip_shell_helmet(preload("res://resources/content/smw_helmet_spiny_rules.tres")) if spiny else player.equip_buzzy_helmet()
	Input.action_press("player_run")
	await ticks(2)
	var helmet: PlayerHelmet = player.get_node("BuzzyHelmet")
	var top := helmet.global_position.y + helmet.rules.head_top
	var body := shot(level, kind, Vector2(player.position.x, top - 32))
	body.position.y += top - 4 - Utility.get_bounding_box(body).end.y
	body.velocity = Vector2(0, 120)
	var bounced := false
	for frame in 12:
		await ticks(1)
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			bounced = kind == BroProjectile.Kind.HAMMER
			break
		if body.velocity.y < 0:
			bounced = kind != BroProjectile.Kind.HAMMER
			break
	check(bounced and player.has_helmet() and not player.is_frozen() and player.score == 0 \
			and player.invulnerability_left == 0,
			"Actual head overlap failed to deflect Bro shot %s with helmet %s while Run was held" % [kind, spiny])
	if kind == BroProjectile.Kind.HAMMER:
		var corpses := live_nodes(level.current_sub_area, SwimmingEnemyDefeat)
		check(corpses.size() == 1 and corpses[0].velocity.y < -200,
				"Helmet hammer contact missed its native rotating source defeat")
	if is_instance_valid(body):
		body.queue_free()
	# Physical shots have a separate rising-head response from enemy/held masks.
	if kind in [BroProjectile.Kind.FIRE, BroProjectile.Kind.ICE]:
		body = shot(level, kind, Vector2(player.position.x, top - 32))
		body.set_physics_process(false)
		body.position.y += top + 2 - Utility.get_bounding_box(body).end.y
		body.velocity = Vector2(0, 60)
		player.velocity.y = -60
		check(player.helmet_deflects(body) and is_equal_approx(body.velocity.y, -180 if spiny else -120),
				"Physical-shot rising bounce reused the enemy helmet impulse")
		body.queue_free()
	release_input()
	level.queue_free()
	await ticks(2)


func check_boomerang_armor(spiny: bool) -> void:
	var level := await make_level()
	var player := level.hud.player
	player.equip_shell_helmet(preload("res://resources/content/smw_helmet_spiny_rules.tres")) if spiny else player.equip_buzzy_helmet()
	await ticks(2)
	var body := shot(level, BroProjectile.Kind.BOOMERANG, player.position + Vector2(0, -24))
	body.velocity = Vector2.ZERO
	await ticks(4)
	check(not player.has_helmet() and player.get_powerup() is SuperPowerup and is_instance_valid(body),
			"Boomerang incorrectly inherited the physical-shot helmet head guard")
	level.queue_free()
	await ticks(2)


func check_carried_shell(kind: BroProjectile.Kind) -> void:
	var level := await make_level()
	var player := level.hud.player
	Input.action_press("player_run")
	var shell: KoopaShell = load("res://scenes/entities/koopa_shell.tscn").instantiate()
	shell.position = Vector2(600, -96)
	level.current_sub_area.add(shell)
	await ticks(17)
	player.give_item(shell)
	await ticks(3)
	check(player.held_item == shell and shell.motion == KoopaShell.Motion.CARRIED,
			"Carried-shot test failed to establish actual shell ownership")
	var body := shot(level, kind, Vector2(player.position.x, -200), -1)
	body.set_physics_process(false)
	body.velocity = Vector2.ZERO
	# Cross the held mask first, then the player's torso. Source Bro shots
	# override/omit enemy collisions, so the shell is not a universal shield.
	body.global_position = shell.global_position - Vector2(0, 8)
	await ticks(3)
	check(is_instance_valid(body) and is_instance_valid(shell), "A held shell consumed a Bro projectile")
	if not is_instance_valid(body):
		release_input()
		level.queue_free()
		await ticks(2)
		return
	body.global_position = player.global_position - Vector2(0, 20)
	await ticks(5)
	check(player.get_powerup() is SmallPowerup and not player.is_dead() and is_instance_valid(body),
			"Carried shell incorrectly shielded a Bro projectile's real player contact")
	release_input()
	level.queue_free()
	await ticks(2)


func check_water_shots() -> void:
	var level := await make_level()
	var liquid := add_liquid(level, Level.LevelTheme.FOREST, -240)
	var fire := shot(level, BroProjectile.Kind.FIRE, Vector2(300, -200))
	var ice := shot(level, BroProjectile.Kind.ICE, Vector2(340, -200))
	fire.velocity = Vector2.ZERO
	ice.velocity = Vector2.ZERO
	await ticks(5)
	check(is_equal_approx(fire.velocity.y, 6) and is_equal_approx(ice.velocity.y, 60),
			"Water applied one gravity to fire and ice instead of the distinct source parents")
	var hammer := shot(level, BroProjectile.Kind.HAMMER, Vector2(450, liquid.position.y + 14))
	check(is_equal_approx(hammer.velocity.y, -180), "Hammer water entry lost its strict +14 origin boundary")
	hammer.position.y += 0.1
	hammer.velocity = Vector2.ZERO
	await ticks(1)
	check(is_equal_approx(hammer.velocity.y, 3) and is_equal_approx(hammer._sprite.rotation_degrees, 6),
			"Hammer did not switch gravity/rotation after crossing the water boundary")
	level.current_sub_area.level_theme = Level.LevelTheme.BEACH
	var beach := shot(level, BroProjectile.Kind.HAMMER, Vector2(480, -200))
	check(is_equal_approx(beach.velocity.y, -180), "Beach launch must retain Create_0's air speed before its water Step")
	beach.velocity = Vector2.ZERO
	await ticks(1)
	check(is_equal_approx(beach.velocity.y, 3), "Beach hammer did not acquire water gravity after launching")
	level.current_sub_area.level_theme = Level.LevelTheme.UNDERWATER
	var player := level.hud.player
	player.equip_buzzy_helmet()
	await ticks(2)
	var helmet: PlayerHelmet = player.get_node("BuzzyHelmet")
	var top := helmet.global_position.y + helmet.rules.head_top
	var deflected := shot(level, BroProjectile.Kind.HAMMER, Vector2(player.position.x, top))
	deflected.set_physics_process(false)
	deflected.position.y += top + 2 - Utility.get_bounding_box(deflected).end.y
	check(player.helmet_deflects(deflected), "Underwater head contact failed to deflect a hammer")
	await ticks(1)
	var corpses := live_nodes(level.current_sub_area, SwimmingEnemyDefeat)
	check(corpses.size() == 1 and corpses[0].velocity.y >= -96 and corpses[0].velocity.y <= -94.79,
			"Underwater deflected hammer reused the air -4px/frame defeat launch")
	level.queue_free()
	await ticks(2)


func check_shot_liquid_boundaries() -> void:
	var level := await make_level()
	# This oracle counts projectile splashes while changing liquid themes;
	# isolate Mario so his newly implemented water entry cannot add a splash.
	level.hud.player.set_physics_process(false)
	var area := level.current_sub_area
	var liquid := add_liquid(level, Level.LevelTheme.CASTLE, -160)
	var fire := shot(level, BroProjectile.Kind.FIRE, Vector2(300, -180))
	fire.set_physics_process(false)
	check(not fire._liquid_contact() and not fire.is_queued_for_deletion(), "Bro fire burst on the lava surface")
	fire.position.y = liquid.position.y + 32
	check(not fire._liquid_contact(), "Bro fire's deep-lava cull must be strict")
	fire.position.y += 0.1
	check(fire._liquid_contact() and fire.is_queued_for_deletion(), "Bro fire survived below lava+32")
	var hammer := shot(level, BroProjectile.Kind.HAMMER, Vector2(500, -220))
	hammer.set_physics_process(false)
	hammer.position.y += liquid.position.y - 3 - Utility.get_bounding_box(hammer).end.y
	hammer._liquid_contact()
	check(not hammer._molten, "Hammer entered lava at the excluded mask boundary")
	hammer.position.y += 0.1
	hammer._liquid_contact()
	hammer._liquid_contact()
	await ticks(1)
	check(hammer._molten and effects(area, &"spr_splash_lava").size() == 1,
			"Hammer must splash once on lava entry, with no fire surface splash")
	hammer.velocity = Vector2(0, 120)
	hammer._physics_process(1.0 / 60)
	check(is_equal_approx(hammer.velocity.y, 63), "Molten hammer missed its cap-before-gravity 1px/frame sink")
	hammer.queue_free()
	for theme in [Level.LevelTheme.CASTLE, Level.LevelTheme.FOREST, Level.LevelTheme.MOUNTAIN]:
		area.level_theme = theme
		area.night_mode = true
		var ice := shot(level, BroProjectile.Kind.ICE, Vector2(340, -220))
		ice.set_physics_process(false)
		ice.position.y += liquid.position.y - 3 - Utility.get_bounding_box(ice).end.y
		check(not ice._liquid_contact(), "Ice broke at the excluded damaging-liquid boundary")
		ice.position.y += 0.5
		check(ice._liquid_contact() and ice.is_queued_for_deletion(), "Ice survived damaging liquid theme %s" % theme)
		await ticks(1)
	area.level_theme = Level.LevelTheme.FOREST
	area.night_mode = false
	var ice := shot(level, BroProjectile.Kind.ICE, Vector2(560, -220))
	ice.set_physics_process(false)
	ice.position.y += liquid.position.y - 2 - Utility.get_bounding_box(ice).end.y
	var splashes := effects(area, &"spr_splash").size()
	check(not ice._liquid_contact() and not ice.is_queued_for_deletion(), "Ice broke at a water surface")
	await ticks(1)
	check(effects(area, &"spr_splash").size() == splashes + 1, "Ice lost the narrow source water-splash band")
	level.queue_free()
	await ticks(2)


func check_ice_supported_above_liquid() -> void:
	var level := await make_level()
	add_liquid(level, Level.LevelTheme.CASTLE, -100)
	var ice := shot(level, BroProjectile.Kind.ICE, Vector2(300, -160))
	ice.set_physics_process(false)
	ice.position.y += -96 - Utility.get_bounding_box(ice).end.y
	ice.velocity = Vector2(0, 60)
	check(not ice._liquid_contact() and not ice.is_queued_for_deletion(),
			"Source ice must resolve a supporting solid before its liquid branch")
	ice._bouncing_shot(1.0 / 60)
	check(is_equal_approx(ice.velocity.y, -253.5) and not ice.is_queued_for_deletion(),
			"Ice lost its normal first floor rebound where liquid overlaps the support")
	level.queue_free()
	await ticks(2)


func check_bro_sinking() -> void:
	for sledge in [false, true]:
		var level := await make_level()
		var area := level.current_sub_area
		var liquid := add_liquid(level, Level.LevelTheme.CASTLE, -160)
		var bro: HammerBro = load("res://scenes/entities/hammer_bro.tscn").instantiate()
		if sledge:
			bro.variant = preload("res://resources/content/smw_hammerbro_sledge.tres")
		bro.position = Vector2(520, liquid.position.y - 3)
		bro.wings = true
		area.add(bro)
		bro.set_physics_process(false)
		check(bro._touches_damaging_liquid(), "Castle Bro sink boundary should include equality")
		area.level_theme = Level.LevelTheme.FOREST
		area.night_mode = true
		check(not bro._touches_damaging_liquid(), "Poison Bro sink boundary should exclude equality")
		bro.position.y += 0.1
		check(bro._touches_damaging_liquid(), "Bro failed to enter poison below its exact source mask boundary")
		var source_at := bro.position - Vector2(0, 16)
		bro._physics_process(1.0 / 60)
		await ticks(1)
		var sinks := live_nodes(area, SinkingEnemy)
		check(not is_instance_valid(bro) and sinks.size() == 1 and effects(area, &"spr_splash_lava_purple").size() == 1,
				"Bro did not replace itself with one native poison-sinking actor")
		if sinks.size() == 1:
			var sink: SinkingEnemy = sinks[0]
			check(sink.ellipse_mask and sink.mask_size == (Vector2(18, 24) if sledge else Vector2(10, 16)) \
					and absf(sink.position.y - source_at.y) < 0.1 and sink._sprite.frame == 0,
					"Sinking Bro changed source origin, elliptical mask or initial art")
		level.reload()
		await ticks(4)
		check(live_nodes(area, SinkingEnemy).is_empty(), "Bro sink survived a runtime revision/retry")
		level.queue_free()
		await ticks(2)


func check_frozen_contacts() -> void:
	var level := await make_level()
	var player := level.hud.player
	check(player.freeze_in_ice(), "Frozen contact test could not freeze Mario")
	await ticks(2)
	var frozen: PlayerFrozenState = player.state_machine.current_state
	var proxy := frozen._ice_body
	check(is_instance_valid(proxy) and proxy.collision_layer == PlayerFrozenState.ICE_CONTACT_LAYER \
			and proxy.collision_mask == 0, "Frozen contact proxy should never block actor motion")
	var ice := shot(level, BroProjectile.Kind.ICE, frozen._ice_bounds().get_center() - Vector2(0, 8))
	ice.set_physics_process(false)
	await ticks(3)
	check(not is_instance_valid(ice) and player.is_frozen(), "Fresh ice did not break against the frozen replacement mask")
	player.state_machine.switch(PlayerIdleState)
	await ticks(2)
	check(not is_instance_valid(proxy) and player.collision_layer == 4, "Thaw kept a stale frozen contact body")
	check(player.freeze_in_ice(), "Mario failed to freeze again before retry cleanup")
	proxy = player.state_machine.current_state._ice_body
	level.reload()
	await ticks(3)
	check(not is_instance_valid(proxy), "Retry leaked a frozen contact proxy")
	level.queue_free()
	await ticks(2)


func check_frozen_melting(small: bool) -> void:
	var level := await make_level()
	var player := level.hud.player
	if small:
		player.set_powerup(SmallPowerup.new(), false)
	check(player.freeze_in_ice(), "Early-melt test failed to freeze Mario")
	await ticks(2)
	var frozen: PlayerFrozenState = player.state_machine.current_state
	var liquid := add_liquid(level, Level.LevelTheme.CASTLE, frozen._ice_bounds().end.y + 3)
	await ticks(2)
	check(player.is_frozen() and not frozen._melt_pending, "Frozen ice melted at an excluded lava boundary")
	liquid.position.y -= 0.5
	await ticks(1)
	check(player.is_frozen() and frozen._melt_pending, "Frozen Mario must schedule a one-tick thaw on liquid entry")
	await ticks(1)
	check(not player.is_frozen() and (player.get_powerup() is SmallPowerup) == small,
			"Lava entry failed to thaw next tick while preserving Mario's power")
	level.current_sub_area.level_theme = Level.LevelTheme.FOREST
	level.current_sub_area.night_mode = false
	check(player.freeze_in_ice(), "Water-melt test could not freeze Mario")
	await ticks(4)
	check(player.is_frozen(), "Water incorrectly melted the frozen player")
	level.queue_free()
	await ticks(2)


func check_frozen_held_item(small: bool, held_kind: StringName) -> void:
	var level := await make_level()
	var player := level.hud.player
	if small:
		player.set_powerup(SmallPowerup.new(), false)
	Input.action_press("player_run")
	var item: Entity = load("res://scenes/entities/stomped_galoomba.tscn" \
			if held_kind == &"galoomba" else "res://scenes/entities/koopa_shell.tscn").instantiate()
	if held_kind == &"buzzy":
		item.variant = preload("res://resources/content/smw_buzzy_empty.tres")
	elif held_kind == &"spiny":
		item.variant = preload("res://resources/content/smw_spiny_empty.tres")
	item.position = Vector2(600, -96)
	level.current_sub_area.add(item)
	await ticks(17)
	player.give_item(item)
	await ticks(2)
	player.set_physics_process(false)
	player.position.y = -176
	player.state_machine.current_state.position_held_item(-player.direction)
	await ticks(1)
	var at := item.global_position
	var pose := player.sprite.animation
	var frame := player.sprite.frame
	check(player.held_item == item, "Freeze/held regression failed to establish ownership")
	check(player.freeze_in_ice(), "Freeze/held regression failed to freeze Mario")
	check(player.held_item == null, "Frozen Mario retained his carried item")
	player.give_item(item)
	check(player.held_item == null, "A queued pickup reattached an item while Mario was frozen")
	player.set_physics_process(true)
	await ticks(2)
	var pickup: PickupComponent = Utility.find_child_by_class(item, PickupComponent)
	check(item.get_parent() == player.get_parent() and pickup.get_holder() == null,
			"Frozen item did not leave the player hierarchy and clear pickup ownership")
	check(absf(item.global_position.x - at.x) < 0.01 and item.velocity.x == 0 and item.velocity.y > 0,
			"Frozen item was kicked/shifted instead of falling freely at its captured position")
	check(player.sprite.animation == pose and player.sprite.frame == frame and not player.sprite.is_playing(),
			"Forced detachment overwrote frozen Mario's captured pose with a kick")
	if item is KoopaShell:
		check(item.motion == KoopaShell.Motion.STATIONARY and item.collision_layer == 2,
				"Frozen release left a shell carried, moving or without its native body layer")
	await ticks(12)
	check(absf(item.global_position.x - at.x) < 0.01,
			"A stale held-item turn tween moved the detached item in area coordinates")
	var frozen: PlayerFrozenState = player.state_machine.current_state
	frozen.remaining = 2.0 / 60
	await ticks(3)
	check(not player.is_frozen() and player.held_item == null and is_instance_valid(item),
			"Thaw restored obsolete ownership or removed the detached item")
	player.give_item(item)
	await ticks(2)
	check(player.freeze_in_ice(), "Detached item could not participate in a later freeze")
	level.reload()
	await ticks(3)
	check(not is_instance_valid(item) and not level.hud.player.is_frozen(),
			"Retry retained an item or pending detach from the previous frozen player")
	release_input()
	level.queue_free()
	await ticks(2)


func check_frozen_low_ceiling() -> void:
	var level := await make_level()
	var player := level.hud.player
	player.set_powerup(SmallPowerup.new(), false)
	var ceiling := StaticBody2D.new()
	ceiling.position = Vector2(400, -117)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 4)
	collider.shape = shape
	ceiling.add_child(collider)
	level.current_sub_area.add(ceiling)
	await ticks(2)
	player.set_powerup(SuperPowerup.new(), false)
	await ticks(2)
	check(player.growth_crouched and player.sprite.animation == &"duck",
			"Frozen crouch regression failed to establish blocked native growth")
	check(player.freeze_in_ice(), "Crouched Mario failed to freeze")
	var before := player.position
	ceiling.queue_free()
	await ticks(4)
	check(player.growth_crouched and player.sprite.animation == &"duck" and not player.sprite.is_playing() \
			and player.position == before,
			"Frozen Mario resumed his low-ceiling animation or expanded/moved before thaw")
	var frozen: PlayerFrozenState = player.state_machine.current_state
	frozen.remaining = 2.0 / 60
	await ticks(4)
	check(not player.is_frozen() and not player.growth_crouched and player.get_node("CollShape").shape.size.y == 27,
			"Thawed Mario failed to resume native standing-room checks")
	level.queue_free()
	await ticks(2)


func check_spawn_ownership() -> void:
	var level := await make_level()
	var area := level.current_sub_area
	var bro: HammerBro = load("res://scenes/entities/hammer_bro.tscn").instantiate()
	bro.variant = preload("res://resources/content/smw_hammerbro_boomerang.tres")
	bro.position = Vector2(460, -96)
	area.add(bro)
	bro._spawn_projectile()
	bro.queue_free()
	await ticks(2)
	var shots := live_nodes(area, BroProjectile)
	check(shots.size() == 1, "A source-created projectile was incorrectly cancelled with its defeated owner")
	if shots.size() == 1:
		var boom: BroProjectile = shots[0]
		boom._age = 2
		await ticks(2)
		check(is_instance_valid(boom), "Returning shot failed after its owner was freed")
	bro = load("res://scenes/entities/hammer_bro.tscn").instantiate()
	bro.position = Vector2(600, -96)
	area.add(bro)
	bro._spawn_projectile()
	level.reload()
	await ticks(3)
	check(live_nodes(area, BroProjectile).is_empty() and area._pending_spawns.is_empty(),
			"Retry allowed a deferred Bro shot into the new runtime revision")
	level.queue_free()
	await ticks(2)


func capture_environment() -> void:
	var level := await make_level()
	var player := level.hud.player
	player.equip_shell_helmet(preload("res://resources/content/smw_helmet_spiny_rules.tres"))
	await ticks(2)
	var ice := shot(level, BroProjectile.Kind.ICE, player.position + Vector2(0, -52))
	ice.velocity = Vector2(0, 100)
	for frame in 12:
		await ticks(1)
		if ice.velocity.y < 0:
			break
	check(ice.velocity.y < 0 and player.has_helmet() and not player.is_frozen(), "Capture missed the actual ice/helmet rebound")
	var liquid := add_liquid(level, Level.LevelTheme.FOREST, -144, true)
	var bro: HammerBro = load("res://scenes/entities/hammer_bro.tscn").instantiate()
	bro.position = Vector2(304, liquid.position.y - 2.5)
	level.current_sub_area.add(bro)
	await ticks(3)
	check(not is_instance_valid(bro) and live_nodes(level.current_sub_area, SinkingEnemy).size() == 1,
			"Capture missed the actual poison sink")
	# This fixture stops the liquid clock, so refresh its cached viewport fill.
	liquid.queue_redraw()
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_bro_environment.png")
	check(error == OK, "Could not save Bro environment capture")
	print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	level.queue_free()
	await ticks(2)
	get_tree().quit(0 if failures.is_empty() else 1)
