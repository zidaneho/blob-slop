extends Unit
class_name EnemyUnit

# Config
var chase_range: float = 20.0 # How close before they start chasing
var current_target: Node3D = null
var is_active: bool

func _ready():
	# 1. START ATTACHED
	# Do NOT detach yet. We ride the chunk to the correct spawn position.
	set_as_top_level(false) 
	
	# 2. Standard Setup
	add_to_group("enemies")
	smoothing_speed = 3.0 
	
	var kill_area = $KillArea
	if kill_area:
		kill_area.area_entered.connect(_on_contact)
		kill_area.body_entered.connect(_on_contact)

func _process(delta):
	# 1. SEARCH FOR TARGET
	if not is_active:
		current_target = get_closest_player_unit()
		if current_target:
			var dist = global_position.distance_squared_to(current_target.global_position)
			if dist < chase_range * chase_range:
				start_chasing()
	else:
		# Update target position constantly while chasing
		current_target = get_closest_player_unit()

	# 2. MOVEMENT LOGIC
	if is_active and current_target:
		target_position = current_target.global_position
		
		# --- MANUAL SLIDE MOVEMENT ---
		# We use lerp() to slide smoothly towards the target. 
		# We do NOT call super._process(delta)
		global_position = global_position.lerp(target_position, delta * smoothing_speed)
		
		# Optional: Rotate to face the player unit
		look_at_target(target_position, delta)
		
	else:
		# If not active, do nothing (it will stick to the chunk automatically)
		pass
func start_chasing():
	is_active = true
	# NOW we detach so we can move freely off the chunk
	set_as_top_level(true)
func get_closest_player_unit() -> Node3D:
	var units = get_tree().get_nodes_in_group("units") # Assuming player units are in this group
	if units.is_empty():
		return null
		
	var closest: Node3D = null
	var closest_dist = chase_range * chase_range # Squared for performance
	
	for unit in units:
		# Basic check: ensure it's a valid node
		if not is_instance_valid(unit): continue
		
		var dist = global_position.distance_squared_to(unit.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = unit
			
	return closest

func _on_contact(other):
	# Check if we hit a Player Unit area
	# Note: Adjust group name if your unit's Area3D uses a different group
	if other.is_in_group("player_units") or other.get_parent().is_in_group("units"):
		var unit = other.get_parent()
		if unit.has_method("die"):
			unit.die() # Kill the player unit
		else:
			unit.queue_free()
			
		# Optional: Slime dies on impact?
		# die()

func take_damage(amount):
	die()

func die():
	queue_free()
