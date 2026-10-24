@icon("uid://dgfxxtttchbse")
class_name SlideComponent
extends Component
## Provides sliding and turning around behavior.
## 
## Entities that use this type of movement include Goombas, Koopas, Mushrooms,
## 1-UPs, etc.

## Triggered when the node hits a wall and turns around.
signal turned(direction: Vector2)

## The speed the node will move at.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var speed := 60.0
## Turn back on the leading foot losing support (obj_enemyparent/Other_16.gml).
@export var avoid_ledges := false
## The current direction as a speed multiplier. [code]-1[/code] is left,
## [code]1[/code] is right.
var direction := -1

var _started := false


func _physics_process(_delta: float) -> void:
	if get_parent().is_on_floor():
		_started = true
	if _started:
		if get_parent().is_on_wall() or (avoid_ledges and get_parent().is_on_floor() \
				and not _has_floor_ahead()):
			direction *= -1
			if direction == 1:
				turned.emit(Vector2.RIGHT)
			elif direction == -1:
				turned.emit(Vector2.LEFT)
		get_parent().velocity.x = speed * direction


func _has_floor_ahead() -> bool:
	var body := get_parent() as CharacterBody2D
	var shape: CollisionShape2D = body.get_node("CollShape")
	var half_width := shape.shape.get_rect().size.x / 2.0
	var probe := body.global_position + Vector2(direction * maxf(1, half_width - 3), -1)
	var query := PhysicsRayQueryParameters2D.create(probe, probe + Vector2(0, 5), body.collision_mask)
	query.exclude = [body.get_rid()]
	if not body.get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		return true
	# Uphill-corner support leaves the leading foot farther above a downhill
	# face, even while the rear foot still reports the flat cap's normal.
	# Extend only for an actual slope; ordinary drops retain the5px ledge rule.
	query.to = probe + Vector2(0, half_width * 2 + 5)
	var lower := body.get_world_2d().direct_space_state.intersect_ray(query)
	return not lower.is_empty() and lower.collider is SlopeBody
