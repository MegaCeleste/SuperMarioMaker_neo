class_name TurnBlock
extends InteractableBlock
## REQ-PHYS-122.

var _turn_left: int = 0


func _trigger_effect(_player: Player) -> void:
	_state = State.TURNING
	_turn_left = int(_config["turn_frames"])
	body_shape.disabled = true
	sprite.animation = &"turning"
	_frame_phase = 0.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if current_state != State.TURNING:
		return
	_turn_left = maxi(0, _turn_left - 1)
	if _turn_left == 0 and _can_restore():
		body_shape.disabled = false
		_state = State.ACTIVE
		sprite.animation = &"idle"
		_frame_phase = 0.0


func _can_restore() -> bool:
	var rectangle: RectangleShape2D = (body_shape.shape as RectangleShape2D).duplicate() as RectangleShape2D
	rectangle.size -= Vector2.ONE * float(_config["restore_epsilon"])
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = rectangle
	query.transform = body_shape.global_transform
	query.collision_mask = CollisionConfig.mask(["player", "enemies", "pickups"])
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func hit_from_above(player: Player) -> bool:
	if current_state != State.ACTIVE or not player.has_ability("spin_jump") or not player.powerups.is_large() or not player.motion.spin_active:
		return false
	_state = State.BROKEN
	body_shape.disabled = true
	collision_layer = 0
	queue_free()
	return true
