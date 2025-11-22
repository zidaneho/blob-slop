extends Node3D

# 1. GET REFERENCES TO YOUR NEW NODES
@onready var ground = $Ground
@onready var grass = $Grass
@onready var rocks = $Rocks
@onready var decor = $Decor

# Inside Chunk.gd
func _ready() -> void:
	if grass.multimesh:
		grass.multimesh = grass.multimesh.duplicate()
	if rocks.multimesh:
		rocks.multimesh = rocks.multimesh.duplicate()
	if decor.multimesh:
		decor.multimesh = decor.multimesh.duplicate()

func configure(biome: BiomeData):
	# 1. GROUND
	# We assume ground always exists, but safety check anyway
	if biome.ground_material:
		ground.material_override = biome.ground_material
	else:
		ground.visible = false
	
	# 3. GRASS
	if biome.grass_mesh:
		grass.multimesh.mesh = biome.grass_mesh
		grass.visible = true
		if biome.grass_material:
			grass.material_override = biome.grass_material
	else:
		grass.visible = false 

	# 4. ROCKS
	if biome.rock_mesh:
		rocks.multimesh.mesh = biome.rock_mesh
		rocks.visible = true
	else:
		rocks.visible = false

	# 5. DECOR (Array check)
	if biome.decor_meshes and biome.decor_meshes.size() > 0:
		decor.multimesh.mesh = biome.decor_meshes.pick_random()
		decor.visible = true
	else:
		decor.visible = false

	# Only randomize layout for things that are actually visible
	randomize_layout()

func randomize_layout():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	if grass.visible:
		_scatter_objects(grass, rng)
	if rocks.visible:
		_scatter_objects(rocks, rng)
	
	if decor.visible:
		_scatter_objects(decor, rng)

# A helper function so we don't write the same loop 4 times
func _scatter_objects(node: MultiMeshInstance3D, rng: RandomNumberGenerator):
	var count = node.multimesh.instance_count
	
	for i in range(count):
		var t = Transform3D()
		
		var x_range = GameConfig.HALF_WIDTH 
		var z_range = GameConfig.CHUNK_LENGTH
		
		# Random Position (Adjust -10/10 to fit your chunk size)
		t.origin = Vector3(rng.randf_range(-x_range, x_range), 0, rng.randf_range(0, z_range))
		
		# Random Rotation (Y-axis)
		t.basis = Basis(Vector3.UP, rng.randf_range(0, TAU))
		
		var scale_amount = rng.randf_range(0.8, 1.2)
		var height_modifier = 0.3 # <--- Change this to 0.5 for half height, 2.0 for double
		
		# Scale X and Z normally, but multiply Y by height_modifier
		t.basis = t.basis.scaled(Vector3(scale_amount, scale_amount * height_modifier, scale_amount))
		
		node.multimesh.set_instance_transform(i, t)
