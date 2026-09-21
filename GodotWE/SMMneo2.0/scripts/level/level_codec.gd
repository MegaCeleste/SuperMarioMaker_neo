class_name LevelCodec
## Encodes and decodes [Level]s to and from the .neo file format.
##
## The .neo format is a JSON file containing the level's metadata and all its
## parts. Levels are stored in [code]user://levels/[/code].

const LEVELS_DIR = "user://levels/"

## Maps part class names to their PackedScene resources.
const PART_TYPE_MAP := {
	"CoinPart": preload("uid://cxu0namx61nsi"),
	"EditorPlayer": preload("uid://dl475ic48ilql"),
	"BuzzyBeetlePart": preload("res://scenes/parts/buzzybeetle_part.tscn"),
	"GaloombaPart": preload("uid://bqogj600unc0d"),
	"KoopaPart": preload("res://scenes/parts/koopa_part.tscn"),
	"RedKoopaPart": preload("res://scenes/parts/red_koopa_part.tscn"),
	"GroundPart": preload("uid://dpfaa6qawfnk1"),
	"MushroomPart": preload("res://scenes/parts/mushroom_part.tscn"),
	"OneUpPart": preload("res://scenes/parts/1up_part.tscn"),
	"QuestionBlockPart": preload("uid://b7i6hre4grgbn"),
	"StartingGround": preload("uid://di2ei4ammvd8g"),
	"TurnBlockPart": preload("uid://k7sykscno8vb"),
}


## Encodes a [Level] into a dictionary for JSON serialization.
static func encode(level: Level) -> Dictionary:
	var data := {
		"version": 1,
		"level_name": level.level_name,
		"author": level.author,
		"game_style": level.game_style,
		"description": level.description,
		"time": level.time,
		"clear_condition": level.clear_condition,
		"tag_1": level.tag_1,
		"tag_2": level.tag_2,
		"sub_areas": [],
	}

	for sub_area in level.sub_areas:
		var sub_data := {
			"level_theme": sub_area.level_theme,
			"night_mode": sub_area.night_mode,
			"autoscroll": sub_area.autoscroll,
			"parts": [],
		}
		for child in sub_area.get_parts().get_children():
			var part := child as Part
			if part == null:
				continue
			var type_name := _get_part_type_name(part)
			var grid_pos := Level.to_grid(part.global_position)
			sub_data.parts.append({
				"type": type_name,
				"grid_x": grid_pos.x,
				"grid_y": grid_pos.y,
			})
		data.sub_areas.append(sub_data)

	return data


## Saves a [Level] to a .neo file at [param path].
static func save(level: Level, path: String) -> void:
	_ensure_dir()
	var data := encode(level)
	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, 'LevelCodec: cannot open file for writing: "%s"' % path)
	file.store_string(json)
	file.close()
	level.file_path = path
	print("Level saved: ", ProjectSettings.globalize_path(path))


## Decodes a dictionary into a [Level] instance.
## The returned level is NOT added to the scene tree — the caller must add it.
## When added to the tree, [Level._ready] sets up sub-areas, backgrounds,
## and parts automatically.
static func decode(data: Dictionary, path := "") -> Level:
	var lvl: Level = load("uid://b16kyjui2n3qv").instantiate()

	lvl.level_name = data.get("level_name", "")
	lvl.author = data.get("author", "")
	lvl.game_style = data.get("game_style", Level.GameStyle.SMW) as Level.GameStyle
	lvl.description = data.get("description", "")
	lvl.time = data.get("time", 300)
	lvl.clear_condition = data.get("clear_condition", Level.ClearCondition.NONE) as Level.ClearCondition
	lvl.tag_1 = data.get("tag_1", Level.Tag.NONE) as Level.Tag
	lvl.tag_2 = data.get("tag_2", Level.Tag.NONE) as Level.Tag
	lvl.file_path = path

	# Remove default parts from the template (EditorPlayer, StartingGround, etc.)
	var sub_area: SubArea = lvl.get_node("%SubArea0")
	var parts_node := sub_area.get_parts()
	for child in parts_node.get_children():
		child.free()

	# Restore sub-area metadata
	var sub_areas_data: Array = data.get("sub_areas", [])
	if not sub_areas_data.is_empty():
		var sub_data: Dictionary = sub_areas_data[0]
		sub_area.level_theme = sub_data.get("level_theme", Level.LevelTheme.OVERWORLD) as Level.LevelTheme
		sub_area.night_mode = sub_data.get("night_mode", false)
		sub_area.autoscroll = sub_data.get("autoscroll", Level.Autoscroll.NONE) as Level.Autoscroll

		# Restore parts — _ready() will call part.load() when the level
		# enters the scene tree
		for part_data in sub_data.get("parts", []):
			var type_name: String = part_data.get("type", "")
			var scene: PackedScene = PART_TYPE_MAP.get(type_name)
			if scene == null:
				push_warning('LevelCodec: unknown part type "%s"' % type_name)
				continue
			var part: Part = scene.instantiate()
			part.global_position = Level.from_grid(Vector2i(
					part_data.get("grid_x", 0),
					part_data.get("grid_y", 0)))
			parts_node.add_child(part)

	return lvl


## Loads a [Level] from a .neo file at [param path].
static func load_from_path(path: String) -> Level:
	var file := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(file) as Dictionary
	assert(data != null, "LevelCodec: invalid .neo file: %s" % path)
	return decode(data, path)


## Scans [member LEVELS_DIR] and returns metadata for every .neo file found.
## Each entry contains: path, file_name, level_name, author, description,
## time, game_style.
static func list_levels() -> Array[Dictionary]:
	_ensure_dir()

	var dir := DirAccess.open(LEVELS_DIR)
	if dir == null:
		var abs := ProjectSettings.globalize_path(LEVELS_DIR)
		push_warning('LevelCodec: cannot open "%s" (abs: %s)' % [LEVELS_DIR, abs])
		return []

	var levels: Array[Dictionary] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		print('  -> found: ', file_name)
		if file_name.ends_with(".neo"):
			var path := LEVELS_DIR.path_join(file_name)
			var file := FileAccess.get_file_as_string(path)
			var data = JSON.parse_string(file) as Dictionary
			if data is Dictionary:
				levels.append({
					"path": path,
					"file_name": file_name,
					"level_name": data.get("level_name", file_name),
					"author": data.get("author", ""),
					"description": data.get("description", ""),
					"time": data.get("time", 300),
					"game_style": data.get("game_style", Level.GameStyle.SMW),
				})
		file_name = dir.get_next()

	print('LevelCodec.list_levels: found ', levels.size(), ' levels in ', LEVELS_DIR)
	return levels


## Ensures the levels directory exists.
static func _ensure_dir() -> void:
	if DirAccess.open(LEVELS_DIR) != null:
		return
	var abs := ProjectSettings.globalize_path(LEVELS_DIR)
	var err := DirAccess.make_dir_recursive_absolute(abs)
	if err != OK:
		push_error('LevelCodec: cannot create directory "%s" -> "%s", error: %d' % [LEVELS_DIR, abs, err])


## Returns the class name string for a Part instance.
static func _get_part_type_name(part: Part) -> String:
	return part.get_script().get_global_name()
