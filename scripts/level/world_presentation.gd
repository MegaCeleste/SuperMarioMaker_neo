# SPDX-License-Identifier: AGPL-3.0-or-later
class_name WorldPresentation
extends Node
## Interpolate drawing, never the scene/physics state. Camera and actors use
## the same two completed ticks; render-time effects keep their own clock.

## Owning playable area, assigned before entering the scene tree.
var sub_area: SubArea
## Whether to interpolate display transforms; disabling restores physical transforms.
var enabled := true
var _tracks: Dictionary[int, Dictionary] = {}
var _previous_camera := Vector2.ZERO
var _camera_valid := false
var _paused := false
var _owns_camera := false
var _slopes := false


func _ready() -> void:
	get_tree().node_added.connect(_watch)
	get_tree().node_removed.connect(_forget)
	for node in sub_area.get_foreground().get_children():
		_watch(node)
	get_tree().physics_frame.connect(_before_physics)
	RenderingServer.frame_pre_draw.connect(present)


func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(present)
	get_tree().physics_frame.disconnect(_before_physics)
	get_tree().node_added.disconnect(_watch)
	get_tree().node_removed.disconnect(_forget)
	if _owns_camera:
		Utility.camera_render_offset = Vector2.ZERO


func _watch(node: Node) -> void:
	if node.get_parent() != sub_area.get_foreground():
		return
	if node is SlopeBody:
		_slopes = true
		return
	if not (
		node is CharacterBodyExt
		or node is DeadEntity
		or node is FloatingEnemyDefeat
		or node is SwimmingEnemyDefeat
		or node is SinkingEnemy
		or node is DetachedEnemyAttachment
		or node is BlockShard
		or node is DonutPlatform
		or node is NoteBlock
		or node is PlayerBubble
	):
		return
	_tracks[node.get_instance_id()] = {
		"node": weakref(node),
		"previous": node.transform,
		"displayed": node.transform,
		"offset": Vector2.ZERO,
		"valid": false
	}


func _forget(node: Node) -> void:
	if _tracks.erase(node.get_instance_id()) and node is Node2D:
		# Reparented held objects must not retain a server-only old transform.
		RenderingServer.canvas_item_set_transform(node.get_canvas_item(), node.transform)


func _active() -> bool:
	return (
		sub_area.is_visible_in_tree()
		and sub_area.level.current_sub_area == sub_area
		and sub_area.level.status != Level.Status.EDITING
	)


func _before_physics() -> void:
	if not _active() or get_tree().paused:
		return
	for entry: Dictionary in _tracks.values():
		var node: Node2D = entry.node.get_ref()
		if is_instance_valid(node):
			var current := node.transform
			if _slopes and node is CharacterBody2D:
				current.origin += SlopeBody.visual_floor_offset(node)
			if not entry.valid:
				# Factories can assign the spawn position after add_child(). A
				# first-tick power pause must not hold that temporary origin.
				entry.displayed = current
			entry.previous = entry.displayed if _paused else current
			entry.valid = true
	_previous_camera = (
		Utility.camera_position - Utility.camera_render_offset / Utility.camera_scale
		if _paused
		else Utility.camera_position
	)
	_camera_valid = true
	_paused = false


## Presents the last two completed physics ticks without changing collision transforms.
## A nonnegative fraction overrides the engine fraction for deterministic render probes.
func present(fraction_override := -1.0) -> void:
	var active := _active() and enabled
	if not active:
		if _owns_camera:
			Utility.camera_render_offset = Vector2.ZERO
		_owns_camera = false
		_camera_valid = false
		_slopes = false
	_paused = active and get_tree().paused or _paused and active
	var fraction := (
		Engine.get_physics_interpolation_fraction() if fraction_override < 0 else fraction_override
	)
	for entry: Dictionary in _tracks.values():
		var node: Node2D = entry.node.get_ref()
		if not is_instance_valid(node):
			continue
		var physical := node.transform
		var shown := physical
		if active and _slopes and node is CharacterBody2D:
			shown.origin += SlopeBody.visual_floor_offset(node)
		if active and entry.valid:
			if _paused:
				shown.origin = entry.displayed.origin
			elif node.can_process() and physical.origin.distance_to(entry.previous.origin) < 32:
				shown.origin = entry.previous.origin.lerp(shown.origin, fraction)
		# Keep the current basis: flips, squash and render-time spin tweens
		# are poses, not physics translations to blend through.
		RenderingServer.canvas_item_set_transform(node.get_canvas_item(), shown)
		entry.displayed = shown
		entry.offset = node.get_parent().global_transform.basis_xform(
			shown.origin - physical.origin
		)
		if not active:
			entry.valid = false
	# A spring's source texture changes its top in4px steps. Its rider must
	# follow that displayed pose, rather than blend through the old top.
	var player: Player = (
		sub_area.level.hud.player if is_instance_valid(sub_area.level.hud) else null
	)
	if (
		active
		and not _paused
		and is_instance_valid(player)
		and player.state_machine.current_state is PlayerSpringState
	):
		var spring: Spring = player.state_machine.current_state.spring
		if is_instance_valid(spring):
			var hero_track: Dictionary = _tracks.get(player.get_instance_id(), {})
			var spring_track: Dictionary = _tracks.get(spring.get_instance_id(), {})
			if not hero_track.is_empty() and not spring_track.is_empty():
				var shown: Transform2D = hero_track.displayed
				shown.origin.y = spring_track.displayed.origin.y - 15 + spring.compression - 0.08
				RenderingServer.canvas_item_set_transform(player.get_canvas_item(), shown)
				hero_track.displayed = shown
				hero_track.offset = player.get_parent().global_transform.basis_xform(
					shown.origin - player.position
				)
	if active and _camera_valid and not _paused:
		var current := Utility.camera_position
		var shown_camera := _previous_camera.lerp(current, fraction)
		if current.distance_to(_previous_camera) >= 32:
			shown_camera = current
		Utility.camera_render_offset = (current - shown_camera) * Utility.camera_scale
		_owns_camera = true
	# Background drawing bakes the physical camera's parallax translation.
	# Apply the same display correction so scenery cannot stair-step at 60Hz.
	var backgrounds: Array[Background] = []
	if sub_area.background is Background:
		backgrounds.append(sub_area.background)
	elif is_instance_valid(sub_area.background):
		for child in sub_area.background.get_children():
			if child is Background:
				backgrounds.append(child)
	for background in backgrounds:
		var shown := background.transform
		if active:
			shown.origin -= (
				(Vector2.ONE - background.follow_scale)
				* Utility.camera_render_offset
				/ Utility.camera_scale
			)
		RenderingServer.canvas_item_set_transform(background.get_canvas_item(), shown)


## Shadows and pixel probes must use the same displayed hierarchy as the GPU.
func global_transform_for(source: Node2D) -> Transform2D:
	var result := source.global_transform
	var ancestor: Node = source
	while ancestor is Node2D:
		var entry: Dictionary = _tracks.get(ancestor.get_instance_id(), {})
		if not entry.is_empty():
			result.origin += entry.offset
			break
		if ancestor.top_level:
			break
		ancestor = ancestor.get_parent()
	return result


## Returns the same interpolated transform in viewport coordinates for shadows/probes.
func canvas_transform_for(source: Node2D) -> Transform2D:
	return source.get_viewport().canvas_transform * global_transform_for(source)
