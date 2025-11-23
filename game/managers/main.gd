extends Node3D

enum GameState {
	INACTIVE,
	ACTIVE,
	GAME_OVER
}

@onready var start_screen : Control = $Canvas/StartScreen
@onready var score_label : Label = $Canvas/ScoreContainer/HBoxContainer/ScoreLabel
@onready var stat_container = $Canvas/StatContainer
@onready var high_score_label : Label = $Canvas/ScoreContainer/HBoxContainer/HighScoreLabel
@onready var game_over_screen = $Canvas/GameOverScreen
@onready var player_scene = preload("res://components/player/player.tscn")
@onready var unit_scene = preload("res://components/blobs/player_blob.tscn")
@onready var map_gen = $MapGen
@onready var opening_music = $Canvas/StartScreen/OpeningMusic
@onready var spring_music = $SpringMusic
@onready var spring_music_boss = $SpringMusicBoss
@onready var game_over_music = $Canvas/GameOverScreen/GameOverMusic
@export var start_position : Vector3 = Vector3(0,1,1)


var game_state : GameState = GameState.INACTIVE
var is_game_active : bool = false
var player_instance : Node3D

func _ready() -> void:
	GameManager.reset_score()
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.high_score_updated.connect(_on_high_score_updated)
	GameManager.started_boss_fight.connect(_on_boss_started)
	GameManager.ended_boss_fight.connect(_on_boss_ended)
	start_screen.visible = true
	score_label.visible = false
	high_score_label.visible = false
	game_over_screen.visible = false
	stat_container.visible = false
	spawn_entities()
	opening_music.play()

func _process(_delta: float) -> void:
	if game_state != GameState.ACTIVE:
		return
	
	map_gen.update_chunk(player_instance)

func start_game():
	opening_music.stop()
	spring_music.play()
	if player_instance is Player:
		(player_instance as Player).start_running()
	
func game_over():
	spring_music.stop()
	spring_music_boss.stop()
	game_over_music.play()
	game_state = GameState.GAME_OVER
	game_over_screen.visible = true

func _input(event: InputEvent) -> void:
	if game_state == GameState.INACTIVE and (event.is_action_pressed("left") or event.is_action_pressed("right")):
		game_state = GameState.ACTIVE
		start_screen.visible = false
		high_score_label.visible = true
		score_label.visible = true
		score_label.text = "Score: 0"
		stat_container.visible = true
		stat_container.set_unit_count(0)
		start_game	()
	elif game_state == GameState.GAME_OVER and (event.is_action_pressed("left") or event.is_action_pressed("right")):
		game_state = GameState.INACTIVE
		start_screen.visible = true
		game_over_screen.visible = false
		get_tree().reload_current_scene()
		
func spawn_entities():
	# --- STEP A: SPAWN PLAYER --- 
	player_instance = player_scene.instantiate()
	player_instance.updated_unit_count.connect(_on_updated_unit_count)
	if player_instance != null:
		
		add_child(player_instance)
		$MapGen.player = player_instance
		player_instance.global_position = start_position
		player_instance.player_died.connect(_on_game_over)
func _on_score_updated(new_val):
	score_label.text = "Score: " + str(new_val)

func _on_high_score_updated(new_val):
	high_score_label.text = "High Score: " + str(new_val)
func _on_updated_unit_count(new_count : int):
	stat_container.set_unit_count(new_count)
func _on_game_over():
	game_over()
	
	# 1. Show Game Over UI (You need to create this in your scene)
	# $Canvas/GameOverScreen.visible = true
	
	# 2. Stop generating new chunks
	if has_node("MapGen"):
		$MapGen.set_process(false)
		
func _on_boss_started():
	spring_music.stop()
	spring_music_boss.play()
func _on_boss_ended():
	spring_music_boss.stop()
	spring_music.play()
