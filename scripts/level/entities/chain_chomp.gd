# SPDX-License-Identifier: AGPL-3.0-or-later
class_name ChainChomp
extends Enemy
## The pinned editor builds free Chomps, without stakes or a release state.
## Chain links draw the head's pre-motion history and have no live collisions.

@export var variant: ChompVariant = preload("res://resources/content/smw_chomp_small.tres")
var direction := -1
var dark := false
var swimming := false
var _wake_left := 0.0
var _follow := true
var _history := PackedVector2Array()
var _links: Array[Sprite2D] = []
var _sprite: AnimatedSprite2D


func _ready() -> void:
	super()
	stomp_behavior = Stompability.RECOIL
	fireproof = true # obj_fireball explicitly excludes both Chomp objects.
	dark = sub_area.night_mode or sub_area.level_theme in [Level.LevelTheme.CASTLE,
		Level.LevelTheme.MANSION, Level.LevelTheme.UNDERGROUND]
	_wake_left = variant.wake_delay
	for path in ["CollShape", "PlayerArea/CollShape"]:
		get_node(path).shape = SpriteCollision.ellipse(variant.mask_rect.size, variant.mask_rect.get_center())
	_sprite = $Graphics/Sprite
	SpriteLibrary.configure_sprite(_sprite, variant.head_sprite, &"chomp", variant.head_fps)
	_history.resize(variant.history_length + 1)
	_history.fill(source_origin())
	for index in 4:
		var link := Sprite2D.new()
		link.name = "Link%d" % (index + 1)
		link.centered = false
		var frames := SpriteLibrary.get_frames(variant.chain_sprite)
		# draw_sprite wraps source subimages. SMW chains have only one frame.
		link.texture = frames.get_frame_texture(&"default", int(dark) % frames.get_frame_count(&"default"))
		link.offset = -SpriteLibrary.get_origin(variant.chain_sprite)
		$Links.add_child(link)
		_links.append(link)
	_update_visuals()


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if _is_below_world():
		queue_free()
		return
	var stopped := source_death_stopped()
	_wake_left -= delta
	if _wake_left <= 0:
		_wake_left = INF
		if velocity.x == 0:
			velocity.x = (variant.water_launch_speed if _water_launch() else variant.launch_speed) * direction
	swimming = _is_swimming()
	if _touches_damaging_liquid():
		_sink()
		return
	_turn_from_neighbours()
	var cap := variant.water_walk_speed if _full_water() else variant.walk_speed
	# Other_12 tests the old direct; a neighbour reversal delays this clamp
	# until next tick. Step_0 updates direct only after all inherited events.
	if absf(velocity.x) > cap and velocity.x * direction > 0:
		velocity.x = move_toward(velocity.x, cap * signf(velocity.x), variant.deceleration * delta)
	if velocity.x != 0 and _wall_ahead():
		velocity.x *= -1
	if velocity.x != 0:
		direction = int(signf(velocity.x))
	if _follow and not stopped:
		_record_history()
	# Source Other_14 computes gravity from geometry each tick. is_on_floor()
	# alone is stale while WorldDeath suppresses native automatic body motion.
	if _has_support():
		velocity.y = -(variant.water_hop_speed if swimming else variant.hop_speed)
		position.y -= 1
	elif not stopped:
		velocity.y = minf(variant.water_fall_speed if swimming else variant.fall_speed, velocity.y) + variant.gravity * delta
	var incoming_x := velocity.x
	# Source Other_14 culls before automatic movement, not at its new position.
	move_source_and_slide()
	if not stopped and is_on_wall() and incoming_x != 0:
		velocity.x = -incoming_x
	_update_visuals()


## Original centered instance origin, independent of native feet/draw rounding.
func source_origin() -> Vector2:
	return global_position - Vector2(0, variant.source_to_feet)


func _record_history() -> void:
	_history[0] = source_origin()
	# Source writes slot0 first; slots0/1 therefore both contain this tick.
	for index in range(variant.history_length, 0, -1):
		_history[index] = _history[index - 1]


func _update_visuals() -> void:
	$Graphics.position = Vector2(roundf(global_position.x) - global_position.x,
			SpriteLibrary.contact_draw_y(variant.head_sprite))
	_sprite.flip_h = direction < 0
	for index in _links.size():
		_links[index].position = to_local(_history[(index + 1) * variant.link_spacing])


func _solid_query(bounds: Rect2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = bounds.size
	query.shape = shape
	query.transform.origin = bounds.get_center()
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var body: CollisionObject2D = hit.collider
		# Side checks exclude source obj_solidtop. Native platforms advertise
		# this through their existing one-way collision shape.
		var owner_id := body.shape_find_owner(hit.shape)
		var collider := body.shape_owner_get_owner(owner_id)
		if not collider is CollisionShape2D or not collider.one_way_collision:
			return true
	return false


func _wall_ahead() -> bool:
	var edge := variant.mask_rect.end.x if velocity.x > 0 else variant.mask_rect.position.x
	var x := global_position.x + edge - 1 if velocity.x > 0 else global_position.x + edge - 0.2
	return _solid_query(Rect2(Vector2(x, global_position.y + variant.mask_rect.position.y + 1),
			Vector2(1.2, variant.mask_rect.size.y - 5)))


func _has_support() -> bool:
	if velocity.y < 0 and not source_death_stopped():
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(variant.mask_rect.size.x, 0.25)
	query.shape = shape
	query.transform.origin = global_position
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	if get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	# The source rejects support embedded four pixels above bbox_bottom.
	query.transform.origin = global_position - Vector2(0, 5)
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _turn_from_neighbours() -> void:
	if velocity.x == 0:
		return
	var bounds := variant.mask_rect
	bounds.size.y -= 4
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = bounds.size
	query.shape = shape
	query.transform.origin = global_position + bounds.get_center()
	query.collision_mask = 2
	query.exclude = [get_rid()]
	var ordinary: Array[CollisionObject2D] = []
	var held: Array[CollisionObject2D] = []
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var other: CollisionObject2D = hit.collider
		if other.is_queued_for_deletion() or not other.is_visible_in_tree():
			continue
		if other is KoopaShell and other._grace > 0:
			continue
		if other is StompedGaloomba and other.get_node("PickupComponent").pickup_immunity_left > 0:
			continue
		if other is KoopaShell or other is StompedGaloomba:
			held.append(other)
		elif other is Enemy:
			ordinary.append(other)
	# Source performs these separately. A held-parent overlap can supersede
	# the ordinary enemy's turn in the same tick.
	for targets: Array[CollisionObject2D] in [ordinary, held]:
		if targets.is_empty():
			continue
		targets.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
		var other := targets[0]
		var center := Utility.get_bounding_box(other).get_center().x
		velocity.x = absf(velocity.x) if global_position.x > center \
				or (global_position.x == center and get_instance_id() > other.get_instance_id()) else -absf(velocity.x)


func _full_water() -> bool:
	return sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (sub_area.night_mode and sub_area.level_theme in [Level.LevelTheme.SKY, Level.LevelTheme.AIRSHIP])


func _water_launch() -> bool:
	return _full_water() or (is_instance_valid(sub_area.liquid) \
			and sub_area.level_theme == Level.LevelTheme.FOREST and not sub_area.night_mode \
			and source_origin().y > sub_area.liquid.global_position.y + 4)


func _is_swimming() -> bool:
	return _full_water() or (is_instance_valid(sub_area.liquid) \
			and source_origin().y + 8 >= sub_area.liquid.global_position.y - 12)


func _touches_damaging_liquid() -> bool:
	return is_instance_valid(sub_area.liquid) and source_origin().y + 8 >= sub_area.liquid.global_position.y - 12 \
			and (sub_area.level_theme == Level.LevelTheme.CASTLE \
			or (sub_area.night_mode and sub_area.level_theme in [Level.LevelTheme.FOREST, Level.LevelTheme.MOUNTAIN]))


func _sink() -> void:
	var liquid := sub_area.liquid
	EnemyEffect.play_once(sub_area, liquid.rules.poison_splash_sprite if sub_area.level_theme == Level.LevelTheme.FOREST \
			else liquid.rules.lava_splash_sprite, Vector2(global_position.x, liquid.global_position.y - 26), liquid.rules.splash_fps, false)
	var sink := SinkingEnemy.new()
	sink.sub_area = sub_area
	sink.sprite_name = variant.head_sprite
	sink.mask_size = variant.mask_rect.size
	sink.mask_center = variant.source_mask().get_center()
	sink.direction = direction
	sink.position = sub_area.get_foreground().to_local(source_origin())
	sub_area.add_deferred(sink)
	queue_free() # Source conversion keeps just the head, with frame0 initially.


func hit_by_projectile(kind: StringName, launch_direction := 0.0) -> bool:
	if kind == &"pow" and (velocity.y != 0 or not _has_support()):
		return false
	return super(kind, launch_direction)


func bumped_by_block(block: PhysicsBody2D, _activator: PhysicsBody2D) -> void:
	source_block_defeat(block)


func kill(_launch_direction := 0.0) -> void:
	if is_queued_for_deletion():
		return
	var head := _corpse(variant.head_sprite, _sprite.frame, source_origin(), variant.source_mask())
	for index in 4:
		var half := SpriteLibrary.get_origin(variant.chain_sprite)
		var size := SpriteLibrary.get_frames(variant.chain_sprite).get_frame_texture(&"default", 0).get_size()
		var link := _corpse(variant.chain_sprite, int(dark), _history[(index + 1) * variant.link_spacing], Rect2(-half, size))
		link.velocity.x = -60
		# Source assigns this to the head four times, not to the new link.
		head.velocity.x = 60 if randi() % 2 == 0 else -60
	queue_free()


func _corpse(art: StringName, frame: int, at: Vector2, mask: Rect2) -> SwimmingEnemyDefeat:
	var style := EnemyDefeatStyle.new()
	style.dead_sprite = art
	style.dead_frame = frame % SpriteLibrary.get_frames(art).get_frame_count(&"default")
	style.dead_spins = true
	style.dead_mask_rect = mask
	var effect := SwimmingEnemyDefeat.new()
	effect.variant = style
	effect.sub_area = sub_area
	effect.direction = direction
	effect.position = sub_area.get_foreground().to_local(at)
	sub_area.add_deferred(effect)
	return effect


func apply_source_death() -> void:
	super()
	_follow = false
	_wake_left = INF


func _is_below_world() -> bool:
	return global_position.y + variant.mask_rect.position.y - 16 > 0
