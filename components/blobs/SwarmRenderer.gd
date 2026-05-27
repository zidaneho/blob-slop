class_name SwarmRenderer extends Node3D

# Renders the player's swarm via MultiMesh (one draw call per visual layer)
# instead of one MeshInstance3D per minion. Each unit is still its own Node3D
# (for formation/targeting logic) — only the visual side is consolidated.

const TEX_LAYERS: Array[Texture2D] = [
	preload("res://assets/blobs/Player_Blob-1.png"),
	preload("res://assets/blobs/Player_Blob-2.png"),
	preload("res://assets/blobs/Player_Blob-3.png"),
]
const QUAD_SIZE := Vector2(2, 2)
const VISUAL_Y_OFFSET := 0.98

var _multimeshes: Array[MultiMesh] = []

func _ready() -> void:
	# Sit at world origin so per-instance transforms are world-space.
	top_level = true
	global_transform = Transform3D.IDENTITY

	var quad := QuadMesh.new()
	quad.size = QUAD_SIZE

	for tex in TEX_LAYERS:
		var mat := StandardMaterial3D.new()
		# Alpha scissor (not alpha blend) so the swarm writes depth normally
		# and doesn't sort-flicker against the player's transparent billboards.
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.albedo_texture = tex
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = quad
		mm.instance_count = 0

		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		add_child(mmi)
		_multimeshes.append(mm)

func sync(units: Array) -> void:
	var count := units.size()
	for mm in _multimeshes:
		if mm.instance_count != count:
			mm.instance_count = count

	var offset := Vector3(0, VISUAL_Y_OFFSET, 0)
	for i in range(count):
		var unit: Node3D = units[i]
		if not is_instance_valid(unit):
			continue
		var t := Transform3D(unit.global_transform.basis, unit.global_position + offset)
		for mm in _multimeshes:
			mm.set_instance_transform(i, t)
