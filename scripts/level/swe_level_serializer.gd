# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SWELevelSerializer
extends RefCounted
## Serializes the represented SWE subset while retaining unported source data.
## Call on the main thread; the worker receives only the resulting Dictionary.

## Default SWE setting fields supplied only when absent from the retained source row.
const SETTING_DEFAULTS := {
	"autoavance": 0,
	"water_level": 0,
	"water_level_limit": 0,
	"water_level_speed": 0.2,
	"condiciones": 0,
	"condiciones_type": 0,
	"condiciones_object": 0
}
## Defaults for represented object rows; unknown source fields remain untouched.
const OBJECT_DEFAULTS := {
	"sprout": 0,
	"direct_t": 0,
	"progresivo": 0,
	"wings": 0,
	"rotacion": 0,
	"paracaidas": 0,
	"key": 0,
	"inup": 0,
	"modo_water": 0,
	"s_scaley": 1
}


## Captures one fully loaded area's editor state on the main thread without file I/O.
## Returns error/message plus data/bindings on success; bindings apply only after saving.
static func snapshot(level: Level, object_table: Dictionary, ground_table: Array) -> Dictionary:
	if level.metadata_only:
		return _failure("Open the complete level before saving it.")
	if not level.source_swe.is_empty() and not level.swe_load_complete:
		return _failure("The original level could not be fully loaded; saving would lose data.")
	var areas: Array[SubArea] = []
	for child in level.get_children():
		if child is SubArea:
			areas.append(child)
	if areas.size() != 1 or areas[0] != level.current_sub_area:
		return _failure("Saving multiple playable areas is not supported yet.")
	var data: Dictionary = level.source_swe.duplicate(true)
	if data.is_empty():
		data = {"MAIN": {"AJUSTES": [{}], "SUELO": [], "NIVEL": []}}
	var wrapper: Dictionary = data.get("S0", data.get("MAIN", {}))
	var settings: Array = wrapper.get("S1", wrapper.get("AJUSTES", [{}]))
	if settings.is_empty() or settings[0] is not Dictionary:
		return _failure("The original level settings cannot be preserved safely.")
	var map: Dictionary = settings[0]
	_set_alias(map, "gamestyle", "apariencia", level.game_style)
	_set_alias(map, "gametheme", "entorno", _theme_name(level.current_sub_area.level_theme))
	_set_alias(map, "timer", "cronometro", level.time)
	_set_alias(map, "label_1", "etiqueta1", int(level.tag_1) - 1)
	_set_alias(map, "label_2", "etiqueta2", int(level.tag_2) - 1)
	_set_alias(map, "c_conditions", "condiciones_count", level.clear_condition)
	_set_alias(map, "desc", "description", level.description)
	_set_alias(map, "width", "size", level.width)
	_set_alias(map, "nightmode", "modo_noche", int(level.current_sub_area.night_mode))
	map.water_level = level.current_sub_area.water_start_y + 432
	map.water_level_limit = level.current_sub_area.water_limit_y + 432
	map.water_level_speed = [0.2, 0.5, 0.8][level.current_sub_area.water_speed]
	map.user = level.author
	map.date = level.creation_date
	map.time = level.creation_time
	# Required empty collections/default settings in the legacy OpenWE loader.
	for key in ["TUBERIAS", "DECORACION", "CANNON", "PLATAFORMAS", "PUERTAS"]:
		if not wrapper.has(key) and not data.has("S0"):
			wrapper[key] = []
	for key in SETTING_DEFAULTS:
		if not map.has(key):
			map[key] = SETTING_DEFAULTS[key]

	var object_records: Array[Dictionary] = []
	var terrain_records: Array[Dictionary] = []
	var platform_records: Array[Dictionary] = []
	var door_records: Array[Dictionary] = []
	var has_goal := false
	for part: Part in level.current_sub_area.get_parts().get_children():
		if part.is_queued_for_deletion():
			continue
		if part.held or ((part is SlopePart or part is SemisolidPart) and part.resizing):
			return _failure("Place the held object before saving.")
		if part is EditorPlayer:
			# The editor test cursor is not an NIVEL object in OpenWE's format.
			continue
		if part is StartingGround:
			_set_alias(map, "start_y", "ground2", part.position.y + 432)
			continue
		if part is GoalPolePart:
			if has_goal:
				return _failure("A level can contain only one goal.")
			has_goal = true
			map.ground3_x = part.position.x
			map.ground3_y = part.position.y + 432 + 137
			continue
		var entry: Dictionary = part.swe_data.duplicate(true)
		if part is DoorPart:
			# One record per pair, stored on the primary door.
			if part.primary or part.get_exit() == null:
				door_records.append({"part": part, "entry": _door_entry(part, entry)})
			continue
		_set_alias(entry, "xx", "x_pos", part.position.x)
		_set_alias(entry, "yy", "y_pos", part.position.y + 432)
		if part is SemisolidPart:
			_set_alias(entry, "ID", "object", "obj_semisolid_platform1")
			entry.width = part.dimensions.x
			entry.height = part.dimensions.y
			entry.color = part.appearance
			entry.sprite = String(SemisolidPart.sprite_name(part.sub_area, part.appearance))
			entry.depth = 244 - part.position.y / 16
			if not entry.has("direct_t"):
				entry.direct_t = 0
			if not entry.has("wings"):
				entry.wings = 0
			platform_records.append({"part": part, "entry": entry})
			continue
		if part is GroundPart:
			var index: int = part.swe_frame
			if index < 0:
				var texture: Texture2D = part.get_node("%Sprite").texture
				if texture is AtlasTexture:
					index = ground_table.find(texture.region.position)
			if index < 0 or index >= ground_table.size():
				return _failure("A terrain tile has no supported SWE atlas frame.")
			_set_alias(entry, "i", "index", index)
			terrain_records.append({"part": part, "entry": entry})
			continue
		var id := _object_id(part)
		if id.is_empty():
			return _failure(
				"This object cannot be saved yet: %s." % part.get_script().get_global_name()
			)
		_set_alias(entry, "ID", "object", id)
		for key in OBJECT_DEFAULTS:
			if not entry.has(key):
				entry[key] = OBJECT_DEFAULTS[key]
		if part is ContainerBlockPart:
			entry.sprout = {
				&"none": 0,
				&"coin": -1 if part is TurnBlockPart else 0,
				&"multi_coin": -1,
				&"mushroom": 1,
				&"flower": 2,
				&"progressive_flower": 2,
				&"star": -21,
				&"one_up": -18
			}[part.content_id]
			entry.progresivo = int(part.content_id == &"progressive_flower")
		if part is FireFlowerPart:
			entry.progresivo = int(part.progressive)
		if part is SlopePart:
			entry.slope_rise = part.rise
			entry.slope_right = int(part.rises_right)
		if (
			part is GoombaPart
			or part is KoopaPart
			or part is BuzzyPart
			or part is SpinyPart
			or part is CheepCheepPart
			or part is PiranhaPart
			or part is MuncherPart
			or part is MontyPart
			or part is ChompPart
		):
			entry.wings = int(part.wings)
			entry.paracaidas = int(part.parachute)
		if part is MuncherPart:
			_set_alias(entry, "xx", "x_pos", part.position.x + part.variant.source_x_offset)
		if part is ThwompPart:
			entry.direct_t = part.attack_direction
			entry.wings = int(part.wings)
			entry.paracaidas = int(part.parachute)
		if part is HammerBroPart:
			entry.wings = int(part.wings)
			entry.paracaidas = int(part.parachute)
		if part is CheepCheepPart:
			entry.modo_water = int(part.is_in_water())
		if part is BuzzyPart or part is SpinyPart:
			entry.inup = int(part.is_ceiling_attached())
		if part is PiranhaPart and not part.variant.fire:
			entry.inup = part.attachment_orientation()
		object_records.append({"part": part, "entry": entry})
	if not has_goal:
		map.ground3_x = level.width - 112
		map.ground3_y = map.get("start_y", map.get("ground2", 400))
	var terrain := _merge(
		wrapper.get("S2", wrapper.get("SUELO", [])),
		terrain_records,
		object_table,
		true,
		level.swe_revision
	)
	var objects := _merge(
		wrapper.get("S4", wrapper.get("NIVEL", [])),
		object_records,
		object_table,
		false,
		level.swe_revision
	)
	_set_alias(wrapper, "S2", "SUELO", terrain.entries)
	_set_alias(wrapper, "S4", "NIVEL", objects.entries)
	var platform_source: Variant = wrapper.get("S7", wrapper.get("PLATAFORMAS", []))
	if platform_source is not Array:
		return _failure("The original platform collection cannot be preserved safely.")
	var platforms := _merge(
		platform_source,
		platform_records,
		{"obj_semisolid_platform1": true},
		false,
		level.swe_revision
	)
	_set_alias(wrapper, "S7", "PLATAFORMAS", platforms.entries)
	var door_source: Variant = wrapper.get("PUERTAS", [])
	if door_source is not Array:
		return _failure("The original door collection cannot be preserved safely.")
	# Key and P-switch door rows are not represented and stay as they were.
	var doors := _merge(door_source, door_records, {"obj_door_res": true}, false, level.swe_revision)
	wrapper.PUERTAS = doors.entries
	var bindings: Array = terrain.bindings + objects.bindings + platforms.bindings + doors.bindings
	return {"error": OK, "message": "", "data": data, "bindings": bindings}


## One PUERTAS row: the door and its partner, both by the middle of the door,
## in OpenWE's obj_door_res layout.
static func _door_entry(door: DoorPart, entry: Dictionary) -> Dictionary:
	var exit := door.get_exit() if door.get_exit() != null else door
	entry.object = "obj_door_res"
	entry.x_pos = door.position.x
	entry.y_pos = door.position.y + 448
	entry.door_x = exit.position.x
	entry.door_y = exit.position.y + 448
	return entry


## Retains unknown rows and source ordering, replacing only represented rows.
## Binding indices are committed on the main thread only after a successful save.
static func _merge(
	source: Array,
	records: Array[Dictionary],
	object_table: Dictionary,
	terrain: bool,
	revision: int
) -> Dictionary:
	var indexed: Dictionary = {}
	var added: Array[Dictionary] = []
	for record in records:
		var index: int = (
			record.part.swe_source_index if record.part.swe_revision == revision else -1
		)
		if index >= 0 and index < source.size() and not indexed.has(index):
			indexed[index] = record
		else:
			added.append(record)
	var entries: Array = []
	var bindings: Array = []
	for index in source.size():
		if indexed.has(index):
			var record: Dictionary = indexed[index]
			bindings.append({"part": record.part, "entry": record.entry, "index": entries.size()})
			entries.append(record.entry)
		elif (
			source[index] is not Dictionary
			or (
				not terrain
				and (
					str(source[index].get("ID", source[index].get("object", "")))
					not in object_table
				)
			)
		):
			entries.append(source[index])
	for record in added:
		bindings.append({"part": record.part, "entry": record.entry, "index": entries.size()})
		entries.append(record.entry)
	return {"entries": entries, "bindings": bindings}


static func _set_alias(dict: Dictionary, modern: String, legacy: String, value: Variant) -> void:
	dict[modern if dict.has(modern) else legacy] = value


static func _object_id(part: Part) -> String:
	if part is SpringPart:
		return "obj_spring_res"
	if part is SlopePart:
		return "godotwe_gentle_slope" if part.gentle else "godotwe_slope"
	if part is CoinPart:
		return "obj_coin_res"
	if part is MushroomPart:
		return "obj_mushroom_res"
	if part is FireFlowerPart:
		return "obj_fireflower_res"
	if part is StarPart:
		return "obj_star_res"
	if part is OneUpPart:
		return "obj_1up_res"
	if part is HardBlockPart:
		return "obj_rock_res"
	if part is IceBlockPart:
		return "obj_ice_res"
	if part is SpikePart:
		return "obj_pinchos_res"
	if part is CloudPart:
		return "obj_nube_res"
	if part is DonutPart:
		return "obj_donut_res"
	if part is NoteBlockPart:
		return "obj_noteblock_res"
	if part is HiddenBlockPart:
		return "obj_block_hidden_res"
	if part is QuestionBlockPart:
		return "obj_qblock_res"
	if part is TurnBlockPart:
		return "obj_block_res"
	if part is GoombaPart:
		return part.variant.object_id
	if part is GaloombaPart:
		return "obj_goomba_res"
	if part is KoopaPart:
		return part.variant.object_id
	if part is BuzzyPart:
		return part.variant.object_id
	if part is SpinyPart:
		return part.variant.object_id
	if part is BlooperPart:
		return "obj_blooper_res"
	if part is CheepCheepPart:
		return part.variant.object_id
	if part is PiranhaPart:
		return part.variant.object_id
	if part is MuncherPart:
		return part.variant.object_id
	if part is ThwompPart:
		return part.variant.object_id
	if part is MontyPart:
		return part.variant.object_id
	if part is RockyPart:
		return part.variant.object_id
	if part is HammerBroPart:
		return part.variant.object_id
	if part is ChompPart:
		return part.variant.object_id
	return ""


static func _theme_name(theme: Level.LevelTheme) -> String:
	if theme == Level.LevelTheme.OVERWORLD:
		return "ground"
	if theme == Level.LevelTheme.MANSION:
		return "ghost"
	return Level.LevelTheme.find_key(theme).to_lower()


static func _failure(message: String) -> Dictionary:
	return {"error": ERR_UNAVAILABLE, "message": message}
