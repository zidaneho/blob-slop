extends CharacterBody3D

# --- CONFIG ---
const SPEED = 20.0
const ROTATION_SPEED = 8.0 # How fast the missile turns towards the target
const MAX_LIFETIME = 1.5 # Safety net so untargeted projectiles don't fly forever
const SNAP_DISTANCE_SQ = 0.25 # Despawn once we're effectively at the target

# --- STATE ---
var target: Node3D = null
var attack_damage: float = 5.0
var _lifetime: float = 0.0
var _last_target_pos: Vector3 = Vector3.ZERO
var _has_target_pos: bool = false

# This function is called by Unit.gd upon spawn
func start_homing(target_node: Node3D, damage: float):
	target = target_node
	attack_damage = damage
	if is_instance_valid(target):
		_last_target_pos = target.global_position
		_has_target_pos = true

func _physics_process(delta):
	_lifetime += delta
	if _lifetime > MAX_LIFETIME:
		queue_free()
		return

	# Refresh the snapshot while the target is alive; once it dies we keep
	# flying toward where it was so cosmetic projectiles still look like they
	# converge on the kill instead of evaporating mid-air.
	if is_instance_valid(target):
		_last_target_pos = target.global_position
		_has_target_pos = true

	if _has_target_pos:
		if global_position.distance_squared_to(_last_target_pos) < SNAP_DISTANCE_SQ:
			queue_free()
			return
		var target_transform = global_transform.looking_at(_last_target_pos, Vector3.UP)
		global_transform = global_transform.interpolate_with(target_transform, delta * ROTATION_SPEED)

	velocity = -global_transform.basis.z * SPEED
	move_and_slide()

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
