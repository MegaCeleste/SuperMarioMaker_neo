# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SpriteCollision
extends RefCounted
## Native shapes from a source frame-alpha union or a source ellipse.


static func precise(sprite_name: StringName, anchor := Vector2.ZERO, frame := -1) -> Array[ConvexPolygonShape2D]:
	var frames := SpriteLibrary.get_frames(sprite_name)
	var size := frames.get_frame_texture(&"default", 0).get_size()
	var bitmap := BitMap.new()
	bitmap.create(Vector2i(size))
	for index in frames.get_frame_count(&"default"):
		if frame >= 0 and index != frame:
			continue
		var image := frames.get_frame_texture(&"default", index).get_image()
		if image.is_compressed():
			image.decompress()
		for y in int(size.y):
			for x in int(size.x):
				# These source masks use collisionTolerance=0, including faint pixels.
				if image.get_pixel(x, y).a > 0:
					bitmap.set_bit(x, y, true)
	# Outer contour triangulation fills transparent holes (e.g. Thwomp's
	# mouth). Pack identical horizontal runs vertically into native convex
	# rectangles instead; their union preserves every source pixel and hole.
	var result: Array[ConvexPolygonShape2D] = []
	var active: Dictionary = {}
	var origin := SpriteLibrary.get_origin(sprite_name)
	for y in range(int(size.y) + 1):
		var next: Dictionary = {}
		var x := 0
		while y < int(size.y) and x < int(size.x):
			if not bitmap.get_bit(x, y):
				x += 1
				continue
			var start := x
			while x < int(size.x) and bitmap.get_bit(x, y):
				x += 1
			var key := Vector2i(start, x)
			var run: Rect2i = active.get(key, Rect2i(start, y, x - start, 0))
			run.size.y += 1
			next[key] = run
		for key in active:
			if not next.has(key):
				var run: Rect2i = active[key]
				result.append(rectangle(Vector2(run.size), Vector2(run.position) + Vector2(run.size) / 2 - origin + anchor))
		active = next
	return result


static func ellipse(size: Vector2, center: Vector2) -> ConvexPolygonShape2D:
	var shape := ConvexPolygonShape2D.new()
	var points := PackedVector2Array()
	for index in 32:
		var angle := TAU * index / 32
		points.append(Vector2(cos(angle), sin(angle)) * size / 2 + center)
	shape.points = points
	return shape


static func rectangle(size: Vector2, center: Vector2) -> ConvexPolygonShape2D:
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([center - size / 2, center + Vector2(size.x, -size.y) / 2,
			center + size / 2, center + Vector2(-size.x, size.y) / 2])
	return shape


static func add_shapes(body: CollisionObject2D, shapes: Array[ConvexPolygonShape2D]) -> void:
	for shape in shapes:
		var collision := CollisionShape2D.new()
		collision.shape = shape
		body.add_child(collision)
