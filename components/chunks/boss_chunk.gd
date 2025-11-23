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
