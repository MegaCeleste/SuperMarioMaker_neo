class_name PrototypeEntityConfig
extends RefCounted

const PATH: String = "res://data/gameplay/prototype_entities.json"
static var _document: Dictionary = {}


static func actor(name: String) -> Dictionary:
	return section("enemy").merged(section(name), true) if name != "enemy" else section("enemy").duplicate(true)


static func section(name: String) -> Dictionary:
	if _document.is_empty():
		var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
		if file != null:
			var value: Variant = JSON.parse_string(file.get_as_text())
			if value is Dictionary:
				_document = value as Dictionary
	if not _document.has(name):
		push_error("Missing prototype configuration: " + name)
		return {}
	return _document[name] as Dictionary
