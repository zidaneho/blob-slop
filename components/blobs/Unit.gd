class_name Unit extends Node3D

# --- VISUAL SETTINGS ---
@export var smoothing_speed: float = 10.0

# --- ATTACK CONFIGURATION ---
@export var ATTACK_COOLDOWN: float = 0.25
const PROJECTILE_SCENE: PackedScene = preload("res://components/projectile/projectile.tscn")
@export var PROJECTILE_SPAWN_OFFSET: Vector3 = Vector3(0, 0.5, 0)

# --- STATE (Managed by Player) ---
var target_position: Vector3 = Vector3.ZERO
var target_enemy: Node3D = null
var can_shoot: bool = true
var attack_damage : float = 0

# --- COMPONENTS ---
@onready var model = $MeshInstance3D 
# @onready var gun_tip = $GunTip # Optional: spawn point for bullets

func _ready():
	add_to_group("units")
	# Detach from parent visually to allow smooth movement in world space
	set_as_top_level(true)
	# Start at the player's position to avoid "flying in" from (0,0,0)
	global_position = get_parent().global_position

func _process(delta):
	# 1. MOVEMENT (Visual Interpolation)
	global_position = global_position.lerp(target_position, delta * smoothing_speed)
	
	# 2. ROTATION
	if is_instance_valid(target_enemy):
		look_at_target(target_enemy.global_position, delta)
	else:
		var move_dir = target_position - global_position
		if move_dir.length() > 0.1:
			look_at_target(global_position + move_dir, delta)

func look_at_target(target_pos: Vector3, delta: float):
	# Smooth look_at to prevent jitter
	var look_pos = Vector3(target_pos.x, global_position.y, target_pos.z)
	var current_transform = global_transform
	var target_transform = current_transform.looking_at(look_pos, Vector3.UP)
	global_transform = current_transform.interpolate_with(target_transform, delta * 10.0)

# --- COMMANDS (Called by Player) ---

func set_formation_target(pos: Vector3):
	target_position = pos

func assign_target(enemy: Node3D):
	target_enemy = enemy

func trigger_attack():
	if not can_shoot: return
	if not is_instance_valid(target_enemy): return
	if not PROJECTILE_SCENE: # Check if the scene is set
		push_error("Projectile Scene not set on Unit!")
		return
	
	# 1. Spawn the projectile (replaces the direct damage call)
	var missile = PROJECTILE_SCENE.instantiate()
	get_tree().root.add_child(missile)
	
	# 2. Set spawn position and orientation
	# Spawns the missile at the unit's position + offset
	missile.global_transform = global_transform.translated(PROJECTILE_SPAWN_OFFSET)
	
	# 3. CRITICAL: Initialize the projectile
	if missile.has_method("start_homing"):
		# Pass the target node and the damage value
		missile.start_homing(target_enemy, attack_damage)
	else:
		push_error("Projectile script is missing the 'start_homing' function! Projectile destroyed.")
		missile.queue_free()
		return
		
	# 4. Visuals and Cooldown
	_play_shoot_visuals()
	can_shoot = false
	# Use the exported attack_cooldown
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout 
	can_shoot = true

func _play_shoot_visuals():
	# Example: Simple "Squash" animation to show firing
	var tween = create_tween()
	tween.tween_property(model, "scale", Vector3(1.2, 0.8, 1.2), 0.1)
	tween.tween_property(model, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
	pass
	
func take_damage(amount):
	# If you had health, you'd apply damage here.
	# For now, we assume this function will be called by another script.
	die()

func die():
	# Implement any death visuals/sounds here before removal
	queue_free()
