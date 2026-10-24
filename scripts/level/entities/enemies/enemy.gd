# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Enemy
extends Entity
## Represents an enemy with configurable settings on how it interacts with the
## player.

## Defines what type of stomping is allowed on an enemy.
enum Stompability {
	## Allows the player to stomp this enemy with any kind of jump. Triggers the
	## [signal stomped] signal.
	STOMPABLE,
	## Allows the player to only recoil off the enemy with a spin jump. Triggers
	## the [signal stomped] signal.
	RECOIL,
	## Does not allow the player to stomp this enemy. Does not trigger the
	## [signal stomped] signal.
	NONE,
	## Does nothing; doesn't bounce the player and doesn't damage it. Triggers
	## the [signal stomped] signal.
	CUSTOM,
}

## Fired when the enemy is stomped on by the player. Only fires if 
signal stomped(player: Player)

## The hitbox [Area2D] this enemy will use to damage the player.
@export var hitbox: Area2D

## The stompability of this enemy.
var stomp_behavior := Stompability.STOMPABLE

var _player_stomped_on_enter := false
var fireproof := false
var hardness := 0
var _contact_turned := false


func uses_source_deactivation() -> bool:
	return true


func uses_source_death_stop() -> bool:
	return true


## Projectile controllers use this entry point; kill() remains a forced defeat.
func hit_by_projectile(kind: StringName, launch_direction := 0.0) -> bool:
	if is_queued_for_deletion() or (kind == &"fire" and fireproof):
		return false
	kill(launch_direction)
	return true


## Preserve the collision partner for families whose death direction depends
## on its actual speed/bounds, rather than Mario's facing.
func hit_by_actor(kind: StringName, _impact: CollisionObject2D, fallback_direction := 0.0) -> bool:
	return hit_by_projectile(kind, fallback_direction)


func source_hit_direction(impact: CollisionObject2D, weighted_bounds := false) -> float:
	if not is_instance_valid(impact):
		return 0
	if impact is CharacterBody2D and impact.velocity.x != 0:
		return signf(impact.velocity.x)
	var target := Utility.get_bounding_box(self)
	var incoming := Utility.get_bounding_box(impact)
	# Monty's source compares left + right/2 (not the center). The Bros use
	# target.right in both terms, reducing their stationary test to left edges.
	var difference := target.position.x - incoming.position.x
	if weighted_bounds:
		difference += (target.end.x - incoming.end.x) / 2
	return signf(difference)


func spawn_source_defeat(style: EnemyDefeatStyle, facing: float, launch_direction: float, smoke := false) -> void:
	if is_queued_for_deletion():
		return
	var effect := SwimmingEnemyDefeat.new()
	effect.variant = style
	effect.sub_area = sub_area
	effect.direction = facing
	effect.velocity.x = 60 * signf(launch_direction)
	effect.position = sub_area.get_foreground().to_local(global_position + style.dead_offset)
	sub_area.add_deferred(effect)
	if smoke:
		EnemyEffect.play_once(sub_area, &"spr_spinthump", global_position + style.dead_offset + Vector2(0, -5), 18)
	queue_free()


## Other families retain their existing block responses. The block itself is
## also supplied because it, rather than its activator, is source `other`.
func bumped_by_block(_block: PhysicsBody2D, activator: PhysicsBody2D) -> void:
	if has_method("bumped_from_below"):
		call("bumped_from_below", activator)


func source_block_defeat(block: PhysicsBody2D) -> void:
	if is_queued_for_deletion() or velocity.y < 0:
		return
	if hit_by_actor(&"block", block):
		EnemyEffect.sound_once(sub_area, "res://assets/openwe/sounds/snd_klock.ogg")
		if is_instance_valid(level.hud.player) and not level.hud.player.is_dead() and level.status == Level.Status.PLAYING:
			level.hud.player.score += 200


func kill(launch_direction := 0.0) -> void:
	if is_queued_for_deletion():
		return
	var graphics: Node2D
	var sprite_name := get_defeat_sprite()
	if SpriteLibrary.has_sprite(sprite_name):
		graphics = Node2D.new()
		var sprite := SpriteLibrary.make_sprite(sprite_name)
		sprite.stop()
		sprite.frame = mini(get_defeat_frame(), sprite.sprite_frames.get_frame_count(&"default") - 1)
		graphics.add_child(sprite)
		graphics.position = sub_area.get_foreground().to_local(global_position + Vector2(0, -8))
	else:
		graphics = $Graphics.duplicate() as Node2D
		graphics.position = sub_area.get_foreground().to_local($Graphics.global_position)
	graphics.name = "Dead" + name
	graphics.z_index = GameConstants.Layers.Z_DEAD
	graphics.z_as_relative = false
	graphics.set_script(DeadEntity)
	if launch_direction == 0:
		launch_direction = level.hud.player.direction if is_instance_valid(level.hud.player) else -1
	graphics.velocity = Vector2(60 * signf(launch_direction), -240)
	sub_area.add_deferred(graphics)
	queue_free()


func get_defeat_sprite() -> StringName:
	return &""


func get_defeat_frame() -> int:
	return 0


func _ready() -> void:
	if hitbox == null:
		push_warning("Enemy does not have a damage hitbox! ",
			"Please add one via the \"hitbox\" variable.")
		return
	hitbox.body_entered.connect(func(entity): _body_handling(true, entity))
	hitbox.body_exited.connect(func(entity): _body_handling(false, entity))
	stomped.connect(_stomped)


func _stomped(player: Player) -> void:
	match stomp_behavior:
		Stompability.STOMPABLE:
			player.bounce()
			if player.state_machine.current_state is PlayerJumpingState or player.is_swimming():
				player.sounds.stream = preload("uid://c345xnns7om3m")
				player.sounds.play()
				player.spawn_spin_thump()
			elif player.state_machine.current_state is PlayerSpinJumpingState:
				_spin_stomp()
		Stompability.RECOIL:
			if player.state_machine.current_state is PlayerSpinJumpingState:
				player.bounce()
				player.sounds.stream = preload("uid://e8157k7h45xi")
				player.sounds.play()
				player.spawn_spin_thump()
			else:
				player.damage()
		Stompability.NONE:
				player.damage()
		# Stompability.CUSTOM has no default behavior


func _spin_stomp() -> void:
	var spin_smoke = SpinSmoke.create()
	add_sibling(spin_smoke)
	spin_smoke.global_position = global_position
	spin_smoke.position.y -= 8
	queue_free()
	

func _physics_process(_delta: float) -> void:
	_contact_turned = sub_area.actor_contacts.turn_enemy(self) if sub_area.actor_contacts != null else false
	move_source_and_slide()
	if _is_below_world():
		queue_free()


## Large actors can retain their source top-edge culling boundary.
func _is_below_world() -> bool:
	return global_position.y >= Player.VOID_LEVEL


func _body_handling(entering: bool, body: Node2D) -> void:
	if is_queued_for_deletion():
		return
	var player = body as Player
	if player == null or player.is_dead() or player.is_frozen():
		return
	if player.has_star():
		player.star_hit(self)
		return
	if player.state_machine.current_state is PlayerSlopeSlideState and player.state_machine.current_state.hit(self):
		return
	if player.helmet_deflects(self):
		return
	if stomp_behavior == Stompability.NONE:
		if entering:
			player.damage()
		return
	var player_rect = Utility.get_bounding_box(player)
	player_rect.position -= player.global_position
	player_rect.position += player.previous_position
	var self_rect = Utility.get_bounding_box(self)
	
	if entering:
		_player_stomped_on_enter = true
	elif _player_stomped_on_enter:
		_player_stomped_on_enter = false
		return
	if player_rect.end.y < self_rect.position.y + 5:
		stomped.emit(player)
	else:
		player.damage()
