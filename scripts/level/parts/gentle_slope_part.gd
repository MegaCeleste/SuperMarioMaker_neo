# SPDX-License-Identifier: AGPL-3.0-or-later
class_name GentleSlopePart
extends SlopePart


func _init() -> void:
	gentle = true


static func create() -> GentleSlopePart:
	return load("res://scenes/parts/gentle_slope_part.tscn").instantiate()


static func get_part_name(_environment: SubArea) -> String:
	return "Gentle Slope"


static func get_part_icon(_environment: SubArea) -> Texture2D:
	var image := Image.create(60, 60, false, Image.FORMAT_RGBA8)
	var texture := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for lower in [false, true]:
		texture.blit_rect(SlopePart.surface_texture(true, true, lower, false, SMWTheme.atlas(_environment)).get_image(), Rect2i(0, 0, 32, 16), Vector2i(0, 16 if lower else 0))
	texture.resize(54, 54, Image.INTERPOLATE_NEAREST)
	image.blit_rect(texture, Rect2i(0, 0, 54, 54), Vector2i(3, 3))
	return ImageTexture.create_from_image(image)


static func is_placeable(grid_pos: Vector2i, world: World2D) -> bool:
	return space_free(Level.from_grid(grid_pos), polygon_for(1, true, true), world)
