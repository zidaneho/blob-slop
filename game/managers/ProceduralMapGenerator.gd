extends Node3D

@export var chunk_scene: PackedScene  # Drag Chunk.tscn here
@export var world_env: WorldEnvironment # Assign WorldEnvironment node
@export var biomes: Array[BiomeData]  # Drag Forest.tres, Desert.tres here
@export var gate_chunk_scene : Array[PackedScene]
@export var boss_chunk_scene: PackedScene

enum ChunkType { NORMAL, GATE, BOSS }

# Defines the pattern: 10 Normals -> 1 Gate -> 10 Normals -> 1 Boss
var spawn_pattern = [
	ChunkType.GATE, ChunkType.NORMAL, ChunkType.NORMAL, 
	ChunkType.GATE, ChunkType.NORMAL, ChunkType.GATE, 
	ChunkType.NORMAL, ChunkType.NORMAL, ChunkType.GATE, 
	ChunkType.BOSS
]
var pattern_index = 0

# Config
var pool_size = 5
var active_chunks: Array[Node3D] = []

# State
var current_biome_index = 0
var chunks_spawned = 0
var biome_switch_threshold = 50 # Switch every 50 chunks (1000m)

func _ready():
	var chunk_length = GameConfig.CHUNK_LENGTH
	
	for i in range(pool_size):
		var type_to_spawn = ChunkType.NORMAL
		
		# SAFE ZONE: Force the first 3 chunks to be Normal
		# This gives the player time to start running before hitting a gate/boss
		if i < 3:
			type_to_spawn = ChunkType.NORMAL
		else:
			# Use the pattern for everything else
			type_to_spawn = spawn_pattern[pattern_index]
			pattern_index = (pattern_index + 1) % spawn_pattern.size()
		
		# Create the chunk using our new helper
		var chunk = spawn_chunk_of_type(type_to_spawn)
		
		add_child(chunk)
		chunk.position.z = i * chunk_length
		
		# Configure visual biome
		if chunk.has_method("configure"):
			chunk.configure(biomes[current_biome_index])
			
		active_chunks.append(chunk)
		
	# Set initial environment
	apply_environment_instant(biomes[current_biome_index])

func update_chunk(player : Node3D):
	# Check if the chunk behind the player is too far back
	var back_chunk = active_chunks[0]
	if player.global_position.z > back_chunk.global_position.z + (GameConfig.CHUNK_LENGTH * 2):
		recycle_chunk()

func recycle_chunk():
	var chunk = active_chunks.pop_front()
	var front_chunk = active_chunks.back()
	
	# 1. DECIDE TYPE
	var current_type = spawn_pattern[pattern_index]
	pattern_index = (pattern_index + 1) % spawn_pattern.size()
	
	# 2. MANAGE POOLING
	# If we need a special chunk, we MUST delete the old one and create new.
	# If we need a Normal chunk, we try to reuse the old one to save performance.
	
	if current_type != ChunkType.NORMAL:
		# Case A: Special Chunk (Boss/Gate) -> Create New
		chunk.queue_free() 
		chunk = spawn_chunk_of_type(current_type)
		add_child(chunk)
		
	else:
		# Case B: Normal Chunk needed
		if chunk.has_node("Gate") or chunk.has_node("BossUnit"):
			# If the old chunk was special, destroy it and make a normal one
			chunk.queue_free()
			chunk = spawn_chunk_of_type(ChunkType.NORMAL)
			add_child(chunk)
		else:
			# Case C: Old chunk was Normal, New chunk is Normal -> REUSE IT (Fastest)
			pass 

	# 3. POSITION IT
	chunk.position.z = front_chunk.position.z + GameConfig.CHUNK_LENGTH
	
	if chunk.has_method("configure"):
		chunk.configure(biomes[current_biome_index])
		
	active_chunks.append(chunk)

func start_biome_transition():
	# 1. Calculate next index
	current_biome_index = (current_biome_index + 1) % biomes.size()
	var next_biome = biomes[current_biome_index]
	
	var env = world_env.environment
	var tween = create_tween()
	
	# 2. CURTAIN DOWN (Thicken fog to 1.0)
	# We use the OLD color to blind them, so it feels like entering a storm/sandstorm
	tween.tween_property(env, "fog_density", 1.0, 1.5)
	
	await tween.finished
	
	# 3. SWAP GLOBALS (Player is blind now)
	env.sky.sky_material.panorama = next_biome.sky_texture
	env.ambient_light_color = next_biome.ambient_light_color
	env.ambient_light_energy = next_biome.ambient_light_energy
	
	# 4. CURTAIN UP (Reveal new biome)
	var reveal_tween = create_tween()
	
	# Snap fog color immediately
	env.fog_light_color = next_biome.fog_color 
	# Fade density to new target
	reveal_tween.tween_property(env, "fog_density", next_biome.fog_density, 2.0)

func apply_environment_instant(biome: BiomeData):
	# Helper for the very start of the game
	if not world_env:
		return
	var env = world_env.environment
	env.sky.sky_material.panorama = biome.sky_texture
	env.fog_light_color = biome.fog_color
	env.fog_density = biome.fog_density
	env.ambient_light_color = biome.ambient_light_color
func randomize_gate(gate: Gate):
	# 1. Pick a random Math Operation (Add, Sub, Mult, Div)
	var op_index = randi() % 4 
	var operation = GameConfig.Operation.values()[op_index]
	var val = 0
	
	# 2. Pick a "Fair" Number based on the operation
	match operation:
		GameConfig.Operation.ADD: 
			val = randi_range(5, 25)
		GameConfig.Operation.SUBTRACT: 
			val = randi_range(2, 10)
		GameConfig.Operation.MULTIPLY: 
			val = randi_range(2, 4) # Small numbers for multiply to prevent infinite growth
		GameConfig.Operation.DIVIDE: 
			val = randi_range(2, 3) # Divide by 2 or 3 only
			
	# 3. Apply to the Gate
	gate.setup(operation, val)
func spawn_chunk_of_type(type: ChunkType) -> Node3D:
	var new_chunk: Node3D
	
	match type:
		ChunkType.BOSS:
			new_chunk = boss_chunk_scene.instantiate()
			
		ChunkType.GATE:
			# Pick random gate scene
			var random_scene = gate_chunk_scene.pick_random()
			new_chunk = random_scene.instantiate()
			
			# Configure gates immediately
			var gates = new_chunk.find_children("*", "Gate", true, false)
			for gate in gates:
				randomize_gate(gate)
				
		ChunkType.NORMAL:
			new_chunk = chunk_scene.instantiate()
			
	return new_chunk
