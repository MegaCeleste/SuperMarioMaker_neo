class_name KoopaPart
extends Part


static func get_category() -> PaletteCategory:
	return load("uid://bisixphutjm6u")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("uid://i6yqrkdrb4c8")


static func create() -> KoopaPart:
	return load("res://scenes/parts/koopa_part.tscn").instantiate()


static func get_variants() -> Array[PackedScene]:
	return [load("res://scenes/parts/red_koopa_part.tscn")]


func build() -> void:
	var koopa = preload("res://scenes/entities/koopa.tscn").instantiate()
	koopa.global_position = global_position + Vector2(8, 16)
	sub_area.add(koopa)
