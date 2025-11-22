class_name BossChunk extends Chunk

@onready var boss_unit = $BossUnit # Assign your boss node here
var player_ref: Player = null

func _ready():
	# Connect the trigger
	$ArenaTrigger.body_entered.connect(_on_player_entered_arena)
	
	# Connect the Boss Death signal (assuming your Boss emits "died")
	# boss_unit.died.connect(_on_boss_defeated)

func configure(biome: BiomeData):
	# Call the normal chunk configuration to set ground/walls
	# You can create a specific "Arena" look here if you want
	super.configure(biome) 

func _on_player_entered_arena(body):
	if body is Player:
		player_ref = body
		player_ref.is_movement_locked = true
		# Start Boss Logic (Animation, Health Bar, etc.)
		boss_unit.start_fight()

func _on_boss_defeated():
	# Unlock player so they run to the next chunk
	if player_ref:
		player_ref.is_movement_locked = false
	
	# Optional: Reward the player
	GameManager.add_score(1000)
