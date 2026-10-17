extends Node2D
## Regression for the owner's 2026-10-10 passage, flipped art and spin feedback.
var checks: Array[Dictionary] = []
var failures: int = 0
var world: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _clear()
	await _passage()
	await _flipped_art()
	await _spin_defeats()
	await _effect_lifecycle()
	await _skid_dust()
	await _clear()
	world.queue_free()
	await _frames(2)
	var file: FileAccess = FileAccess.open("res://local_debug_output/entity-feedback-verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "count": checks.size(), "failures": failures, "evidence": "Native collisions, state/render and effect lifecycle; owner play approval pending"}, "\t"))
	file.close()
	print("ENTITY_FEEDBACK_CHECKS ", checks.size(), " FAILURES ", failures)
	get_tree().quit(0 if failures == 0 else 1)


func check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
	if not passed:
		failures += 1
		push_error(label)


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _clear() -> void:
	get_tree().paused = false
	GameManager.clear_gameplay_freeze()
	if is_instance_valid(world):
		world.queue_free()
	await _frames(2)
	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)


func _actor(path: String) -> Enemy:
	var enemy: Enemy = (load("res://src/gameplay/enemies/" + path + ".tscn") as PackedScene).instantiate() as Enemy
	enemy.position = Vector2(100, 100)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func _passage() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/debug/basic_entities_playground.json")) as Dictionary
	for solid: Dictionary in config["solids"]:
		var body: StaticBody2D = StaticBody2D.new()
		body.position = Vector2(float(solid["center"][0]), float(solid["center"][1]))
		body.collision_layer = CollisionConfig.layer("solids")
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rectangle: RectangleShape2D = RectangleShape2D.new()
		rectangle.size = Vector2(float(solid["size"][0]), float(solid["size"][1]))
		shape.shape = rectangle
		body.add_child(shape)
		world.add_child(body)
	var player: Player = (load("res://src/gameplay/player/player.tscn") as PackedScene).instantiate() as Player
	world.add_child(player)
	player.set_physics_process(false)
	player.input_enabled = false
	for form: PowerUpManager.Form in [PowerUpManager.Form.SMALL, PowerUpManager.Form.FIRE]:
		player.reset_to(Vector2(1490, 192 - player.physics_profile.feet_y), form)
		await _frames(2)
		var grounded: bool = true
		for tick: int in 80:
			player.velocity = Vector2(180, 12)
			player.move_and_slide()
			grounded = grounded and player.is_on_floor()
			await _frames(1)
		check("passage clears old wall and joins floor form %d" % form, player.position.x > 1700 and grounded and not player.is_on_wall())
	await _clear()


func _flipped_art() -> void:
	var enemy: Galoomba = _actor("galoomba") as Galoomba
	var feet: Vector2 = enemy.feet_position()
	var walk: AtlasTexture = enemy.sprite.sprite_frames.get_frame_texture(&"walk", 0) as AtlasTexture
	enemy.stomp(false)
	var stunned: AtlasTexture = enemy.sprite.sprite_frames.get_frame_texture(&"stunned", 0) as AtlasTexture
	check("galoomba flipped original atlas and frame", stunned.atlas == walk.atlas and stunned.region == walk.region and enemy.sprite.flip_v)
	check("galoomba stomp keeps feet and 600 frame recovery", enemy.feet_position() == feet and enemy._recovery_left == 600)
	enemy._on_picked_up(null)
	check("galoomba held stays upside down", enemy.sprite.flip_v)
	enemy._on_thrown(Vector2(100, 0))
	check("galoomba thrown stays upside down", enemy.sprite.flip_v)
	enemy._on_dropped()
	enemy._recovery_left = 1
	enemy._process_state(1.0 / 60.0)
	enemy._render(0)
	check("galoomba recovery restores original orientation", enemy.state == Enemy.State.WALKING and not enemy.sprite.flip_v)
	await _clear()


func _spin_defeats() -> void:
	for path: String in ["goomba", "galoomba", "koopa", "buzzy_beetle", "koopa_shell", "naked_koopa"]:
		var enemy: Enemy = _actor(path)
		var emitted: Array[int] = [0]
		enemy.defeated.connect(func(_who: Enemy) -> void: emitted[0] += 1)
		var result: EntityHitResult = enemy.receive_hit(EntityHit.new(EntityHit.Kind.SPIN))
		check(path + " spin immediately hides and retires corpse", result.affected and enemy.is_queued_for_deletion() and not enemy.visible and enemy.velocity == Vector2.ZERO and enemy.collision_layer == 0)
		check(path + " one effect and defeat signal", get_tree().get_nodes_in_group("spin_defeat_effects").size() == 1 and emitted[0] == 1)
		enemy.receive_hit(EntityHit.new(EntityHit.Kind.SPIN))
		check(path + " duplicate spin causes no duplicate effect", get_tree().get_nodes_in_group("spin_defeat_effects").size() == 1 and emitted[0] == 1)
		await _frames(1)
		check(path + " root freed by next frame", not is_instance_valid(enemy))
		await _clear()
	for path: String in ["spiny", "piranha_plant", "bob_omb"]:
		var enemy: Enemy = _actor(path)
		if enemy is PiranhaPlant:
			(enemy as PiranhaPlant).extension = 16.0
			(enemy as PiranhaPlant)._update_exposure()
		enemy.receive_hit(EntityHit.new(EntityHit.Kind.SPIN))
		check(path + " spin retains special behavior without kill effect", not enemy.is_dead and not enemy.is_queued_for_deletion() and get_tree().get_nodes_in_group("spin_defeat_effects").is_empty())
		await _clear()
	var normal: Enemy = _actor("goomba")
	normal.receive_hit(EntityHit.new(EntityHit.Kind.FIREBALL))
	check("fireball retains ballistic death", normal.visible and not normal.is_queued_for_deletion() and normal.velocity.y < 0 and get_tree().get_nodes_in_group("spin_defeat_effects").is_empty())
	await _clear()


func _effect_lifecycle() -> void:
	_actor("goomba").stomp(true)
	var effect: Node2D = get_tree().get_first_node_in_group("spin_defeat_effects") as Node2D
	check("effect starts at target center with four stars and no smoke", effect.position == Vector2(100,100) and effect.stars.size() == 4 and effect.get_child_count() == 5 and effect.age == 0)
	await _frames(6)
	check("stars spread symmetrically at source-converted speed", effect.stars[0].position == Vector2(effect.age, effect.age * 0.5) and effect.stars[3].position == -effect.stars[0].position)
	get_tree().paused = true
	var previous: int = effect.age
	await _frames(5)
	check("effect pauses with gameplay", effect.age == previous)
	get_tree().paused = false
	GameManager.freeze_gameplay(100)
	await _frames(5)
	check("effect pauses for transformation", effect.age == previous)
	GameManager.clear_gameplay_freeze()
	while effect.age < 15:
		await _frames(1)
	check("stars remain visible through final active frame", effect.stars[0].visible and not effect.is_queued_for_deletion())
	await _frames(2)
	check("stars free at 16 active frames", not is_instance_valid(effect))
	_actor("galoomba").stomp(true)
	await _clear()
	check("world reset clears outstanding effects", get_tree().get_nodes_in_group("spin_defeat_effects").is_empty())


func _skid_dust() -> void:
	var player: Player = (load("res://src/gameplay/player/player.tscn") as PackedScene).instantiate() as Player
	world.add_child(player)
	player.set_physics_process(false)
	player.motion.state_machine.resolve(true, false, true, Vector2(120,0), 0.01)
	var dust: Node2D = player.get_node("SkidDust") as Node2D
	await _frames(1)
	check("skid uses authored five frame smoke strip", dust._puffs.size() == 1 and (dust._puffs[0]["sprite"] as AnimatedSprite2D).sprite_frames.get_frame_count(&"idle") == 5)
	var sprite: AnimatedSprite2D = dust._puffs[0]["sprite"] as AnimatedSprite2D
	var original: Vector2 = sprite.global_position
	check("skid smoke sits at feet with half source scale", original.y == player.feet_y() - 2.0 and sprite.scale == Vector2.ONE * 0.5)
	player.position.x += 20
	await _frames(4)
	check("skid smoke stays at emitted world position and animates", sprite.global_position == original and sprite.frame > 0)
	var age: int = int(dust._puffs[0]["age"])
	get_tree().paused = true
	await _frames(4)
	check("skid smoke pauses with gameplay", int(dust._puffs[0]["age"]) == age)
	get_tree().paused = false
	GameManager.freeze_gameplay(100)
	await _frames(4)
	check("skid smoke freezes for transformations", int(dust._puffs[0]["age"]) == age and dust._puffs.size() == 1)
	GameManager.clear_gameplay_freeze()
	await _frames(4)
	check("skid emits another puff on eight tick cadence", dust._puffs.size() == 2)
	player.motion.state_machine.resolve(true, false, false, Vector2.ZERO, 0.01)
	await _frames(18)
	check("skid exit stops emission and finishes existing frames", dust._puffs.is_empty())
	player.motion.state_machine.resolve(true, false, true, Vector2(120,0), 0.01)
	await _frames(1)
	player.reset_to(Vector2.ZERO)
	check("player reset clears skid sprites", dust._puffs.is_empty())
	player.motion.state_machine.resolve(true, false, true, Vector2(120,0), 0.01)
	await _frames(1)
	player.powerups.kill()
	check("player death clears skid sprites", dust._puffs.is_empty())
	await _frames(18)
	check("dead player cannot emit new skid smoke", dust._puffs.is_empty())
	await _clear()
