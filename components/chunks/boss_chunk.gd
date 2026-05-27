class_name BossChunk extends Chunk # Ensure this inherits from your base Chunk class

# Boss difficulty scales as base * growth^tier. Growth values are small so the
# curve only really separates from linear after a handful of tiers.
const HEALTH_BASE: float = 250.0
const HEALTH_GROWTH: float = 1.2
const DAMAGE_BASE: float = 1.0
const DAMAGE_GROWTH: float = 1.5

@onready var boss_spawn_point = $BossSpawnPoint
@export var boss_scene : PackedScene
var boss_instance : Boss
var difficulty_tier: int = 0
signal level_complete

func _ready():
	$ArenaTrigger.area_entered.connect(_on_player_entered_arena)
	_spawn_boss()

func configure_boss_scene(scene : PackedScene, tier : int):
	# Called by ProceduralMapGenerator before this chunk enters the tree, so we
	# can't touch @onready vars yet. Stash params; _ready does the spawn.
	boss_scene = scene
	difficulty_tier = tier

func _spawn_boss():
	if not boss_scene:
		push_error("BossChunk: boss_scene not configured")
		return
	boss_instance = boss_scene.instantiate() as Boss
	boss_instance.max_health = HEALTH_BASE * pow(HEALTH_GROWTH, difficulty_tier)
	boss_instance.current_health = boss_instance.max_health
	boss_instance.boss_damage = DAMAGE_BASE * pow(DAMAGE_GROWTH, difficulty_tier)
	boss_instance.died.connect(_on_boss_defeated)
	# Parent under the spawn point so the boss rides the chunk into position.
	# start_fight() detaches it to root once the fight begins.
	boss_spawn_point.add_child(boss_instance)

func _on_player_entered_arena(body):
	if body.get_parent() is Player:
		if boss_instance:
			boss_instance.start_fight()
		else:
			push_error("Boss instance not configured yet!")

func _on_boss_defeated():
	GameManager.add_score(1000)
	# Despawn the wall so the player can physically walk past.
	$ArenaTrigger.set_deferred("monitoring", false)
	emit_signal("level_complete")
