class_name MushroomPart
extends Part


static func get_category() -> PaletteCategory:
	return load("uid://d15pdc5d1rkwr")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("uid://r27a566o13yi")


static func create() -> MushroomPart:
	return load("res://scenes/parts/mushroom_part.tscn").instantiate()


func build() -> void:
	var mushroom = preload("uid://eu7xxlwcq05b").instantiate()
	mushroom.global_position = global_position + Vector2(8, 16)
	sub_area.add(mushroom)
