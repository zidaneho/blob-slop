class_name Unit extends Node3D

# --- VISUAL SETTINGS ---
@export var smoothing_speed: float = 10.0

# --- ATTACK CONFIGURATION ---
@export var ATTACK_COOLDOWN: float = 0.25
const PROJECTILE_SCENE: PackedScene = preload("res://components/projectile/projectile.tscn")
@export var PROJECTILE_SPAWN_OFFSET: Vector3 = Vector3(0, 0.5, 0)

# --- STATE (Driven by Player loop) ---
var formation_offset: Vector3 = Vector3.ZERO
var target_enemy: Node3D = null
var can_shoot: bool = true
var attack_damage : float = 0

# --- COMPONENTS ---
@onready var model = $MeshInstance3D

func _ready():
	add_to_group("units")
	set_as_top_level(true)
	global_position = get_parent().global_position

func look_at_target(target_pos: Vector3, delta: float):
	var look_pos = Vector3(target_pos.x, global_position.y, target_pos.z)
	var current_transform = global_transform
	var target_transform = current_transform.looking_at(look_pos, Vector3.UP)
	global_transform = current_transform.interpolate_with(target_transform, delta * 10.0)

# --- COMMANDS (Called by Player) ---

func assign_target(enemy: Node3D):
	target_enemy = enemy

func trigger_attack():
	if not can_shoot: return
	if not is_instance_valid(target_enemy): return
	if not PROJECTILE_SCENE:
		push_error("Projectile Scene not set on Unit!")
		return

	var missile = PROJECTILE_SCENE.instantiate()
	print("spawned projectile")
	get_tree().root.add_child(missile)
	missile.global_transform = global_transform.translated(PROJECTILE_SPAWN_OFFSET)

	if missile.has_method("start_homing"):
		missile.start_homing(target_enemy, attack_damage)
	else:
		push_error("Projectile script is missing the 'start_homing' function! Projectile destroyed.")
		missile.queue_free()
		return

	_play_shoot_visuals()
	can_shoot = false
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	can_shoot = true

func fire_cosmetic_projectile() -> void:
	# Visual-only homing projectile. Damage is handled by the swarm-level DPS
	# tick in Player.update_unit_commands; this exists purely so the player
	# still sees bullets in the air.
	if not is_instance_valid(target_enemy): return
	if not PROJECTILE_SCENE: return

	var missile = PROJECTILE_SCENE.instantiate()
	get_tree().root.add_child(missile)
	missile.global_transform = global_transform.translated(PROJECTILE_SPAWN_OFFSET)
	if missile.has_method("start_homing"):
		missile.start_homing(target_enemy, 0.0)
	else:
		missile.queue_free()

func _play_shoot_visuals():
	var tween = create_tween()
	tween.tween_property(model, "scale", Vector3(1.2, 0.8, 1.2), 0.1)
	tween.tween_property(model, "scale", Vector3(1.0, 1.0, 1.0), 0.1)

func take_damage(_amount):
	die()

func die():
	queue_free()
