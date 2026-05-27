class_name Gate extends Node3D

signal gate_triggered

@export var operation: GameConfig.Operation
@export var value: int

# Color Configuration
# Blue/Green for positive, Red for negative. Alpha (0.5) keeps it transparent.
@export var color_positive: Color = Color(0.2, 0.6, 1.0, 0.5)
@export var color_negative: Color = Color(1.0, 0.2, 0.2, 0.5)
@export var color_neutral: Color = Color(0.6, 0.6, 0.6, 0.5)

@onready var value_label = $Label3D
@onready var panel = $Panel

func setup(new_op: GameConfig.Operation, new_val: int):
	operation = new_op
	value = new_val
	
	if is_inside_tree():
		update_visuals()

func _ready():
	update_visuals()
	$Area3D.set_deferred("monitoring", true)

func update_visuals():
	# 1. UPDATE TEXT
	if not value_label: return
	
	value_label.text = ""
	var tint = color_negative
	var show_value = true

	match operation:
		GameConfig.Operation.ADD:
			value_label.text = "+"
			tint = color_positive
		GameConfig.Operation.SUBTRACT:
			value_label.text = "-"
			tint = color_negative
		GameConfig.Operation.MULTIPLY:
			value_label.text = "x"
			tint = color_positive
		GameConfig.Operation.DIVIDE:
			value_label.text = "÷"
			tint = color_negative
		GameConfig.Operation.LOG:
			value_label.text = "log"
			tint = color_negative
		GameConfig.Operation.RANDOM:
			value_label.text = "RANDOM"
			tint = color_neutral
			show_value = false
		GameConfig.Operation.SQRT:
			value_label.text = "SQRT"
			tint = color_negative
			show_value = false

	if show_value:
		value_label.text += str(value)

	# 2. UPDATE PANEL COLOR
	if panel:
		var mat = panel.get_surface_override_material(0)
		if mat:
			if not mat.resource_local_to_scene:
				mat = mat.duplicate()
				panel.set_surface_override_material(0, mat)
			mat.albedo_color = tint

func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("players"): # Ensure your Player area is in this group
		# We access the parent because the Area3D is usually a child of the Player node
		var player_node = area.get_parent()
		
		# Check if the parent script has the handle_operation method
		if player_node.has_method("handle_operation"):
			player_node.handle_operation(operation, value)
			
			# Disable the gate visually and logically
			$Area3D.set_deferred("monitoring", false)
			emit_signal("gate_triggered")
