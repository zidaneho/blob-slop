extends Resource
class_name BiomeData

# --- GROUND & OBJECTS (From previous steps) ---
@export_group("Ground & Objects")
@export var ground_material: StandardMaterial3D
@export var grass_mesh : Mesh
@export var grass_material : ShaderMaterial
@export var rock_mesh : Mesh
@export var decor_meshes : Array[Mesh]
# You could also add: var grass_mesh, var rock_mesh, etc.

# --- SKY & ATMOSPHERE (Required for Method A) ---
@export_group("Sky & Atmosphere")
@export var sky_texture: Texture2D # The Panorama HDR image

@export_subgroup("Fog Settings")
@export var fog_color: Color = Color.GRAY
@export_range(0.0, 1.0) var fog_density: float = 0.01 
# ^ Note: 0.01 is usually "clear", 0.05 is "misty", 0.1 is "thick"

@export_subgroup("Lighting Adjustment")
@export var ambient_light_color: Color = Color.WHITE
@export_range(0.0, 16.0) var ambient_light_energy: float = 1.0
# ^ Useful if your Snow sky is much brighter than your Night sky
