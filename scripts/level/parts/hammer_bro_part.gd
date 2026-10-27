# SPDX-License-Identifier: AGPL-3.0-or-later
class_name HammerBroPart
extends Part
## obj_hammerbro/firebro/icebro/boomerangbro share one tool with four types.
## Sledge uses the separate size/wings/parachute window, not a fifth type icon.

const VARIANTS: Array[HammerBroVariant] = [
	preload("res://resources/content/smw_hammerbro_hammer.tres"),
	preload("res://resources/content/smw_hammerbro_fire.tres"),
	preload("res://resources/content/smw_hammerbro_ice.tres"),
	preload("res://resources/content/smw_hammerbro_boomerang.tres"),
	preload("res://resources/content/smw_hammerbro_sledge.tres"),
]
@export var variant: HammerBroVariant = preload("res://resources/content/smw_hammerbro_hammer.tres")
@export var wings := false
@export var parachute := false
var _decoration: EnemyPartDecoration


static func create() -> HammerBroPart:
	return load("res://scenes/level/parts/hammer_bro_part.tscn").instantiate()


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_enemies.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	# Invoke generation at runtime; a const Resource property access can be
	# evaluated before the sprite autoload is ready and retain its null value.
	return VARIANTS[0].get_icon()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	_refresh_preview()


func _refresh_preview() -> void:
	var sprite: Sprite2D = $Graphics/Sprite
	if SpriteLibrary.has_sprite(variant.editor_sprite):
		sprite.texture = SpriteLibrary.get_frames(variant.editor_sprite).get_frame_texture(
				&"default", variant.editor_frame)
		sprite.centered = false
		sprite.offset = Vector2.ZERO
		sprite.position = -$Graphics.position - variant.editor_origin
	var collider: CollisionShape2D = $CollShape
	var shape := RectangleShape2D.new()
	shape.size = footprint().size
	collider.shape = shape
	collider.position = footprint().get_center()
	if _decoration == null:
		_decoration = EnemyPartDecoration.new()
		$Graphics.add_child(_decoration)
	_decoration.position = -$Graphics.position
	_decoration.refresh(load("res://resources/content/smw_flight_sledgebro.tres") if variant.sledge \
			else load("res://resources/content/smw_flight_hammerbro.tres"), wings, parachute)
	EnemyPartPreview.align_contact(self, sprite, 0, _decoration)
	queue_redraw()


func build() -> void:
	var body: HammerBro = load("res://scenes/level/entities/hammer_bro.tscn").instantiate()
	body.variant = variant
	body.wings = wings
	body.parachute = parachute if variant.sledge else false
	body.position = position + Vector2(8, 16)
	sub_area.add(body)


func get_variants() -> Array[Dictionary]:
	if variant.sledge:
		return []
	var options: Array[Dictionary] = []
	for choice in VARIANTS:
		if choice.sledge:
			continue
		options.append({"id": choice.id, "label": choice.label, "icon": choice.icon})
	return options


func get_variant() -> StringName:
	return variant.id


func set_variant(id: StringName) -> void:
	for choice in VARIANTS:
		if choice.id == id and choice != variant:
			if choice.sledge != variant.sledge:
				position.x += 16 if choice.sledge else -16
			else:
				parachute = false # Regular type replacements copy only wings.
			variant = choice
			_grid_pos = Level.to_grid(position)
			_original_pos = _grid_pos
			_drag_start = position
			if is_node_ready():
				_refresh_preview()


func get_modifiers() -> Array[Dictionary]:
	var icons := SpriteLibrary.get_frames(&"spr_window_button_SMW")
	var result: Array[Dictionary] = [
		{"id": &"large", "label": &"EDITOR_ENEMY_SLEDGE", "icon": icons.get_frame_texture(&"default", 0)},
		{"id": &"wings", "label": &"EDITOR_WINGS",
			"icon": icons.get_frame_texture(&"default", 1)},
	]
	if variant.sledge:
		result.append({"id": &"parachute", "label": &"EDITOR_PARACHUTE", "icon": icons.get_frame_texture(&"default", 2)})
	return result


func has_modifier(id: StringName) -> bool:
	return variant.sledge if id == &"large" else wings if id == &"wings" else parachute if id == &"parachute" else false


func set_modifier(id: StringName, enabled: bool) -> void:
	if id == &"wings":
		wings = enabled
	elif id == &"parachute":
		parachute = enabled
	elif id == &"large":
		set_variant(&"sledge" if enabled else &"hammer")
	if is_node_ready():
		_refresh_preview()


func get_variant_state() -> Dictionary:
	return {"id": variant.id, "wings": wings, "parachute": parachute, "position": position}


func restore_variant_state(state: Dictionary) -> void:
	for choice in VARIANTS:
		if choice.id == state.id:
			variant = choice
	position = state.position
	wings = state.wings
	parachute = state.parachute
	_grid_pos = Level.to_grid(position)
	_original_pos = _grid_pos
	_drag_start = position
	if is_node_ready():
		_refresh_preview()


func footprint() -> Rect2:
	return Rect2(-16, -16, 32, 32) if variant.sledge else Rect2(0, 0, 16, 16)


static func is_variant_placeable(grid_pos: Vector2i, world: World2D, id: StringName) -> bool:
	return _check_rect(Rect2i(grid_pos - Vector2i.ONE, Vector2i(2, 2)), world) if id == &"sledge" \
			else Part.is_placeable(grid_pos, world)


func _draw_highlight(pos: Vector2, color: Color) -> void:
	var bounds := footprint()
	bounds.position += pos
	draw_rect(bounds, color)


func _check_validity() -> void:
	_grid_pos = Level.to_grid(global_position + Vector2(8, 8))
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = footprint().size - Vector2(2, 2)
	query.shape = shape
	query.transform.origin = Level.from_grid(_grid_pos) + footprint().get_center()
	query.collision_mask = 1 << 8
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	_valid_space = get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


static func variant_for_object(id: String) -> HammerBroVariant:
	for choice in VARIANTS:
		if choice.object_id == id:
			return choice
	return VARIANTS[0]
