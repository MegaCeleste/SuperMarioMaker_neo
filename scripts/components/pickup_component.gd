# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PickupComponent
extends Component
## Makes an [Entity] holdable by the [Player].
##
## The [PickupComponent] is required for the [Player] to be able to hold an
## entity. The component also provides default behavior for items.

## Represents the way an item was released by the player.
enum ReleaseType {
	## The item was kicked in the player's direction. This release type happens
	## when the player lets go of the item with no additional actions.
	KICKED,
	## The item was thrown up above the player. This release type happens when
	## the player lets go and is looking up simultaneously.
	THROWN_UP,
	## The item was dropped next to the player. This release type happens when
	## the player lets go and is ducking simultaneously.
	DROPPED,
	## The active player body was replaced, as with obj_frozenmario. Release
	## at the current position without a kick, upward throw or drop impulse.
	DETACHED,
	## A Sledge landing interrupts the hold after Mario's horizontal stop.
	STUNNED,
}

## SMM2 (SMW style) carry items share one throw and one free motion: the
## spring, P-switch, POW block, stunned Galoomba and lit Bob-omb. Shells have
## their own. Measured from SMM2 at 60 fps.
## Gravity 3/16 px/frame^2, falling at most 4 px/frame.
const CARRY_GRAVITY := 675.0
const CARRY_MAX_FALL := 240.0
## A kicked item stops about 10 frames after landing.
const CARRY_FLOOR_FRICTION := 900.0
## Kick: 2.625 px/frame plus Mario's speed, with a 1.75 px/frame hop.
const KICK_SPEED := 157.5
const KICK_HOP := -105.0
## Up throw: 6.4 px/frame, straight up when Mario stands still.
const THROW_UP_SPEED := -384.0

## Emitted when the player picks up the item. Note that the item won't be in its
## held position yet when the signal is emitted. There isn't a convenient way to
## get this position, as you would have to wait until the next frame ends.
signal picked_up(player: Player)
## Emitted when the player lets go of the item along with the way it was
## released by the player.
signal dropped(player: Player, release_type: ReleaseType)

## The area used to detect the player for pick-ups. Must have the player
## collision mask selected.
@export var check_area: Area2D:
	set = _set_check_area
## Whether the player can hold this item. If this is set to [code]false[/code],
## the player will not pick up the item even in the right conditions.
var can_be_held := true
## Whether the item uses the default dropping behavior. This should be kept on
## for consistency across items, however you are free to create your own unique
## behavior if the default does not fit your needs.
var use_default_behavior := true
## The two source hold parents use different immunity alarms. Ordinary shells
## clear alarm6 after 15 ticks; Galoomba has no alarm6 handler and keeps it.
var stun_pickup_immunity := 15.0 / 60
var pickup_immunity_left := 0.0
## The physics tick in which this component was ready. Used to prevent immediate
## pickups when the entity enters the tree.
var start_tick: int

var _player: Player


func _ready() -> void:
	# trigger setter
	#check_area = check_area
	picked_up.connect(_picked_up)
	dropped.connect(_dropped)
	start_tick = Engine.get_physics_frames()


## Returns the [Player] currently holding this item or [code]null[/code] if no
## one is holding it. Can be used to check whether this item is being held.
func get_holder() -> Player:
	return _player


func _physics_process(delta: float) -> void:
	if pickup_immunity_left > 0:
		pickup_immunity_left = maxf(0, pickup_immunity_left - delta)
		if pickup_immunity_left < 0.00001:
			pickup_immunity_left = 0
	if _player != null or check_area == null or not check_area.monitoring:
		return
	# Source pickup probes run every Step, including after immunity ends or
	# Run is pressed while the bodies are already overlapping.
	for body in check_area.get_overlapping_bodies():
		_body_entered(body)


func _body_entered(body: Node2D) -> void:
	var player = body as Player
	if get_parent().is_queued_for_deletion():
		return
	if player != null and player.has_star() and player.star_hit(get_parent()):
		return
	if Engine.get_physics_frames() <= start_tick + 1:
		return
	if player == null or not can_be_held or pickup_immunity_left > 0:
		return
	if not Input.is_action_pressed("player_run"):
		return
	player.give_item(get_parent())


func _picked_up(player: Player) -> void:
	_player = player


func _dropped(player: Player, release_type: ReleaseType) -> void:
	_player = null
	if release_type == ReleaseType.STUNNED:
		pickup_immunity_left = stun_pickup_immunity
	if not use_default_behavior:
		return
	get_parent().velocity = throw_velocity(player, release_type)


## The shared SMM2 carry-item release velocity. Holding Down sets the item
## down in front of Mario with no speed.
static func throw_velocity(player: Player, release_type: ReleaseType) -> Vector2:
	match release_type:
		ReleaseType.KICKED:
			return Vector2((KICK_SPEED + absf(player.velocity.x)) * player.direction, KICK_HOP)
		ReleaseType.THROWN_UP:
			return Vector2(30 * player.direction if player.velocity.x != 0 else 0, THROW_UP_SPEED)
		ReleaseType.STUNNED:
			return Vector2(60 * player.direction, 0)
	return Vector2.ZERO


func _set_check_area(v: Area2D) -> void:
	if check_area != null:
		check_area.body_entered.disconnect(_body_entered)
	if v != null and not v.body_entered.is_connected(_body_entered):
		v.body_entered.connect(_body_entered)
	check_area = v
