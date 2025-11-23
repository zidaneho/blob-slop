extends Node

# --- SIGNALS ---
# UI will listen to these to update the text labels
signal score_updated(new_score: int)
signal high_score_updated(new_high_score: int)
signal started_boss_fight
signal ended_boss_fight
signal boss_health_updated(current_hp: float, max_hp: float)
# --- CONFIGURATION ---
const SAVE_PATH = "user://blob_slop_save.data"

# --- STATE ---
var score: int = 0
var high_score: int = 0

func _ready():
	load_high_score()

# --- SCORE LOGIC ---

func add_score(amount: int):
	score += amount
	emit_signal("score_updated", score)
	
	# Check for new High Score immediately
	if score > high_score:
		high_score = score
		emit_signal("high_score_updated", high_score)
		save_high_score()

func reset_score():
	score = 0
	emit_signal("score_updated", score)

# --- SAVING & LOADING ---

func save_high_score():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# We store it as a dictionary for easy expansion later
		var data = {
			"high_score": high_score
		}
		file.store_string(JSON.stringify(data))
		file.close()

func load_high_score():
	if not FileAccess.file_exists(SAVE_PATH):
		return # No save file yet, keep default 0
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		
		if parse_result == OK:
			var data = json.get_data()
			# Safety check in case the file is corrupted or empty
			if data.has("high_score"):
				high_score = int(data["high_score"])
				emit_signal("high_score_updated", high_score)
		else:
			push_error("Failed to parse save file.")
