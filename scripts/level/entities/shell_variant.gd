# SPDX-License-Identifier: AGPL-3.0-or-later
class_name ShellVariant
extends Resource
## Shared shell art, collision and occupant policy; no assumption of a Koopa.

@export var id: StringName
@export var shell_sprite: StringName
@export var inside_sprite: StringName
@export var dead_sprite: StringName
@export var mask_width := 10.0
@export var mask_height := 16.0
@export var restore_scene := ""
@export var reentry_time := 1.0
@export var recovery_time := 0.0
@export var warning_time := 9.0
@export var stopped_recovery_time := 10.0
@export var wearable := false
@export var spiked_top := false
@export var helmet_rules: HelmetRules
@export var fireproof := false
