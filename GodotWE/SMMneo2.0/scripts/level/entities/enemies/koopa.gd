extends Enemy

var _slide_dir := 1.0


func kill() -> void:
	if killed_by_shell:
		killed_by_shell = false
		super.kill()
		return
	
	# Save direction from SlideComponent (more reliable than velocity at stomp time)
	var slide = $SlideComponent as SlideComponent
	if slide != null:
		_slide_dir = slide.direction
	call_deferred(&"_spawn_shell")


func _spawn_shell() -> void:
	var shell = preload("res://scenes/entities/shell.tscn").instantiate()
	shell.global_position = global_position
	get_parent().add_child(shell)
	# Spawn shell-less koopa body that slides forward in the same direction
	var body = preload("res://scenes/entities/beach_koopa.tscn").instantiate()
	body.global_position = global_position + Vector2(16 * _slide_dir, 0)
	body.velocity.x = 120 * _slide_dir
	get_parent().add_child(body)
	queue_free()
