class_name Gate extends Node3D



@export var operation : GameConfig.Operation
@export var value : int








func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("players"):
		var player = area.get_parent() as Player
		if player != null:
			player.handle_operation(operation,value)
