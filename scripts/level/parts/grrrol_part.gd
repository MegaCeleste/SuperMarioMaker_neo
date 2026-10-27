# SPDX-License-Identifier: AGPL-3.0-or-later
class_name GrrrolPart
extends ThwompPart
## Separate native card for obj_panel_circle/Other_17's new rolling variant.


func _init() -> void:
	variant = ROLLING_SMALL
	attack_direction = 2


static func create() -> ThwompPart:
	return load("res://scenes/level/parts/grrrol_part.tscn").instantiate()


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return icon_for_variant(ROLLING_SMALL.id)
