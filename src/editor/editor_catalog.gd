class_name EditorCatalog
extends RefCounted
## 只读物件名称/图标/静态帧；绝不调用 Registry.instantiate_object。

const ICON_ROOT: String = "res://textures/ui/editor/part_icons/smw/"
const QUICK_PARTS: Array[Dictionary] = [
	{"icon": "bowser", "name": "MAKER_BOWSER", "color": "enemy"},
	{"icon": "clown_car", "name": "MAKER_CLOWN_CAR", "color": "enemy"},
	{"icon": "hammer_bro", "name": "MAKER_HAMMER_BRO", "color": "enemy"},
	{"icon": "green_pipe", "name": "MAKER_PIPE", "color": "terrain"},
	{"icon": "bowser_jr", "name": "MAKER_BOWSER_JR", "color": "enemy"},
	{"icon": "hard_block", "id": "smm.block.hard", "color": "terrain"},
	{"icon": "arrow_sign", "name": "MAKER_ARROW_SIGN", "color": "gizmo"},
	{"icon": "fire_flower", "id": "smm.item.fire_flower", "color": "item"},
	{"icon": "slope", "name": "MAKER_SLOPE", "color": "terrain"},
	{"icon": "fire_red_koopa", "name": "MAKER_FIRE_KOOPA", "color": "enemy"},
	{"icon": "ground", "id": "smm.terrain.ground", "color": "terrain"},
	{"icon": "coin", "id": "smm.item.coin", "color": "item"},
]
const PART_COLORS: Dictionary = {
	"enemy": Color("6edc26"), "terrain": Color("10bfd8"),
	"gizmo": Color("ffe928"), "item": Color("db5cdb"),
}
const ICONS: Dictionary = {
	"smm.enemy.koopa_green": "green_koopa",
	"smm.enemy.koopa_red": "red_koopa",
	"smm.enemy.koopa_shell": "koopa_shell",
	"smm.enemy.buzzy_beetle": "buzzy_beetle",
	"smm.enemy.spiny": "spiny",
	"smm.enemy.bob_omb": "bob_omb",
	"smm.enemy.piranha_plant": "piranha_plant",
	"smm.item.super_star": "star",
	"smm.item.one_up": "1up",
	"smm.item.coin_10": "10_coin",
	"smm.item.coin_30": "30_coin",
	"smm.item.coin_50": "50_coin",
	"smm.terrain.ground": "ground", "smm.block.question": "question_block",
	"smm.block.hard": "hard_block", "smm.block.turn": "turn_block",
	"smm.item.coin": "coin", "smm.item.super_mushroom": "mushroom",
	"smm.item.fire_flower": "fire_flower", "smm.enemy.galoomba": "galoomba",
}
const GROUPS: Dictionary = {
	"smm.enemy.koopa_green": "koopa_green",
	"smm.enemy.koopa_red": "koopa_red",
	"smm.enemy.koopa_shell": "shell_green",
	"smm.enemy.buzzy_beetle": "buzzy",
	"smm.enemy.spiny": "spiny",
	"smm.enemy.bob_omb": "bob_omb",
	"smm.enemy.piranha_plant": "piranha",
	"smm.item.super_star": "star",
	"smm.item.one_up": "one_up",
	"smm.item.coin_10": "coin_10",
	"smm.item.coin_30": "coin_30",
	"smm.item.coin_50": "coin_50",
	"smm.block.question": "question", "smm.block.empty": "empty",
	"smm.block.hard": "hard", "smm.block.turn": "turn", "smm.item.coin": "coin",
	"smm.item.super_mushroom": "mushroom", "smm.item.fire_flower": "fire_flower",
	"smm.enemy.goomba": "goomba", "smm.enemy.galoomba": "galoomba",
}

var _icons: Dictionary[String, Texture2D] = {}
var _palette_icons: Dictionary[String, Texture2D] = {}
var _previews: Dictionary[String, Texture2D] = {}
var _manifest: Dictionary = {}
var _manifest_loaded: bool = false


func label_for(object_id: String) -> String:
	var definition: Dictionary = Registry.get_object(object_id)
	var label: String = tr(String(definition.get("display_name_key", object_id)))
	if object_id == "smm.enemy.goomba":
		label += " · " + tr("MAKER_PLACEHOLDER")
	return label


func objects_for(category: String = "") -> Array[Dictionary]:
	var definitions: Array[Dictionary] = Registry.get_by_style(&"smw")
	var result: Array[Dictionary] = []
	for entry: Dictionary in definitions:
		if category.is_empty() or String(entry["category"]) == category:
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	return result


func icon_for(object_id: String) -> Texture2D:
	if _icons.has(object_id):
		return _icons[object_id]
	var texture: Texture2D = null
	if ICONS.has(object_id):
		texture = load_optional(ICON_ROOT + String(ICONS[object_id]) + ".png")
	if texture == null:
		texture = preview_for(object_id)
	_icons[object_id] = texture
	return texture


func preview_for(object_id: String) -> Texture2D:
	if _previews.has(object_id):
		return _previews[object_id]
	var texture: Texture2D = null
	if GROUPS.has(object_id):
		texture = _manifest_frame(String(GROUPS[object_id]), "walk" if object_id.begins_with("smm.enemy.") else "idle")
	elif ICONS.has(object_id):
		texture = load_optional(ICON_ROOT + String(ICONS[object_id]) + ".png")
	_previews[object_id] = texture
	return texture


func _manifest_frame(group: String, animation: String) -> Texture2D:
	# Check the actual PNG before loading it; missing local media stays a label placeholder.
	if not _manifest_loaded:
		_manifest_loaded = true
		var file: FileAccess = FileAccess.open(BasicSpriteLibrary.PATH, FileAccess.READ)
		if file != null:
			var value: Variant = JSON.parse_string(file.get_as_text())
			if value is Dictionary:
				_manifest = value as Dictionary
	var groups: Dictionary = _manifest.get("groups", {}) as Dictionary
	var definition: Dictionary = groups.get(group, {}) as Dictionary
	var animations: Dictionary = definition.get("animations", {}) as Dictionary
	var selected: String = animation if animations.has(animation) else String(animations.keys()[0]) if not animations.is_empty() else ""
	var mapping: Dictionary = animations.get(selected, {}) as Dictionary
	var assets: Dictionary = _manifest.get("assets", {}) as Dictionary
	var record: Dictionary = assets.get(String(mapping.get("asset", "")), {}) as Dictionary
	var indices: Array = mapping.get("frames", []) as Array
	if record.get("metadata_state", "") != "verified" or indices.is_empty():
		return null
	var texture: Texture2D = load_optional(String(record.get("texture_path", "")))
	if texture == null:
		return null
	var width: int = int(record["frame_width"])
	var height: int = int(record["frame_height"])
	var index: int = int(indices[0])
	if width <= 0 or height <= 0 or index < 0 or index >= int(record["frame_count"]) or texture.get_width() != width * int(record["frame_count"]) or texture.get_height() != height:
		return null
	var frame: AtlasTexture = AtlasTexture.new()
	frame.atlas = texture
	frame.region = Rect2(index * width, 0, width, height)
	return frame


static func load_optional(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func palette_entries(category: String) -> Array[Dictionary]:
	# Original visual palette order; unregistered parts stay inactive.
	var icons: Array = {
		"terrain": ["ground", "green_pipe", "question_block", "hard_block", "turn_block", "empty", "slope", "cloud", "ice_block", "bridge", "donut_block", "note_block", "red_pipe", "blue_pipe", "yellow_pipe"],
		"item": ["coin", "10_coin", "key_coin", "mushroom", "fire_flower", "cape_feather", "p_balloon", "star", "1up", "yoshi_egg", "30_coin", "50_coin", "red_yoshi_egg", "poison_mushroom"],
		"enemy": ["galoomba", "goomba", "green_koopa", "red_koopa", "piranha_plant", "buzzy_beetle", "spiny", "bob_omb", "blooper", "cheep_cheep", "bowser", "bowser_jr", "hammer_bro", "thwomp", "wiggler", "monty_mole", "koopa_shell"],
		"gizmo": ["arrow_sign", "spiketrap", "platform_1", "platform_2", "platform_3", "bounce_block"],
	}.get(category, [])
	var result: Array[Dictionary] = []
	for icon: String in icons:
		var object_id: String = ""
		for registered_id: String in ICONS:
			if ICONS[registered_id] == icon:
				object_id = registered_id
		if icon == "empty":
			object_id = "smm.block.empty"
		elif icon == "goomba":
			object_id = "smm.enemy.goomba"
		result.append({"icon": icon, "id": object_id})
	return result


func palette_icon(entry: Dictionary) -> Texture2D:
	var object_id: String = String(entry.get("id", ""))
	if not object_id.is_empty():
		return icon_for(object_id)
	var icon: String = String(entry["icon"])
	# Canvas draw commands retain RIDs, not Resource references. Keep art alive.
	if not _palette_icons.has(icon):
		_palette_icons[icon] = load_optional(ICON_ROOT + icon + ".png")
	return _palette_icons[icon]
