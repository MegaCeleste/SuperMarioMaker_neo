# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SlopeBody
extends StaticBody2D

var points: PackedVector2Array


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = 20
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	add_child(shape)


static func configure(body: CharacterBody2D) -> void:
	# A45-degree floor needs tolerance below the engine's equality boundary.
	# Snap follows a3px/tick descent; constant speed prevents uphill acceleration.
	body.floor_max_angle = deg_to_rad(50)
	body.floor_snap_length = 6
	body.floor_constant_speed = true


## The rectangular physical foot touches a slope at its uphill corner. Draw
## upright actors at the surface under their center, as on the source slopes;
## leave their collision geometry and airborne poses untouched.
static func visual_floor_offset(body: CharacterBody2D) -> Vector2:
	if not body.is_on_floor():
		return Vector2.ZERO
	var box := Utility.get_bounding_box(body)
	var foot := Vector2(box.get_center().x, box.end.y)
	var reach := clampf(box.size.x / 2 + 2, 4, 64)
	var query := PhysicsRayQueryParameters2D.create(foot - Vector2(0, 0.5), foot + Vector2(0, reach), 1)
	query.exclude = [body.get_rid()]
	var hit := body.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is SlopeBody:
		return Vector2.ZERO
	return Vector2(0, clampf(hit.position.y - foot.y, 0, reach))
