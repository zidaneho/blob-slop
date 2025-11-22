class_name Unit extends Node3D

# --- VISUAL SETTINGS ---
@export var smoothing_speed: float = 10.0
@export var attack_cooldown: float = 0.5

# --- STATE (Managed by Player) ---
var target_position: Vector3 = Vector3.ZERO
var target_enemy: Node3D = null
var can_shoot: bool = true

# --- COMPONENTS ---
@onready var model = $MeshInstance3D # Assuming you have a mesh child
# @onready var gun_tip = $GunTip # Optional: spawn point for bullets

func _ready():
	# Detach from parent visually to allow smooth movement in world space
	set_as_top_level(true)
	# Start at the player's position to avoid "flying in" from (0,0,0)
	global_position = get_parent().global_position

func _process(delta):
	# 1. MOVEMENT (Visual Interpolation)
	# The unit blindly slides towards where the Player tells it to be.
	# This is much cheaper than pathfinding or rigid body physics for every unit.
	global_position = global_position.lerp(target_position, delta * smoothing_speed)
	
	# 2. ROTATION
	# Look at the enemy if we have one, otherwise look forward
	if is_instance_valid(target_enemy):
		look_at_target(target_enemy.global_position, delta)
	else:
		# Optional: Look in movement direction
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
	
	# VISUAL ONLY: Play animation, squash/stretch, or spawn particle
	_play_shoot_visuals()
	
	# Reset Cooldown
	can_shoot = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_shoot = true

func _play_shoot_visuals():
	# Example: Simple "Squash" animation to show firing
	var tween = create_tween()
	tween.tween_property(model, "scale", Vector3(1.2, 0.8, 1.2), 0.1)
	tween.tween_property(model, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
	
	# TODO: Spawn projectile scene here if needed
	# var bullet = bullet_scene.instantiate()
	# get_tree().root.add_child(bullet)
	# bullet.global_position = global_position
	pass
