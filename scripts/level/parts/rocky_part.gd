# SPDX-License-Identifier: AGPL-3.0-or-later
class_name RockyPart
extends Part
## Source obj_rocky_res has no type or attachment window.

const VARIANT = preload("res://resources/content/smw_rocky.tres")
@export var variant: RockyVariant = VARIANT


static func create() -> RockyPart:
	return load("res://scenes/level/parts/rocky_part.tscn").instantiate()


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_enemies.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/rocky_wrench.png")


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
		# Source editor art is 18x20 with origin (1,4).
		sprite.position = -$Graphics.position - variant.editor_origin
	EnemyPartPreview.align_contact(self, sprite)
	queue_redraw()


func build() -> void:
	var body: Rocky = load("res://scenes/level/entities/rocky.tscn").instantiate()
	body.variant = variant
	body.position = position + Vector2(8, 16)
	sub_area.add(body)


static func variant_for_object(_id: String) -> RockyVariant:
	return VARIANT
