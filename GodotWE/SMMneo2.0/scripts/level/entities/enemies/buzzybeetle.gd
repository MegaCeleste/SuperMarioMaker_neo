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
	var shell = preload("res://scenes/entities/shell_buzzy.tscn").instantiate()
	shell.global_position = global_position
	get_parent().add_child(shell)
	queue_free()
