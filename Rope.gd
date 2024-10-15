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

var raycast_query: PhysicsRayQueryParameters2D


func _ready() -> void:
	raycast_query= PhysicsRayQueryParameters2D.new()
	#raycast_query.hit_from_inside= true
	
	var spawn_pos: Vector2 = start_anchor_pos
	
	for i in range(nodes_amount):
		nodes.append(VerletNode.new())
		nodes[i].set_up(spawn_pos)
		
		spawn_pos += Vector2(0, nodes_separation)


func _physics_process(delta: float) -> void:
	%"Label FPS".text= "FPS: %d" % Engine.get_frames_per_second()
	simulate()
	for i in range(iterations):
		apply_constraints()
		#collision_resolution()
	
	update_line()

func simulate():
	for i in range(nodes_amount):
		var node: VerletNode = nodes[i]
		var temp: Vector2 = node.position
		node.position += collide_and_translate(node.position, (node.position - node.old_position) + gravity * timestep * timestep)
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
			var final_translate: Vector2= collide_and_translate(node_1.position, translate)
			node_1.position += final_translate
			
			final_translate= collide_and_translate(node_2.position, -final_translate)
			node_2.position += final_translate

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
			var final_translate: Vector2= collide_and_translate(node_1.position, translate)
			node_1.position += final_translate
			
			final_translate= collide_and_translate(node_2.position, -final_translate)
			node_2.position += final_translate

func collide_and_translate(origin: Vector2, motion: Vector2)-> Vector2:
	if motion.is_zero_approx():
		return Vector2.ZERO
		
	raycast_query.from= origin
	raycast_query.to= origin + motion
	var result: Dictionary= get_world_2d().direct_space_state.intersect_ray(raycast_query)
	
	if not result:
		return motion
	return (result.position - origin) + result.normal * motion.length()

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
	shape = shape as CircleShape2D
	var direction: Vector2 = point - shape_pos
	return shape_pos + direction.normalized() * shape.radius
	
	match shape:
		WorldBoundaryShape2D:
			shape = shape as WorldBoundaryShape2D
		
		SegmentShape2D:
			shape = shape as SegmentShape2D
			return Geometry2D.get_closest_point_to_segment(point, shape.a + shape_pos, shape.b + shape_pos)
		
		SeparationRayShape2D:
			shape = shape as SeparationRayShape2D
		
		CircleShape2D:
			print("circle")
			shape = shape as CircleShape2D
			#var direction: Vector2 = point - shape_pos
			#return shape_pos + direction.normalized() * shape.radius
		
		RectangleShape2D:
			shape = shape as RectangleShape2D
		
		CapsuleShape2D:
			shape = shape as CapsuleShape2D
		
		ConvexPolygonShape2D:
			shape = shape as ConvexPolygonShape2D
		
		ConcavePolygonShape2D:
			shape = shape as ConcavePolygonShape2D
	
	return Vector2(0, 0)



class VerletNode:
	const STEP_TIME: float = 0.01
	
	var position: Vector2
	var old_position: Vector2
	
	func set_up(position: Vector2):
		self.position = position
		self.old_position = position
