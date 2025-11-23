extends Node

# --- MAP DIMENSIONS ---
# How wide is the playable road? (e.g. Width 10 = -5 to +5)
const ROAD_WIDTH: float = 15 
const HALF_WIDTH: float = ROAD_WIDTH / 2.0

# How long is one chunk?
const CHUNK_LENGTH: float = 15 # Updated to your new short length

# --- GAMEPLAY ---
const SWARM_SPREAD: float = 3.0 # How far units spread out

enum Operation {
	ADD,
	MULTIPLY,
	SUBTRACT,
	DIVIDE,
	LOG,
}
