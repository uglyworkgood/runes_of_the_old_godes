# res://scripts/gameplay/Entity3D.gd
extends Node3D
class_name Entity3D

@export var entity_id: StringName
@export var team: int = 0

@export var max_hp: int = 10
@export var hp: int = 10

@export var move_points_per_turn: int = 5
@export var move_points: int = 5

# Optional cosmetics for the billboard
@export var portrait_tex: Texture2D
@export var status_effects: Array = []   # e.g., ["poison", "stun"]

var tile: Vector2i
var billboard: UnitBillboard

func set_tile(t: Vector2i, grid: Node) -> void:
	tile = t
	global_position = grid.tile_to_world(t)

func _ready() -> void:
	# --- simple pawn mesh so it's visible on the board ---
	var m := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.2
	m.mesh = cap

	var color := Color(0.3, 0.8, 1.0) if team == 0 else Color(1.0, 0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	add_child(m)

	# --- billboard UI (portrait + HP bar + status chips) ---
	billboard = UnitBillboard.new()
	add_child(billboard)

	billboard.set_max_hp(max_hp)
	billboard.set_hp(hp)

	if portrait_tex:
		billboard.set_portrait(portrait_tex)

	if not status_effects.is_empty():
		billboard.set_status_effects(status_effects)

func move_along(path: Array, grid: Node, seconds_per_tile: float = 0.12) -> void:
	if path.size() <= 1:
		return
	# assume path[0] is current tile; start at 1
	for i in range(1, path.size()):
		var t: Vector2i = path[i]
		var to: Vector3 = grid.tile_to_world(t)
		var tw: Tween = create_tween()
		tw.tween_property(self, "global_position", to, seconds_per_tile)\
		  .set_trans(Tween.TRANS_SINE)\
		  .set_ease(Tween.EASE_IN_OUT)
		await tw.finished
		tile = t

# ---------- convenience hooks for gameplay ----------

func apply_damage(amount: int) -> void:
	hp = clampi(hp - amount, 0, max_hp)
	if billboard:
		billboard.set_hp(hp)

func heal(amount: int) -> void:
	hp = clampi(hp + amount, 0, max_hp)
	if billboard:
		billboard.set_hp(hp)

func set_statuses(effects: Array) -> void:
	status_effects = effects.duplicate()
	if billboard:
		billboard.set_status_effects(status_effects)

func set_portrait(tex: Texture2D) -> void:
	portrait_tex = tex
	if billboard and tex:
		billboard.set_portrait(tex)

func set_max_hp_and_sync(v: int) -> void:
	max_hp = max(1, v)
	hp = min(hp, max_hp)
	if billboard:
		billboard.set_max_hp(max_hp)
		billboard.set_hp(hp)
