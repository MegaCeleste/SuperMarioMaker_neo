# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BobOmbPart
extends Part
## Editor Bob-omb (source obj_bobomb_res); builds a [BobOmb].


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_enemies.tres")


static func get_part_name(_environment: SubArea) -> String:
	return "Bob-omb"


static func get_part_icon(_environment: SubArea) -> Texture2D:
	var icon := Image.create(60, 60, false, Image.FORMAT_RGBA8)
	if SpriteLibrary.has_sprite(&"spr_bobomb"):
		var image := SpriteLibrary.get_frames(&"spr_bobomb").get_frame_texture(&"default", 0).get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.flip_x()  # Enemies face left in the editor; the art faces right.
		var size := image.get_size() * 48 / maxi(image.get_width(), image.get_height())
		image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
		icon.blit_rect(image, Rect2i(Vector2i.ZERO, size), (Vector2i(60, 60) - size) / 2)
	return ImageTexture.create_from_image(icon)


static func create() -> BobOmbPart:
	return load("res://scenes/level/parts/bob_omb_part.tscn").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	# Enemies face left in the editor; the source art faces right.
	$Graphics/Sprite.flip_h = true
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_bobomb").get_frame_texture(&"default", 0)


func build() -> void:
	var enemy := load("res://scenes/level/entities/bob_omb.tscn").instantiate() as BobOmb
	enemy.position = position + Vector2(8, 16)
	sub_area.add(enemy)
