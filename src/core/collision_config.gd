class_name CollisionConfig
extends RefCounted

const PATH := "res://data/physics/collision_layers.json"
static var _layers: Dictionary = {}


static func layer(name: String) -> int:
	if _layers.is_empty():
		var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
		if file == null:
			push_error("Missing collision layer configuration: " + PATH)
			return 0
		var document: Variant = JSON.parse_string(file.get_as_text())
		if document is Dictionary:
			_layers = document as Dictionary
	if not _layers.has(name):
		push_error("Unknown collision layer: " + name)
		return 0
	return 1 << (int(_layers[name]) - 1)


static func mask(names: Array[String]) -> int:
	var value: int = 0
	for name: String in names:
		value |= layer(name)
	return value
