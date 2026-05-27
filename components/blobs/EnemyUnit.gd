extends Unit
class_name EnemyUnit

# Driven by EnemyManager — no per-enemy _process callback.

var chase_range: float = 20.0
var current_target: Node3D = null
var target_position: Vector3 = Vector3.ZERO
var is_active: bool = false

func _ready():
	# Stay parented to the chunk so we ride it into the spawn area.
	set_as_top_level(false)
	add_to_group("enemies")
	smoothing_speed = 3.0

	var kill_area = $KillArea
	if kill_area:
		kill_area.area_entered.connect(_on_contact)
		kill_area.body_entered.connect(_on_contact)

func start_chasing():
	if is_active:
		return
	is_active = true
	# Detach so the chunk's transform stops dragging us around.
	set_as_top_level(true)

func _on_contact(other):
	if other.is_in_group("player_units") or other.get_parent().is_in_group("units"):
		var unit = other.get_parent()
		if unit.has_method("take_damage"):
			unit.take_damage(1)
		else:
			unit.queue_free()

func take_damage(_amount):
	die()

func die():
	GameManager.add_score(10)
	queue_free()
