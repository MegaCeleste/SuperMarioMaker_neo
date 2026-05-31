extends Control

@export var target_node: Node2D


@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
	var label = %PosLabel
	
	label.text = "pos: {0}".format([target_node.position])
	
	
