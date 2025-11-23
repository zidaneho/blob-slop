extends CharacterBody3D

# --- CONFIG ---
const SPEED = 20.0
const ROTATION_SPEED = 8.0 # How fast the missile turns towards the target

# --- STATE ---
var target: Node3D = null
var attack_damage: float = 5.0

# This function is called by Unit.gd upon spawn
func start_homing(target_node: Node3D, damage: float):
	target = target_node
	attack_damage = damage
	# Since Unit.gd already sets the transform to face the enemy, we can start moving immediately.

func _physics_process(delta):
	# Check if the target is valid before proceeding
	if not is_instance_valid(target):
		queue_free()
		return
		
	# 1. Calculate direction to target
	var target_position = target.global_position
	
	# 2. Smoothly rotate the projectile towards the target position
	var target_transform = global_transform.looking_at(target_position, Vector3.UP)
	global_transform = global_transform.interpolate_with(target_transform, delta * ROTATION_SPEED)
	
	# 3. Move the projectile forward
	# The projectile's forward is typically its -Z axis in Godot 3D
	velocity = -global_transform.basis.z * SPEED
	
	move_and_slide()
	
	# 4. Handle collision when it hits something
	for i in range(get_slide_collision_count()):
		var collision_info = get_slide_collision(i)
		handle_hit(collision_info.get_collider())
		return # Stop movement and free the projectile after a hit

# --- COLLISION HANDLER ---
func handle_hit(collider: Object):
	# Check if the thing we hit has the 'take_damage' method (like EnemyUnit.gd)
	if collider.has_method("take_damage"):
		collider.take_damage(attack_damage)
	# Check if we hit a child node of the target (e.g., a MeshInstance3D)
	elif collider is Node3D and collider.get_parent() == target:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)

	# The projectile is destroyed after impact
	queue_free()
