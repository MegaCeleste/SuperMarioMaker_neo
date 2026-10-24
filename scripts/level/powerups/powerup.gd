class_name Powerup
extends Resource
## Represents a powerup.

var player: Player


static func default_animate(
		tree: SceneTree,
		old_graphics: Node2D,
		new_graphics: Node2D,
		growing := false
) -> void:
	assert(tree == new_graphics.get_tree())
	cancel_animation(new_graphics)
	var animation := PowerupAnimation.new()
	animation.process_mode = Node.PROCESS_MODE_ALWAYS
	animation.old_graphics_id = old_graphics.get_instance_id()
	if growing:
		var player := new_graphics.get_parent().get_parent() as Player
		if player != null:
			if player.is_ducking():
				# Growth always uses big art, including blocked/voluntary crouch.
				animation.growth_texture = player.sprite.sprite_frames.get_frame_texture(player.sprite.animation, player.sprite.frame)
			else:
				var pose: StringName = &"hold_idle" if player.held_item != null else &"idle"
				animation.growth_texture = player.sprite.sprite_frames.get_frame_texture(pose, 0)
			animation.growth_facing = player.direction
	new_graphics.add_child(animation)


## End the preceding pause before taking a new snapshot or changing instantly.
static func cancel_animation(graphics: Node2D) -> void:
	for child in graphics.get_children():
		if child is PowerupAnimation:
			child.cancel()


## Runs once the state has just been enabled.
@warning_ignore("unused_parameter", "shadowed_variable")
func start(animate := false) -> void:
	pass


## Runs once the state is just about to stop in favor of a new powerup.
func end() -> void:
	pass


## Runs every frame. Clone of [method Node._process].
@warning_ignore("unused_parameter")
func process(delta: float) -> void:
	pass

## Runs every physics tick. Clone of [method Node._physics_process].
@warning_ignore("unused_parameter")
func physics_process(delta: float) -> void:
	pass
