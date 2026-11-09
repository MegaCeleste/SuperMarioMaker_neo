# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PSwitchPart
extends Part
## Editor P-switch (source obj_pswitch_res); builds a [PSwitch].


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_gizmos.tres")


static func get_part_name(_environment: SubArea) -> String:
	return "P Switch"


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return icon_from(&"spr_pswitch", 0)


## A 60px palette icon from one 16x16 source frame, scaled 3x.
static func icon_from(sprite: StringName, frame: int) -> Texture2D:
	var icon := Image.create(60, 60, false, Image.FORMAT_RGBA8)
	if SpriteLibrary.has_sprite(sprite):
		var image := SpriteLibrary.get_frames(sprite).get_frame_texture(&"default", frame).get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(48, 48, Image.INTERPOLATE_NEAREST)
		icon.blit_rect(image, Rect2i(0, 0, 48, 48), Vector2i(6, 6))
	return ImageTexture.create_from_image(icon)


static func create() -> PSwitchPart:
	return load("res://scenes/level/parts/p_switch_part.tscn").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_pswitch").get_frame_texture(&"default", 0)
	# Overlap the floor outline by one pixel, like Mario and the enemies.
	$Graphics/Sprite.position = Vector2.ZERO
	EnemyPartPreview.align_contact(self, $Graphics/Sprite)


func build() -> void:
	var entity := load("res://scenes/level/entities/p_switch.tscn").instantiate() as PSwitch
	entity.position = position + Vector2(8, 16)
	sub_area.add(entity)
