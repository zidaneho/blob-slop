extends Node3D

enum GameState {
	INACTIVE,
	ACTIVE,
	GAME_OVER
}

@onready var start_screen : Control = $Canvas/StartScreen
@onready var score_label : Label = $Canvas/ScoreContainer/HBoxContainer/ScoreLabel
@onready var game_over_screen = $Canvas/GameOverScreen
@onready var player_scene = preload("res://components/player/player.tscn")
@onready var unit_scene = preload("res://components/blobs/player_blob.tscn")
@onready var map_gen = $MapGen
@export var start_position : Vector3 = Vector3(0,1,1)



var game_state : GameState = GameState.INACTIVE
var is_game_active : bool = false
var player_instance : Node3D

func _ready() -> void:
	start_screen.visible = true
	score_label.visible = false
	game_over_screen.visible = false
	spawn_entities()

func _process(_delta: float) -> void:
	if game_state != GameState.ACTIVE:
		return
	map_gen.update_chunk(player_instance)
func start_game():
	if player_instance is Player:
		(player_instance as Player).start_running()
	
func game_over():
	game_state = GameState.GAME_OVER
	game_over_screen.visible = true

func _input(event: InputEvent) -> void:
	if game_state == GameState.INACTIVE and (event.is_action_pressed("left") or event.is_action_pressed("right")):
		game_state = GameState.ACTIVE
		start_screen.visible = false;
		score_label.visible = true;
		score_label.text = "Score: 0"
		start_game()
	elif game_state == GameState.GAME_OVER and (event.is_action_pressed("left") or event.is_action_pressed("right")):
		game_state = GameState.INACTIVE
		start_screen.visible = true
		game_over_screen.visible = false
		
func spawn_entities():
	# --- STEP A: SPAWN PLAYER ---
	player_instance = player_scene.instantiate()
	if player_instance != null:
		add_child(player_instance)
		player_instance.global_position = start_position
