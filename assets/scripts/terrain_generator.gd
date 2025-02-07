@tool
extends MeshInstance3D

const terrain_size : float = 2560.0

@export_range(4, 256, 4) var terrain_resolution := 320:
	set(new_resolution):
		terrain_resolution = new_resolution
		update_mesh()

@export var noise: FastNoiseLite:
	set(new_noise):
		noise = new_noise
		update_mesh()
		if noise: 
			noise.changed.connect(update_mesh)

@export_range(4.0, 128.0, 4.0) var height : float = 64.0:
	set(new_height):
		height = new_height
		update_mesh()

func get_height(x: float, y: float) -> float:
	return noise.get_noise_2d(x, y) * height

func get_normal(x: float, y: float) -> Vector3:
	var epsilon := terrain_size / terrain_resolution
	var normal := Vector3(
		(get_height(x + epsilon, y) - get_height(x - epsilon, y)) / (2.0 * epsilon),
		1.0,
		(get_height(x, y + epsilon) - get_height(x, y - epsilon)) / (2.0 * epsilon),
	)

	return normal.normalized()

func update_mesh() -> void:
	var plane := PlaneMesh.new()
	plane.subdivide_depth = terrain_resolution
	plane.subdivide_width = terrain_resolution
	plane.size = Vector2(terrain_size, terrain_size)

	var plane_arrays := plane.get_mesh_arrays() 
	var vertex_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var normal_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array: PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]

	for i:int in vertex_array.size():
		var vertex := vertex_array[i]
		var normal := Vector3.UP
		var tangent := Vector3.RIGHT 

		if noise:
			vertex.y = get_height(vertex.x, vertex.z)
			normal = get_normal(vertex.x, vertex.z)
			tangent = normal.cross(Vector3.UP)
		
		vertex_array[i] = vertex
		normal_array[i] = normal
		tangent_array[4 * i] = tangent.x
		tangent_array[4 * i + 1] = tangent.y
		tangent_array[4 * i + 2] = tangent.z



	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_arrays)
	mesh = array_mesh
	# Need to fix this, as creating programatically is generating the collision with mistakes
	# as opposed to baking in the editor
	#generate_collision()


func generate_collision() -> void:
	var terrain_mesh = $"."

	var static_body = StaticBody3D.new()
	add_child(static_body)

	var collision_shape = CollisionShape3D.new()
	static_body.add_child(collision_shape)

	var shape = terrain_mesh.mesh.create_trimesh_shape()
	collision_shape.shape = shape
