class_name BuzzyBeetlePart
extends Part


static func get_category() -> PaletteCategory:
	return load("uid://bisixphutjm6u")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("uid://w0md0f0jr8kl")


static func create() -> BuzzyBeetlePart:
	return load("res://scenes/parts/buzzybeetle_part.tscn").instantiate()


func build() -> void:
	var e = preload("res://scenes/entities/buzzybeetle.tscn").instantiate()
	e.global_position = global_position + Vector2(8, 16)
	sub_area.add(e)
