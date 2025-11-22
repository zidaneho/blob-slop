extends Unit
class_name Boss

signal died

@export var max_health = 100
var current_health = 100

func start_fight():
	# Play roar animation, show UI
	pass

func take_damage(amount):
	current_health -= amount
	if current_health <= 0:
		die()

func die():
	died.emit()
	queue_free()
