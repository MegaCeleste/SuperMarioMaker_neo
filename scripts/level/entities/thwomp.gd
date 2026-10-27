# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Thwomp
extends Enemy
## Native SMW hazard phases; source coordinates are converted only at the edges.

enum Phase { WAITING, ATTACKING, IMPACT, RETURNING }
@export var variant: ThwompVariant = preload("res://resources/content/smw_thwomp_small.tres")
@export_enum("Down:1", "Left:2", "Right:3") var attack_direction := 1
@export var wings := false
@export var parachute := false
var phase := Phase.WAITING
var swimming := false
var _home: Vector2
var _wait_left := 0.0
var _impact_ticks := 0
var _sprite: AnimatedSprite2D
var _art: StringName
var _before: Rect2
var _passed_blocks: Array[int] = []
var _mask_art: StringName
var _mask_shapes: Array[ConvexPolygonShape2D] = []
var _mask_cache: Dictionary = {}
var _mask_pending := false
var _splash_contact := false
var _splash_alarm := 0.0


func _ready() -> void:
	hardness = 99
	fireproof = true
	stomp_behavior = Stompability.RECOIL
	_home = global_position
	hitbox = Area2D.new()
	hitbox.name = "PlayerHitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 4
	add_child(hitbox)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	add_child(_sprite)
	_update_visuals()
	super()


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	_before = Utility.get_bounding_box(self)
	_tick_splashes(delta)
	swimming = _in_water()
	var attack_axis := Vector2.DOWN if attack_direction == 1 else Vector2.LEFT if attack_direction == 2 else Vector2.RIGHT
	var finished_return := false
	if phase == Phase.IMPACT:
		_wait_left -= delta
		if _wait_left <= 0.00001:
			_restore_block_collisions()
			phase = Phase.RETURNING
			velocity = -attack_axis * variant.return_speed
	elif phase == Phase.RETURNING:
		var remaining := (_home - global_position).dot(-attack_axis)
		if _return_obstructed(attack_axis):
			_finish_return(true)
			finished_return = true
		elif remaining < variant.return_snap_distance:
			global_position += -attack_axis * remaining
			_finish_return(false)
			finished_return = true
	if attack_direction != 1 or phase in [Phase.WAITING, Phase.ATTACKING]:
		_vertical_motion(delta)
	var triggered := false
	if phase == Phase.WAITING and not finished_return and _player_in_trigger():
		phase = Phase.ATTACKING
		triggered = true
		if attack_direction == 1 and is_on_floor():
			velocity.y = -90
	if phase == Phase.ATTACKING and attack_direction != 1 and not triggered:
		var cap := variant.water_side_speed if swimming else variant.side_speed
		velocity.x = move_toward(velocity.x, attack_axis.x * cap, variant.side_acceleration * delta)
	var incoming := velocity
	if variant.giant and phase == Phase.ATTACKING and not triggered:
		_pass_breakable_blocks(attack_axis, delta)
	super(delta) # One native move_and_slide, never a second body movement.
	if phase == Phase.ATTACKING and not triggered:
		var stopped := is_on_floor() and incoming.y > 0 if attack_direction == 1 else is_on_wall()
		if stopped:
			if attack_direction == 1:
				for index in get_slide_collision_count():
					var hit := get_slide_collision(index)
					if hit.get_collider() is CloudPlatform and hit.get_normal().y < -0.5:
						hit.get_collider().crush()
			_impact()
	elif phase == Phase.RETURNING:
		var blocked := is_on_ceiling() if attack_direction == 1 else is_on_wall()
		if blocked:
			_finish_return(true)
	if _impact_ticks > 0:
		_impact_ticks -= 1
		_activate_blocks(attack_axis)
	_crush_enemies(incoming.y)
	for body in hitbox.get_overlapping_bodies():
		_body_handling(true, body)
	_update_visuals()
	var liquid := sub_area.liquid
	if is_instance_valid(liquid) and not liquid.is_water() \
			and variant.source_position(global_position).y > liquid.global_position.y + 32:
		queue_free()


func _finish_return(blocked: bool) -> void:
	if attack_direction == 1:
		if blocked:
			_home.y = global_position.y
		velocity.y = 0
	else:
		if blocked:
			_home.x = global_position.x
		velocity.x = 0
	phase = Phase.WAITING
	_impact_ticks = 0


func _return_obstructed(axis: Vector2) -> bool:
	var bounds := Utility.get_bounding_box(self)
	var query := PhysicsShapeQueryParameters2D.new()
	var strip := RectangleShape2D.new()
	strip.size = Vector2(bounds.size.x, 2) if axis.y > 0 else Vector2(1, bounds.size.y)
	query.shape = strip
	query.transform.origin = Vector2(bounds.get_center().x, bounds.position.y - 1) if axis.y > 0 \
			else Vector2(bounds.end.x + 0.5 if axis.x < 0 else bounds.position.x - 0.5, bounds.get_center().y)
	query.collision_mask = 1
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var body: CollisionObject2D = hit.collider
		if body is AnimatableBody2D:
			return true
		for owner_id in body.get_shape_owners():
			if body.is_shape_owner_disabled(owner_id):
				continue
			var owner_node := body.shape_owner_get_owner(owner_id)
			if not owner_node is CollisionShape2D or not owner_node.one_way_collision:
				return true
	return false


func _tick_splashes(delta: float) -> void:
	var liquid := sub_area.liquid
	# Source alarms run before Step_0 samples this tick's contact rectangle.
	if _splash_alarm > 0:
		_splash_alarm = maxf(0, _splash_alarm - delta)
		if _splash_alarm <= 0.00001 and _splash_contact and is_instance_valid(liquid):
			if liquid.velocity != 0:
				if sub_area.level_theme != Level.LevelTheme.FOREST:
					EnemyEffect.sound_if_idle(sub_area, SoundLibrary.path("snd_podoboo"))
				for offset in [-16, 16]:
					EnemyEffect.play_once(sub_area, variant.splash_sprite,
							Vector2(variant.source_position(global_position).x + offset, liquid.global_position.y - 16), variant.splash_fps, false)
				_splash_alarm = variant.splash_interval
			else:
				_splash_alarm = variant.splash_first_tick
	var bounds := Utility.get_bounding_box(self)
	var probe := Rect2(bounds.position + Vector2(0, 2), bounds.size - Vector2(0, 3))
	var touching := is_instance_valid(liquid) and probe.intersects(liquid.source_contact_bounds())
	if touching and not _splash_contact:
		_splash_alarm = variant.splash_first_tick
	_splash_contact = touching


func _vertical_motion(delta: float) -> void:
	var hold_home := attack_direction != 1 or phase == Phase.WAITING
	if hold_home and global_position.y >= _home.y and velocity.y >= 0:
		global_position.y = _home.y
		velocity.y = 0
		return
	if is_on_floor():
		return
	var gravity_value := variant.parachute_gravity if parachute else variant.water_gravity if swimming else variant.gravity
	var cap := variant.parachute_fall_speed if parachute else variant.water_fall_speed if swimming else variant.fall_speed
	velocity.y = minf(velocity.y, cap) + gravity_value * delta


func _in_water() -> bool:
	if sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (sub_area.night_mode and sub_area.level_theme in [Level.LevelTheme.SKY, Level.LevelTheme.AIRSHIP]):
		return true
	var liquid := sub_area.liquid
	return is_instance_valid(liquid) and liquid.is_water() \
			and variant.source_position(global_position).y > liquid.global_position.y + 16


func _player_in_trigger() -> bool:
	var player := level.hud.player
	if not is_instance_valid(player) or player.is_dead() or player.is_frozen() or level.status != Level.Status.PLAYING:
		return false
	var point := player.global_position - Vector2(0, 32)
	var bounds := Utility.get_bounding_box(self)
	if attack_direction == 1:
		return point.x > bounds.position.x - variant.vertical_trigger_margin \
				and point.x < bounds.end.x - 1 + variant.vertical_trigger_margin \
				and variant.source_position(global_position).y < point.y + variant.vertical_trigger_offset
	var in_height := point.y > bounds.position.y - variant.side_trigger_top \
			and point.y < bounds.end.y - 1 - variant.side_trigger_bottom
	if attack_direction == 2:
		return in_height and point.x < bounds.position.x + variant.side_trigger_inset \
				and point.x > bounds.position.x - variant.side_trigger_distance
	return in_height and point.x > bounds.end.x - 1 - variant.side_trigger_inset \
			and point.x < bounds.end.x - 1 + variant.side_trigger_distance


func _impact() -> void:
	phase = Phase.IMPACT
	_wait_left = variant.impact_wait
	_impact_ticks = 4
	velocity.x = 0
	if attack_direction == 1:
		velocity.y = 0
	EnemyEffect.sound_once(sub_area, SoundLibrary.path(variant.impact_sound))
	level.shake_camera(1)
	var bounds := Utility.get_bounding_box(self)
	for x in [bounds.position.x - 8, bounds.end.x - 9]:
		EnemyEffect.play_once(sub_area, &"spr_smoke", Vector2(x, bounds.end.y - 9), 18)


func _activate_blocks(axis: Vector2) -> void:
	var bounds := Utility.get_bounding_box(self)
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(bounds.size.x - 1, 4) if axis.y > 0 else Vector2(4, bounds.size.y - 4)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = rectangle
	query.transform.origin = bounds.get_center() + axis * (bounds.size / 2 + Vector2.ONE)
	query.collision_mask = 1
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var block: BlockComponent = Utility.find_child_by_class(hit.collider, BlockComponent)
		if block != null:
			if hit.collider is TurnBlockTile:
				_break_block(hit.collider, false)
			else:
				block.activate(self, Vector2.DOWN if axis.y > 0 else Vector2.UP)


## Giant source attacks exclude block parents from their stop conditions.
## Its left-wall handler breaks them; down/right handlers activate and pass.
func _pass_breakable_blocks(axis: Vector2, delta: float) -> void:
	var bounds := Utility.get_bounding_box(self)
	var shape := RectangleShape2D.new()
	shape.size = bounds.size - Vector2(1, 1)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform.origin = bounds.get_center() + axis * (absf(velocity.dot(axis)) * delta + 2)
	query.collision_mask = 1
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var body := hit.collider as PhysicsBody2D
		if body == null or body.is_queued_for_deletion():
			continue
		if body is HardBlock:
			body.break_from_impact()
			if not _passed_blocks.has(body.get_instance_id()):
				_passed_blocks.append(body.get_instance_id())
				add_collision_exception_with(body)
			continue
		var block: BlockComponent = Utility.find_child_by_class(body, BlockComponent)
		if block == null:
			continue
		if axis.x < 0 or body is TurnBlockTile:
			_break_block(body, axis.x < 0)
		else:
			block.activate(self, Vector2.DOWN if axis.y > 0 else Vector2.UP)
		if not _passed_blocks.has(body.get_instance_id()):
			_passed_blocks.append(body.get_instance_id())
			add_collision_exception_with(body)


func _restore_block_collisions() -> void:
	for id in _passed_blocks:
		if is_instance_id_valid(id):
			remove_collision_exception_with(instance_from_id(id))
	_passed_blocks.clear()


func _break_block(body: PhysicsBody2D, stronger: bool) -> void:
	BlockBreakRequest.break_now(sub_area, body, variant.break_sprite, variant.empty_break_sprite, stronger)


func _crush_enemies(incoming_y: float) -> void:
	if incoming_y <= 0:
		return
	var bounds := Utility.get_bounding_box(self)
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(bounds.size.x, maxf(2, bounds.end.y - _before.end.y + 2))
	query.shape = shape
	query.transform.origin = Vector2(bounds.get_center().x, (_before.end.y + bounds.end.y) / 2)
	query.collision_mask = 2
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var enemy := hit.collider as Enemy
		if enemy != null and enemy.hardness < 99 and not enemy.is_queued_for_deletion() \
				and _before.end.y < Utility.get_bounding_box(enemy).position.y + 1:
			enemy.hit_by_actor(&"crush", self)


func _body_handling(entering: bool, body: Node2D) -> void:
	if not entering or is_queued_for_deletion() or not body is Player or body.is_dead() or body.is_frozen():
		return
	if body.has_star():
		body.star_hit(self)
		return
	# The helmet handlers see the swept bottom edge so a 240px/s fall cannot
	# cross the source 5px head window between two reported Area overlaps.
	var previous_bottom := _before.end.y if _before.size.y > 0 else INF
	if body.helmet_deflects(self, previous_bottom):
		return
	if body.helmet_shields(self, previous_bottom):
		return
	var previous := Utility.get_bounding_box(body)
	previous.position += body.previous_position - body.global_position
	if previous.end.y < Utility.get_bounding_box(self).position.y - velocity.y / 60 + 5:
		if body.velocity.y >= 0:
			stomped.emit(body)
	else:
		body.damage()


func _update_visuals() -> void:
	var art := variant.body_sprite if attack_direction == 1 else variant.horizontal_sprite
	_sync_masks(variant.mask_sprite if not variant.mask_sprite.is_empty() else art)
	if _art != art:
		_art = art
		SpriteLibrary.configure_sprite(_sprite, art, &"body", 0, -variant.source_to_feet)
		_sprite.pause()
	_sprite.position.y = SpriteLibrary.contact_draw_y(variant.body_sprite)
	_sprite.position.x = roundf(global_position.x) - global_position.x
	_sprite.flip_h = attack_direction == 3 and phase != Phase.RETURNING
	if phase == Phase.ATTACKING or phase == Phase.IMPACT:
		_sprite.frame = 2
	else:
		_sprite.frame = 0
		var player := level.hud.player
		if phase == Phase.WAITING and is_instance_valid(player):
			var point := player.global_position - Vector2(0, 32)
			var bounds := Utility.get_bounding_box(self)
			if attack_direction == 1 and point.y > bounds.position.y - 1:
				if point.x > bounds.position.x - 48 and point.x < bounds.position.x - 32:
					_sprite.frame = 1
				elif point.x < bounds.end.x - 1 + 48 and point.x > bounds.end.x - 1 + 32:
					_sprite.frame = 1
					_sprite.flip_h = true
			elif attack_direction != 1 and point.y > bounds.position.y - 40 and point.y < bounds.end.y - 8:
				var distance := bounds.position.x - point.x if attack_direction == 2 else point.x - bounds.end.x + 1
				if distance > -4 and distance < 150:
					_sprite.frame = 1


func _sync_masks(art: StringName) -> void:
	if _mask_art == art:
		return
	var first_mask := _mask_art.is_empty()
	_mask_art = art
	if not _mask_cache.has(art):
		_mask_cache[art] = SpriteCollision.precise(art, -variant.source_to_feet)
	_mask_shapes = _mask_cache[art]
	if first_mask:
		_apply_masks()
	elif not _mask_pending:
		_mask_pending = true
		_apply_masks.call_deferred()


func _apply_masks() -> void:
	_mask_pending = false
	for container in [self, hitbox]:
		for child in container.get_children():
			if child is CollisionShape2D:
				container.remove_child(child)
				child.queue_free()
		SpriteCollision.add_shapes(container, _mask_shapes)


func _is_below_world() -> bool:
	return Utility.get_bounding_box(self).position.y > 16


func get_helmet_hit_margin(spiny: bool) -> float:
	# Spiny uses bbox_top+10, without Buzzy's player-motion correction.
	return 10 + level.hud.player.velocity.y / 60 if spiny else 5.0


func helmet_bounce_velocity(requested: float) -> float:
	return -30.0 if test_move(global_transform, Vector2.UP) else requested


func hit_by_projectile(kind: StringName, launch_direction := 0.0) -> bool:
	if is_queued_for_deletion():
		return false
	if kind == &"helmet" or (kind == &"pow" and is_zero_approx(velocity.y)):
		kill(launch_direction if kind == &"helmet" else 0.0)
		return true
	return false


func bumped_from_below(_activator: PhysicsBody2D) -> void:
	if velocity.y >= 0:
		kill(0)


func kill(launch_direction := 0.0) -> void:
	if is_queued_for_deletion():
		return
	var source_at := variant.source_position(global_position)
	var style := EnemyDefeatStyle.new()
	style.dead_sprite = _art
	style.dead_frame = _sprite.frame
	style.dead_water_offset = Utility.get_bounding_box(self).end.y - source_at.y - 9
	var dead := SwimmingEnemyDefeat.new()
	dead.variant = style
	dead.sub_area = sub_area
	dead.direction = -1 if _sprite.flip_h else 1
	dead.position = sub_area.get_foreground().to_local(source_at)
	# dead_h=1 leaves hspeed=0, so girar=1 still produces no rotation.
	dead.velocity.x = 0
	sub_area.add_deferred(dead)
	EnemyEffect.play_once(sub_area, &"spr_spinthump", source_at - Vector2(0, 5), 18)
	queue_free()
