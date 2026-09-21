extends Enemy

enum State { SLIDING, LYING, WALKING, SQUISHED, REENTERING }

var _state := State.SLIDING
var _lie_timer := 0.0
var _squish_timer := 0.0
var _move_dir := 1.0


func _ready() -> void:
	super()
	$SlideComponent.process_mode = Node.PROCESS_MODE_DISABLED
	_move_dir = sign(velocity.x) if absf(velocity.x) > 0.5 else 1.0
	$Graphics/Sprite.flip_h = _move_dir < 0
	call_deferred(&"_check_initial_overlap")


func _check_initial_overlap() -> void:
	for body in $KillArea.get_overlapping_bodies():
		if body is Player:
			_body_handling(true, body)


func _physics_process(delta: float) -> void:
	match _state:
		State.SLIDING:
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0, 120 * delta)
			move_and_slide()
			if absf(velocity.x) > 0.5:
				_move_dir = sign(velocity.x)
			$Graphics/Sprite.flip_h = _move_dir < 0
			if is_on_floor() and absf(velocity.x) < 0.5:
				_start_lying()
			# Shell wall collision intercept
			if is_on_wall():
				for i in get_slide_collision_count():
					var coll = get_slide_collision(i)
					var shell = coll.get_collider() as Shell
					if shell != null:
						var pickup = Utility.find_child_by_class(shell, PickupComponent) as PickupComponent
						if pickup == null or not pickup.held:
							_reenter_shell(shell)
							return
		State.LYING:
			_lie_timer -= delta
			if _lie_timer <= 0:
				_start_walking()
		State.WALKING:
			move_and_slide()
			# Cliff detection
			if is_on_floor() and not _floor_ahead(_move_dir):
				$SlideComponent.direction *= -1
				_move_dir *= -1
				$Graphics/Sprite.flip_h = _move_dir < 0
			# Shell wall collision intercept
			if is_on_wall():
				for i in get_slide_collision_count():
					var coll = get_slide_collision(i)
					var shell = coll.get_collider() as Shell
					if shell != null:
						var pickup = Utility.find_child_by_class(shell, PickupComponent) as PickupComponent
						if pickup == null or not pickup.held:
							_reenter_shell(shell)
							return
		State.SQUISHED:
			_squish_timer -= delta
			if _squish_timer <= 0:
				queue_free()
		State.REENTERING:
			pass
	# Check for shell re-entry
	if _state != State.SQUISHED and _state != State.REENTERING:
		for body in $ShellSensor.get_overlapping_bodies():
			if body is Shell:
				var pickup = Utility.find_child_by_class(body, PickupComponent) as PickupComponent
				if pickup == null or not pickup.held:
					_reenter_shell(body)
					return


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


func _start_lying() -> void:
	_state = State.LYING
	velocity = Vector2.ZERO
	$Graphics/Sprite.stop()
	$Graphics/Sprite.frame = 0
	_lie_timer = 0.5


func _start_walking() -> void:
	_state = State.WALKING
	$Graphics/Sprite.flip_h = _move_dir < 0
	$Graphics/Sprite.play(&"walk")
	$SlideComponent.direction = sign(_move_dir)
	$SlideComponent.process_mode = Node.PROCESS_MODE_INHERIT


func kill() -> void:
	if _state == State.SQUISHED:
		return
	_squish()


func _squish() -> void:
	_state = State.SQUISHED
	velocity = Vector2.ZERO
	collision_layer = 0
	$SlideComponent.process_mode = Node.PROCESS_MODE_DISABLED
	$Graphics/Sprite.stop()
	$Graphics/Sprite.play(&"squish")
	$Graphics/Sprite.frame = 0
	_squish_timer = 0.3


func _reenter_shell(shell: Shell) -> void:
	_state = State.REENTERING
	$SlideComponent.process_mode = Node.PROCESS_MODE_DISABLED
	var move_dir = _move_dir
	velocity = Vector2.ZERO
	
	# Disable shell interaction while re-entering
	var shell_pickup = Utility.find_child_by_class(shell, PickupComponent) as PickupComponent
	if shell_pickup:
		shell_pickup.can_be_held = false
	
	# Stop shell's physics so it doesn't override our animation
	shell.set_physics_process(false)
	shell.set_process(false)
	shell.collision_layer = 0
	var shell_sprite = shell.get_node("Graphics/Sprite")
	shell_sprite.stop()
	shell_sprite.frame = 0
	shell_sprite.play("inside")
	
	# Jump toward the shell then disappear
	var target = shell.global_position
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target, 0.15)
	tween.tween_property(self, "global_position:y", target.y - 12, 0.08)
	tween.tween_property(self, "global_position:y", target.y, 0.07).set_delay(0.08)
	tween.chain()
	tween.tween_callback(func():
		hide()
		collision_layer = 0
		# Shake the shell for ~1 second then spawn the restored koopa
		var shake = shell.create_tween()
		for _i in range(8):
			shake.tween_property(shell, "rotation", 0.05, 0.06)
			shake.tween_property(shell, "rotation", -0.05, 0.06)
		shake.tween_callback(func():
			var koopa = load("res://scenes/entities/red_koopa.tscn").instantiate()
			koopa.global_position = shell.global_position
			koopa.velocity.x = move_dir * 30.0
			shell.get_parent().add_child(koopa)
			shell.queue_free()
			queue_free()
		)
	)
