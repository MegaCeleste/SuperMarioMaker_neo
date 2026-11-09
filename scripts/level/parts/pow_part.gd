# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PowPart
extends Part
## Editor POW block (source obj_pow_res); builds a [PowBlock].


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_gizmos.tres")


static func get_part_name(_environment: SubArea) -> String:
	return "POW Block"


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return PSwitchPart.icon_from(&"spr_block_pow", 0)


static func create() -> PowPart:
	return load("res://scenes/level/parts/pow_part.tscn").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_block_pow").get_frame_texture(&"default", 0)
	# Overlap the floor outline by one pixel, like Mario and the enemies.
	$Graphics/Sprite.position = Vector2.ZERO
	EnemyPartPreview.align_contact(self, $Graphics/Sprite)


func build() -> void:
	var entity := load("res://scenes/level/entities/pow_block.tscn").instantiate() as PowBlock
	entity.position = position + Vector2(8, 16)
	sub_area.add(entity)
