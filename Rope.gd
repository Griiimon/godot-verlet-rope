class_name Rope

extends Node2D

@export var iterations: int = 80
@export var nodes_amount: int = 100
@export var nodes_separation: float = 10
@export var gravity: Vector2 = Vector2(0, 100)

@onready var line: Line2D = $"Line"

var nodes: Array[VerletNode] = []

var start_anchor: bool = false
var start_anchor_pos: Vector2

var end_anchor: bool = false
var end_anchor_pos: Vector2

const timestep: float = 0.1

func _ready() -> void:
	var spawn_pos: Vector2 = start_anchor_pos
	
	for i in range(nodes_amount):
		nodes.append(VerletNode.new())
		nodes[i].set_up(spawn_pos)
		
		spawn_pos += Vector2(0, nodes_separation)

func _physics_process(delta: float) -> void:
	simulate()
	for i in range(iterations):
		apply_constraints()
		collision_resolution()
	
	update_line()

func simulate():
	for i in range(nodes_amount):
		var node: VerletNode = nodes[i]
		var temp: Vector2 = node.position
		node.position += (node.position - node.old_position) + gravity * timestep * timestep;
		node.old_position = temp;

func apply_constraints():
	pull_toward_anchor1()
	pull_toward_anchor2()

func pull_toward_anchor1():
	if start_anchor:
		# Anchor starting node
		nodes[0].position = start_anchor_pos
		
		for i in range(nodes_amount - 1):
			var node_1: VerletNode = nodes[i + 1]
			var node_2: VerletNode = nodes[i]
			
			var direction: Vector2 = node_1.position - node_2.position
			var distance: float = direction.length()
			
			# Avoid div by 0
			if distance == 0:
				continue
			
			direction = direction.normalized()
			var difference_factor: float = nodes_separation - distance
			var translate: Vector2 = direction * difference_factor * 0.9
			
			# Update positions
			node_1.position += translate
			node_2.position -= translate

func pull_toward_anchor2():
	if end_anchor:
		# Anchor ending node
		nodes[nodes_amount - 1].position = end_anchor_pos
		
		for i in range(nodes_amount - 1):
			var node_1: VerletNode = nodes[nodes_amount - i - 2]
			var node_2: VerletNode = nodes[nodes_amount - i - 1]
			
			var direction: Vector2 = node_1.position - node_2.position
			var distance: float = direction.length()
			
			# Avoid div by 0
			if distance == 0:
				continue
			
			direction = direction.normalized()
			var difference_factor: float = nodes_separation - distance
			var translate: Vector2 = direction * difference_factor * 0.9
			
			# Update positions
			node_1.position += translate
			node_2.position -= translate

func is_node_colliding(node: VerletNode) -> bool:
	var space_state = get_world_2d().direct_space_state
	
	var query_params := PhysicsPointQueryParameters2D.new()
	query_params.position = node.position
	var results: Array[Dictionary] = space_state.intersect_point(query_params, 1)
	
	if results.size() > 0:
		return true
	else: 
		return false
	

func collision_resolution():
	var space_state = get_world_2d().direct_space_state
	for i in range(nodes_amount - 1):
		# Make a physics query
		var query_params := PhysicsPointQueryParameters2D.new()
		query_params.position = nodes[i].position
		var results: Array[Dictionary] = space_state.intersect_point(query_params, 1)
		
		if results.size() > 0:
			var collider: CollisionObject2D = results[0].get("collider")
			var shape_index: int = results[0].get("shape")
			var collision_shape: CollisionShape2D = CollisionShape2D.new()
			
			# Get the collision shape
			for child in collider.get_children():
				if child is CollisionShape2D:
					collision_shape = child
					break
			
			var edge_point: Vector2 = get_closest_point_on_shape(
				nodes[i].position,
				collision_shape.shape,
				collision_shape.global_position
			)
			
			nodes[i].position = edge_point
	


func update_line():
	var display_nodes: PackedVector2Array = []
	for node: VerletNode in nodes:
		display_nodes.append(node.position)
	
	line.points = display_nodes


func get_closest_point_on_shape(point: Vector2, shape: Shape2D, shape_pos: Vector2) -> Vector2:
	
	if shape is	WorldBoundaryShape2D:
		shape = shape as WorldBoundaryShape2D
		return Geometry2D.get_closest_point_to_segment_uncapped(point, shape.normal.rotated(PI / 4) + shape_pos, shape.normal.rotated(-PI / 4) + shape_pos)
		
	elif shape is SegmentShape2D:
		# a point cannot be inside a SegmentShape
		assert(false, "not implemented")
		
	elif shape is SeparationRayShape2D:
		# its not a real collision shape
		assert(false, "not implemented")
		
	elif shape is CircleShape2D:
		shape = shape as CircleShape2D
		var direction: Vector2 = point - shape_pos
		return shape_pos + direction.normalized() * shape.radius
		
	elif shape is RectangleShape2D:
		shape = shape as RectangleShape2D
		var points: PackedVector2Array
		points.append(-shape.size / 2)
		points.append(Vector2(shape.size.x / 2, -shape.size.y / 2))
		points.append(shape.size / 2)
		points.append(Vector2(-shape.size.x / 2, shape.size.y / 2))
		
		return get_closes_point_on_polygon(point, shape_pos, points)

	elif shape is CapsuleShape2D:
		assert(false, "not implemented")
		shape = shape as CapsuleShape2D
		
	elif shape is ConvexPolygonShape2D:
		shape = shape as ConvexPolygonShape2D
		return get_closes_point_on_polygon(point, shape_pos, shape.points)
		
	elif shape is ConcavePolygonShape2D:
		shape = shape as ConcavePolygonShape2D
		return get_closes_point_on_polygon(point, shape_pos, shape.points)
	
	return Vector2(0, 0)


func get_closes_point_on_polygon(point: Vector2, polygon_pos: Vector2, polygon: PackedVector2Array):
	#assert(Geometry2D.is_point_in_polygon(point - polygon_pos, polygon), str(point))
	var nearest= null
	var closest_point: Vector2
	var prev_point= null
	
	for polygon_point: Vector2 in polygon:
		if prev_point == null:
			prev_point= polygon[-1]
			
		var close_point: Vector2= Geometry2D.get_closest_point_to_segment(point, prev_point + polygon_pos, polygon_point + polygon_pos)
		var distance: float= (point).distance_to(close_point)
		if nearest == null or distance < nearest:
			nearest= distance
			closest_point= close_point
			
		prev_point= polygon_point

	return closest_point


class VerletNode:
	const STEP_TIME: float = 0.01
	
	var position: Vector2
	var old_position: Vector2
	
	func set_up(position: Vector2):
		self.position = position
		self.old_position = position
