extends Node2D
## Accepted behavior matrix plus real physics scenarios; no mocking move_and_slide.
var checks: Array[Dictionary] = []
var failures: int = 0
var world: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _frames(2)
	await _matrix()
	await _pickups()
	await _shells()
	await _derived_physics()
	await _existing_recovery()
	await _bombs()
	await _plants()
	await _player_effects()
	await _fireballs()
	await _lifecycle()
	await _blocks()
	await _catalog()
	await _clear()
	world.queue_free()
	await _frames(2)
	var file: FileAccess = FileAccess.open("res://local_debug_output/entity-batch-verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "count": checks.size(), "failures": failures, "engine": Engine.get_version_info(), "evidence": "Godot native physics and accepted interaction matrix; no owner play approval"}, "\t"))
	file.close()
	print("ENTITY_BATCH_CHECKS ", checks.size(), " FAILURES ", failures)
	get_tree().quit(0 if failures == 0 else 1)

func check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
	if not passed:
		failures += 1
		push_error("ENTITY_BATCH_FAIL: " + label)

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

func actor(id: String, at: Vector2 = Vector2(100, 100), properties: Dictionary = {}, disabled: bool = true) -> Node2D:
	var node: Node2D = Registry.instantiate_object(id, properties)
	check("factory " + id, node != null)
	if node == null:
		return null
	node.position = at
	world.add_child(node)
	if disabled:
		node.process_mode = Node.PROCESS_MODE_DISABLED
	return node

func floor_at(at: Vector2, size: Vector2) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = at
	body.collision_layer = CollisionConfig.layer("solids")
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	world.add_child(body)
	return body

func player_at(at: Vector2 = Vector2(40, 100)) -> Player:
	var player: Player = (load("res://src/gameplay/player/player.tscn") as PackedScene).instantiate() as Player
	player.position = at
	world.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.input_enabled = false
	return player

func _matrix() -> void:
	var ids: Array[String] = ["goomba", "galoomba", "koopa_green", "koopa_red", "buzzy_beetle", "spiny", "bob_omb", "piranha_plant"]
	for id: String in ids:
		for kind: EntityHit.Kind in [EntityHit.Kind.STOMP, EntityHit.Kind.SPIN, EntityHit.Kind.FIREBALL, EntityHit.Kind.SHELL, EntityHit.Kind.THROWN, EntityHit.Kind.BUMP, EntityHit.Kind.STAR, EntityHit.Kind.EXPLOSION]:
			await _clear()
			var enemy: Enemy = actor("smm.enemy." + id) as Enemy
			if enemy == null:
				continue
			if enemy is PiranhaPlant:
				(enemy as PiranhaPlant).extension = 16.0
				(enemy as PiranhaPlant)._update_exposure()
			var result: EntityHitResult = enemy.receive_hit(EntityHit.new(kind))
			var ignored_stomp: bool = id in ["spiny", "piranha_plant"] and kind == EntityHit.Kind.STOMP
			var safe_spin: bool = id in ["spiny", "piranha_plant"] and kind == EntityHit.Kind.SPIN
			var immune_fire: bool = id == "buzzy_beetle" and kind == EntityHit.Kind.FIREBALL
			check(id + " response " + EntityHit.Kind.keys()[kind], result.affected == not (ignored_stomp or safe_spin or immune_fire))
			if safe_spin:
				check(id + " safe spin preserves enemy", not enemy.is_dead and result.bounce == EntityHitResult.Bounce.SAFE_SPIN)
			if immune_fire:
				check("buzzy fireball consumed without damage", result.consume_attack and not enemy.is_dead)
			if id == "bob_omb" and kind in [EntityHit.Kind.STOMP, EntityHit.Kind.SPIN, EntityHit.Kind.FIREBALL, EntityHit.Kind.BUMP]:
				check("bomb ignited " + EntityHit.Kind.keys()[kind], (enemy as BobOmb).fuse.remaining == 300 and not enemy.is_dead)
			if id == "goomba" and kind == EntityHit.Kind.STOMP:
				check("goomba squashed", enemy.state == Enemy.State.SQUASHED)
			if id == "galoomba" and kind == EntityHit.Kind.STOMP:
				check("galoomba stunned", enemy.state == Enemy.State.STUNNED)
			if id.begins_with("koopa") and kind == EntityHit.Kind.STOMP:
				check("koopa separates shell and naked", world.get_child_count() == 3)

func _pickups() -> void:
	await _clear()
	GameManager.reset_coins()
	var player: Player = player_at()
	for value: int in [10, 30, 50]:
		var coin: Coin = actor("smm.item.coin_%d" % value, Vector2(value * 10, 80)) as Coin
		coin.interaction._entered(player)
		coin.interaction._entered(player)
		check("large coin deduplicates contact %d" % value, coin.interaction.contacts.size() == 1)
		check("large coin collect %d" % value, coin.interaction.try_collect())
		check("large coin no duplicate reward %d" % value, not coin.interaction.try_collect())
	check("large coin total 90", GameManager.coins == 90)
	var one: OneUp = actor("smm.item.one_up") as OneUp
	one.interaction._entered(player)
	check("1UP single reward", one.interaction.try_collect() and GameManager.extra_lives == 1)
	check("1UP consumed once", not one.interaction.try_collect())
	for id: String in ["super_mushroom", "fire_flower", "super_star", "one_up"]:
		var pickup: PowerUpPickup = actor("smm.item." + id, Vector2(200, 100)) as PowerUpPickup
		check(id + " has release contract", pickup.get_node("BlockContent") is BlockContent)
		(pickup.get_node("BlockContent") as BlockContent).release_from_block(player, Vector2(200, 100), Vector2(200, 84), 42)
		check(id + " emergence disables collision", pickup.collision_layer == 0 and not pickup.pickup_area.monitoring)
		for frame: int in 42:
			pickup._physics_process(1.0 / 60.0)
		check(id + " emergence finishes at target", pickup.position.is_equal_approx(Vector2(200, 84)) and pickup.pickup_area.monitoring)
	GameManager.reset_coins()
	check("session reset clears rewards", GameManager.coins == 0 and GameManager.extra_lives == 0)
	var coin: Coin = actor("smm.item.coin", Vector2(200, 100)) as Coin
	coin.pop_from_block(player, Vector2(200, 100))
	for frame: int in 20:
		coin._physics_process(1.0 / 60.0)
	check("block coin follows reference ballistic apex", coin.position.y < 82 and coin._popup_velocity == 0)
	for frame: int in 20:
		if not coin.is_queued_for_deletion():
			coin._physics_process(1.0 / 60.0)
	check("block coin expires on downward return", coin.is_queued_for_deletion())

func _shells() -> void:
	await _clear()
	var shell: KoopaShell = actor("smm.enemy.koopa_shell") as KoopaShell
	check("empty shell cannot recover by itself", shell.occupant.is_empty() and shell.state == Enemy.State.STUNNED)
	check("wrong-color shell entry rejected", not shell.enter_koopa("red"))
	check("matching shell entry accepted", shell.enter_koopa("green"))
	check("green entry timer 60", shell.recovery_left == 60)
	floor_at(Vector2(100, 100), Vector2(64, 8))
	for frame: int in 60:
		shell._process_state(1.0 / 60.0)
	check("blocked headroom defers recovery", not shell.is_queued_for_deletion() and shell.recovery_left == 0)
	await _clear()
	shell = actor("smm.enemy.koopa_shell") as KoopaShell
	shell.enter_koopa("green")
	for frame: int in 60:
		shell._process_state(1.0 / 60.0)
	check("clear shell recovers once", shell.is_queued_for_deletion() and world.get_child_count() == 2)
	await _clear()
	floor_at(Vector2(200, 128), Vector2(400, 16))
	floor_at(Vector2(184, 76), Vector2(16, 88))
	shell = actor("smm.enemy.koopa_shell", Vector2(120, 112), {}, false) as KoopaShell
	shell._thrown(Vector2(132, 0))
	check("kick protection starts", not shell.can_damage_player())
	await _frames(16)
	check("kick protection expires", shell.can_damage_player())
	await _frames(25)
	check("shell reflects from wall", shell.dir < 0 and shell.velocity.x < 0)
	shell.receive_hit(EntityHit.new(EntityHit.Kind.STOMP))
	check("stomp stops shell", shell.state == Enemy.State.STUNNED and shell.velocity.x == 0.0)
	await _clear()
	shell = actor("smm.enemy.koopa_shell", Vector2(50, 100)) as KoopaShell
	var a: Enemy = actor("smm.enemy.goomba", Vector2(120, 100)) as Enemy
	var b: Enemy = actor("smm.enemy.goomba", Vector2(160, 100)) as Enemy
	shell.global_position = Vector2(200, 100)
	var hits: Array[Enemy] = EntitySpawn.swept_enemies(shell, Vector2(50, 100))
	check("sweep catches both crossed enemies", hits.has(a) and hits.has(b))
	for enemy: Enemy in hits:
		enemy.receive_hit(EntityHit.new(EntityHit.Kind.SHELL, shell))
	check("shell continues through two enemies", a.is_dead and b.is_dead and not shell.is_dead)
	await _clear()
	var green: Koopa = actor("smm.enemy.koopa_green", Vector2(100, 100), {"start_direction":1}, false) as Koopa
	var red: Koopa = actor("smm.enemy.koopa_red", Vector2(300, 100), {"start_direction":1}, false) as Koopa
	floor_at(Vector2(100, 116), Vector2(40, 16))
	floor_at(Vector2(300, 116), Vector2(40, 16))
	await _frames(90)
	check("green walks off cliff", green.position.y > 130)
	check("red stays on platform", absf(red.feet_position().y - 108) < 1.0 and red.position.x < 324)

func _derived_physics() -> void:
	await _clear()
	floor_at(Vector2(300,128), Vector2(600,16))
	floor_at(Vector2(30,76), Vector2(16,88))
	var original: Koopa = actor("smm.enemy.koopa_green", Vector2(150,112)) as Koopa
	original.receive_hit(EntityHit.new(EntityHit.Kind.STOMP, null, null, -1))
	await _frames(520)
	var recovered_count: int = 0
	var naked_count: int = 0
	var shell_count: int = 0
	for node: Node in world.get_children():
		if node is Koopa:
			recovered_count += 1
		if node is NakedKoopa:
			naked_count += 1
		if node is KoopaShell:
			shell_count += 1
	check("full stomp-ejection-recovery-reentry chain", recovered_count == 1 and naked_count == 0 and shell_count == 0)
	await _clear()
	floor_at(Vector2(300, 128), Vector2(600, 16))
	var shell: KoopaShell = actor("smm.enemy.koopa_shell", Vector2(170, 112), {}, false) as KoopaShell
	var naked: NakedKoopa = EntitySpawn.enemy("res://src/gameplay/enemies/naked_koopa.tscn", world, Vector2(150, 120), {"color":"green", "start_direction":1}) as NakedKoopa
	await _frames(120)
	check("naked koopa actually enters and recovers shell", not is_instance_valid(naked) and not is_instance_valid(shell))
	var restored: Koopa = null
	for node: Node in world.get_children():
		if node is Koopa:
			restored = node as Koopa
	check("re-entry produces green walking koopa at ground", restored != null and restored.color == "green" and absf(restored.feet_position().y - 120.0) < 1.0)
	await _clear()
	floor_at(Vector2(300, 128), Vector2(600, 16))
	var beetle: BuzzyBeetle = actor("smm.enemy.buzzy_beetle", Vector2(150, 112)) as BuzzyBeetle
	beetle.receive_hit(EntityHit.new(EntityHit.Kind.STOMP))
	await _frames(641)
	var recovered: bool = false
	for node: Node in world.get_children():
		if node is BuzzyBeetle and not node.is_dead:
			recovered = true
	check("buzzy shell recovers after 640 active frames", recovered)
	await _clear()
	floor_at(Vector2(300,128), Vector2(600,16))
	shell = actor("smm.enemy.koopa_shell", Vector2(150,112), {"shell_kind":"buzzy"}, false) as KoopaShell
	shell.occupant = "buzzy"
	shell.recovery_left = 2
	shell._thrown(Vector2(132,0))
	await _frames(10)
	check("sliding occupied shell suspends stationary recovery", is_instance_valid(shell) and shell.recovery_left == 2 and shell.state == Enemy.State.THROWN)
	shell.receive_hit(EntityHit.new(EntityHit.Kind.STOMP))
	await _frames(2)
	check("stopping shell resumes stationary recovery", not is_instance_valid(shell))
	await _clear()
	floor_at(Vector2(300, 128), Vector2(600, 16))
	shell = actor("smm.enemy.koopa_shell", Vector2(150, 112), {}, false) as KoopaShell
	shell._thrown(Vector2(0, -180))
	await _frames(50)
	check("high-thrown shell lands stationary", shell.state == Enemy.State.STUNNED and absf(shell.velocity.x) < 1.0)
	var player: Player = player_at(Vector2(10, 100))
	player.velocity.x = 100
	shell.carried_by = player
	shell._thrown(Vector2(132, 0))
	check("shell inherits half player momentum", shell.velocity.x == 170 and shell._slide_target == 182)
	await _frames(5)
	check("shell accelerates to sliding target", shell.velocity.x == 182)
	await _clear()
	floor_at(Vector2(300, 128), Vector2(600, 16))
	var a: KoopaShell = actor("smm.enemy.koopa_shell", Vector2(150, 112), {}, false) as KoopaShell
	var b: KoopaShell = actor("smm.enemy.koopa_shell", Vector2(190, 112), {}, false) as KoopaShell
	a._thrown(Vector2(132, 0))
	b._thrown(Vector2(-132, 0))
	await _frames(20)
	check("two sliding shells defeat each other", a.is_dead and b.is_dead)
	await _clear()
	for id: String in ["koopa_green", "buzzy_beetle", "spiny"]:
		var enemy: Enemy = actor("smm.enemy." + id, Vector2(100,100)) as Enemy
		enemy.receive_hit(EntityHit.new(EntityHit.Kind.BUMP))
		check(id + " top bump transforms into shell", enemy.is_queued_for_deletion())
	var flipped: int = 0
	for node: Node in world.get_children():
		if node is KoopaShell:
			var changed: KoopaShell = node as KoopaShell
			changed.process_mode = Node.PROCESS_MODE_DISABLED
			flipped += 1
			check(changed.shell_kind + " flipped shell keeps occupant and timer", changed.flipped and not changed.occupant.is_empty() and changed.recovery_left in [600, 640])
	check("three bumped enemies produce three flipped shells", flipped == 3)
	await _clear()
	shell = actor("smm.enemy.koopa_shell", Vector2(100,100), {"shell_kind":"buzzy"}) as KoopaShell
	shell.occupant = "buzzy"
	check("occupied buzzy shell survives thrown enemy", not shell.receive_hit(EntityHit.new(EntityHit.Kind.THROWN)).affected and not shell.is_dead)
	check("occupied buzzy shell survives explosion", not shell.receive_hit(EntityHit.new(EntityHit.Kind.EXPLOSION)).affected and not shell.is_dead)
	check("star defeats occupied buzzy shell", shell.receive_hit(EntityHit.new(EntityHit.Kind.STAR)).affected and shell.is_dead)

func _existing_recovery() -> void:
	await _clear()
	var galoomba: Galoomba = actor("smm.enemy.galoomba") as Galoomba
	var player: Player = player_at()
	galoomba.stomp(false)
	var input: PlayerInputFrame = PlayerInputFrame.new()
	input.run = true
	player.carry.add_candidate(galoomba)
	player.carry.tick(input, true, 1, false, true)
	await _frames(15)
	check("held galoomba suspends recovery", player.carry.is_carrying() and galoomba._recovery_left == 600)
	player.carry.drop(Vector2.ZERO)
	for frame: int in 599:
		galoomba._process_state(1.0 / 60.0)
	check("galoomba retains remaining recovery after carry", galoomba._recovery_left == 1 and galoomba.state == Enemy.State.STUNNED)
	galoomba._process_state(1.0 / 60.0)
	check("galoomba resumes walking after expiry", galoomba.state == Enemy.State.WALKING)
	galoomba.stomp(false)
	galoomba._on_thrown(Vector2(100, -30))
	var target: Enemy = actor("smm.enemy.goomba", Vector2(200, 100)) as Enemy
	galoomba._on_attack_contact(target)
	galoomba._process_state(1.0 / 60.0)
	check("thrown galoomba uses hit contract and dies on hit", target.is_dead and galoomba.is_dead)

func _bombs() -> void:
	await _clear()
	var bomb: BobOmb = actor("smm.enemy.bob_omb") as BobOmb
	var player: Player = player_at()
	bomb.ignite()
	player.carry.add_candidate(bomb)
	var input: PlayerInputFrame = PlayerInputFrame.new()
	input.run = true
	player.carry.tick(input, true, 1, false, true)
	check("primed bomb picked up", player.carry.is_carrying() and bomb.state == Enemy.State.HELD)
	await _frames(10)
	check("held bomb fuse keeps ticking", bomb.fuse.remaining == 290)
	var before: int = bomb.fuse.remaining
	check("held bomb fuse has pausable independent mode", bomb.fuse.process_mode == Node.PROCESS_MODE_PAUSABLE)
	get_tree().paused = true
	await _frames(5)
	check("held fuse pauses with tree", bomb.fuse.remaining == before)
	get_tree().paused = false
	GameManager.freeze_gameplay(8)
	await _frames(5)
	check("held fuse pauses during transform", bomb.fuse.remaining == before)
	GameManager.clear_gameplay_freeze()
	player.carry.drop(Vector2.ZERO)
	bomb.process_mode = Node.PROCESS_MODE_DISABLED
	bomb.ignite()
	check("drop and re-ignite do not refresh fuse", bomb.fuse.remaining == before)
	player.carry.tick(input, true, 1, false, true)
	bomb.fuse.remaining = 1
	await _frames(2)
	check("held bomb explodes and clears carry", not player.carry.is_carrying() and not is_instance_valid(bomb))
	player._process_events()
	check("held explosion can damage player", player.power_form == PowerUpManager.Form.DEAD)
	var explosions: int = 0
	for node: Node in world.get_children():
		if node is EntityExplosion:
			explosions += 1
	check("single explosion spawned", explosions == 1)
	await _clear()
	bomb = actor("smm.enemy.bob_omb") as BobOmb
	bomb.receive_hit(EntityHit.new(EntityHit.Kind.FIREBALL, null, null, 1))
	check("first fireball only ignites bomb", bomb.primed and bomb.velocity == Vector2.ZERO)
	bomb.fuse.remaining = 200
	bomb.receive_hit(EntityHit.new(EntityHit.Kind.FIREBALL, null, null, -1))
	check("primed bomb fireball push retains fuse", bomb.velocity == Vector2(-36, -45) and bomb.fuse.remaining == 200)
	bomb.receive_hit(EntityHit.new(EntityHit.Kind.EXPLOSION))
	check("exploded neighboring bomb dies without chain explosion", bomb.is_dead and world.get_child_count() == 1)
	await _clear()
	var enemy: Enemy = actor("smm.enemy.goomba") as Enemy
	var explosion: EntityExplosion = EntityExplosion.new()
	explosion.position = Vector2(100, 100)
	world.add_child(explosion)
	await _frames(2)
	check("explosion defeats nearby enemy", enemy.is_dead)
	check("explosion records each target once", explosion._hit.has(enemy.get_instance_id()))
	await _frames(30)
	check("explosion expires", not is_instance_valid(explosion))

func _plants() -> void:
	for direction: String in ["up", "down", "left", "right"]:
		await _clear()
		var plant: PiranhaPlant = actor("smm.enemy.piranha_plant", Vector2(200, 100), {"orientation":direction}, false) as PiranhaPlant
		check(direction + " hidden is harmless", not plant.can_damage_player() and plant.collision_layer == 0)
		plant.extension = 4
		plant._update_exposure()
		var response: EntityHitResult = plant.receive_hit(EntityHit.new(EntityHit.Kind.FIREBALL))
		check(direction + " partially sheltered flower consumes fireball without damage", not response.affected and response.consume_attack and not plant.is_dead)
		plant.extension = 0
		plant._update_exposure()
		await _frames(34)
		check(direction + " fully extended", plant.phase == PiranhaPlant.Phase.EXPOSED and plant.extension == 16.0)
		check(direction + " exposed geometry", plant.can_damage_player() and plant.collision_layer != 0)
		await _frames(122)
		check(direction + " retracts harmlessly", plant.phase == PiranhaPlant.Phase.HIDDEN and plant.extension == 0.0)
	await _clear()
	var player: Player = player_at(Vector2(200, 80))
	var plant: PiranhaPlant = actor("smm.enemy.piranha_plant", Vector2(200, 100), {}, false) as PiranhaPlant
	await _frames(40)
	check("near player inhibits emergence", plant.phase == PiranhaPlant.Phase.HIDDEN and plant.extension == 0.0)
	player.position.x = 400
	await _frames(34)
	check("leaving mouth releases inhibition", plant.phase == PiranhaPlant.Phase.EXPOSED)

func _player_effects() -> void:
	await _clear()
	var player: Player = player_at()
	var base_walk: float = player.physics_profile.walk_max
	player.take_damage()
	check("star pickup accepted before queued damage", player.collect_star())
	player._process_events()
	check("same-frame star protects queued damage", player.effects.star_left == 600 and player.power_form == PowerUpManager.Form.SMALL)
	var enemy: Spiny = actor("smm.enemy.spiny", Vector2(80, 100)) as Spiny
	player.register_enemy_overlap(enemy)
	player._resolve_enemy_contacts()
	check("star contact defeats spiny through hit contract", enemy.is_dead)
	player.unregister_enemy_overlap(enemy)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	GameManager.freeze_gameplay(100)
	await _frames(5)
	check("star timer suspends during transform freeze", player.effects.star_left == 600)
	GameManager.clear_gameplay_freeze()
	get_tree().paused = true
	await _frames(5)
	check("star timer suspends during tree pause", player.effects.star_left == 600)
	get_tree().paused = false
	await _frames(12)
	check("star decrements only active player physics frames", player.effects.star_left == 588)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.effects.apply_star()
	check("star timer 600", player.effects.star_left == 600)
	check("star speed bonus 30", player.effects.speed_bonus() == 30)
	player.take_damage()
	player._process_events()
	check("star blocks ordinary damage", player.power_form == PowerUpManager.Form.SMALL)
	for index: int in 599:
		player.effects.finish_active_tick()
	check("star remains for final frame", player.effects.star_left == 1)
	player.effects.apply_star()
	check("star refreshes to 600", player.effects.star_left == 600)
	for index: int in 600:
		player.effects.finish_active_tick()
	check("star expires and restores speed", player.effects.star_left == 0 and player.effects.speed_bonus() == 0.0 and player.physics_profile.walk_max == base_walk)
	player.effects.apply_star()
	player.die()
	player._physics_process(1.0 / 60.0)
	check("forced death clears star", player.power_form == PowerUpManager.Form.DEAD and player.effects.star_left == 0)
	player.reset_to(Vector2(40, 100))
	check("respawn clears effects", player.motion.speed_bonus == 0 and player.effects.star_left == 0)
	var profile: PlayerPhysicsProfile = player.physics_profile.duplicate(true) as PlayerPhysicsProfile
	var motion: PlayerMotion = PlayerMotion.new(profile)
	var input: PlayerInputFrame = PlayerInputFrame.new()
	input.axis = 1.0
	input.run = true
	motion.speed_bonus = 30
	for index: int in 120:
		motion._update_horizontal(input, true, 1.0 / 60.0)
	check("star raises actual running threshold", motion.velocity.x > profile.run_max + 25 and motion.velocity.x < profile.run_max + 36)
	motion.speed_bonus = 0
	for index: int in 60:
		motion._update_horizontal(input, true, 1.0 / 60.0)
	check("expiry removes overspeed gradually", motion.velocity.x < profile.run_max + 6)

func _fireballs() -> void:
	for id: String in ["goomba", "koopa_green", "buzzy_beetle", "koopa_shell"]:
		await _clear()
		var enemy: Enemy = actor("smm.enemy." + id, Vector2(100,100), {"shell_kind":"buzzy"} if id == "koopa_shell" else {}) as Enemy
		if enemy is KoopaShell:
			(enemy as KoopaShell)._thrown(Vector2(132,0))
		var fireball: PlayerFireball = PlayerFireball.new(load("res://data/physics/base_physics.tres") as PlayerPhysicsProfile, -1)
		fireball.position = Vector2(108,100)
		world.add_child(fireball)
		await _frames(8)
		check(id + " actual fireball consumed on contact", not is_instance_valid(fireball))
		check(id + " native fireball immunity response", enemy.is_dead == (id not in ["buzzy_beetle", "koopa_shell"]))

func _lifecycle_snapshot(node: Node2D) -> Dictionary:
	var result: Dictionary = {"position":node.position}
	if node is CharacterBody2D:
		result["velocity"] = (node as CharacterBody2D).velocity
	if node is Enemy:
		result["frames"] = (node as Enemy)._state_frames
		result["animation"] = (node as Enemy)._animation_phase
	if node is BobOmb:
		result["fuse"] = (node as BobOmb).fuse.remaining
	if node is Galoomba:
		result["recovery"] = (node as Galoomba)._recovery_left
	if node is PowerUpPickup:
		result["animation"] = (node as PowerUpPickup)._frame_phase
	if node is Coin:
		result["animation"] = (node as Coin)._frame_phase
	if node is PiranhaPlant:
		result["cycle"] = (node as PiranhaPlant).phase_left
	return result

func _lifecycle() -> void:
	await _clear()
	var ids: Array[String] = ["enemy.goomba", "enemy.galoomba", "enemy.koopa_green", "enemy.koopa_red", "enemy.koopa_shell", "enemy.buzzy_beetle", "enemy.spiny", "enemy.bob_omb", "enemy.piranha_plant", "item.super_mushroom", "item.fire_flower", "item.coin", "item.super_star", "item.one_up", "item.coin_10", "item.coin_30", "item.coin_50"]
	var nodes: Array[Node2D] = []
	for index: int in ids.size():
		var node: Node2D = actor("smm." + ids[index], Vector2(100 + index * 40, 100), {}, false)
		nodes.append(node)
		if node is BobOmb:
			(node as BobOmb).ignite()
		if node is Galoomba:
			(node as Galoomba).stomp(false)
	await _frames(2)
	var before: Array[Dictionary] = []
	for node: Node2D in nodes:
		before.append(_lifecycle_snapshot(node))
	get_tree().paused = true
	await _frames(5)
	for index: int in nodes.size():
		check(ids[index] + " native pause retains motion and clocks", _lifecycle_snapshot(nodes[index]) == before[index])
	get_tree().paused = false
	GameManager.freeze_gameplay(100)
	await _frames(5)
	for index: int in nodes.size():
		check(ids[index] + " native freeze retains motion and clocks", _lifecycle_snapshot(nodes[index]) == before[index])
	GameManager.clear_gameplay_freeze()
	var player: Player = player_at()
	var effects: PlayerStatusEffects = player.effects
	effects.apply_star()
	await _clear()
	check("scene exit clears retained star status", effects.star_left == 0 and not GameManager.is_gameplay_frozen)
	check("scene reset removes all spawned entities", world.get_child_count() == 0)

func _blocks() -> void:
	for content: String in ["coin", "super_mushroom", "fire_flower", "super_star", "one_up"]:
		await _clear()
		var player: Player = player_at()
		var block: QuestionBlock = actor("smm.block.question", Vector2(100, 100), {"contained_item":"smm.item." + content}) as QuestionBlock
		block.hit_by_attack(EntityHit.new(EntityHit.Kind.SHELL, null, player))
		check(content + " question becomes used", block.current_state == InteractableBlock.State.EMPTY)
		var count: int = world.get_child_count()
		block.hit_by_attack(EntityHit.new(EntityHit.Kind.SHELL, null, player))
		check(content + " question releases only once", world.get_child_count() == count)
	for id: String in ["hard", "turn"]:
		await _clear()
		var block: InteractableBlock = actor("smm.block." + id) as InteractableBlock
		block.hit_by_attack(EntityHit.new(EntityHit.Kind.EXPLOSION))
		check(id + " destroyed by explosion", block.is_queued_for_deletion() and block.collision_layer == 0)
	await _clear()
	GameManager.reset_coins()
	var question: QuestionBlock = actor("smm.block.question") as QuestionBlock
	question.hit_by_attack(EntityHit.new(EntityHit.Kind.EXPLOSION))
	check("unowned explosion releases coin once", question.current_state == InteractableBlock.State.EMPTY and GameManager.coins == 1)
	question.hit_by_attack(EntityHit.new(EntityHit.Kind.EXPLOSION))
	check("used exploded question has no duplicate reward", GameManager.coins == 1)
	await _clear()
	var turning: TurnBlock = actor("smm.block.turn") as TurnBlock
	turning.hit_by_player(null)
	check("shell can turn flip block", turning.current_state == InteractableBlock.State.TURNING and turning.body_shape.disabled)
	var explosion: EntityExplosion = EntityExplosion.new()
	explosion.position = turning.position
	world.add_child(explosion)
	await _frames(2)
	check("explosion destroys already turning block", not is_instance_valid(turning))

func _catalog() -> void:
	var rule: Dictionary = {"type":"int", "enum":[-1.0, 1.0]}
	check("registry accepts integer enum from code", Registry._valid_runtime_property(1, rule))
	check("registry accepts integer enum from JSON", Registry._valid_runtime_property(-1.0, rule))
	check("registry rejects fractional enum", not Registry._valid_runtime_property(0.5, rule))
	check("registry rejects out-of-range enum", not Registry._valid_runtime_property(2, rule))
	var catalog: EditorCatalog = EditorCatalog.new()
	for definition: Dictionary in Registry.get_by_style(&"smw"):
		if definition["category"] == "terrain":
			continue
		var id: String = String(definition["id"])
		check(id + " preview available", catalog.preview_for(id) != null)
	for key: String in ["enemy", "item"]:
		for entry: Dictionary in catalog.palette_entries(key):
			var id: String = String(entry["id"])
			if not id.is_empty():
				check("palette registered " + id, Registry.has_object(id))
