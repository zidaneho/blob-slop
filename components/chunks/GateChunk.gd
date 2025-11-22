extends Chunk # Inherit from your base Chunk script

var is_gate_locked: bool = false # The Master Switch
func _ready() -> void:
	var gates = find_children("*", "Gate")
	for gate in gates:
		if not gate.is_connected("gate_triggered", _on_gate_triggered):
			gate.gate_triggered.connect(_on_gate_triggered)
		is_gate_locked = false

func can_trigger_gate() -> bool:
	# Gates call this BEFORE doing their math
	return not is_gate_locked

func _on_gate_triggered():
	# The moment ANY gate is hit, lock everything immediately
	is_gate_locked = true
	
	# Optional: Visually fade out the unpicked gates
	disable_all_gates()

func disable_all_gates():
	var gates = find_children("*", "Gate")
	for gate in gates:
		# Turn off collisions for everyone (Double safety)
		var area = gate.get_node_or_null("Area3D")
		if area:
			area.set_deferred("monitoring", false)
			
		# Optional: visual feedback that gates are closed
		# gate.visible = false
