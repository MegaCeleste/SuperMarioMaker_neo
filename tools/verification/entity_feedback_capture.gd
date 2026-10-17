extends Node2D
## Actual-window evidence for the three owner feedback fixes.
func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var playground: Node2D = (load("res://src/gameplay/debug/basic_entities_playground.tscn") as PackedScene).instantiate() as Node2D
	add_child(playground)
	playground._player.reset_to(Vector2(1580, 192 - playground._player.physics_profile.feet_y), PowerUpManager.Form.FIRE)
	playground._player.set_physics_process(false)
	for child: Node in playground.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	playground.set_physics_process(false)
	playground._camera.position = Vector2(1580, 160)
	await _capture("passage")
	playground.queue_free()
	await get_tree().process_frame
	var world: Node2D = Node2D.new()
	add_child(world)
	var camera: Camera2D = Camera2D.new()
	camera.position = Vector2(128, 100)
	camera.zoom = Vector2.ONE * 6
	world.add_child(camera)
	camera.make_current()
	var walk: Galoomba = _enemy("galoomba", world, Vector2(112,100)) as Galoomba
	var flipped: Galoomba = _enemy("galoomba", world, Vector2(144,100)) as Galoomba
	walk.set_physics_process(false)
	flipped.set_physics_process(false)
	flipped.stomp(false)
	await _capture("galoomba-original-and-flipped")
	walk.queue_free()
	flipped.queue_free()
	await get_tree().process_frame
	var target: Enemy = _enemy("goomba", world, Vector2(128,100))
	target.stomp(true)
	var effect: Node2D = get_tree().get_first_node_in_group("spin_defeat_effects") as Node2D
	while effect.age < 11:
		await get_tree().physics_frame
		await get_tree().process_frame
	effect.set_physics_process(false)
	await _capture("spin-stars")
	effect.queue_free()
	var player: Player = (load("res://src/gameplay/player/player.tscn") as PackedScene).instantiate() as Player
	player.position = Vector2(128,90)
	world.add_child(player)
	player.set_physics_process(false)
	player.motion.facing = -1.0
	player.motion.state_machine.resolve(true, false, true, Vector2(120,0), 0.01)
	player._render(0,0)
	for tick: int in 12:
		player.position.x += 0.5
		await get_tree().physics_frame
		await get_tree().process_frame
	player.get_node("SkidDust").set_physics_process(false)
	await _capture("skid-dust")
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _enemy(path: String, parent: Node2D, at: Vector2) -> Enemy:
	var enemy: Enemy = (load("res://src/gameplay/enemies/" + path + ".tscn") as PackedScene).instantiate() as Enemy
	enemy.position = at
	parent.add_child(enemy)
	return enemy


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://local_debug_output/entity-feedback-" + label + ".png")
