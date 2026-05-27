class_name EnemyManager extends Node

# One loop drives every EnemyUnit so we don't pay a per-enemy script callback
# plus a per-enemy get_nodes_in_group("units") walk every frame.

func _physics_process(delta: float) -> void:
	_update_enemies(delta)
	_update_bosses()

func _update_enemies(delta: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var player_units := get_tree().get_nodes_in_group("units")
	var pu_count := player_units.size()
	var pu_positions := PackedVector3Array()
	pu_positions.resize(pu_count)
	for i in range(pu_count):
		pu_positions[i] = (player_units[i] as Node3D).global_position

	for enemy in enemies:
		if not (enemy is EnemyUnit) or not is_instance_valid(enemy):
			continue
		var e: EnemyUnit = enemy
		var enemy_pos: Vector3 = e.global_position
		var chase_range_sq: float = e.chase_range * e.chase_range

		var closest: Node3D = null
		var closest_dist: float = chase_range_sq
		for i in range(pu_count):
			var dx: float = pu_positions[i].x - enemy_pos.x
			var dz: float = pu_positions[i].z - enemy_pos.z
			var dist: float = dx * dx + dz * dz
			if dist < closest_dist:
				closest_dist = dist
				closest = player_units[i]

		e.current_target = closest

		if not e.is_active:
			if closest != null:
				e.start_chasing()
			continue

		if closest == null:
			continue

		var target_pos: Vector3 = closest.global_position
		e.target_position = target_pos
		e.global_position = enemy_pos.lerp(target_pos, delta * e.smoothing_speed)

		if enemy_pos.distance_squared_to(target_pos) > 0.0001:
			e.look_at_target(target_pos, delta)

func _update_bosses() -> void:
	# Bosses ride along at the player's forward speed at a fixed Z offset.
	# No X/Y motion — no strafe.
	var bosses := get_tree().get_nodes_in_group("bosses")
	if bosses.is_empty():
		return

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var player_z := player.global_position.z

	for boss in bosses:
		if not is_instance_valid(boss):
			continue
		var b: Boss = boss
		var pos := b.global_position
		pos.z = player_z + b.follow_z_offset
		b.global_position = pos
