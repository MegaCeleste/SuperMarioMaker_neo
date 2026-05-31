class_name C_AddCoin
extends Node


@onready var par = get_parent() as Area2D


func _ready() -> void:
	par.area_entered.connect(
		
	)
