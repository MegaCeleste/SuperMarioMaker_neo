extends Enemy

var _slide_dir := 1.0


func kill() -> void:
	if killed_by_shell:
		killed_by_shell = false
		super.kill()
		return
	var slide = $SlideComponent as SlideComponent
	if slide != null:
		_slide_dir = slide.direction
	call_deferred(&"_spawn_shell")


func _spawn_shell() -> void:
	var shell = preload("res://scenes/entities/red_shell.tscn").instantiate()
	shell.global_position = global_position
	get_parent().add_child(shell)
	var body = preload("res://scenes/entities/red_beach_koopa.tscn").instantiate()
	var slide_dir = _slide_dir
	body.global_position = global_position + Vector2(16 * slide_dir, 0)
	body.velocity.x = 120 * slide_dir
	get_parent().add_child(body)
	queue_free()


func _physics_process(delta: float) -> void:
	super(delta)
	# Cliff detection: if floor ahead is missing, turn around
	if is_on_floor():
		var dir = signf(velocity.x)
		if dir == 0:
			dir = 1
		if not _floor_ahead(dir):
			$SlideComponent.direction *= -1
			velocity.x = 30 * $SlideComponent.direction
			_turned(Vector2.RIGHT if $SlideComponent.direction > 0 else Vector2.LEFT)


func _floor_ahead(dir: float) -> bool:
	var space = get_world_2d().direct_space_state
	if space == null:
		return true
	var from = global_position + Vector2(8 * dir, 0)
	var to = from + Vector2(0, 20)
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 3
	var result = space.intersect_ray(query)
	return not result.is_empty()
