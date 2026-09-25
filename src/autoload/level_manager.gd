extends Node
## LevelManager — 关卡数据内存持有者与 .smmlevel 序列化（03-level-format.md）

signal level_loaded
signal level_saved(path: String)

const FORMAT_VERSION := 1

var level_data: Dictionary = {}

func new_level(style: StringName = &"smw") -> void:
	level_data = {
		"format_version": FORMAT_VERSION,
		"metadata": {
			"title": "", "author": "", "description": "",
			"game_style": style,
			"creation_timestamp": Time.get_unix_time_from_system(),
			"timer": 300,
			"clear_condition": {"type": "none", "target_id": "", "count_required": 0},
		},
		"main_area": _empty_area("ground", 240, 27),
	}

func _empty_area(theme: String, width: int, height: int) -> Dictionary:
	return {
		"theme": theme,
		"is_night": false,
		"autoscroll_speed": "none",
		"bounds": {"left": 0, "top": 0, "right": width, "bottom": height},
		"tilemap_layers": [],
		"entities": [],
	}

func save_to_file(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(level_data, "\t"))
	level_saved.emit(path)
	return OK

func load_from_file(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return ERR_PARSE_ERROR
	if not data.has("format_version") or not data.has("metadata") or not data.has("main_area"):
		return ERR_INVALID_DATA
	level_data = data
	level_loaded.emit()
	return OK

## RLE 编解码（REQ-LVL-005）：行优先展平，格式 "<tile_id>:<count>" 逗号分隔
static func rle_encode(tiles: PackedInt32Array) -> String:
	if tiles.is_empty():
		return ""
	var parts: PackedStringArray = []
	var current := tiles[0]
	var count := 1
	for i: int in range(1, tiles.size()):
		if tiles[i] == current:
			count += 1
		else:
			parts.append("%d:%d" % [current, count])
			current = tiles[i]
			count = 1
	parts.append("%d:%d" % [current, count])
	return ",".join(parts)

static func rle_decode(rle: String, expected_count: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if rle.is_empty():
		return result
	for part: String in rle.split(","):
		var pair := part.split(":")
		if pair.size() != 2:
			push_error("LevelManager: RLE 段格式非法: " + part)
			return PackedInt32Array()
		var tile_id := pair[0].to_int()
		var count := pair[1].to_int()
		for i: int in count:
			result.append(tile_id)
	if result.size() != expected_count:
		push_error("LevelManager: RLE 展开长度 %d 与区域面积 %d 不符" % [result.size(), expected_count])
		return PackedInt32Array()
	return result
