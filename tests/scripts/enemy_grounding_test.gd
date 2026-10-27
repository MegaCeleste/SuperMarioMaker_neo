# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/hammer_bro_test.gd"
## Actual opaque pixels against actual solids, independent of sprite origins.

var grounding_trace: Array[Dictionary] = []
var capture_grounding := false
var grounding_sheet: Image
var sample_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture_grounding = "--capture-enemy-grounding" in OS.get_cmdline_user_args()
	if capture_grounding:
		grounding_sheet = Image.create(1440, 1792, false, Image.FORMAT_RGBA8)
	var level := await make_level()
	level.current_sub_area.actor_activity.enabled = false
	level.hud.player.process_mode = Node.PROCESS_MODE_DISABLED
	Utility.camera_position = Vector2(400, -216)
	await ticks(40)
	for pair in [
		["galoomba", "smw_goomba_normal"], ["galoomba", "smw_goomba_goombud"],
		["green_koopa", "smw_koopa_green"], ["green_koopa", "smw_koopa_red"],
		["buzzy_beetle", "smw_buzzy_beetle"], ["spiny", "smw_spiny"],
		["stomped_galoomba", "smw_goomba_normal"], ["stomped_galoomba", "smw_goomba_goombud"],
		["beach_koopa", "smw_koopa_green"], ["beach_koopa", "smw_koopa_red"],
		["monty", "smw_monty"], ["hammer_bro", "smw_hammerbro_hammer"],
		["hammer_bro", "smw_hammerbro_fire"], ["hammer_bro", "smw_hammerbro_ice"],
		["hammer_bro", "smw_hammerbro_boomerang"], ["hammer_bro", "smw_hammerbro_sledge"],
		["muncher", "smw_muncher_small"], ["muncher", "smw_muncher_giant"],
		["thwomp", "smw_thwomp_small"], ["thwomp", "smw_thwomp_giant"],
		["grrrol", "smw_grrrol_legacy"], ["grrrol", "smw_grrrol_small"], ["grrrol", "smw_grrrol_giant"],
		["chain_chomp", "smw_chomp_small"], ["chain_chomp", "smw_chomp_giant"],
		["piranha_plant", "smw_piranha_jump"], ["piranha_plant", "smw_piranha_fire"]]:
		await check_grounded(level, pair[0], pair[1])
	for resource_name in ["smw_koopa_green", "smw_koopa_red", "smw_buzzy_beetle", "smw_buzzy_empty", "smw_spiny", "smw_spiny_empty"]:
		for inverted in [false, true]:
			await check_grounded(level, "koopa_shell", resource_name, inverted)
	for pair in [["buzzy_beetle", "smw_buzzy_beetle"], ["spiny", "smw_spiny"]]:
		await check_grounded(level, pair[0], pair[1], false, true)
	var log := FileAccess.open("res://.godot/porting-tests/enemy_grounding.json", FileAccess.WRITE)
	log.store_string(JSON.stringify(grounding_trace, "  "))
	log.close()
	if capture_grounding:
		check(grounding_sheet.save_png("res://.godot/porting-tests/slice_enemy_grounding.png") == OK, "Could not save enemy grounding pixels")
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("ENEMY_GROUNDING_RESULT", level)


func primary_sprite(body: Node) -> AnimatedSprite2D:
	var sprite := body.get_node_or_null("Graphics/Sprite") as AnimatedSprite2D
	if sprite != null:
		return sprite
	for child in body.get_children():
		if child is AnimatedSprite2D:
			return child
	return null


func check_grounded(level: Level, scene_name: String, resource_name: String, inverted := false, ceiling := false) -> void:
	var body: CharacterBody2D = load("res://scenes/level/entities/%s.tscn" % scene_name).instantiate()
	body.set("variant", load("res://resources/content/%s.tres" % resource_name))
	if body is KoopaShell:
		body.inverted = inverted
	if ceiling:
		body.set("ceiling", true)
	body.position = Vector2(480, -140 if ceiling else -130)
	# Keep real colliders while disabling AI/timers, so the probe never invents
	# a resting pose by moving a nonphysical or deactivated sprite onto a line.
	body.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	level.current_sub_area.add(body)
	body.process_mode = Node.PROCESS_MODE_DISABLED
	var roof: StaticBody2D
	if ceiling:
		roof = StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(96, 16)
		shape.shape = rectangle
		roof.add_child(shape)
		roof.position = Vector2(480, -168)
		# Show the real native ground texture on this physical ceiling in the
		# diagnostic sheet, rather than making its crawlers appear unsupported.
		if capture_grounding:
			for tile in level.current_sub_area.get_foreground().get_children():
				if not tile is GroundTile:
					continue
				var prototype := Utility.find_child_by_class(tile, Sprite2D) as Sprite2D
				if prototype == null:
					continue
				for cell in 6:
					var art := Sprite2D.new()
					art.texture = prototype.texture
					art.centered = false
					art.position = Vector2(-48 + cell * 16, -8)
					roof.add_child(art)
				break
		level.current_sub_area.add(roof)
	await ticks(2)
	for tick in 14:
		body.velocity = Vector2(0, -240 if ceiling else 240)
		body.move_and_slide()
		await ticks(1)
	if body.has_method("_update_visuals"):
		body.call("_update_visuals")
	var sprite := primary_sprite(body)
	var description := "%s/%s inverted=%s ceiling=%s" % [scene_name, resource_name, inverted, ceiling]
	check(sprite != null, "Missing primary art: " + description)
	check(body.is_on_ceiling() if ceiling else body.is_on_floor(), "Body did not settle on the actual solid: " + description)
	var ray := PhysicsRayQueryParameters2D.create(body.global_position + Vector2(0, -12 if ceiling else -4),
			body.global_position + Vector2(0, -20 if ceiling else 4), 1, [body.get_rid()])
	var floor_hit := body.get_world_2d().direct_space_state.intersect_ray(ray)
	check(not floor_hit.is_empty(), "No physical surface under the opaque-pixel probe: " + description)
	if sprite != null and not floor_hit.is_empty():
		sprite.pause()
		var floor_y: float = floor_hit.position.y
		var contact := INF if ceiling else -INF
		var furthest := -INF if ceiling else INF
		var planted_frame := 0
		var indices: Array = [2] if body is Grrrol else range(sprite.sprite_frames.get_frame_count(sprite.animation))
		for index: int in indices:
			sprite.frame = index
			var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, index)
			var used := texture.get_image().get_used_rect()
			var low := texture.get_height() - used.position.y if sprite.flip_v else used.end.y
			var high := texture.get_height() - used.end.y if sprite.flip_v else used.position.y
			var edge := sprite.to_global(sprite.offset + Vector2(0, high if ceiling else low)).y
			if (edge < contact if ceiling else edge > contact):
				contact = edge
				planted_frame = index
			furthest = maxf(furthest, edge) if ceiling else minf(furthest, edge)
		var overlap := floor_y - contact if ceiling else contact - floor_y
		grounding_trace.append({"case": description, "contact": contact, "surface": floor_y,
			"overlap": overlap, "pose_lift": absf(contact - furthest), "frame": planted_frame,
			"feet": str(body.position), "sprite": str(sprite.position)})
		print("GROUND_TRACE ", description, " overlap=", overlap, " lift=", absf(contact - furthest))
		check(absf(overlap - 1) < 0.11, "Visible rest pose must overlap its physical surface by 1px: " + description + " actual=" + str(overlap))
		if capture_grounding:
			sprite.frame = planted_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var pixels := get_viewport().get_texture().get_image()
			var at := Vector2i(body.get_global_transform_with_canvas().origin.round())
			var crop := Rect2i(at - Vector2i(120, 120 if ceiling else 220), Vector2i(240, 256))
			grounding_sheet.blit_rect(pixels, crop, Vector2i((sample_index % 6) * 240, (sample_index / 6) * 256))
			sample_index += 1
	body.queue_free()
	if roof != null:
		roof.queue_free()
	await ticks(2)
