# SPDX-License-Identifier: AGPL-3.0-or-later
class_name DryBonesPart
extends Part
## Editor Dry Bones (source obj_drybones_res); builds a [DryBones].


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_enemies.tres")


static func get_part_name(_environment: SubArea) -> String:
	return "Dry Bones"


static func get_part_icon(_environment: SubArea) -> Texture2D:
	var icon := Image.create(60, 60, false, Image.FORMAT_RGBA8)
	if SpriteLibrary.has_sprite(&"spr_drybones"):
		var image := SpriteLibrary.get_frames(&"spr_drybones").get_frame_texture(&"default", 0).get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.flip_x()  # Enemies face left in the editor; the art faces right.
		var size := image.get_size() * 48 / maxi(image.get_width(), image.get_height())
		image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
		icon.blit_rect(image, Rect2i(Vector2i.ZERO, size), (Vector2i(60, 60) - size) / 2)
	return ImageTexture.create_from_image(icon)


static func create() -> DryBonesPart:
	return load("res://scenes/level/parts/dry_bones_part.tscn").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	# Enemies face left in the editor; the source art faces right.
	$Graphics/Sprite.flip_h = true
	var texture := SpriteLibrary.get_frames(&"spr_drybones").get_frame_texture(&"default", 0)
	$Graphics/Sprite.texture = texture
	# The 32px-tall art stands on the cell's bottom edge instead of centring on it.
	if texture != null:
		$Graphics/Sprite.offset.y = 8 - texture.get_height() / 2.0


func build() -> void:
	var enemy := load("res://scenes/level/entities/dry_bones.tscn").instantiate() as DryBones
	enemy.position = position + Vector2(8, 16)
	sub_area.add(enemy)
