# SPDX-License-Identifier: AGPL-3.0-or-later
class_name CarryBlock
extends Entity
## A 16x16 object Mario can carry, throw and stand on, shared by the P-switch
## and the POW block. Gravity, friction and releases follow the spring
## (source obj_pswitch, obj_block_pow_hold movement and throw events).

## Set by a throw or kick until the block first touches something.
var thrown := false
## Downward acceleration in px/s²; the spring's value unless a block sets its own.
var fall_gravity := PickupComponent.CARRY_GRAVITY
var _surface: AnimatableBody2D
var _sprite: AnimatedSprite2D
@onready var pickup: PickupComponent = $PickupComponent


func uses_source_deactivation() -> bool:
	return true


func uses_source_death_stop() -> bool:
	return true


func _ready() -> void:
	_surface = AnimatableBody2D.new()
	_surface.name = "Surface"
	_surface.sync_to_physics = false
	_surface.collision_layer = 1
	_surface.collision_mask = 0
	add_child(_surface)
	var top := CollisionShape2D.new()
	top.shape = RectangleShape2D.new()
	top.shape.size = Vector2(16, 3)
	top.one_way_collision = true
	top.one_way_collision_margin = 2
	top.position.y = -14.5
	_surface.add_child(top)
	add_collision_exception_with(_surface)
	_surface.add_collision_exception_with(self)
	pickup.use_default_behavior = false
	pickup.picked_up.connect(_picked_up)
	pickup.dropped.connect(_dropped)


## Top edge in global coordinates; the node origin is the bottom centre.
func top_y() -> float:
	return global_position.y - 16


func is_held() -> bool:
	return pickup.get_holder() != null or (is_instance_valid(level.hud.player) and level.hud.player.held_item == self)


func _physics_process(delta: float) -> void:
	if source_death_stopped():
		return
	if is_held():
		velocity = Vector2.ZERO
		return
	var falling := velocity.y > 0
	velocity.y = minf(PickupComponent.CARRY_MAX_FALL, velocity.y + fall_gravity * delta)
	var before_x := velocity.x
	move_source_and_slide()
	if thrown and ((is_on_floor() and falling) or (is_on_wall() and before_x != 0)):
		thrown = false
		_thrown_impact()
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0, PickupComponent.CARRY_FLOOR_FRICTION * delta)
	if is_on_wall():
		velocity.x = 0
	if position.y > Player.VOID_LEVEL:
		queue_free()


## Called once when a thrown block first lands or hits a wall.
func _thrown_impact() -> void:
	pass


func _picked_up(_player: Player) -> void:
	velocity = Vector2.ZERO
	_surface.collision_layer = 0
	collision_layer = 0
	thrown = false


func _dropped(player: Player, release: PickupComponent.ReleaseType) -> void:
	_surface.collision_layer = 1
	collision_layer = 8
	pickup.pickup_immunity_left = 0.25
	velocity = PickupComponent.throw_velocity(player, release)
	thrown = release in [PickupComponent.ReleaseType.THROWN_UP, PickupComponent.ReleaseType.KICKED]


## Mario lands on the top this tick (falling, feet within the top edge).
func player_landing(player: Player) -> bool:
	if not is_instance_valid(player) or player.is_dead() or player.is_traveling() or player.velocity.y < 0:
		return false
	var bounds := Utility.get_bounding_box(player)
	var previous := bounds.end.y + player.previous_position.y - player.global_position.y
	return bounds.end.x > global_position.x - 8 and bounds.position.x < global_position.x + 8 \
			and bounds.end.y >= top_y() - 3 and bounds.end.y <= top_y() + 3 and previous <= top_y() + 4


## Mario's head meets the bottom while he moves up (a bump from below).
func player_bump(player: Player) -> bool:
	if not is_instance_valid(player) or player.is_dead() or player.is_traveling() or player.velocity.y >= 0:
		return false
	var bounds := Utility.get_bounding_box(player)
	return bounds.end.x > global_position.x - 7 and bounds.position.x < global_position.x + 7 \
			and bounds.position.y <= global_position.y + 2 and bounds.position.y >= global_position.y - 6
