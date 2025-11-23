class_name BossChunk extends Chunk # Ensure this inherits from your base Chunk class

@onready var boss_unit = $BossUnit 
var player_ref: Player = null
signal level_complete

func _ready():
	# 1. Connect Trigger (Stops Player)
	$ArenaTrigger.area_entered.connect(_on_player_entered_arena)
	
	# 2. Connect Boss Death (Resumes Player)
	# We connect the signal from the boss node to our local function
	print(boss_unit)
	if boss_unit:
		boss_unit.died.connect(_on_boss_defeated)

func _on_player_entered_arena(body):
	# This part is already correct in your file
	print(body, body.get_parent() is Player)
	if body.get_parent() is Player:
		player_ref = body.get_parent()
		player_ref.is_movement_locked = true # STOP
		boss_unit.start_fight()

func _on_boss_defeated():
	# 3. Unlock Player
	if player_ref:
		player_ref.is_movement_locked = false # GO
	
	# Reward
	GameManager.add_score(1000)
	
	# Optional: Despawn the wall so player can physically walk past
	$ArenaTrigger.set_deferred("monitoring", false)
	emit_signal("level_complete")
func setup_boss_stats(difficulty_tier: int):
	# Wait for children to be ready if called immediately after instantiation
	if not boss_unit: 
		await ready
	
	if boss_unit:
		# Example Scaling:
		# HP: +50% per biome (100 -> 150 -> 200...)
		# DMG: +20% per biome (5 -> 6 -> 7...)
		
		var health_mult = 1.0 + (difficulty_tier * 0.5)
		var damage_mult = 1.0 + (difficulty_tier * 0.2)
		
		boss_unit.max_health = round(boss_unit.max_health * health_mult)
		boss_unit.current_health = boss_unit.max_health # IMPORTANT: Reset current HP
		boss_unit.boss_damage = boss_unit.boss_damage * damage_mult
		
		print("Boss Spawned! Tier: ", difficulty_tier, " | HP: ", boss_unit.max_health)
