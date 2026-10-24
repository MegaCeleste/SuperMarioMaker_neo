# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/bro_projectile_test.gd"
## End-step source activation: preserve alarms/animation, remove physical
## contacts, use full bboxes, retain independent shots and dispose on retry.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for kind in [&"monty", &"rocky", &"bro", &"held"]:
		await check_suspend_resume(kind)
	await check_other_families()
	await check_region_and_cadence()
	await check_modes_and_disable()
	await check_independent_projectiles()
	await check_retry()
	await finish("ACTOR_ACTIVITY_RESULT")


func fixed_camera(level: Level, x := 0.0) -> void:
	level.hud.player.set_physics_process(false)
	Utility.camera_position = Vector2(x, -216)


func actor(level: Level, kind: StringName, at: Vector2) -> Enemy:
	var body: Enemy = load("res://scenes/entities/%s.tscn" % (
			"hammer_bro" if kind == &"bro" else String(kind))).instantiate()
	body.position = at
	level.current_sub_area.add(body)
	return body


func clock(body: Entity) -> float:
	if body is Monty:
		return body._charge_left
	if body is Rocky:
		return body._timer
	if body is HammerBro:
		return body._throw_timer
	return body._age


func point_hits(body: CollisionObject2D) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = Utility.get_bounding_box(body).get_center()
	query.collision_mask = 2
	query.collide_with_areas = false
	return not body.get_world_2d().direct_space_state.intersect_point(query, 4).is_empty()


func check_suspend_resume(kind: StringName) -> void:
	var level := await make_level()
	fixed_camera(level)
	var body: Entity
	if kind == &"held":
		body = load("res://scenes/entities/stomped_galoomba.tscn").instantiate()
		body.position = Vector2(900, -160)
		level.current_sub_area.add(body)
	else:
		body = actor(level, kind, Vector2(400, -96) if kind == &"rocky" else Vector2(900, -160))
	if body is Rocky:
		for frame in 90:
			await ticks(1)
			if body.phase == Rocky.Phase.WAIT:
				break
		check(body.phase == Rocky.Phase.WAIT, "Activity test Rocky failed to enter its real wait alarm")
		var platform := StaticBody2D.new()
		platform.position = Vector2(900, -88)
		var collider := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(64, 16)
		collider.shape = rectangle
		platform.add_child(collider)
		level.current_sub_area.add(platform)
		body.position.x = 900
	await ticks(4)
	var at := body.position
	var left := clock(body)
	var sprite: AnimatedSprite2D = body.get_node("Graphics/Sprite")
	var frame := sprite.frame
	var progress := sprite.frame_progress
	var immune: float = body.get_node("PickupComponent").pickup_immunity_left if kind == &"held" else 0.0
	check(not body.can_process() and not body.is_visible_in_tree() and not point_hits(body),
			"Out-of-strip %s retained processing, drawing or physical contacts" % kind)
	await ticks(24)
	check(body.position == at and clock(body) == left and sprite.frame == frame and sprite.frame_progress == progress,
			"Suspended %s advanced motion, its source alarm or sprite animation" % kind)
	if kind == &"held":
		check(body.get_node("PickupComponent").pickup_immunity_left == immune,
				"A suspended carried-family object advanced its inherited immunity alarm")
	fixed_camera(level, 720)
	await ticks(4)
	check(body.can_process() and body.is_visible_in_tree() and point_hits(body),
			"Returning to the source strip did not restore %s and its real collider" % kind)
	check(clock(body) != left, "Reactivated %s failed to resume its saved alarm" % kind)
	if not body is Rocky:
		check(body.position != at, "Reactivated %s failed to resume motion" % kind)
	level.queue_free()
	await ticks(2)


func check_other_families() -> void:
	for scene in ["galoomba", "green_koopa", "beach_koopa", "koopa_shell", "buzzy_beetle", "spiny", "blooper", "cheep_cheep", "piranha_plant", "muncher", "thwomp", "mushroom", "grrrol"]:
		var level := await make_level()
		fixed_camera(level)
		var body: CharacterBodyExt = load("res://scenes/entities/%s.tscn" % scene).instantiate()
		body.position = Vector2(900, -160)
		if scene == "mushroom":
			# RiseSprout uses the existing sibling factory rather than SubArea.add.
			level.current_sub_area.get_foreground().add_child(body)
		else:
			level.current_sub_area.add(body)
		body.set_physics_process(false)
		await ticks(4)
		check(not body.can_process() and not body.is_visible_in_tree() and not point_hits(body),
				"Ported source descendant %s did not suspend through its actual spawn path" % scene)
		level.queue_free()
		await ticks(2)


func check_region_and_cadence() -> void:
	var level := await make_level()
	fixed_camera(level)
	var activity := level.current_sub_area.actor_activity
	var view := Utility.get_visible_rect()
	check(activity.region() == Rect2(Vector2(-128, -528), Vector2(view.size.x + 256, 624)),
			"Source activation lost its fixed room-height strip or horizontal margins")
	var body := actor(level, &"monty", Vector2(400, -400))
	body.set_physics_process(false)
	await ticks(4)
	check(body.can_process(), "Activation incorrectly used camera y instead of the source room-height strip")
	var bounds := Utility.get_bounding_box(body)
	body.position += Vector2(activity.region().end.x - 1 - bounds.position.x,
			activity.region().position.y + 1 - bounds.end.y)
	await ticks(3)
	# Only the ellipse bbox's transparent corner crosses the rectangle.
	check(body.can_process(), "Source activation used the precise silhouette instead of its bounding box")
	activity._clock = 1
	body.position.x += 3
	await ticks(1)
	check(body.can_process(), "The source manager rescanned before the second end-step")
	await ticks(1)
	check(not body.can_process(), "The two-tick manager failed to suspend an actor beyond the strip")
	level.queue_free()
	await ticks(2)


func check_modes_and_disable() -> void:
	var level := await make_level()
	fixed_camera(level)
	var activity := level.current_sub_area.actor_activity
	var body := actor(level, &"bro", Vector2(900, -160))
	body.process_mode = Node.PROCESS_MODE_PAUSABLE
	body.hide()
	await ticks(4)
	check(not body.can_process(), "Invisible actors incorrectly skipped source suspension")
	activity.enabled = false
	await ticks(2)
	check(body.can_process() and body.process_mode == Node.PROCESS_MODE_PAUSABLE and not body.visible,
			"Disabling the source optimisation lost the actor's prior mode or visibility")
	activity.enabled = true
	await ticks(4)
	check(not body.can_process(), "Re-enabling source activation failed to suspend the distant actor")
	level.queue_free()
	await ticks(2)


func check_independent_projectiles() -> void:
	var level := await make_level()
	fixed_camera(level)
	var hammer := shot(level, BroProjectile.Kind.HAMMER, Vector2(200, -400))
	var wrench := Wrench.new()
	wrench.position = Vector2(240, -400)
	level.current_sub_area.add(wrench)
	var at := hammer.position
	await ticks(24)
	check(is_instance_valid(hammer) and hammer.can_process() and hammer.position != at \
			and is_instance_valid(wrench) and wrench.can_process() and wrench._age > 0.3,
			"Independent hammer/wrench motion was incorrectly suspended above the camera")
	for kind in [BroProjectile.Kind.FIRE, BroProjectile.Kind.ICE]:
		var body := shot(level, kind, Vector2(900, -160))
		body.set_physics_process(false)
		await ticks(4)
		check(not body.can_process() and not point_hits(body),
				"A Bro fire/ice shot omitted its inherited physical-parent activation policy")
	var boom := shot(level, BroProjectile.Kind.BOOMERANG, Vector2(200, -400))
	await ticks(2)
	check(not is_instance_valid(boom), "Independent boomerang failed its ordinary outside_view removal")
	level.queue_free()
	await ticks(2)


func check_retry() -> void:
	var level := await make_level()
	fixed_camera(level)
	var body := actor(level, &"bro", Vector2(900, -160))
	await ticks(3)
	var activity := level.current_sub_area.actor_activity
	check(not body.can_process(), "Retry fixture did not contain a suspended source actor")
	activity._apply.call_deferred(body.get_instance_id(), true, level.current_sub_area._runtime_revision)
	level.reload()
	await ticks(4)
	check(not is_instance_valid(body) and activity._actors.is_empty(),
			"Retry retained a suspended actor or accepted its stale deferred activation")
	level.queue_free()
	await ticks(2)
