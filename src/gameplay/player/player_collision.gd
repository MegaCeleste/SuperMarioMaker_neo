class_name PlayerCollision
extends RefCounted
## REQ-PHYS-006/104/105/115, REQ-PWR-005/011.

const CEILING_NORMAL_MIN: float = 0.5

var profile: PlayerPhysicsProfile
var crouched: bool = false
var terrain_height: float = 0.0
var hurt_height: float = 0.0
var _body: CharacterBody2D
var _terrain: CollisionShape2D
var _hurt: CollisionShape2D


func _init(body: CharacterBody2D, terrain: CollisionShape2D, hurt: CollisionShape2D, physics: PlayerPhysicsProfile) -> void:
	_body = body
	_terrain = terrain
	_hurt = hurt
	profile = physics
	_terrain.shape = RectangleShape2D.new()
	_hurt.shape = RectangleShape2D.new()
	_body.collision_layer = CollisionConfig.layer("player")
	_body.collision_mask = CollisionConfig.mask(["solids", "semisolids"])
	refresh(false, false)


func refresh(requested_crouch: bool, large: bool) -> void:
	_body.safe_margin = profile.collision_margin
	_body.floor_snap_length = profile.floor_snap
	_body.floor_max_angle = deg_to_rad(profile.floor_angle_degrees)
	_body.floor_constant_speed = true
	var standing_height: float = profile.super_height if large else profile.small_height
	crouched = requested_crouch or not can_expand_to(standing_height)
	terrain_height = (profile.crouch_height if large else profile.small_crouch_height) if crouched else standing_height
	hurt_height = (profile.crouch_hurt_height if large else profile.small_crouch_hurt_height) if crouched else (profile.super_hurt_height if large else profile.small_hurt_height)
	_set_rectangle(_terrain, terrain_height)
	_set_rectangle(_hurt, hurt_height)


func can_expand_to(target_height: float) -> bool:
	if terrain_height <= 0.0 or target_height <= terrain_height + profile.clearance_epsilon:
		return true
	var extension: float = target_height - terrain_height
	var epsilon: float = profile.clearance_epsilon
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(maxf(profile.hitbox_width - epsilon * 2.0, epsilon), maxf(extension - epsilon * 2.0, epsilon))
	var center: Vector2 = Vector2(0.0, profile.feet_y - (target_height + terrain_height) / 2.0)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = rectangle
	query.transform = _body.global_transform * Transform2D(0.0, center)
	query.collision_mask = CollisionConfig.layer("solids")
	query.exclude = [_body.get_rid()]
	query.collide_with_areas = false
	return _body.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _set_rectangle(node: CollisionShape2D, height: float) -> void:
	var rectangle: RectangleShape2D = node.shape as RectangleShape2D
	var dimensions: Vector2 = Vector2(profile.hitbox_width, height)
	if rectangle.size != dimensions:
		rectangle.size = dimensions
	node.position = Vector2(0.0, profile.feet_y - height / 2.0)


func set_enabled(enabled: bool) -> void:
	_terrain.disabled = not enabled
	_hurt.disabled = not enabled


func attempt_corner_correction(velocity: Vector2, delta: float) -> void:
	if velocity.y >= 0.0:
		return
	var prediction: Vector2 = velocity * delta
	var collision: KinematicCollision2D = KinematicCollision2D.new()
	if not _body.test_move(_body.global_transform, prediction, collision, profile.collision_margin):
		return
	if collision.get_normal().y <= CEILING_NORMAL_MIN:
		return
	var preferred_side: int = -1 if velocity.x < 0.0 else 1
	for offset: int in range(1, floori(profile.corner_correction_max) + 1):
		for side: int in [preferred_side, -preferred_side]:
			var shift: Vector2 = Vector2(float(offset * side), 0.0)
			if not _body.test_move(_body.global_transform, shift) and not _body.test_move(_body.global_transform.translated(shift), prediction):
				_body.global_position += shift
				return


func head_block() -> InteractableBlock:
	return _contact_block(true)


func floor_block() -> InteractableBlock:
	return _contact_block(false)


func _contact_block(ceiling: bool) -> InteractableBlock:
	var best: InteractableBlock = null
	var overlap_max: float = -1.0
	var left: float = _body.global_position.x - profile.hitbox_width / 2.0
	var right: float = _body.global_position.x + profile.hitbox_width / 2.0
	for index: int in _body.get_slide_collision_count():
		var collision: KinematicCollision2D = _body.get_slide_collision(index)
		if ceiling and collision.get_normal().y <= CEILING_NORMAL_MIN:
			continue
		if not ceiling and collision.get_normal().y >= -CEILING_NORMAL_MIN:
			continue
		var block: InteractableBlock = collision.get_collider() as InteractableBlock
		if block == null:
			continue
		var block_shape: CollisionShape2D = block.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if block_shape == null or not block_shape.shape is RectangleShape2D:
			continue
		var rectangle: RectangleShape2D = block_shape.shape as RectangleShape2D
		var block_left: float = block_shape.global_position.x - rectangle.size.x / 2.0
		var block_right: float = block_shape.global_position.x + rectangle.size.x / 2.0
		var overlap: float = maxf(0.0, minf(right, block_right) - maxf(left, block_left))
		if overlap > overlap_max:
			overlap_max = overlap
			best = block
	return best


func terrain_rect() -> Rect2:
	return Rect2(Vector2(-profile.hitbox_width / 2.0, profile.feet_y - terrain_height), Vector2(profile.hitbox_width, terrain_height))


func hurt_rect() -> Rect2:
	return Rect2(Vector2(-profile.hitbox_width / 2.0, profile.feet_y - hurt_height), Vector2(profile.hitbox_width, hurt_height))
