# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PixelShadows
extends CanvasGroup
## One translucent silhouette behind the foreground, in world pixels. Only
## drawing is mirrored: never duplicate actors, physics, scripts or animation.
## Sync immediately before rendering so 120Hz frames and growth swaps use the
## same current pose/camera as the visible originals, without a history buffer.

const MATERIAL = preload("res://resources/rendering/pixel_shadows.tres")
const OFFSET := Vector2(2, 2)
var sub_area: SubArea
var _copies: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	name = "PixelShadows"
	z_as_relative = false
	z_index = GameConstants.Layers.Z_SHADOWS
	position = OFFSET
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = MATERIAL
	fit_margin = 2
	clear_margin = 2
	# The dummy renderer cannot exercise the CanvasGroup shader.
	if DisplayServer.get_name() == "headless":
		return
	get_tree().node_added.connect(_watch)
	get_tree().node_removed.connect(_forget)
	_scan(sub_area.get_foreground())
	_scan(sub_area.get_parts())
	RenderingServer.frame_pre_draw.connect(_sync)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync):
		RenderingServer.frame_pre_draw.disconnect(_sync)
	if get_tree().node_added.is_connected(_watch):
		get_tree().node_added.disconnect(_watch)
		get_tree().node_removed.disconnect(_forget)


func _scan(node: Node) -> void:
	_watch(node)
	for child in node.get_children():
		_scan(child)


func _watch(node: Node) -> void:
	if not (node is Sprite2D or node is AnimatedSprite2D or node is StartingGround.GroundDrawer):
		return
	if not (sub_area.get_foreground().is_ancestor_of(node) or sub_area.get_parts().is_ancestor_of(node)):
		return
	# Editor controls and the starting arrow are visual aids, not world art.
	if node.name in [&"Direction", &"GrabberSprite", &"StartArrow"]:
		return
	var copy := Node2D.new()
	copy.name = "Silhouette"
	copy.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(copy)
	var id := node.get_instance_id()
	_copies[id] = {"source": weakref(node), "copy": copy, "dirty": true, "revision": 0}
	# Canvas commands persist on the server. Rebuild only when the original
	# redraws (frame/texture/region/flip/ground edits), not on every render.
	node.draw.connect(_invalidate.bind(id))
	# Showing a hidden CanvasGroup/copy also clears its server commands during
	# Godot's canvas update, even when the original texture is unchanged.
	copy.draw.connect(_invalidate.bind(id))


func _invalidate(id: int) -> void:
	if _copies.has(id):
		_copies[id].dirty = true


func _forget(node: Node) -> void:
	var id := node.get_instance_id()
	if not _copies.has(id):
		return
	var copy: Node2D = _copies[id].copy
	if node.draw.is_connected(_invalidate.bind(id)):
		node.draw.disconnect(_invalidate.bind(id))
	_copies.erase(id)
	copy.hide()
	copy.queue_free()


func _sync() -> void:
	if not is_visible_in_tree():
		return
	var basis := sub_area.global_transform.affine_inverse()
	var view := get_viewport()
	var visible_world := view.canvas_transform.affine_inverse() * view.get_visible_rect()
	visible_world = visible_world.grow(4)
	for entry: Dictionary in _copies.values():
		var source := entry.source.get_ref() as Node2D
		var copy: Node2D = entry.copy
		var visible := is_instance_valid(source) and source.is_visible_in_tree()
		if not visible:
			copy.hide()
			continue
		# Reject distant static art before walking its presentation ancestors.
		if source is Sprite2D and not visible_world.grow(32).intersects(source.global_transform * source.get_rect()):
			copy.hide()
			continue
		var shown := (sub_area.presentation.global_transform_for(source)
				if sub_area.presentation != null else source.global_transform)
		if source is Sprite2D:
			if not visible_world.intersects(shown * source.get_rect()):
				copy.hide()
				continue
		copy.show()
		copy.transform = basis * shown
		copy.modulate = Color(1, 1, 1, _opacity(source))
		copy.texture_filter = _inherited(source, &"texture_filter", source.get_viewport().canvas_item_default_texture_filter + 1)
		copy.texture_repeat = _inherited(source, &"texture_repeat", source.get_viewport().canvas_item_default_texture_repeat + 1)
		var material_owner: CanvasItem = source
		while material_owner.use_parent_material and material_owner.get_parent() is CanvasItem:
			material_owner = material_owner.get_parent()
		copy.material = material_owner.material
		if not entry.dirty:
			continue
		entry.dirty = false
		entry.revision += 1
		var canvas := copy.get_canvas_item()
		RenderingServer.canvas_item_clear(canvas)
		if source is StartingGround.GroundDrawer:
			source.draw_ground(copy)
			continue
		var texture: Texture2D
		var region: Rect2
		var clip_uv := true
		if source is Sprite2D:
			texture = source.texture
			if texture == null:
				continue
			var base: Rect2 = source.region_rect if source.region_enabled else Rect2(Vector2.ZERO, texture.get_size())
			var cell := base.size / Vector2(source.hframes, source.vframes)
			region = Rect2(base.position + Vector2(source.frame_coords) * cell, cell)
			clip_uv = source.region_enabled and source.region_filter_clip_enabled
		else:
			texture = source.sprite_frames.get_frame_texture(source.animation, source.frame)
			if texture == null:
				continue
			region = Rect2(Vector2.ZERO, texture.get_size())
		var rect: Rect2 = source.get_rect() if source is Sprite2D else Rect2(
				source.offset - (texture.get_size() / 2 if source.centered else Vector2.ZERO), texture.get_size())
		if source is AnimatedSprite2D and source.get_viewport().snap_2d_transforms_to_pixel:
			rect.position = (rect.position + Vector2(0.5, 0.5)).floor()
		if source.flip_h:
			rect.size.x = -rect.size.x
		if source.flip_v:
			rect.size.y = -rect.size.y
		# Texture2D's RenderingServer API updates the draw commands immediately;
		# Sprite2D.texture would queue a redraw for the *next* canvas update.
		texture.draw_rect_region(canvas, rect, region, Color.WHITE, false, clip_uv)


func _opacity(source: CanvasItem) -> float:
	var result := source.self_modulate.a
	var ancestor: Node = source
	while ancestor is CanvasItem and ancestor != sub_area:
		result *= ancestor.modulate.a
		ancestor = ancestor.get_parent()
	return result


func _inherited(source: CanvasItem, property: StringName, fallback: int) -> int:
	var ancestor: Node = source
	while ancestor is CanvasItem:
		var value: int = ancestor.get(property)
		if value != 0: # Both CanvasItem sampling enums reserve0 for INHERIT.
			return value
		ancestor = ancestor.get_parent()
	return fallback
