extends Button

var _level: Level

# Themes that have background scenes available
const THEMES := [
	Level.LevelTheme.OVERWORLD,
	Level.LevelTheme.AIRSHIP,
	Level.LevelTheme.BEACH,
	Level.LevelTheme.CASTLE,
	Level.LevelTheme.DESERT,
	Level.LevelTheme.FALL,
	Level.LevelTheme.FOREST,
]

var _theme_names := {
	Level.LevelTheme.OVERWORLD: "Overworld",
	Level.LevelTheme.AIRSHIP: "Airship",
	Level.LevelTheme.BEACH: "Beach",
	Level.LevelTheme.CASTLE: "Castle",
	Level.LevelTheme.DESERT: "Desert",
	Level.LevelTheme.FALL: "Fall",
	Level.LevelTheme.FOREST: "Forest",
}


func _ready() -> void:
	pressed.connect(_on_pressed)
	await %Editor.loaded
	_level = %Editor.level
	_update_text()
	_level.game_style_changed.connect(_update_text)


func _on_pressed() -> void:
	if _level == null:
		return
	var current = _level.sub_areas[0].level_theme
	var idx = THEMES.find(current)
	idx = (idx + 1) % THEMES.size()
	_level.sub_areas[0].level_theme = THEMES[idx]
	_level.sub_areas[0]._load_background()
	_update_text()


func _update_text() -> void:
	if _level == null:
		return
	var theme = _level.sub_areas[0].level_theme
	text = "Theme: " + _theme_names.get(theme, "???")
