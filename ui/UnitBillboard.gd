# res://scripts/gameplay/UnitBillboard.gd
extends Node3D
class_name UnitBillboard

@export var portrait: Texture2D
@export var portrait_size: Vector2 = Vector2(0.8, 0.8)      # world meters (w,h)
@export var portrait_offset_y: float = 1.25

@export var bar_size: Vector2 = Vector2(1.1, 0.12)          # world meters (w,h)
@export var bar_offset_y: float = 1.55

@export var status_offset_y: float = 1.75
@export var status_size: Vector2 = Vector2(0.22, 0.22)
@export var status_spacing: float = 0.05

var _portrait_mesh: MeshInstance3D
var _hp_bg: MeshInstance3D
var _hp_fill: MeshInstance3D
var _status_root: Node3D
var _max_hp: int = 10
var _cur_hp: int = 10

func _ready() -> void:
	_make_portrait()
	_make_hp_bar()
	_make_status_root()

# ---------- public API ----------

func set_max_hp(v: int) -> void:
	_max_hp = max(1, v)
	_update_hp_visual()

func set_hp(v: int) -> void:
	_cur_hp = clampi(v, 0, _max_hp)
	_update_hp_visual()

func set_portrait(tex: Texture2D) -> void:
	portrait = tex
	if _portrait_mesh:
		var mat := _portrait_mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			mat.albedo_texture = portrait

func set_status_effects(effects: Array) -> void:
	if not is_instance_valid(_status_root):
		return
	for c in _status_root.get_children():
		c.queue_free()

	var max_shown: int = min(6, effects.size())
	if max_shown <= 0:
		return

	var total_w := max_shown * status_size.x + (max_shown - 1) * status_spacing
	var start_x := -total_w * 0.5 + status_size.x * 0.5

	for i in range(max_shown):
		var name := str(effects[i])
		var col := _status_color_for(name)
		_status_root.add_child(_make_chip(col, Vector3(start_x + i * (status_size.x + status_spacing), status_offset_y, 0.0)))

# ---------- internals ----------

func _make_portrait() -> void:
	_portrait_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = portrait_size
	_portrait_mesh.mesh = quad

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = portrait
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Optional: avoid casting shadows from UI bits
	mat.disable_receive_shadows = true

	_portrait_mesh.material_override = mat
	add_child(_portrait_mesh)
	_portrait_mesh.position = Vector3(0, portrait_offset_y, 0)

func _make_hp_bar() -> void:
	_hp_bg = MeshInstance3D.new()
	_hp_fill = MeshInstance3D.new()

	var bg := QuadMesh.new();   bg.size = bar_size
	var fill := QuadMesh.new(); fill.size = bar_size

	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0,0,0,0.65)
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bg_mat.disable_receive_shadows = true

	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.2, 0.9, 0.2, 0.95)
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_mat.disable_receive_shadows = true

	_hp_bg.mesh = bg
	_hp_bg.material_override = bg_mat
	_hp_fill.mesh = fill
	_hp_fill.material_override = fill_mat

	add_child(_hp_bg)
	add_child(_hp_fill)

	_hp_bg.position = Vector3(0, bar_offset_y, 0)
	_hp_fill.position = Vector3(0, bar_offset_y, 0)

	_update_hp_visual()

func _make_status_root() -> void:
	_status_root = Node3D.new()
	add_child(_status_root)

func _update_hp_visual() -> void:
	if _max_hp <= 0:
		return
	var pct := float(_cur_hp) / float(_max_hp)

	# green -> red ramp (red at 0%, green at 100%)
	var col := Color(1,0.15,0.15).lerp(Color(0.15,1,0.15), pct)
	var mat := _hp_fill.get_active_material(0)
	if mat is StandardMaterial3D:
		mat.albedo_color = col

	# scale X from the left edge
	var full_w := bar_size.x
	var scaled_w: int = max(0.0001, full_w * pct)
	var left_anchor := -full_w * 0.5
	var cx := left_anchor + scaled_w * 0.5

	_hp_fill.scale = Vector3(pct, 1, 1)
	_hp_fill.position.x = cx
	_hp_bg.position.x = 0

func _make_chip(color: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = status_size
	m.mesh = quad

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true

	m.material_override = mat
	m.position = pos
	return m

func _status_color_for(name: String) -> Color:
	match name.to_lower():
		"poison": return Color(0.4, 1.0, 0.4, 0.95)
		"burn":   return Color(1.0, 0.4, 0.2, 0.95)
		"freeze": return Color(0.4, 0.8, 1.0, 0.95)
		"stun":   return Color(1.0, 1.0, 0.4, 0.95)
		_:        return Color(0.8, 0.8, 0.8, 0.95)
