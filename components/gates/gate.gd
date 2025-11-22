class_name Gate extends Node3D
signal gate_triggered
@export var operation: GameConfig.Operation
@export var value: int

@onready var value_label = $Label3D

func setup(new_op: GameConfig.Operation, new_val: int):
	operation = new_op
	value = new_val
	
	# Only try to update text if the node is already active in the scene
	if is_inside_tree():
		update_label()

func _ready():
	# When the node finally enters the scene, update the label
	# This catches the data set by setup() before add_child() was called
	update_label()
	$Area3D.set_deferred("monitoring", true)

func update_label():
	# Safety check
	if not value_label:
		return
		
	value_label.text = ""
	
	if operation == GameConfig.Operation.ADD:
		value_label.text += "+"
	elif operation == GameConfig.Operation.SUBTRACT:
		value_label.text += "-"
	elif operation == GameConfig.Operation.MULTIPLY:
		value_label.text += "x"
	elif operation == GameConfig.Operation.DIVIDE:
		value_label.text += "÷"
		
	value_label.text += str(value)

func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("players"):
		var player = area.get_parent() as Player
		if player != null:
			player.handle_operation(operation, value)
			# Disable the gate so it doesn't trigger twice
			$Area3D.set_deferred("monitoring", false)
			emit_signal("gate_triggered")
