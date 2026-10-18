extends Node
## Headless regression for vertical slice 001: load the generated SWE fixture
## and verify every object the base maps today becomes the expected Part.

const LEVEL_PATH := "res://tests/fixtures/port_slice.swe"

const EXPECTED := {
	"GroundPart": 60,
	"CoinPart": 2,
	"QuestionBlockPart": 1,
	"TurnBlockPart": 1,
	"GaloombaPart": 1,
}


func _ready() -> void:
	var level: Level = await LevelProcessor.from_swe(LEVEL_PATH)
	if level == null:
		_fail("LevelProcessor returned null")
		return
	var sub_area: SubArea = level.current_sub_area
	if sub_area == null:
		_fail("current_sub_area is null")
		return

	var counts := {}
	for part in sub_area.get_parts().get_children():
		var script: Script = part.get_script()
		var key := str(script.get_global_name()) if script != null else part.get_class()
		if key == "":
			key = part.get_class()
		counts[key] = int(counts.get(key, 0)) + 1
	print("PART_COUNTS ", counts)
	print("LEVEL name=%s style=%s theme=%s parts=%d" % [
			level.level_name, level.game_style, sub_area.level_theme,
			sub_area.get_parts().get_child_count()])

	var ok := true
	for key: String in EXPECTED:
		var expected: int = EXPECTED[key]
		var actual: int = int(counts.get(key, 0))
		if actual != expected:
			push_error("expected %s=%d, got %d" % [key, expected, actual])
			ok = false

	print("SLICE001_RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _fail(message: String) -> void:
	push_error(message)
	print("SLICE001_RESULT FAIL")
	get_tree().quit(1)
