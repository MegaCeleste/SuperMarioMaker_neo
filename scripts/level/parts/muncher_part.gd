# SPDX-License-Identifier: AGPL-3.0-or-later
class_name MuncherPart
extends Part
## Both sizes share a lower-left cell; SWE retains each source instance origin.

const VARIANTS: Array[MuncherVariant] = [preload("res://resources/content/smw_muncher_small.tres"),
	preload("res://resources/content/smw_muncher_giant.tres")]
@export var variant: MuncherVariant = preload("res://resources/content/smw_muncher_small.tres"):
	set(value):
		variant = value
		if is_node_ready():
			_refresh_preview()
@export var wings := false
@export var parachute := false
var _decoration: EnemyPartDecoration
var _dark := false


static func create() -> MuncherPart:
	return load("res://scenes/parts/muncher_part.tscn").instantiate()


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_enemies.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/muncher.png")


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$CollShape.shape = $CollShape.shape.duplicate()
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
	var name: StringName = variant.dark_editor_sprite if _dark else variant.editor_sprite
	if SpriteLibrary.has_sprite(name):
		var sprite: Sprite2D = $Graphics/Sprite
		sprite.texture = SpriteLibrary.get_frames(name).get_frame_texture(&"default",
				variant.editor_dark_frame if _dark else variant.editor_frame)
		sprite.centered = false
		sprite.offset = -variant.editor_origin
		# Giant source resources sit at x+16 and share the small one's y.
		sprite.position = Vector2(variant.source_x_offset, 0) - $Graphics.position
	var bounds := variant.footprint()
	$CollShape.position = bounds.get_center()
	$CollShape.shape.size = bounds.size
	if _decoration == null:
		_decoration = EnemyPartDecoration.new()
		$Graphics.add_child(_decoration)
	_decoration.position = Vector2(variant.source_x_offset, 0) - $Graphics.position
	_decoration.refresh(variant.flight, wings, parachute)
	EnemyPartPreview.align_contact(self, $Graphics/Sprite, 0, _decoration)
	queue_redraw()


func build() -> void:
	var body: Muncher = load("res://scenes/entities/muncher.tscn").instantiate()
	body.variant = variant
	body.position = position + variant.feet_offset()
	# scr_edit_to_play deliberately passes neither flag to this physics solid.
	sub_area.add(body)


func get_variants() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for choice in VARIANTS:
		var icon := choice.icon
		if SpriteLibrary.has_sprite(choice.editor_sprite):
			# The dummy renderer can retain the texture's backing Image. Resize
			# an owned copy so generating an icon cannot alter preview alpha bounds.
			var image := SpriteLibrary.get_frames(choice.editor_sprite).get_frame_texture(&"default", choice.editor_frame).get_image().duplicate() as Image
			if image.is_compressed():
				image.decompress()
			var size := 48 if choice.canvas_size.x > 16 else 24
			image.resize(size, size, Image.INTERPOLATE_NEAREST)
			icon = ImageTexture.create_from_image(image)
		options.append({"id": choice.id, "label": choice.label, "icon": icon})
	return options


func get_variant() -> StringName:
	return variant.id


func set_variant(id: StringName) -> void:
	for choice in VARIANTS:
		if choice.id == id and choice != variant:
			# Source Other_13 creates a fresh resource without either flag.
			wings = false
			parachute = false
			variant = choice


func get_modifiers() -> Array[Dictionary]:
	return variant.flight.editor_options()


func has_modifier(id: StringName) -> bool:
	return wings if id == &"wings" else parachute if id == &"parachute" else false


func set_modifier(id: StringName, enabled: bool) -> void:
	if id == &"wings":
		wings = enabled
	elif id == &"parachute":
		parachute = enabled
	if is_node_ready():
		_refresh_preview()


func _draw_highlight(pos: Vector2, color: Color) -> void:
	var bounds := variant.footprint()
	bounds.position += pos
	draw_rect(bounds, color)


func _check_validity() -> void:
	_grid_pos = Level.to_grid(global_position + Vector2(8, 8))
	var query := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = variant.canvas_size - Vector2(2, 2)
	query.shape = rect
	query.transform.origin = Level.from_grid(_grid_pos) + variant.footprint().get_center()
	query.collision_mask = 1 << 8
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	_valid_space = get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


static func variant_for_object(id: String) -> MuncherVariant:
	return VARIANTS[1] if id == VARIANTS[1].object_id else VARIANTS[0]
