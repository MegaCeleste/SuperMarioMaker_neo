extends GutTest
## REQ-LVL-005 RLE 编解码用例

const LevelManagerScript := preload("res://src/autoload/level_manager.gd")

func test_rle_roundtrip() -> void:
	var tiles := PackedInt32Array([0, 0, 0, 34, 34, 0])
	var rle: String = LevelManagerScript.rle_encode(tiles)
	assert_eq(rle, "0:3,34:2,0:1")
	var decoded: PackedInt32Array = LevelManagerScript.rle_decode(rle, 6)
	assert_eq(decoded, tiles)

func test_rle_empty() -> void:
	assert_eq(LevelManagerScript.rle_encode(PackedInt32Array()), "")

func test_rle_rejects_bad_count() -> void:
	var decoded: PackedInt32Array = LevelManagerScript.rle_decode("0:5", 4)
	assert_eq(decoded.size(), 0, "长度不符必须拒绝")
	assert_push_error("LevelManager: RLE 展开长度 5 与区域面积 4 不符")

func test_rle_rejects_bad_format() -> void:
	var decoded: PackedInt32Array = LevelManagerScript.rle_decode("0x5", 5)
	assert_eq(decoded.size(), 0, "非法段必须拒绝")
	assert_push_error("LevelManager: RLE 段格式非法: 0x5")
