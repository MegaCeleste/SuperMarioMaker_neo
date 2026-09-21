class_name OneUpPart
extends Part


static func get_category() -> PaletteCategory:
	return load("uid://d15pdc5d1rkwr")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("uid://ch604d77yhkbi")


static func create() -> OneUpPart:
	return load("res://scenes/parts/1up_part.tscn").instantiate()


func build() -> void:
	var oneup = preload("res://scenes/entities/1_up.tscn").instantiate()
	oneup.global_position = global_position + Vector2(8, 16)
	sub_area.add(oneup)
