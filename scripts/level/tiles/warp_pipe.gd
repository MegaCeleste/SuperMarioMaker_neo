# SPDX-License-Identifier: AGPL-3.0-or-later
class_name WarpPipe
extends StaticBodyExt
## The play-time pipe built from a [PipePart]: solid on every side, drawn over
## Mario while he travels through it, and the entrance check of a linked pipe
## (source obj_tuberia Step).

## Horizontal reach from the pipe's centre line at which Mario can enter an
## upward or downward opening (source 6px probe plus Mario's half width).
const CENTER_REACH := 9.0

## Things let out move through the opening at this speed, like Mario.
const EMERGE_SPEED := 30.0
## How far a let-out thing travels before it moves on its own: one cell out
## of a vertical opening, a cell and a half out of a side one.
const EMERGE_DISTANCE := 16.0
const SIDE_EMERGE_DISTANCE := 24.0

var part: PipePart
var _spawn_left := 0.0
var _spawned: Array[Node2D] = []
## Let-out things still coming through the opening, with their saved state.
var _emerging: Array[Dictionary] = []


func _ready() -> void:
	z_as_relative = false
	z_index = GameConstants.Layers.Z_SOLIDS
	var size := part.get_size()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size
	shape.position = size / 2
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = false
	sprite.texture = PipePart.texture_for(part.color, part.facing, part.segments)
	add_child(sprite)


func _physics_process(delta: float) -> void:
	_let_out(delta)
	var exit := part.get_exit()
	if exit == null or not is_instance_valid(exit.runtime) or not is_instance_valid(part.level):
		return
	var player := part.level.get_living_player()
	if player != null and player.sub_area == part.sub_area and can_enter(player):
		player.enter_pipe(self, exit.runtime)


## Source obj_tuberia Step: Mario must stand on (or, for a downward opening,
## press up against) the opening and push into it. Side openings need him on
## the ground at the bottom of the mouth.
func can_enter(player: Player) -> bool:
	# SMM2 lets Mario carry anything through a pipe, springs included.
	if player.is_traveling():
		return false
	var box := Utility.get_bounding_box(player)
	var mouth := part.mouth_rect()
	var center := mouth.get_center()
	match part.facing:
		PipePart.Facing.UP:
			return Input.is_action_pressed(&"player_down") and player.is_on_floor() \
					and absf(player.global_position.y - mouth.position.y) <= 1.0 \
					and absf(player.global_position.x - center.x) < CENTER_REACH
		PipePart.Facing.DOWN:
			return Input.is_action_pressed(&"player_up") and absf(box.position.y - mouth.end.y) <= 2.0 \
					and absf(player.global_position.x - center.x) < CENTER_REACH
		PipePart.Facing.RIGHT:
			return Input.is_action_pressed(&"player_left") and player.is_on_floor() \
					and absf(player.global_position.y - mouth.end.y) <= 1.0 \
					and box.position.x >= mouth.end.x - 1.0 and box.position.x <= mouth.end.x + 2.0
		_:
			return Input.is_action_pressed(&"player_right") and player.is_on_floor() \
					and absf(player.global_position.y - mouth.end.y) <= 1.0 \
					and box.end.x <= mouth.position.x + 1.0 and box.end.x >= mouth.position.x - 2.0


## SMM2 pipe contents: while the opening is on screen, a new copy comes out
## every colour interval, up to [constant PipePart.MAX_SPAWNED] at once.
func _let_out(delta: float) -> void:
	for item in _emerging.duplicate():
		var body: Node2D = item.body
		if not is_instance_valid(body):
			_emerging.erase(item)
			continue
		body.position += PipePart.axis(part.facing) * EMERGE_SPEED * delta
		item.moved += EMERGE_SPEED * delta
		if item.moved >= item.distance:
			body.process_mode = item.mode
			body.z_as_relative = item.relative
			body.z_index = item.z
			_emerging.erase(item)
	if part.content == null or not is_instance_valid(part.level) or part.level.status != Level.Status.PLAYING:
		return
	_spawned = _spawned.filter(func(body): return is_instance_valid(body) and not body.is_queued_for_deletion())
	if _spawned.size() >= PipePart.MAX_SPAWNED or not _on_screen():
		return
	_spawn_left -= delta
	if _spawn_left > 0:
		return
	_spawn_left = PipePart.SPAWN_INTERVALS[part.color]
	_spawn()


func _on_screen() -> bool:
	var view := Rect2(Utility.camera_position, get_viewport().get_visible_rect().size / Utility.camera_scale)
	var mouth := part.mouth_rect()
	return view.intersects(Rect2(mouth.position + global_position - position, mouth.size))


# Builds one copy of the contents just inside the opening.
func _spawn() -> void:
	var content := part.content
	var foreground := part.sub_area.get_foreground()
	var before := foreground.get_child_count()
	var mouth := part.mouth_rect()
	var out := PipePart.axis(part.facing)
	# Entity origins are bottom-centre; start one cell back inside the opening.
	var origin: Vector2
	match part.facing:
		PipePart.Facing.UP:
			origin = Vector2(mouth.get_center().x, mouth.position.y + EMERGE_DISTANCE)
		PipePart.Facing.DOWN:
			origin = Vector2(mouth.get_center().x, mouth.end.y)
		_:
			origin = Vector2(mouth.get_center().x - out.x * EMERGE_DISTANCE / 2, mouth.end.y)
	content.level = part.level
	content.sub_area = part.sub_area
	content.position = origin - Vector2(8, 16)
	content.build()
	for i in range(before, foreground.get_child_count()):
		var body := foreground.get_child(i) as Node2D
		if body == null:
			continue
		var slide := body.get_node_or_null("SlideComponent") as SlideComponent
		if slide != null and out.x != 0:
			slide.direction = int(out.x)
		_emerging.append({"body": body, "moved": 0.0, "distance": SIDE_EMERGE_DISTANCE if out.x != 0 else EMERGE_DISTANCE,
				"mode": body.process_mode,
				"relative": body.z_as_relative, "z": body.z_index})
		body.process_mode = Node.PROCESS_MODE_DISABLED
		body.z_as_relative = false
		body.z_index = GameConstants.Layers.Z_SOLIDS - 1
		_spawned.append(body)
