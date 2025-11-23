class_name Gate extends Node3D

signal gate_triggered

@export var operation: GameConfig.Operation
@export var value: int

# Color Configuration
# Blue/Green for positive, Red for negative. Alpha (0.5) keeps it transparent.
@export var color_positive: Color = Color(0.2, 0.6, 1.0, 0.5) 
@export var color_negative: Color = Color(1.0, 0.2, 0.2, 0.5)

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
	var is_positive = false
	
	match operation:
		GameConfig.Operation.ADD:
			value_label.text += "+"
			is_positive = true
		GameConfig.Operation.SUBTRACT:
			value_label.text += "-"
			is_positive = false
		GameConfig.Operation.MULTIPLY:
			value_label.text += "x"
			is_positive = true
		GameConfig.Operation.DIVIDE:
			value_label.text += "÷"
			is_positive = false
		GameConfig.Operation.LOG:
			value_label.text = "log" # "log2" or "log10" handled below
			is_positive = false # Log drastically reduces count, so it's "bad/red"
		
	if operation == GameConfig.Operation.LOG:
		value_label.text += str(value)
	else:
		value_label.text += str(value)
	
	# 2. UPDATE PANEL COLOR
	if panel:
		# Get the material currently assigned to the panel
		var mat = panel.get_surface_override_material(0)
		
		if mat:
			# IMPORTANT: Duplicate the material so we don't change 
			# the color of every other gate in the game at the same time.
			if not mat.resource_local_to_scene:
				mat = mat.duplicate()
				panel.set_surface_override_material(0, mat)
			
			# Apply the tint
			if is_positive:
				mat.albedo_color = color_positive
			else:
				mat.albedo_color = color_negative

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
