# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/bro_environment_test.gd"
## Three distinct source IDs, editor routes and actual native rolling contacts.

const LEGACY := preload("res://resources/content/smw_grrrol_legacy.tres")
const SMALL := preload("res://resources/content/smw_grrrol_small.tres")
const GIANT := preload("res://resources/content/smw_grrrol_giant.tres")
const PROFILES := [LEGACY, SMALL, GIANT]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--capture-grrrol" in OS.get_cmdline_user_args():
		await capture_rolling()
		return
	if "--capture-editor-grrrol" in OS.get_cmdline_user_args():
		await capture_rolling_editor()
		return
	for modern in [false, true]:
		await check_rolling_editor(modern)
	for index in PROFILES.size():
		await check_origins_and_masks(index)
		await check_rolling_motion(PROFILES[index])
		await check_water_and_liquid(PROFILES[index])
		await check_hard_contacts(PROFILES[index])
		await check_mario_and_block(PROFILES[index])
		await check_defeat_art(PROFILES[index])
	await check_night_and_drag()
	await check_legacy_separation()
	await check_delayed_break(false)
	await check_delayed_break(true)
	await check_rolling_death(false)
	await check_rolling_death(true)
	await check_rolling_activity()
	await check_liquid_themes_and_cull()
	await finish("GRRROL_RESULT")


func rolling_level() -> Level:
	var level := await make_level()
	level.current_sub_area.actor_activity.enabled = false
	var player := level.hud.player
	player.set_physics_process(false)
	player.collision_layer = 0
	player.position = Vector2(260, -96)
	player.previous_position = player.position
	Utility.camera_position = Vector2(208, -216)
	return level


func rolling(level: Level, data: GrrrolVariant = SMALL, at := Vector2(480, -224), automatic := false, direction := 2) -> Grrrol:
	var body: Grrrol = load("res://scenes/entities/grrrol.tscn").instantiate()
	body.variant = data
	body.attack_direction = direction
	body.position = at
	level.current_sub_area.add(body)
	body.set_physics_process(automatic)
	return body


func click_rolling(button: Button) -> void:
	await click_point(button.get_global_transform_with_canvas() * (button.size / 2))


func click_point(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion, true)
	await ticks(1)
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await ticks(1)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	get_viewport().push_input(event, true)
	await ticks(2)


func check_rolling_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	for index in PROFILES.size():
		data.MAIN.NIVEL.append({"object": PROFILES[index].object_id, "x_pos": 426.5 + index * 80,
			"y_pos": 241.25, "direct_t": 3, "wings": 1, "paracaidas": 1, "future_roll": {"keep": index + 23}})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/grrrol_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var imported := 0
	for part in level.current_sub_area.get_parts().get_children():
		if part is ThwompPart and part.variant is GrrrolVariant:
			check(part.position == Vector2(426.5 + imported * 80, -190.75) and part.attack_direction == 3
					and part.wings and part.parachute and part.variant == PROFILES[imported], "Grrrol import lost source ID, fractional origin, direction or flags")
			imported += 1
	check(imported == 3, "All three source Grrrol resource IDs must load")
	var editor := level.editor
	var ring: PaletteRing = editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_enemies.tres")
	ring.page_index = 1
	ring.choose(2)
	var thwomp := editor.place(Vector2i(32, -15)) as ThwompPart
	thwomp.set_variant(&"thwomp_giant")
	thwomp.attack_direction = 3
	thwomp.wings = true
	thwomp.parachute = true
	var before := thwomp.position
	thwomp.held = true
	thwomp.set_process(false)
	await ticks(42)
	check(is_instance_valid(thwomp._window), "Giant Thwomp did not expose its native type window")
	if is_instance_valid(thwomp._window):
		await click_rolling(thwomp._window.get_node("Content/Options/grrrol"))
	thwomp.held = false
	thwomp.set_process(true)
	await ticks(8)
	check(thwomp.variant == LEGACY and thwomp.position == before - Vector2(0, 16)
			and thwomp.attack_direction == 2 and not thwomp.wings and not thwomp.parachute,
			"Thwomp type conversion did not create the legacy y-16 resource with fresh defaults")
	check(thwomp.get_variants().is_empty() and thwomp.get_modifiers().is_empty()
			and thwomp.get_node("CollShape").shape.size == Vector2(48, 48), "Legacy Grrrol invented a popup or lost its 3x3 footprint")
	editor.history.undo()
	check(thwomp.variant == ThwompPart.GIANT and thwomp.position == before and thwomp.attack_direction == 3
			and thwomp.wings and thwomp.parachute, "Conversion undo lost source type/position/direction/flags")
	editor.history.redo()
	var legacy_next := editor.place(Vector2i(38, -15)) as ThwompPart
	check(legacy_next.variant == LEGACY and legacy_next.attack_direction == 2,
			"Thwomp's converted card did not retain legacy Grrrol for subsequent placements")
	ring.page_index = 4
	check(ring.choose(3) and editor.get_selected_part() == GrrrolPart, "Standalone Grrrol page5 slot3 remains disabled or shares the legacy card")
	var small := editor.place(Vector2i(44, -15)) as GrrrolPart
	check(small.variant == SMALL, "The standalone Grrrol card must start with obj_grrrol_new_res")
	editor.set_part_modifier(small, &"wings", true)
	editor.set_part_modifier(small, &"parachute", true)
	small.attack_direction = 3
	before = small.position
	small.held = true
	small.set_process(false)
	await ticks(42)
	if is_instance_valid(small._window):
		check(small._window.get_node("Content/Attachments").get_child_count() == 3,
				"New Grrrol window must expose size/wings/parachute")
		await click_rolling(small._window.get_node("Content/Attachments/large"))
	else:
		check(false, "New Grrrol opened no native modifier-only window")
	small.held = false
	small.set_process(true)
	await ticks(8)
	check(small.variant == GIANT and small.position == before and small.attack_direction == 2
			and not small.wings and not small.parachute, "New Grrrol size conversion moved its source origin or retained fresh-resource fields")
	editor.history.undo()
	check(small.variant == SMALL and small.attack_direction == 3 and small.wings and small.parachute
			and small.position == before, "Rolling size undo did not restore all dependent state")
	editor.history.redo()
	var next := editor.place(Vector2i(49, -15)) as GrrrolPart
	check(next.variant == GIANT, "Standalone rolling size did not update its own source card")
	var blocker := GroundPart.create()
	blocker.position = next.position + Vector2(48, 48)
	level.current_sub_area.add_part(blocker)
	await ticks(2)
	next._check_validity()
	check(not next._valid_space and not GrrrolPart.is_variant_placeable(Level.to_grid(next.position), level.get_world_2d(), GIANT.id),
			"Giant Grrrol placement/drag did not check the lower-right of all sixteen cells")
	blocker.free()
	var saved: Dictionary = await editor.save_to_path(path)
	check(saved.error == OK, "Native Grrrol signed SWE saving failed")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var restored := 0
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is ThwompPart and part.variant is GrrrolVariant and part.position.x in [426.5, 506.5, 586.5]:
			var index := int((part.position.x - 426.5) / 80)
			check(part.variant == PROFILES[index] and part.position.y == -190.75 and part.attack_direction == 3
					and part.wings and part.parachute and part.swe_data.future_roll.keep == index + 23,
					"Signed Grrrol round-trip lost source geometry, aliases or unknown fields")
			restored += 1
	check(restored == 3, "SWE changed the three authored Grrrol instances")
	reopened.free()
	level.queue_free()
	await ticks(2)


func check_origins_and_masks(index: int) -> void:
	var level := await rolling_level()
	var data: GrrrolVariant = PROFILES[index]
	var part: ThwompPart = ThwompPart.create() if data.legacy else GrrrolPart.create()
	part.variant = data
	part.position = Vector2(480.25, -200.5)
	part.attack_direction = 3
	part.wings = true
	part.parachute = true
	level.current_sub_area.add_part(part)
	part.load()
	part.build()
	var body: Grrrol = live_nodes(level.current_sub_area, Grrrol)[0]
	body.set_physics_process(false)
	body.get_node("PlayerArea").collision_layer = 1 << 7
	await ticks(2)
	var runtime_centers := [Vector2(24, 24), Vector2(20, 18), Vector2(32.5, 32.5)]
	var editor_centers := [Vector2(24, 24), Vector2(16, 16), Vector2(32.5, 32.5)]
	var origins := [Vector2(25, 25), Vector2(20, 20), Vector2(32, 32)]
	check(data.source_position(body.position) == part.position + runtime_centers[index], "Grrrol runtime build rewrote its distinct source center")
	check(body._sprite.global_position.is_equal_approx(Vector2(roundf(body.global_position.x),
			data.source_position(body.global_position).y + [1, 0, 0][index])),
			"Grrrol surface alignment lost rounded x, shifted a correct modern body or lost the legacy 1px fix")
	var preview: Sprite2D = part.get_node("Graphics/Sprite")
	var editor_contact_shift := Vector2(0, [1, -3, 1.5][index])
	check(preview.global_position.is_equal_approx(part.global_position + editor_centers[index] + editor_contact_shift)
			and preview.offset == -origins[index], "Grrrol editor art lost its horizontal origin or one-pixel placement overlap: %s position=%s offset=%s" % [index, preview.global_position, preview.offset])
	check(body.attack_direction == 3 and body.find_children("*", "AnimatedSprite2D", true, false).size() == 1
			and part._decoration.get_child_count() == 0, "Grrrol forwarded editor flags or invented source-absent decorations")
	var mask := Utility.get_bounding_box(body)
	var corner := mask.position + Vector2(0.5, 0.5)
	for sensor in [false, true]:
		var query := PhysicsPointQueryParameters2D.new()
		query.collision_mask = 1 << 7 if sensor else 2
		query.collide_with_bodies = not sensor
		query.collide_with_areas = sensor
		query.position = mask.get_center()
		check(not body.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty(), "Grrrol ellipse lost its center")
		query.position = corner
		check(body.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty(), "Grrrol ellipse retained a rectangular corner")
	body.angle = 67
	body._update_visuals()
	check(Utility.get_bounding_box(body) == mask and is_equal_approx(body._sprite.rotation_degrees, -67)
			and body._sprite.frame == 2 and not body._sprite.is_playing(), "Rolling angle rotated a collision mask or changed the fixed SMW frame")
	level.queue_free()
	await ticks(2)


func check_rolling_motion(data: GrrrolVariant) -> void:
	for direction in [2, 3]:
		var level := await rolling_level()
		var body := rolling(level, data, Vector2(480, -224), false, direction)
		body._physics_process(1.0 / 60)
		check(body.velocity == Vector2(0, 12) and body.angle == 0, "Grrrol moved before the two-tick source alarm")
		body._physics_process(1.0 / 60)
		check(body.velocity.x == (-72 if direction == 2 else 72) and body.angle == (3.5 if direction == 2 else -3.5),
				"Grrrol alarm/drawing angle differs from source")
		body.velocity.y = 300
		body._physics_process(1.0 / 60)
		check(body.velocity.y == 252, "Grrrol fall cap must precede inherited .2/frame gravity")
		level.queue_free()
		await ticks(2)
	var level := await rolling_level()
	var body := rolling(level, data, Vector2(480, -200), true)
	var bounced := false
	for frame in 160:
		await ticks(1)
		bounced = bounced or body.velocity.y < -30
	check(bounced and not body.bouncy and absf(body.position.y + 96) < 0.2, "Source initial bouncy landing did not decay into ordinary rolling")
	body.position = Vector2(480, -96)
	body.velocity = Vector2(72, 0)
	body._wake_left = INF
	var wall := StaticBody2D.new()
	wall.position = Vector2(544, -192)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 192)
	collider.shape = shape
	wall.add_child(collider)
	level.current_sub_area.add(wall)
	var reversed := false
	var hopped := false
	for frame in 65:
		await ticks(1)
		reversed = reversed or body.velocity.x < 0
		hopped = hopped or body.velocity.y <= -59.9
	check(reversed and hopped, "Real Grrrol wall collision did not reverse and perform its 1px/frame hop")
	level.queue_free()
	await ticks(2)


func check_night_and_drag() -> void:
	var level := await rolling_level()
	var area := level.current_sub_area
	var body := rolling(level)
	body._wake_left = INF
	area.night_mode = true
	for right in [false, true]:
		body.position = Vector2(480, -224)
		body.velocity = Vector2.ZERO
		level.hud.player.position.x = 550 if right else 350
		body._physics_process(1.0 / 60)
		check(is_equal_approx(body.velocity.x, 1.944 if right else -1.344), "Night Grrrol lost asymmetric .0324/.0224 source chasing")
	area.night_mode = false
	for speed in [100.0, 120.0, 121.0, -121.0]:
		body.position = Vector2(480, -224)
		body.velocity = Vector2(speed, 0)
		body._physics_process(1.0 / 60)
		var expected: float = 116.2 if speed == 121 else -116.2 if speed < 0 else speed
		check(is_equal_approx(body.velocity.x, expected), "Day Grrrol lost asymmetric positive >2px/frame drag branch")
	area.level_theme = Level.LevelTheme.UNDERWATER
	body.position = Vector2(480, -224)
	body.velocity = Vector2(72, 300)
	body._physics_process(1.0 / 60)
	check(is_equal_approx(body.velocity.x, 67.2) and is_equal_approx(body.velocity.y, 61.2), "Full-water Grrrol lost symmetric drag or cap-before-gravity")
	area.night_mode = true
	for theme in [Level.LevelTheme.SKY, Level.LevelTheme.AIRSHIP]:
		area.level_theme = theme
		body.position = Vector2(480, -224)
		body.velocity = Vector2.ZERO
		body.swimming = false
		body._wake_left = 2.0 / 60
		level.hud.player.position.x = 350
		body._physics_process(1.0 / 60)
		check(is_equal_approx(body.velocity.x, -1.344), "Night chasing must begin before the pending startup alarm")
		body._physics_process(1.0 / 60)
		check(body.velocity.x == -60 and is_equal_approx(body.velocity.y, 2.4), "Night sky/airship Grrrol must use full-water startup and gravity")
	area.level_theme = Level.LevelTheme.OVERWORLD
	level.hud.player.position.x = 550
	check(level.hud.player.freeze_in_ice(), "Could not create the actual frozen target replacement")
	body.position = Vector2(480, -224)
	body.velocity = Vector2.ZERO
	body._physics_process(1.0 / 60)
	check(is_equal_approx(body.velocity.x, -1.344), "Night Grrrol must treat a frozen replacement as missing obj_mario")
	level.queue_free()
	await ticks(2)


func check_legacy_separation() -> void:
	var level := await rolling_level()
	var old := rolling(level, LEGACY, Vector2(484, -176))
	var first := rolling(level, SMALL, Vector2(480, -176))
	old.velocity.x = -72
	first.velocity.x = 72
	old._wake_left = INF
	first._wake_left = INF
	await ticks(2)
	first._physics_process(1.0 / 60)
	check(first.velocity.x == -72, "New rolling source Other_12 must react to overlapping obj_grrrol")
	old._physics_process(1.0 / 60)
	check(old.velocity.x == -72, "Legacy Grrrol must not treat the separate new source class as obj_grrrol")
	old.queue_free()
	var second := rolling(level, GIANT, Vector2(484, -176))
	await ticks(2)
	first.position = Vector2(480, -176)
	first.velocity.x = 72
	first._physics_process(1.0 / 60)
	check(first.velocity.x == 72 and not second.is_queued_for_deletion(), "New and giant Grrrol acquired a source-absent mutual turn/defeat")
	level.queue_free()
	await ticks(2)


func check_water_and_liquid(data: GrrrolVariant) -> void:
	var level := await rolling_level()
	var area := level.current_sub_area
	area.level_theme = Level.LevelTheme.UNDERWATER
	var body := rolling(level, data)
	body._physics_process(1.0 / 60)
	body._physics_process(1.0 / 60)
	check(body.swimming and body.velocity.x == -60 and is_equal_approx(body.velocity.y, 2.4), "Grrrol startup did not use the preceding full-water sample")
	var liquid := add_liquid(level, Level.LevelTheme.CASTLE, -200)
	body._wake_left = INF
	body.position.y = liquid.position.y - 20 + data.source_to_feet.y
	check(body._in_water(), "Grrrol inherited any-liquid swimming sample must be inclusive")
	body.position.y -= 0.01
	check(not body._in_water(), "Grrrol started swimming above source y+8 threshold")
	body.position = Vector2(480, liquid.position.y - 3)
	body._liquid_contact()
	await ticks(2)
	check(body.lava_mode and effects(area, liquid.rules.lava_splash_sprite).size() == 1
			and live_nodes(area, SinkingEnemy).is_empty(), "Grrrol molten entry must latch one splash while retaining its body")
	body._liquid_contact()
	await ticks(1)
	check(effects(area, liquid.rules.lava_splash_sprite).size() == 1, "Grrrol replayed its latched lava splash")
	body.position.y = liquid.position.y - 30
	liquid.velocity = 12
	body._liquid_contact()
	check(data.source_position(body.position).y == liquid.position.y - 20, "Falling liquid did not apply source Grrrol y=liquid-20 at its own origin")
	liquid.velocity = 0
	body.position.y = liquid.position.y + 32 + data.source_to_feet.y + 0.01
	body._physics_process(1.0 / 60)
	check(body.is_queued_for_deletion() != data.legacy, "Only legacy obj_grrrol is exempt from inherited deep-molten culling")
	level.queue_free()
	await ticks(2)


func hold_rolling_corpse(area: SubArea) -> SwimmingEnemyDefeat:
	for entry in area._pending_spawns.values():
		if entry.node is SwimmingEnemyDefeat:
			var corpse: SwimmingEnemyDefeat = entry.node
			corpse.ready.connect(func(): corpse.set_physics_process(false), CONNECT_ONE_SHOT)
			return corpse
	return null


func check_defeat_art(data: GrrrolVariant) -> void:
	var level := await rolling_level()
	var body := rolling(level, data)
	body.angle = 90
	body.kill(-1)
	var corpse := hold_rolling_corpse(level.current_sub_area)
	await ticks(2)
	check(corpse != null and corpse.position == Vector2(480, -224 - data.source_to_feet.y)
			and corpse.velocity == Vector2(-60, -240) and corpse.rotation == 0 and not corpse.get_child(0).flip_h
			and corpse.get_child(0).frame == 2, "Grrrol corpse copied drawing angle/facing or lost original origin/style frame")
	if corpse != null:
		corpse._physics_process(1.0 / 60)
		check(is_equal_approx(corpse.rotation_degrees, -16), "Source Grrrol normal corpse did not spin with its impulse")
	level.queue_free()
	await ticks(2)


func check_hard_contacts(data: GrrrolVariant) -> void:
	var level := await rolling_level()
	var area := level.current_sub_area
	var player := level.hud.player
	var body := rolling(level, data, Vector2(480, -96))
	for kind in [&"fire", &"pow", &"crush"]:
		check(not body.hit_by_projectile(kind, 1), "Hardness99 Grrrol accepted an unsupported projectile/ground POW")
	player.state_machine.switch(PlayerSpinJumpingState)
	player.velocity.y = 60
	body._stomped(player)
	check(not body.is_queued_for_deletion() and player.velocity.y < 0 and player.score == 0, "Spin jump must recoil from Grrrol without defeat points")
	player.state_machine.switch(PlayerIdleState)
	var shell: KoopaShell = load("res://scenes/entities/koopa_shell.tscn").instantiate()
	shell.position = Vector2(430, -96)
	area.add(shell)
	player.direction = 1
	shell.launch(player, false)
	shell.velocity.x = 240
	await ticks(18)
	check(not is_instance_valid(shell) and is_instance_valid(body) and player.score == 0, "Moving shell defeated Grrrol, survived contact or awarded a combo")
	body.position = Vector2(480, -160)
	var monty: Monty = load("res://scenes/entities/monty.tscn").instantiate()
	monty.position = body.position
	area.add(monty)
	monty.set_physics_process(false)
	await ticks(3)
	check(not is_instance_valid(monty) and is_instance_valid(body), "Actual rolling overlap did not defeat an ordinary enemy")
	level.queue_free()
	await ticks(2)
	level = await rolling_level()
	player = level.hud.player
	player.collision_layer = 4
	player.equip_shell_helmet(preload("res://resources/content/smw_helmet_spiny_rules.tres"))
	await ticks(2)
	var hat: PlayerHelmet = player.get_node("BuzzyHelmet")
	body = rolling(level, data, Vector2(player.position.x + 3, -180))
	body.position.y += hat._head_bounds().position.y + 2 - Utility.get_bounding_box(body).end.y
	body.velocity.y = 60
	await ticks(3)
	var dead := live_nodes(level.current_sub_area, SwimmingEnemyDefeat)
	check(not is_instance_valid(body) and dead.size() == 1 and player.score == 200 and player.has_helmet()
			and dead[0].velocity.x == -60, "Actual Spiny helmet did not use the stationary source partner's left-edge impulse")
	level.queue_free()
	await ticks(2)


func check_delayed_break(retry: bool) -> void:
	var level := await rolling_level()
	var area := level.current_sub_area
	var block: QuestionBlock = load("res://scenes/tiles/question_block.tscn").instantiate()
	block.position = Vector2(528, -128)
	area.add(block)
	await ticks(2)
	var body := rolling(level, SMALL, Vector2(508, -112), false, 3)
	body._wake_left = INF
	body.velocity.x = 72
	body._physics_process(1.0 / 60)
	check(block.has_node("SourceBreakAlarm") and not block.is_queued_for_deletion(), "Grrrol must arm the block's one-tick break alarm before impact")
	body.kill(1)
	if retry:
		level.reload()
	await ticks(2)
	check(not is_instance_valid(block) and (live_nodes(area, BlockShard).is_empty() if retry else live_nodes(area, BlockShard).size() == 4),
			"Block-owned break must survive roller defeat and be cancelled by area retry (retry=%s block=%s shards=%s)" % [retry, is_instance_valid(block), live_nodes(area, BlockShard).size()])
	level.queue_free()
	await ticks(2)


func check_mario_and_block(data: GrrrolVariant) -> void:
	var level := await rolling_level()
	var area := level.current_sub_area
	var player := level.hud.player
	var body := rolling(level, data, Vector2(480, -96))
	player.set_powerup(SmallPowerup.new(), false)
	player.collision_layer = 4
	player.position = Vector2(480, -224)
	player.previous_position = player.position
	player.velocity = Vector2(0, 120)
	player.state_machine.switch(PlayerFallingState)
	player.set_physics_process(true)
	await ticks(34)
	check(player.is_dead() and is_instance_valid(body), "Actual normal Mario stomp must be hurt by Grrrol")
	level.queue_free()
	await ticks(2)
	level = await rolling_level()
	player = level.hud.player
	player.collision_layer = 4
	player.equip_buzzy_helmet()
	await ticks(2)
	var hat: PlayerHelmet = player.get_node("BuzzyHelmet")
	body = rolling(level, data, Vector2(player.position.x + 3, -180))
	body.position.y += hat._head_bounds().position.y + 2 - Utility.get_bounding_box(body).end.y
	body.velocity.y = 60
	await ticks(3)
	check(is_instance_valid(body) and body.velocity.y < 0 and player.has_helmet() and player.score == 0,
			"Actual Buzzy helmet must deflect Grrrol without defeating it or consuming armor")
	level.queue_free()
	await ticks(2)
	level = await rolling_level()
	area = level.current_sub_area
	player = level.hud.player
	var block: QuestionBlock = load("res://scenes/tiles/question_block.tscn").instantiate()
	block.position = Vector2(480, -176)
	area.add(block)
	body = rolling(level, data, Vector2(488, Utility.get_bounding_box(block).position.y))
	await ticks(2)
	var component: BlockComponent = block.get_node("BlockComponent")
	component.sprout.empty = true
	component.activate(player)
	var corpse := hold_rolling_corpse(area)
	check(corpse != null and corpse.velocity.x == -60 and player.score == 200,
			"Actual rising block must defeat even hardness99 Grrrol with the source block-partner impulse")
	level.queue_free()
	await ticks(2)


func check_liquid_themes_and_cull() -> void:
	for theme in [Level.LevelTheme.FOREST, Level.LevelTheme.MOUNTAIN, Level.LevelTheme.BEACH]:
		var level := await rolling_level()
		var area := level.current_sub_area
		var liquid := add_liquid(level, theme, -200, theme != Level.LevelTheme.BEACH)
		var body := rolling(level, SMALL, Vector2(480, -203))
		body._liquid_contact()
		await ticks(1)
		check(body.lava_mode == (theme == Level.LevelTheme.FOREST)
				and effects(area, liquid.rules.poison_splash_sprite).size() == (1 if theme == Level.LevelTheme.FOREST else 0),
				"Only forest-night poison should latch; mountain-night/beach must not invent Grrrol molten entry")
		level.queue_free()
		await ticks(2)
	var level := await rolling_level()
	for data: GrrrolVariant in PROFILES:
		var body := rolling(level, data, Vector2(800, 16 - data.runtime_mask.position.y))
		body._wake_left = INF
		body.velocity.y = 120
		body._physics_process(1.0 / 60)
		check(not body.is_queued_for_deletion(), "Grrrol culled at equality or after crossing its source room boundary")
		var after := body.position
		body._physics_process(1.0 / 60)
		check(body.is_queued_for_deletion() and body.position == after, "Grrrol must cull before movement on the next source Step")
		await ticks(1)
	level.queue_free()
	await ticks(2)


func check_rolling_death(night: bool) -> void:
	var level := await rolling_level()
	level.current_sub_area.night_mode = night
	var body := rolling(level)
	var at := body.position
	level.hud.player.kill()
	for frame in 2:
		body._physics_process(1.0 / 60)
	check(body.position == at and body.velocity == Vector2.ZERO and body._wake_left == INF,
			"WorldDeath must stop Grrrol motion without cancelling its pending startup alarm")
	var angle := body.angle
	for frame in 5:
		body._physics_process(1.0 / 60)
	check(is_equal_approx(body.angle - angle, 17.5 if night else 0) and body.position == at,
			"Grrrol death must retain night-chase drawing events while stopping automatic movement")
	level.queue_free()
	await ticks(2)


func check_rolling_activity() -> void:
	var level := await rolling_level()
	level.current_sub_area.actor_activity.enabled = true
	Utility.camera_position = Vector2(208, -216)
	var body := rolling(level, GIANT, Vector2(1100, -224), true)
	await ticks(4)
	var at := body.position
	var angle := body.angle
	await ticks(8)
	check(not body.can_process() and not body.visible and body.position == at and body.angle == angle,
			"Native actor suspension failed to retain rolling motion/drawing state")
	Utility.camera_position = Vector2(850, -216)
	await ticks(4)
	check(body.can_process() and body.visible and body.position != at, "Grrrol did not resume in the native activation strip")
	level.queue_free()
	await ticks(2)


func save_rolling_capture(level: Level, name: String) -> void:
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_" + name + ".png") == OK,
			"Could not save real Grrrol capture")
	print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	level.queue_free()
	await ticks(2)
	get_tree().quit(0 if failures.is_empty() else 1)


func capture_rolling() -> void:
	var level := await rolling_level()
	Utility.camera_position = Vector2(208, -216)
	await ticks(40)
	for index in PROFILES.size():
		rolling(level, PROFILES[index], Vector2([360, 450, 550][index], -96), true)
	await ticks(50)
	check(live_nodes(level.current_sub_area, Grrrol).size() == 3, "Grrrol capture lost one of its actual source forms")
	await save_rolling_capture(level, "grrrol")


func capture_rolling_editor() -> void:
	var level := await LevelActionBtn.prepare_level(FIXTURE, Level.Status.EDITING)
	add_child(level)
	await ticks(35)
	var legacy := ThwompPart.create()
	legacy.variant = LEGACY
	legacy.attack_direction = 2
	legacy.position = Vector2(64, -144)
	level.current_sub_area.add_part(legacy)
	legacy.load()
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_enemies.tres")
	ring.page_index = 4
	ring.choose(3)
	var small := level.editor.place(Vector2i(10, -8)) as GrrrolPart
	var large := level.editor.place(Vector2i(16, -10)) as GrrrolPart
	level.editor.set_part_modifier(large, &"large", true)
	small.held = true
	small.set_process(false)
	await ticks(45)
	check(is_instance_valid(small._window), "Editor Grrrol capture opened no source size/flag window")
	await save_rolling_capture(level, "editor_grrrol")
