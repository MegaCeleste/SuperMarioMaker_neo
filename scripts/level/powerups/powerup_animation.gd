# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PowerupAnimation
extends Node
## The transformation pause belongs to the sprite lifetime, including cancellation.

var old_graphics_id: int
var _tree: SceneTree
var _was_paused := false
var _music_mode: Node.ProcessMode
var _active := false
var _tween: Tween
var growth_texture: Texture2D
var growth_facing := 1
var _growth_pose: Sprite2D
## Growth uses the original big texture immediately; only its height changes.
const GROWTH_HEIGHTS := [24, 20, 26, 20, 28]
const GROWTH_FULL_HEIGHT := 28.0
var _growth_base_scale := Vector2.ONE


func _ready() -> void:
	_tree = get_tree()
	_was_paused = _tree.paused
	_music_mode = MusicPlayer.process_mode
	_active = true
	_tree.paused = true
	MusicPlayer.process_mode = Node.PROCESS_MODE_ALWAYS
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if growth_texture != null:
		_prepare_growth()
		# Reference clip: intermediate heights, brief recoil, then full Super.
		var durations := [6, 5, 5, 6, 6]
		_show_growth(0)
		for phase in GROWTH_HEIGHTS.size():
			if phase > 0:
				_tween.tween_callback(_show_growth.bind(phase))
			_tween.tween_interval(durations[phase] / 60.0)
		_tween.finished.connect(cancel)
		return
	_show_old(false)
	# obj_mario_transform2 alarms: new pose for 6 ticks, then four 7-tick
	# phases. Visibility changes atomically; interpolating bool properties
	# leaves both drawings visible for a frame at every phase boundary.
	_tween.tween_interval(6.0 / 60)
	for old_visible in [true, false, true, false]:
		_tween.tween_callback(_show_old.bind(old_visible))
		_tween.tween_interval(7.0 / 60)
	_tween.finished.connect(cancel)


func _show_old(old_visible: bool) -> void:
	if is_instance_valid(_growth_pose):
		_growth_pose.hide()
	if is_instance_id_valid(old_graphics_id):
		instance_from_id(old_graphics_id).visible = old_visible
	get_parent().visible = not old_visible


func _prepare_growth() -> void:
	_growth_pose = Sprite2D.new()
	_growth_pose.name = "GrowthPose"
	_growth_pose.texture = growth_texture # Keep the source pixels and resource unchanged.
	_growth_pose.centered = false
	_growth_pose.transform = get_parent().transform
	_growth_base_scale = _growth_pose.scale
	_growth_pose.modulate = get_parent().modulate
	_growth_pose.self_modulate = get_parent().self_modulate
	_growth_pose.texture_filter = get_parent().texture_filter
	# Put the pivot at the bottom of the texture, then add the one-pixel overlap.
	# Scaling the whole sprite vertically now leaves the feet in exactly one place.
	_growth_pose.offset = Vector2(-16, -growth_texture.get_height())
	_growth_pose.position.y += 1
	_growth_pose.flip_h = growth_facing < 0
	get_parent().add_sibling(_growth_pose)


func _show_growth(phase: int) -> void:
	_show_old(false)
	get_parent().hide()
	# Duck/held-duck art follows the same ratios without exceeding its own
	# full height under a ceiling. Standing big art is28px tall.
	_growth_pose.scale = _growth_base_scale * Vector2(1, GROWTH_HEIGHTS[phase] / GROWTH_FULL_HEIGHT)
	_growth_pose.show()


func cancel() -> void:
	_cleanup()
	queue_free()


func _exit_tree() -> void:
	_cleanup()


func _cleanup() -> void:
	if not _active:
		return
	_active = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tree.paused = _was_paused
	if is_instance_valid(MusicPlayer):
		MusicPlayer.process_mode = _music_mode
	if is_instance_id_valid(old_graphics_id):
		var old_graphics: Node2D = instance_from_id(old_graphics_id)
		old_graphics.hide()
		old_graphics.queue_free()
	if is_instance_valid(get_parent()):
		get_parent().visible = true
	if is_instance_valid(_growth_pose):
		_growth_pose.hide()
		_growth_pose.queue_free()
