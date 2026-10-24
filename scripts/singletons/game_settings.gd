extends Node
## Manages the game's settings.

## The currently configured username of the player.
var username := ""
## Whether to show button hover animations (see [ButtonHoverEffect]).
var show_hover_effect := true

var _flags: Array[StringName]

## The game's config file path.
const GAME_CONFIG_PATH = "user://SMMWE.cfg"
const LEVELS_PATH = "user://Levels/"


func _init() -> void:
	var file = FileAccess.open(GAME_CONFIG_PATH, FileAccess.ModeFlags.READ)
	if file != null:
		var data: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if data is Dictionary and data.get("username") is String \
				and data.get("show_hover_effect") is bool:
			username = data.username
			show_hover_effect = data.show_hover_effect
			return
	# Keep usable defaults even when the user directory is read-only. Retrying
	# _init recursively here used to overflow the stack on a failed write.
	reset_config()

## Resets the config file.
func reset_config() -> void:
	username = ""
	show_hover_effect = true
	var file = FileAccess.open(GAME_CONFIG_PATH, FileAccess.ModeFlags.WRITE)
	if file == null:
		push_warning("Cannot save game settings; using defaults (%s)." %
				error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({
		"username": "",
		"show_hover_effect": true
	}, "    "))
	file.close()


func flag_exists(flag: StringName) -> bool:
	return flag in _flags
