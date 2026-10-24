# SPDX-License-Identifier: AGPL-3.0-or-later
class_name ChompPart
extends Part
## Size conversion replaces the source resource at y-/+16 with fresh flags.

const SMALL = preload("res://resources/content/smw_chomp_small.tres")
const GIANT = preload("res://resources/content/smw_chomp_giant.tres")
const VARIANTS: Array[ChompVariant] = [SMALL, GIANT]
@export var variant: ChompVariant = SMALL
@export var wings := false
@export var parachute := false
var _dark := false
var _decoration: EnemyPartDecoration


static func create() -> ChompPart:
	return load("res://scenes/parts/chomp_part.tscn").instantiate()


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_enemies.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/chain_chomp.png")


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	_refresh_preview()


func _process(delta: float) -> void:
	super(delta)
	if _dark != _is_dark():
		_refresh_preview()


func _is_dark() -> bool:
	return sub_area.night_mode or sub_area.level_theme in [Level.LevelTheme.CASTLE,
		Level.LevelTheme.MANSION, Level.LevelTheme.UNDERGROUND]


func _refresh_preview() -> void:
	_dark = _is_dark()
	var sprite: Sprite2D = $Graphics/Sprite
	var art := variant.dark_editor_sprite if _dark else variant.editor_sprite
	if SpriteLibrary.has_sprite(art):
		sprite.texture = SpriteLibrary.get_frames(art).get_frame_texture(&"default", 2)
		sprite.centered = false
		sprite.offset = -variant.editor_origin
		sprite.position = -$Graphics.position
	var shape := RectangleShape2D.new()
	shape.size = variant.canvas_size
	$CollShape.shape = shape
	$CollShape.position = variant.canvas_size / 2
	if _decoration == null:
		_decoration = EnemyPartDecoration.new()
		$Graphics.add_child(_decoration)
	_decoration.position = -$Graphics.position
	_decoration.refresh(variant.decoration, wings, parachute)
	EnemyPartPreview.align_contact(self, sprite, 0, _decoration)
	queue_redraw()


func build() -> void:
	var body: ChainChomp = load("res://scenes/entities/chain_chomp.tscn").instantiate()
	body.variant = variant
	body.position = position + variant.part_to_feet()
	# scr_edit_to_play passes neither flag; both runtime Creates set them to 0.
	sub_area.add(body)


func get_variant() -> StringName:
	return variant.id


func set_variant(id: StringName) -> void:
	for choice in VARIANTS:
		if choice.id == id and choice != variant:
			position.y += -16 if choice == GIANT else 16
			variant = choice
			wings = false
			parachute = false
			_update_anchor()


func get_modifiers() -> Array[Dictionary]:
	var icons := SpriteLibrary.get_frames(&"spr_window_button_SMW")
	return [{"id": &"large", "label": GIANT.label, "icon": icons.get_frame_texture(&"default", 0)},
		{"id": &"wings", "label": &"EDITOR_WINGS", "icon": icons.get_frame_texture(&"default", 1)},
		{"id": &"parachute", "label": &"EDITOR_PARACHUTE", "icon": icons.get_frame_texture(&"default", 2)}]


func has_modifier(id: StringName) -> bool:
	return variant == GIANT if id == &"large" else wings if id == &"wings" else parachute if id == &"parachute" else false


func set_modifier(id: StringName, enabled: bool) -> void:
	if id == &"large":
		set_variant(GIANT.id if enabled else SMALL.id)
	elif id == &"wings":
		wings = enabled
	elif id == &"parachute":
		parachute = enabled
	if is_node_ready():
		_refresh_preview()


func get_variant_state() -> Dictionary:
	return {"id": variant.id, "position": position, "wings": wings, "parachute": parachute}


func restore_variant_state(state: Dictionary) -> void:
	variant = GIANT if state.id == GIANT.id else SMALL
	position = state.position
	wings = state.wings
	parachute = state.parachute
	_update_anchor()


func _update_anchor() -> void:
	_grid_pos = Level.to_grid(position)
	_original_pos = _grid_pos
	_drag_start = position
	if is_node_ready():
		_refresh_preview()


func _draw_highlight(pos: Vector2, color: Color) -> void:
	draw_rect(Rect2(pos, variant.canvas_size), color)


func _check_validity() -> void:
	_grid_pos = Level.to_grid(global_position + Vector2(8, 8))
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = variant.canvas_size - Vector2(2, 2)
	query.shape = shape
	query.transform.origin = Level.from_grid(_grid_pos) + variant.canvas_size / 2
	query.collision_mask = 1 << 8
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	_valid_space = get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


static func variant_for_object(id: String) -> ChompVariant:
	return GIANT if id == GIANT.object_id else SMALL
