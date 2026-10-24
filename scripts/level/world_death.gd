# SPDX-License-Identifier: AGPL-3.0-or-later
class_name WorldDeath
extends Node
## obj_deadmario/Other_10 stops selected motion/animation every Step, while
## uncancelled alarms, independent objects and explicit position changes run.

var level: Level


static func active_for(node: Node) -> bool:
	var ancestor := node.get_parent()
	while ancestor != null:
		if ancestor is SubArea:
			return ancestor.level != null and ancestor.level.is_player_dying()
		if ancestor is Level:
			return ancestor.is_player_dying()
		ancestor = ancestor.get_parent()
	return false


static func pause_sprites(node: Node) -> void:
	for sprite in node.find_children("*", "AnimatedSprite2D", true, false):
		sprite.pause()


func _ready() -> void:
	process_physics_priority = 90 # Before the manager's end-step activation pass.
	apply()


func _physics_process(_delta: float) -> void:
	apply()


func apply() -> void:
	for node in level.current_sub_area.get_foreground().find_children("*", "", true, false):
		if node.is_queued_for_deletion() or not node.can_process():
			continue
		if node.has_method("apply_source_death"):
			node.apply_source_death()
		elif node is AnimatedSprite2D and node.has_meta(&"source_smoke"):
			node.pause()
		elif node is Coin:
			pause_sprites(node)
			node.get_node("Sprite").frame = 0
		elif node is QuestionBlock or node is TurnBlockTile or node is GoalGate:
			pause_sprites(node)
