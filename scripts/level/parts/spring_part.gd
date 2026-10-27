# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SpringPart
extends Part

static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_gizmos.tres")

static func get_part_name(_environment: SubArea) -> String:
	return "Spring"

static func get_part_icon(_environment: SubArea) -> Texture2D:
	var icon := Image.create(60, 60, false, Image.FORMAT_RGBA8)
	if SpriteLibrary.has_sprite(&"spr_spring"):
		var image := SpriteLibrary.get_frames(&"spr_spring").get_frame_texture(&"default", 0).get_image()
		image.resize(48, 48, Image.INTERPOLATE_NEAREST)
		icon.blit_rect(image, Rect2i(0, 0, 48, 48), Vector2i(6, 6))
	return ImageTexture.create_from_image(icon)

static func create() -> SpringPart:
	return load("res://scenes/level/parts/spring_part.tscn").instantiate()

func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_spring").get_frame_texture(&"default", 0)
	$Graphics/Sprite.position.y = 1

func build() -> void:
	var spring := load("res://scenes/level/entities/spring.tscn").instantiate() as Spring
	spring.position = position + Vector2(8, 16)
	sub_area.add(spring)
