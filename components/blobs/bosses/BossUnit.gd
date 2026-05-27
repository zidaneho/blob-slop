extends Unit
class_name Boss

signal died
@export var projectile_scene: PackedScene
@export var boss_damage = 5.0 # High damage for the boss
@export var attack_range = 25.0
@export var max_health = 100
@export var attack_cooldown = 0.5
var current_health = 100

# Driven by EnemyManager once the fight starts. Captured at start_fight() so the
# boss rides along at the player's forward speed without snapping.
var follow_z_offset: float = 0.0

func _ready():
	current_health = max_health
	# 1. STAY ATTACHED
	# We want the boss to ride the chunk to its spawn position.
	set_as_top_level(false)
	
	# 2. BE TARGETABLE
	# The player scans for the group "enemies", not "units".
	add_to_group("enemies")

func _process(_delta):
	# 1. TARGETING LOGIC
	if not is_instance_valid(target_enemy) or target_enemy.is_queued_for_deletion():
		target_enemy = find_priority_target()
	
	# 2. ATTACK LOGIC
	if is_instance_valid(target_enemy):
		# Optional: Rotate boss mesh to face target
		# look_at(target_enemy.global_position, Vector3.UP)
		
		var dist_sq = global_position.distance_squared_to(target_enemy.global_position)
		if dist_sq < attack_range * attack_range:
			trigger_attack()
func find_priority_target() -> Node3D:
	var all_units = get_tree().get_nodes_in_group("players")
	var minions = []
	var player_node = null
	
	# Filter units
	for unit in all_units:
		if unit is Player:
			player_node = unit
		else:
			minions.append(unit)
	
	# PRIORITY 1: Closest Minion
	if not minions.is_empty():
		return get_closest_node(minions)
		
	# PRIORITY 2: Player (Only if no minions left)
	return player_node
func get_closest_node(nodes: Array) -> Node3D:
	var closest = null
	var min_dist = INF
	
	for node in nodes:
		if not is_instance_valid(node): continue
		var dist = global_position.distance_squared_to(node.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = node
	return closest
func trigger_attack():
	# Respect Cooldown
	if not can_shoot: return
	if not projectile_scene: return
	
	# 1. Spawn Projectile
	var proj = projectile_scene.instantiate()
	get_tree().root.add_child(proj) # Add to world, not boss (so it flies free)
	
	# 2. Position & Aim
	proj.global_position = global_position + Vector3(0, 1, 0) # Spawn slightly above ground
	proj.damage = boss_damage
	
	# Calculate direction
	var dir = (target_enemy.global_position - proj.global_position).normalized()
	proj.direction = dir
	
	# Rotate projectile visually to face target
	proj.look_at(target_enemy.global_position)
	
	# 3. Reset Cooldown
	can_shoot = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_shoot = true
func start_fight():
	# Play roar animation, show UI
	print("starting fight")
	GameManager.started_boss_fight.emit()
	GameManager.boss_health_updated.emit(current_health, max_health)

	# Detach from the chunk so we survive chunk recycling. Reparent to root and
	# preserve the world position to avoid the transform snap that comes from
	# flipping top_level while still under a non-root parent.
	var tree := get_tree()
	var root := tree.root
	var player := tree.get_first_node_in_group("player") as Node3D
	var world_pos := global_position
	var old_parent := get_parent()
	if old_parent != null and old_parent != root:
		# Defer the reparent so we don't try to mutate the scene tree mid-signal
		# (entered_arena fires from physics). reparent() also keeps global xform.
		reparent(root)
	set_as_top_level(true)
	global_position = world_pos

	if player:
		follow_z_offset = global_position.z - player.global_position.z
	add_to_group("bosses")

func take_damage(amount):
	current_health -= amount
	GameManager.boss_health_updated.emit(current_health, max_health)
	if current_health <= 0:
		die()

func die():
	died.emit()
	GameManager.ended_boss_fight.emit()
	queue_free()
