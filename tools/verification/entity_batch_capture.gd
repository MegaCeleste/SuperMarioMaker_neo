extends Node
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().process_frame
	var playground: Node2D = (load("res://src/gameplay/debug/basic_entities_playground.tscn") as PackedScene).instantiate() as Node2D
	add_child(playground)
	for index: int in playground._config["spawns"].size():
		playground._spawn_index = index
		playground._spawn_select.select(index)
		playground._reset_playground()
		for frame: int in (36 if index == 8 else 1 if index == 9 else 20):
			await get_tree().physics_frame
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://local_debug_output/entity-batch-zone-%02d.png" % index)
	playground._player.effects.apply_star()
	playground._player._render(0, 0)
	playground._update_hud()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://local_debug_output/entity-batch-star.png")
	playground.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	await get_tree().process_frame
	get_tree().quit()
