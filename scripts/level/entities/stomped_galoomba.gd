# SPDX-License-Identifier: AGPL-3.0-or-later
class_name StompedGaloomba
extends Entity

@export var variant: GoombaVariant = preload("res://resources/content/smw_goomba_normal.tres")
var recovery_direction := -1
var _age := 0.0
var _recovering := false
## obj_holdparent inmune with alarm[3] = 15: no touch kick meanwhile.
var kick_immunity := 15
## Collision_obj_mario stomp height: 12 for obj_bobomb_hold, else 5.
var stomp_margin := 5.0

const DECEL = 630.0


func uses_source_deactivation() -> bool:
	return true


func uses_source_death_stop() -> bool:
	return true


func _ready() -> void:
	# obj_enemyparent_held starts alarm3=15 for Galoomba, but stun writes
	# alarm6=15. Neither Galoomba nor its ancestors handles alarm6.
	%PickupComponent.pickup_immunity_left = 15.0 / 60
	%PickupComponent.stun_pickup_immunity = INF
	if SpriteLibrary.has_sprite(variant.held_sprite):
		var sprite: AnimatedSprite2D = $Graphics/Sprite
		SpriteLibrary.configure_sprite(sprite, variant.held_sprite, &"walk", 9, Vector2(0, -16))
		sprite.position.y = SpriteLibrary.contact_draw_y(variant.held_sprite)
		sprite.flip_v = false


func _physics_process(_delta: float) -> void:
	if is_queued_for_deletion():
		return
	super(_delta)
	var holder: Player = %PickupComponent.get_holder()
	if holder == null and global_position.y >= Player.VOID_LEVEL:
		queue_free()
		return
	if kick_immunity > 0:
		kick_immunity -= 1
	if _tick_timer(_delta, holder):
		return
	if holder != null:
		recovery_direction = holder.direction
		velocity = Vector2.ZERO
		sub_area.actor_contacts.hit_from_galoomba(self)
		return
	var old_velocity = velocity
	move_source_and_slide()
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0, DECEL * _delta)
		if old_velocity.y >= 30:
			velocity.y = old_velocity.y / -2.0
	velocity.x = clamp(velocity.x, -240, 240)
	sub_area.actor_contacts.hit_from_galoomba(self)
	if not is_queued_for_deletion():
		_player_contact()


## Galoomba alarms 1 and 2; returns true once this body has been replaced.
func _tick_timer(delta: float, holder: Player) -> bool:
	_age += delta
	# Alarm_2 checks for a holder at 540 frames, resetting both alarms.
	if _age >= variant.shake_time and holder != null:
		_age = 0
	$Graphics/Sprite.position.x = (1 if int(_age * 60) % 2 == 0 else -1) \
			if _age >= variant.shake_time else 0
	if _age >= variant.recovery_time and not _recovering:
		_recover()
		return true
	return false


## obj_holdparent/Collision_obj_mario while nobody holds it: a falling Mario
## above the top runs the stomp event (Other_11); any other touch without
## the Run button kicks it 1px/frame faster than Mario and 0.5px/frame up.
func _player_contact() -> void:
	var player := level.get_living_player()
	if player == null or player.is_frozen() or player.held_item == self:
		return
	var box := Utility.get_bounding_box(self)
	var hero := Utility.get_bounding_box(player)
	if not box.intersects(hero):
		return
	var vspeed := velocity.y / 60
	if hero.end.y < box.position.y - vspeed + stomp_margin and player.velocity.y > 0:
		_stomped_by(player)
		return
	if kick_immunity > 0 or _can_hold(player):
		return
	var swim := 1 if player.is_swimming() else 0
	var right := box.get_center().x >= hero.get_center().x
	velocity.x = player.velocity.x + (60 - 60 * swim) * (1 if right else -1)
	velocity.y = -30 + 60 * swim
	recovery_direction = 1 if right else -1
	kick_immunity = 15
	EnemyEffect.sound_once(sub_area, SoundLibrary.path("snd_kick"))
	player.spawn_spin_thump(player.global_position)


## scr_canhold: Run is held and Mario carries nothing, so the pickup wins.
func _can_hold(player: Player) -> bool:
	return Input.is_action_pressed("player_run") and player.held_item == null


## obj_galoomba_hold/Other_11: only a spin jump defeats it, in a spin smoke.
func _stomped_by(player: Player) -> void:
	if not player.state_machine.current_state is PlayerSpinJumpingState:
		return
	player.bounce()
	var smoke := SpinSmoke.create()
	sub_area.add(smoke)
	smoke.global_position = global_position + Vector2(0, -8)
	_recovering = true
	queue_free()


## Native physical-solid defeats share the held family's source death art.
## Derived from obj_galoomba_hold/Other_10 (OpenWE, AGPL-3.0-or-later).
func kill(launch_direction := 0.0) -> void:
	if is_queued_for_deletion():
		return
	_recovering = true
	var holder: Player = %PickupComponent.get_holder()
	if holder != null:
		holder.forget_held_item(self)
	var dead := DeadEntity.new()
	dead.z_index = GameConstants.Layers.Z_DEAD
	dead.z_as_relative = false
	var sprite := SpriteLibrary.make_sprite(variant.dead_sprite)
	sprite.pause()
	sprite.frame = 2
	sprite.flip_h = recovery_direction < 0
	dead.add_child(sprite)
	dead.position = sub_area.get_foreground().to_local(global_position - Vector2(0, 8))
	dead.velocity = Vector2(60 * signf(launch_direction), -240)
	sub_area.add_deferred(dead)
	queue_free()


## obj_galoomba_hold/Alarm_1 and obj_galoomba_hold2/Alarm_1 retain the type.
func _recover() -> void:
	if _recovering:
		return
	_recovering = true
	var enemy: Galoomba = load("res://scenes/level/entities/galoomba.tscn").instantiate()
	enemy.variant = variant
	enemy.position = sub_area.get_foreground().to_local(global_position)
	enemy.get_node("SlideComponent").direction = recovery_direction
	enemy.velocity = Vector2(30 * recovery_direction, -variant.recovery_hop_speed if is_on_floor() else 0)
	sub_area.add_deferred(enemy)
	queue_free()
