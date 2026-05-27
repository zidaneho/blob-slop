extends Node3D

@export var chunk_scene: PackedScene  # Drag Chunk.tscn here
@export var world_env: WorldEnvironment # Assign WorldEnvironment node
@export var biomes: Array[BiomeData]  # Drag Forest.tres, Desert.tres here
@export var gate_chunk_scene : Array[PackedScene]
@export var boss_chunk_scene: PackedScene
@export var enemy_scene : PackedScene
@export var boss_pool : BossPool

var last_boss_index = INF

var player 

enum ChunkType { NORMAL, GATE, ENEMY,  BOSS }

var spawn_pattern = [
	ChunkType.GATE, ChunkType.NORMAL, 
	ChunkType.GATE, ChunkType.ENEMY, ChunkType.GATE, 
	ChunkType.ENEMY, ChunkType.NORMAL, 
	
	ChunkType.GATE, ChunkType.GATE, ChunkType.ENEMY,
	ChunkType.NORMAL, ChunkType.ENEMY, ChunkType.GATE,

	ChunkType.BOSS,
	ChunkType.NORMAL, ChunkType.NORMAL, ChunkType.NORMAL
]
var pattern_index = 0
var difficulty_tier: int = 0
var boss_fight_active: bool = false
# Config
var pool_size = 5
var active_chunks: Array[Node3D] = []

# State
var current_biome_index = 0
var transition_z: float = INF # The Z-coordinate where the new biome begins
var pending_biome: BiomeData = null # The biome waiting to be revealed
#var chunks_spawned = 0
#var biome_switch_threshold = 50 # Switch every 50 chunks (1000m)
var first_gate_spawned: bool = false
func _ready():
	GameManager.started_boss_fight.connect(_on_boss_fight_started)
	GameManager.ended_boss_fight.connect(_on_boss_fight_ended)

	var chunk_length = GameConfig.CHUNK_LENGTH

	for i in range(pool_size):
		# Safe Zone logic
		var type_to_spawn = ChunkType.NORMAL if i < 3 else spawn_pattern[pattern_index]
		if i >= 3:
			pattern_index = (pattern_index + 1) % spawn_pattern.size()
		
		var chunk = spawn_chunk_of_type(type_to_spawn)
		add_child(chunk)
		chunk.position.z = i * chunk_length
		
		if chunk.has_method("configure"):
			chunk.configure(biomes[current_biome_index])
			
		active_chunks.append(chunk)
		
	apply_environment_instant(biomes[current_biome_index])
func _process(_delta: float) -> void:
	if is_instance_valid(player):
		update_chunk(player)
func update_chunk(_player: Node3D):
	# 1. CHECK RECYCLING (Infinite Runner Logic)
	var back_chunk = active_chunks[0]
	if player.global_position.z > back_chunk.global_position.z + (GameConfig.CHUNK_LENGTH * 2):
		recycle_chunk()
		
	# 2. CHECK BIOME TRANSITION (New Feature)
	# We check if the player has crossed the "Seam" into the new territory
	if transition_z != INF and player.global_position.z > transition_z:
		perform_environment_transition()

func recycle_chunk():
	var chunk = active_chunks.pop_front()
	var front_chunk = active_chunks.back()
	
	# During a boss fight, freeze the pattern and only spawn empty NORMAL chunks
	# so the chase corridor stays clean. The pattern resumes from where we left
	# off once the fight ends.
	var current_type: ChunkType
	if boss_fight_active:
		current_type = ChunkType.NORMAL
	else:
		current_type = spawn_pattern[pattern_index]
		pattern_index = (pattern_index + 1) % spawn_pattern.size()
	
	# --- POOLING LOGIC ---
	if current_type != ChunkType.NORMAL:
		chunk.queue_free() 
		chunk = spawn_chunk_of_type(current_type)
		add_child(chunk)
		
	else:
		if chunk is BossChunk:
			chunk.queue_free()
			chunk = spawn_chunk_of_type(ChunkType.NORMAL)
			add_child(chunk)

	# --- POSITION ---
	chunk.position.z = front_chunk.position.z + GameConfig.CHUNK_LENGTH
	
	# --- ANIMATION ---
	chunk.position.y = -10.0
	var tween = create_tween()
	tween.tween_property(chunk, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# --- CONFIGURE ---
	# This will use the NEW index if the boss just died
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
	# 1. Pick a random Math Operation
	var possible_ops = [
		GameConfig.Operation.ADD,
		GameConfig.Operation.MULTIPLY,
		GameConfig.Operation.SUBTRACT,
		GameConfig.Operation.DIVIDE,
		GameConfig.Operation.RANDOM,
		GameConfig.Operation.SQRT,
	]
	var operation = possible_ops.pick_random()
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
		GameConfig.Operation.LOG:
			# We only want base 2 or base 10 usually, as they make the most sense mentally
			var bases = [2, 10]
			val = bases.pick_random()
		# RANDOM, SQRT: value is unused — outcome decided at trigger time

	# 3. Apply to the Gate
	gate.setup(operation, val)
func spawn_chunk_of_type(type: ChunkType) -> Node3D:
	var new_chunk: Node3D
	
	match type:
		ChunkType.BOSS:
			new_chunk = boss_chunk_scene.instantiate()
			if new_chunk.has_method("configure_boss_scene") and boss_pool.bosses.size() > 0:
				var random_index = randi_range(0,boss_pool.bosses.size()-2)
				if random_index >= last_boss_index:
					random_index += 1
				new_chunk.configure_boss_scene(boss_pool.bosses[random_index].scene,difficulty_tier)
				last_boss_index = random_index
			elif boss_pool.bosses.size() <= 0:
				push_error("Unable to spawn a boss because the boss pool has no bosses!")
		ChunkType.GATE:
			# ... (existing gate logic) ...
			var random_scene = gate_chunk_scene.pick_random()
			new_chunk = random_scene.instantiate()
			var gates = new_chunk.find_children("*", "Gate", true, false)
			for gate in gates:
				if not first_gate_spawned:
					# Force Guaranteed Addition for the tutorial phase
					gate.setup(GameConfig.Operation.ADD, randi_range(5, 10))
				else:
					# Standard Randomization
					randomize_gate(gate)
			if not first_gate_spawned:
				first_gate_spawned = true

		ChunkType.ENEMY:
			# Reuse normal chunk base
			new_chunk = chunk_scene.instantiate()
			spawn_enemies_in_chunk(new_chunk)
			
		ChunkType.NORMAL:
			new_chunk = chunk_scene.instantiate()
	return new_chunk
func spawn_enemies_in_chunk(chunk: Node3D):
	# Spawn 3-5 enemies randomly on the road
	var count = randi_range(3, 5)
	
	for i in range(count):
		var enemy = enemy_scene.instantiate()
		chunk.add_child(enemy)
		
		# Random Position on the road (using GameConfig constants)
		var x_pos = randf_range(-GameConfig.HALF_WIDTH, GameConfig.HALF_WIDTH)
		var z_pos = randf_range(2.0, GameConfig.CHUNK_LENGTH - 2.0)
		
		enemy.position = Vector3(x_pos, 0, z_pos)
func on_boss_defeated():
	# 1. SWITCH DATA IMMEDIATELY
	difficulty_tier += 1
	current_biome_index = (current_biome_index + 1) % biomes.size()
	var new_biome = biomes[current_biome_index]
	
	# 2. REPAINT FUTURE CHUNKS (The Fix)
	# We look through the active chunks to find where the boss is,
	# and update every chunk that comes AFTER it.
	var boss_passed = false
	
	for chunk in active_chunks:
		# Check if this is the boss chunk
		if chunk is BossChunk or chunk.has_node("BossUnit"):
			boss_passed = true
			
			# Set the visual transition to happen exactly when we leave this chunk
			transition_z = chunk.position.z + GameConfig.CHUNK_LENGTH
			continue # Don't change the boss chunk's ground
			
		if boss_passed:
			# This chunk is AHEAD of the boss. Force it to the New Biome!
			if chunk.has_method("configure"):
				chunk.configure(new_biome)
	
	# 3. PREPARE VISUALS (Sky/Fog)
	# This will be applied later by 'perform_environment_transition'
	pending_biome = new_biome
	
	# Fallback: If boss wasn't found (rare), switch at the horizon
	if not boss_passed:
		transition_z = active_chunks.back().position.z

func _on_boss_fight_started():
	print("boss fight started")
	boss_fight_active = true

func _on_boss_fight_ended():
	boss_fight_active = false
	on_boss_defeated()

func perform_environment_transition():
	# Reset the trigger so it doesn't fire every frame
	transition_z = INF 
	
	if not pending_biome: return
	
	# --- VISUAL TRANSITION EFFECT ---
	var env = world_env.environment
	var tween = create_tween()
	
	# 1. Fog thickens (Blinds the player)
	tween.tween_property(env, "fog_density", 1.0, 1.0)
	
	await tween.finished
	
	# 2. Swap Sky/Light while blind
	env.sky.sky_material.panorama = pending_biome.sky_texture
	env.ambient_light_color = pending_biome.ambient_light_color
	env.ambient_light_energy = pending_biome.ambient_light_energy
	
	# 3. Fog clears (Reveals new world)
	var reveal = create_tween()
	env.fog_light_color = pending_biome.fog_color 
	reveal.tween_property(env, "fog_density", pending_biome.fog_density, 2.0)
