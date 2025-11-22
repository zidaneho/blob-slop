extends Node3D

@export var chunk_scene: PackedScene  # Drag Chunk.tscn here
@export var player: Node3D            # Assign your player node
@export var world_env: WorldEnvironment # Assign WorldEnvironment node
@export var biomes: Array[BiomeData]  # Drag Forest.tres, Desert.tres here

# Config
var chunk_length = 10
var pool_size = 5
var active_chunks: Array[Node3D] = []

# State
var current_biome_index = 0
var chunks_spawned = 0
var biome_switch_threshold = 50 # Switch every 50 chunks (1000m)

func _ready():
	# Initialize the pool
	for i in range(pool_size):
		var chunk = chunk_scene.instantiate()
		add_child(chunk)
		chunk.position.z = i * chunk_length
		
		# Configure initial look
		chunk.configure(biomes[current_biome_index])
		active_chunks.append(chunk)
		
	# Set initial environment
	apply_environment_instant(biomes[current_biome_index])

func _process(delta):
	# Check if the chunk behind the player is too far back
	var back_chunk = active_chunks[0]
	if player.global_position.z > back_chunk.global_position.z + (chunk_length):
		recycle_chunk()

func recycle_chunk():
	var chunk = active_chunks.pop_front()
	var front_chunk = active_chunks.back()
	
	# Move chunk to the front
	chunk.position.z = front_chunk.position.z + chunk_length
	
	chunk.position.y = -10.0 
	
	# Create the Tween
	var tween = create_tween()
	# Animate to y=0 over 0.5 seconds with a "Bounce" effect
	tween.tween_property(chunk, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	
	# Logic: Should we switch biomes?
	chunks_spawned += 1
	if chunks_spawned > biome_switch_threshold:
		chunks_spawned = 0
		start_biome_transition()
		
	# Apply the CURRENT biome look to the recycled chunk
	chunk.configure(biomes[current_biome_index])
	
	active_chunks.append(chunk)

# --- TRANSITION LOGIC (Method A: Fog Curtain) ---

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
