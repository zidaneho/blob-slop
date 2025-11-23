extends Area3D

@export var speed: float = 15.0
@export var damage: int = 3
@export var lifetime: float = 5.0

var direction: Vector3 = Vector3.FORWARD

func _ready():
	# Set up collision detection
	area_entered.connect(_on_hit)
	body_entered.connect(_on_hit)
	
	# Destroy self after a few seconds if we miss
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	# Move forward in the direction we were facing when spawned
	global_position += direction * speed * delta

func _on_hit(other):
	# Ignore the Boss itself and other enemies
	if other.is_in_group("enemies"):
		return
		
	# Check for Units or Player
	# Note: We check the parent because usually the Area3D is a child of the Unit
	var target = other
	
	if target.get_parent() != null and target.get_parent() is Player:
		target.get_parent().take_damage(damage)
		queue_free() # Destroy projectile on impact
	elif other is StaticBody3D: 
		queue_free() # Destroy on wall hit
