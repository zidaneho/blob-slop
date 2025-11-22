extends Node3D



@onready var camera : Camera3D = $Camera3D
@onready var start_screen : Control = $Canvas/StartScreen
@onready var score_label : Label = $Canvas/ScoreContainer/Label

@export var camera_speed : float = 5

var is_game_active : bool = false

func _ready() -> void:
	score_label.visible = false

func _process(delta: float) -> void:
	if not is_game_active:
		return
	camera.position.z += camera_speed * delta

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left") or event.is_action_pressed("right"):
		is_game_active = true
		start_screen.visible = false;
		score_label.visible = true;
		score_label.text = "Score: 0"
		
