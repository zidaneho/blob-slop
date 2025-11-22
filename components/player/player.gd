class_name Player extends Node3D

signal updated_unit_count(new_count : int)
signal player_died

# --- CONFIGURATION ---
@export var movement_speed: float = 20
@export var formation_radius: float = 3.0
@export var attack_range: float = 15.0
@export var damage_per_unit : float = 1
@export var unit_scene: PackedScene
@onready var collision_area = $Area3D/CollisionShape3D

var is_movement_locked: bool = false

# --- STATE ---
var units: Array[Unit] = []
var enemy_scan_timer: float = 0.0

# Cache known enemies to avoid finding them every frame
var nearby_enemies: Array[Node3D] = []
var is_game_active : bool = false

func _ready() -> void:
	add_to_group("units")

func _physics_process(delta):
	if not is_game_active or is_movement_locked:
		return
	handle_movement(delta)
	
	# OPTIMIZATION: Only scan for enemies 10 times a second, not 60
	enemy_scan_timer += delta
	if enemy_scan_timer > 0.1:
		scan_for_enemies()
		enemy_scan_timer = 0.0
	
	update_unit_commands()

# --- MOVEMENT ---

func handle_movement(delta):
	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("left"): input_dir.x += 1
	if Input.is_action_pressed("right"): input_dir.x -= 1
	input_dir.z += 1
	
	
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		global_position += input_dir * movement_speed * delta
	var limit = GameConfig.HALF_WIDTH
	global_position.x = clamp(global_position.x, -limit, limit)
# --- UNIT LOGIC ---

func register_unit(unit: Node3D):
	if unit is Unit and not units.has(unit):
		units.append(unit)
		# Assign a random offset so they don't stack on top of each other
		unit.set_meta("formation_offset", Vector3(
			randf_range(-formation_radius, formation_radius),
			0, 
			randf_range(-formation_radius, formation_radius)
		))

func update_unit_commands():
	# This loop handles BOTH movement and shooting orders
	# We do it in one pass for performance
	
	for unit in units:
		# 1. CALCULATE BASE TARGET
		var offset = unit.get_meta("formation_offset")
		var desired_pos = global_position + offset
		
		# 2. HANDLE WALL COLLISIONS (The "Smear" Effect)
		var boundary = GameConfig.HALF_WIDTH
		
		# Right Wall Check
		if desired_pos.x > boundary:
			var excess = desired_pos.x - boundary
			desired_pos.x = boundary
			# Push unit BACKWARD along the wall based on how far out they were
			# (We use -excess so they trail behind slightly)
			desired_pos.z += excess 
			
		# Left Wall Check
		elif desired_pos.x < -boundary:
			var excess = desired_pos.x - (-boundary) # This will be negative
			desired_pos.x = -boundary
			# excess is negative here, so -= adds to Z
			desired_pos.z -= excess 
			
		# 3. SEND COMMAND
		unit.set_formation_target(desired_pos)
		
		# 2. COMBAT LOGIC
		# Find the closest enemy from our cached list
		var target = get_closest_enemy(unit.global_position)
		
		if target:
			unit.assign_target(target)
			# Check distance (sqr_magnitude is faster than length)
			if unit.global_position.distance_squared_to(target.global_position) < attack_range * attack_range:
				unit.trigger_attack()
		else:
			unit.assign_target(null)

func scan_for_enemies():
	# Assuming you put enemies in a group named "enemies"
	nearby_enemies.assign(get_tree().get_nodes_in_group("enemies"))
	
	# Optional: Filter out far away enemies immediately to keep the list small
	# This keeps 'get_closest_enemy' fast
	nearby_enemies = nearby_enemies.filter(func(e): 
		return e.global_position.distance_squared_to(global_position) < (attack_range * 2.0) ** 2
	)

func get_closest_enemy(from_pos: Vector3) -> Node3D:
	var closest: Node3D = null
	var closest_dist = INF
	
	for enemy in nearby_enemies:
		if not is_instance_valid(enemy): continue
		
		var dist = from_pos.distance_squared_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy
			
	return closest
func start_running():
	is_game_active = true
	# Optional: Play a "Run" animation on all units instantly
	for unit in units:
		# if unit.has_method("play_run_anim"):
		# 	unit.play_run_anim()
		pass

func handle_operation(operation: GameConfig.Operation, value: int):
	var current_count = units.size()
	var target_count = current_count
	
	match operation:
		GameConfig.Operation.ADD:
			target_count = current_count + value
			
		GameConfig.Operation.SUBTRACT:
			target_count = current_count - value
			
		GameConfig.Operation.MULTIPLY:
			target_count = current_count * value
			
		GameConfig.Operation.DIVIDE:
			# Prevent division by zero
			if value != 0:
				target_count = current_count / value
			else:
				target_count = 1 # Fallback logic
		
	# Ensure we are between 0 and 500
	target_count = min(500, max(0, target_count))
	
	updated_unit_count.emit(target_count)
	
	# --- ADJUST SWARM SIZE ---
	var diff = target_count - current_count
	
	if diff > 0:
		spawn_units(diff)
	elif diff < 0:
		remove_units(abs(diff))


func spawn_units(amount: int):
	# Safety check
	if not unit_scene:
		push_error("Unit Scene not assigned in Player!")
		return

	for i in range(amount):
		var new_unit = unit_scene.instantiate()
		
		# Add to the same parent as the player (The Main Scene)
		# This keeps them independent in the scene tree
		get_parent().add_child(new_unit)
		new_unit.attack_damage = damage_per_unit
		# Start them at the player's position (with slight random offset)
		new_unit.global_position = global_position + Vector3(
			randf_range(-1, 1), 0, randf_range(-1, 1)
		)
		
		# Register them to the swarm
		register_unit(new_unit)

func remove_units(amount: int):
	# Don't try to remove more than we have
	amount = min(amount, units.size())
	
	for i in range(amount):
		# Remove from the end of the array (last one joined)
		var unit_to_remove = units.pop_back()
		
		if is_instance_valid(unit_to_remove):
			unit_to_remove.queue_free()
func die():
	# Prevent multiple triggers
	if not is_game_active: return
	
	is_game_active = false
	
	# 1. Visuals: Maybe play a death animation or particles
	visible = false 
	
	# 2. Notify the system
	emit_signal("player_died")
	
	# 3. Optional: Stop the game speed
	# Engine.time_scale = 0.1 # Slow motion death effect?
