class_name Player extends Node3D

signal updated_unit_count(new_count : int)
signal player_died

# --- CONFIGURATION ---
@export var movement_speed: float = 10.0
@export var formation_radius: float = 3.0
@export var attack_range: float = 15.0
@export var damage_per_unit : float = 1
@export var unit_attack_cooldown: float = 0.25
@export var max_projectiles_per_frame: int = 6
@export var unit_scene: PackedScene
# @onready var collision_area = $Area3D/CollisionShape3D

var is_movement_locked: bool = false

# --- STATE ---
var units: Array[Unit] = []
var enemy_scan_timer: float = 0.0

# Cache known enemies to avoid finding them every frame
var nearby_enemies: Array[Node3D] = []
var is_game_active : bool = false
var _swarm_renderer: SwarmRenderer

func _ready() -> void:
	add_to_group("units")
	add_to_group("player")
	_swarm_renderer = SwarmRenderer.new()
	add_child(_swarm_renderer)

func _physics_process(delta):
	if not is_game_active:
		return
	handle_movement(delta)
	
	# OPTIMIZATION: Only scan for enemies 10 times a second, not 60
	enemy_scan_timer += delta
	if enemy_scan_timer > 0.1:
		scan_for_enemies()
		enemy_scan_timer = 0.0

	update_unit_commands(delta)

# --- MOVEMENT ---

func handle_movement(delta):
	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("left"): input_dir.x += 1
	if Input.is_action_pressed("right"): input_dir.x -= 1
	if not is_movement_locked:
		input_dir.z += 1

	var limit = GameConfig.HALF_WIDTH
	if (global_position.x >= limit and input_dir.x > 0) or (global_position.x <= -limit and input_dir.x < 0):
		input_dir.x = 0

	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		global_position += input_dir * movement_speed * delta
	global_position.x = clamp(global_position.x, -limit, limit)
# --- UNIT LOGIC ---

func register_unit(unit: Node3D):
	if unit is Unit and not units.has(unit):
		units.append(unit)
		unit.formation_offset = Vector3(
			randf_range(-formation_radius, formation_radius),
			0,
			randf_range(-formation_radius, formation_radius)
		)
		# SwarmRenderer draws all minions in a few MultiMesh draw calls; hide
		# the per-unit MeshInstance3D so we don't pay for both.
		if unit.model:
			unit.model.visible = false

func update_unit_commands(delta: float):
	# Single pass: formation target, movement lerp, look_at, targeting.
	# Damage is aggregated per-target across the swarm (one take_damage per
	# target per frame instead of one-per-projectile-per-unit) so unit count
	# can scale without exploding the projectile/damage call count.
	var boundary = GameConfig.HALF_WIDTH
	var attack_range_sq = attack_range * attack_range
	var dps_per_unit := damage_per_unit / unit_attack_cooldown if unit_attack_cooldown > 0.0 else damage_per_unit

	var damage_per_target: Dictionary = {}
	var shot_candidates: Array = []

	for unit in units:
		var desired_pos = global_position + unit.formation_offset

		# Wall "smear" effect
		if desired_pos.x > boundary:
			var excess = desired_pos.x - boundary
			desired_pos.x = boundary
			desired_pos.z += excess
		elif desired_pos.x < -boundary:
			var excess = desired_pos.x + boundary
			desired_pos.x = -boundary
			desired_pos.z -= excess

		# Movement lerp (was Unit._process)
		var unit_pos = unit.global_position
		unit.global_position = unit_pos.lerp(desired_pos, delta * unit.smoothing_speed)

		# Targeting (no per-unit shoot — see aggregate damage below)
		var target = get_closest_enemy(unit.global_position)
		if target:
			unit.assign_target(target)
			unit.look_at_target(target.global_position, delta)
			if unit.global_position.distance_squared_to(target.global_position) < attack_range_sq:
				damage_per_target[target] = damage_per_target.get(target, 0.0) + dps_per_unit
				shot_candidates.append(unit)
		else:
			unit.assign_target(null)
			var move_dir = desired_pos - unit_pos
			if move_dir.length_squared() > 0.01:
				unit.look_at_target(unit_pos + move_dir, delta)

	# Apply aggregated swarm DPS to each unique target (one call per target).
	for target in damage_per_target:
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(damage_per_target[target] * delta)

	# Visual: spawn a capped number of cosmetic projectiles so the swarm still
	# looks like it's shooting, independent of how many units are in range.
	var candidate_count := shot_candidates.size()
	if candidate_count > 0:
		var shot_count := mini(max_projectiles_per_frame, candidate_count)
		for i in range(shot_count):
			var unit: Unit = shot_candidates[randi() % candidate_count]
			unit.fire_cosmetic_projectile()

	if _swarm_renderer:
		_swarm_renderer.sync(units)

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
		GameConfig.Operation.LOG:
			# Safety: Can't log 0 or negative numbers, and base must be > 1
			if current_count > 0 and value > 1:
				# Change of Base Formula: log_b(x) = ln(x) / ln(b)
				target_count = log(current_count) / log(value)
			else:
				target_count = 1 # Fallback
		GameConfig.Operation.RANDOM:
			target_count = max(0,current_count + randi_range(-10, 50))
		GameConfig.Operation.SQRT:
			if current_count > 0:
				target_count = int(sqrt(current_count))
			else:
				target_count = 0

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
func take_damage(amount: int):
	# Safety check: Don't take damage if the game is already over
	if not is_game_active:
		return

	# Case 1: The Player has a swarm (Units act as Health/Armor)
	if units.size() > 0:
		# If the damage is greater than or equal to remaining units, 
		# the player loses everything and dies.
		if amount >= units.size():
			remove_units(units.size()) # Clear the array visually/logically
			updated_unit_count.emit(0)
			die()
		else:
			# The swarm absorbs the damage
			remove_units(amount)
			updated_unit_count.emit(units.size())
			
			# Optional: Add a "hit" effect here (e.g., screen shake or flash)
			
	# Case 2: The Player has no units left (Direct hit)
	else:
		die()
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
