# res://scripts/grid/Grid3D.gd
extends Node3D
class_name Grid3D

@export var width: int = 20
@export var height: int = 15
@export var tile_size: float = 1.0
@export var generate_on_ready: bool = true
@export var show_checker: bool = true

# --- members (accessible to all methods) ---
var _mmi: MultiMeshInstance3D
var _reach_mmi: MultiMeshInstance3D
var _path_mmi: MultiMeshInstance3D
var _rot_flat := Basis(Vector3.RIGHT, -PI / 2.0)  # rotate -90° around X
var _area_mmi: MultiMeshInstance3D

# Optional terrain blocking
var blocked := {}  # Dictionary<Vector2i, bool>

func _ready() -> void:
	if generate_on_ready:
		_build_grid()

func _build_grid() -> void:
	# Clear old children
	for c in get_children():
		c.queue_free()

	# Base grid
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = width * height

	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = mm
	add_child(_mmi)

	var i := 0
	for y in range(height):
		for x in range(width):
			var xf := Transform3D()
			xf.basis = _rot_flat.scaled(Vector3(tile_size, tile_size, 1.0))
			xf.origin = Vector3(x * tile_size, 0.0, y * tile_size)
			mm.set_instance_transform(i, xf)

			if show_checker:
				var is_dark := ((x + y) % 2) == 1
				var c := Color(0.14, 0.14, 0.14, 1.0) if is_dark else Color(0.18, 0.18, 0.18, 1.0)
				mm.set_instance_color(i, c)
			i += 1

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.16, 0.16, 0.16, 1)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mmi.material_override = mat

	# --- overlays: reachable + path ---
	_reach_mmi = MultiMeshInstance3D.new()
	_reach_mmi.multimesh = _make_overlay_multimesh()
	_reach_mmi.material_override = _make_overlay_material(Color(0.7, 0.7, 0.7, 0.35))
	add_child(_reach_mmi)

	_path_mmi = MultiMeshInstance3D.new()
	_path_mmi.multimesh = _make_overlay_multimesh()
	_path_mmi.material_override = _make_overlay_material(Color(0.15, 0.9, 0.3, 0.55))
	add_child(_path_mmi)
	
	_area_mmi = MultiMeshInstance3D.new()
	_area_mmi.multimesh = _make_overlay_multimesh()
	_area_mmi.material_override = _make_overlay_material(Color(1.0, 0.5, 0.2, 0.45)) # orange
	add_child(_area_mmi)

# --- helpers the gameplay code uses ---

func _make_overlay_multimesh() -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = 0
	return mm

func _make_overlay_material(base: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = base
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func tile_to_world(t: Vector2i) -> Vector3:
	return Vector3(t.x * tile_size, 0.0, t.y * tile_size)

func world_to_tile(p: Vector3) -> Vector2i:
	var tx := int(round(p.x / tile_size))
	var ty := int(round(p.z / tile_size))
	return Vector2i(tx, ty)

func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.x < width and t.y >= 0 and t.y < height

func is_blocked(t: Vector2i) -> bool:
	return blocked.get(t, false)

# --- overlay API ---

# Show a set/array of tiles as semi-transparent overlays (reachable)
func show_reachable(tiles: Array) -> void:
	_set_tiles_on_mmi(_reach_mmi, tiles, 0.02, 0.92, Color(0.7, 0.7, 0.7, 0.35))

# Show the A* path as colored strips; last tile highlighted
func show_path(path: Array) -> void:
	_set_tiles_on_mmi(_path_mmi, path, 0.03, 0.72, Color(0.15, 0.9, 0.3, 0.55), Color(0.25, 1.0, 0.45, 0.75))

func show_area(tiles: Array, color: Color = Color(1.0, 0.5, 0.2, 0.45)) -> void:
	_set_tiles_on_mmi(_area_mmi, tiles, 0.035, 0.82, color)

func clear_area() -> void:
	if _area_mmi and _area_mmi.multimesh:
		_area_mmi.multimesh.instance_count = 0

func clear_reachable() -> void:
	if _reach_mmi and _reach_mmi.multimesh:
		_reach_mmi.multimesh.instance_count = 0

func clear_path() -> void:
	if _path_mmi and _path_mmi.multimesh:
		_path_mmi.multimesh.instance_count = 0

# Internal: place quads on tiles, slightly raised/inset; base color + optional last color
func _set_tiles_on_mmi(mmi: MultiMeshInstance3D, tiles: Array, y_offset: float, inset_scale: float, base_color: Color, last_color: Color = Color(0,0,0,0)) -> void:
	if mmi == null or mmi.multimesh == null:
		return
	var mm := mmi.multimesh
	mm.instance_count = tiles.size()

	for i in range(tiles.size()):
		var t: Vector2i = tiles[i]
		var xf := Transform3D()
		xf.basis = _rot_flat.scaled(Vector3(tile_size * inset_scale, tile_size * inset_scale, 1.0))
		xf.origin = Vector3(t.x * tile_size, y_offset, t.y * tile_size)
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, base_color)

	# highlight last tile if provided (non-zero alpha)
	if tiles.size() > 0 and last_color.a > 0.0:
		mm.set_instance_color(tiles.size() - 1, last_color)
