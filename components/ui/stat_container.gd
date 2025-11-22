extends MarginContainer

@onready var unit_label = $UnitLabel

func set_unit_count(count : int):
	unit_label.text = "Units: " + str(count)
