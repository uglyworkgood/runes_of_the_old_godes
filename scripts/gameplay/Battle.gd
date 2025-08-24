extends Node
class_name Battle
const PF := preload("res://scripts/grid/Pathfinder3D.gd")

# --- tuning ---
const MELEE_RANGE := 1
const MELEE_DAMAGE := 3

const FIREBALL_RANGE := 5     # max tiles from caster to target (Manhattan)
const FIREBALL_RADIUS := 1    # radius around target (Manhattan)
const FIREBALL_DAMAGE := 4

@onready var board: Node3D = get_parent().get_node("Board")
@onready var grid: Node = board  # Grid3D API (tile_to_world, world_to_tile, in_bounds)
var Net: Node

var entities: Dictionary = {}            # id -> Entity3D
var turn_order: Array[StringName] = []
var active_index: int = 0

var hover_marker: MeshInstance3D

# input mode: "move" or "cast_fb"
var _mode: StringName = "move"

func _ready() -> void:
	# Resolve Networking autoload
	if has_node("/root/Networking"):
		Net = get_node("/root/Networking")
	elif has_node("/root/Network"):
		Net = get_node("/root/Network")
	else:
		push_error("Battle.gd: Networking autoload not found")
		return

	# Listen to all messages from the adapter facade
	Net.state_received.connect(_on_net_message)

	_spawn_demo_party()
	_make_hover_marker()
	_refresh_reachable()
	_broadcast_state()  # announce first active to everyone

func _spawn_demo_party() -> void:
	var e1 := Entity3D.new()
	e1.entity_id = "hero_1"
	e1.team = 0
	add_child(e1)
	entities[e1.entity_id] = e1
	e1.set_tile(Vector2i(2, 2), grid)

	var e2 := Entity3D.new()
	e2.entity_id = "enemy_1"
	e2.team = 1
	add_child(e2)
	entities[e2.entity_id] = e2
	e2.set_tile(Vector2i(8, 6), grid)

	turn_order = [e1.entity_id, e2.entity_id]
	active_index = 0

func _make_hover_marker() -> void:
	hover_marker = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.0)
	hover_marker.mesh = qm

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hover_marker.material_override = mat

	add_child(hover_marker)
	hover_marker.visible = false

func _physics_process(_dt: float) -> void:
	_update_hover()

func _update_hover() -> void:
	var t: Vector2i = _mouse_tile()
	if t == null:
		hover_marker.visible = false
		grid.clear_path()
		if grid.has_method("clear_area"):
			grid.clear_area()
		return

	hover_marker.visible = true
	hover_marker.global_position = grid.tile_to_world(t)
	hover_marker.rotation_degrees = Vector3(-90, 0, 0)
	hover_marker.scale = Vector3(grid.tile_size, grid.tile_size, 1)

	if turn_order.is_empty():
		grid.clear_path()
		if grid.has_method("clear_area"):
			grid.clear_area()
		return

	var active_id := turn_order[active_index]
	var pawn: Entity3D = entities[active_id]

	# Mode-specific previews
	if _mode == "move":
		if grid.has_method("clear_area"):
			grid.clear_area()
		var path := Pathfinder3D.a_star(pawn.tile, t, _make_blocker(active_id))
		if path.size() > 1:
			var budget: int = max(0, pawn.move_points)
			if path.size() - 1 > budget:
				path = path.slice(0, budget + 1)
			grid.show_path(path)
		else:
			grid.clear_path()
	elif _mode == "cast_fb":
		grid.clear_path()
		if grid.has_method("show_area"):
			var tiles := _tiles_in_radius(t, FIREBALL_RADIUS)
			grid.show_area(tiles)

# ----------------- Input -----------------

func _unhandled_input(event: InputEvent) -> void:
	# Toggle fireball mode with F
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			_mode = "cast_fb" if _mode == "move" else "move"
			grid.clear_path()
			if grid.has_method("clear_area"):
				grid.clear_area()
			return

	if event is InputEventMouseButton and event.pressed:
		# Right click = melee try
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var t_rc: Vector2i = _mouse_tile()
			if t_rc != null:
				_try_melee(t_rc)
			return

		# Left click = move OR cast
		if event.button_index == MOUSE_BUTTON_LEFT:
			var t: Vector2i= _mouse_tile()
			if t == null: return
			if _mode == "cast_fb":
				_try_fireball(t)
			else:
				_try_move(t)

# ----------------- Actions (local intents) -----------------

func _try_move(t: Vector2i) -> void:
	if turn_order.is_empty(): return
	if _is_host():
		var active_id := turn_order[active_index]
		var pawn: Entity3D = entities[active_id]
		var path := PF.a_star(pawn.tile, t, _make_blocker(active_id))
		if path.size() > 1:
			var budget: int = max(0, pawn.move_points)
			if path.size() - 1 > budget:
				path = path.slice(0, budget + 1)

			await pawn.move_along(path, grid)
			pawn.move_points -= max(0, path.size() - 1)

			_broadcast_state()
			_refresh_reachable()

			if pawn.move_points <= 0:
				_next_turn()
				_refresh_reachable()
				_broadcast_state()
	else:
		if Net.has_method("send_action"):
			Net.send_action({"kind": "move_to", "x": t.x, "y": t.y})

func _try_melee(t: Vector2i) -> void:
	if turn_order.is_empty(): return
	var target_id := _entity_id_at_tile(t)
	if target_id == "": return
	var active_id := turn_order[active_index]
	if target_id == active_id: return
	var dist := _manhattan(entities[active_id].tile, t)
	if dist > MELEE_RANGE: return

	if _is_host():
		_apply_damage(target_id, MELEE_DAMAGE)
		_next_turn()
		_refresh_reachable()
		_broadcast_state()
	else:
		if Net.has_method("send_action"):
			Net.send_action({"kind": "melee", "target": str(target_id)})

func _try_fireball(t: Vector2i) -> void:
	if turn_order.is_empty(): return
	var active_id := turn_order[active_index]
	var caster: Entity3D = entities[active_id]
	if _manhattan(caster.tile, t) > FIREBALL_RANGE:
		return

	if _is_host():
		_apply_fireball(t)
		# casting ends turn
		_next_turn()
		_mode = "move"
		if grid.has_method("clear_area"):
			grid.clear_area()
		_refresh_reachable()
		_broadcast_state()
	else:
		if Net.has_method("send_action"):
			Net.send_action({"kind": "cast_fireball", "x": t.x, "y": t.y})

# ----------------- Turn / State -----------------

func _next_turn() -> void:
	active_index = (active_index + 1) % turn_order.size()
	var active_pawn: Entity3D = entities[turn_order[active_index]]
	if active_pawn:
		active_pawn.move_points = active_pawn.move_points_per_turn

func _broadcast_state() -> void:
	if not _is_host(): return
	var state := {
		"active": str(turn_order[active_index]),
		"entities": {}
	}
	for id in entities.keys():
		var e: Entity3D = entities[id]
		state["entities"][str(id)] = {
			"x": e.tile.x, "y": e.tile.y,
			"team": e.team,
			"hp": e.hp, "max_hp": e.max_hp,
			"mp": e.move_points,
			"statuses": e.status_effects
		}
	Net.broadcast_state(state)

# ----------------- Networking handlers -----------------

func _on_net_message(msg: Dictionary) -> void:
	var kind := String(msg.get("type",""))
	if kind == "state":
		_apply_state_snapshot(msg.get("payload", {}))
	elif kind == "action" and _is_host():
		var a: Dictionary = msg.get("payload", {})
		match String(a.get("kind","")):
			"end_turn":
				_next_turn()
				_refresh_reachable()
				_broadcast_state()

			"move_to":
				var t := Vector2i(int(a.get("x",0)), int(a.get("y",0)))
				var active_id := turn_order[active_index]
				var pawn: Entity3D = entities[active_id]
				var path := PF.a_star(pawn.tile, t, _make_blocker(active_id))
				if path.size() > 1:
					var budget: int = max(0, pawn.move_points)
					if path.size() - 1 > budget:
						path = path.slice(0, budget + 1)
					await pawn.move_along(path, grid)
					pawn.move_points -= max(0, path.size() - 1)
				_broadcast_state()
				_refresh_reachable()
				if pawn.move_points <= 0:
					_next_turn()
					_refresh_reachable()
					_broadcast_state()

			"melee":
				var target_id := StringName(a.get("target",""))
				if target_id != "":
					_apply_damage(target_id, MELEE_DAMAGE)
					_next_turn()
					_refresh_reachable()
					_broadcast_state()

			"cast_fireball":
				var t_fb := Vector2i(int(a.get("x",0)), int(a.get("y",0)))
				var caster: Dictionary = entities[turn_order[active_index]]
				if caster and _manhattan(caster.tile, t_fb) <= FIREBALL_RANGE:
					_apply_fireball(t_fb)
					_next_turn()
					_mode = "move"
					if grid.has_method("clear_area"):
						grid.clear_area()
					_refresh_reachable()
					_broadcast_state()

# ----------------- Game-state mutators -----------------

func _apply_damage(entity_id: StringName, amount: int) -> void:
	var e: Entity3D = entities.get(entity_id)
	if e == null: return
	e.apply_damage(amount)

func _apply_fireball(center: Vector2i) -> void:
	# Visual flash of the area
	if grid.has_method("show_area"):
		var tiles := _tiles_in_radius(center, FIREBALL_RADIUS)
		grid.show_area(tiles, Color(1.0, 0.35, 0.2, 0.65))
		var tw := create_tween()
		tw.tween_interval(0.18)
		tw.tween_callback(Callable(grid, "clear_area"))

	# Apply damage to all entities in radius
	for id in entities.keys():
		var e: Entity3D = entities[id]
		if _manhattan(e.tile, center) <= FIREBALL_RADIUS:
			_apply_damage(id, FIREBALL_DAMAGE)

# Apply an instant move (used during reconstruction if needed)
func _apply_move(entity_id: StringName, t: Vector2i) -> void:
	if not grid.in_bounds(t): return
	var pawn: Entity3D = entities.get(entity_id)
	if pawn == null: return
	pawn.set_tile(t, grid)

# Everyone: consume authoritative snapshots
func _apply_state_snapshot(p: Dictionary) -> void:
	if p.is_empty(): return
	if p.has("entities"):
		for id in p["entities"].keys():
			var data: Dictionary = p["entities"][id]
			var e: Entity3D = entities.get(id)
			if e == null:
				e = Entity3D.new()
				e.entity_id = id
				e.team = int(data.get("team", 0))
				add_child(e)
				entities[id] = e
			# sync position
			var t := Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
			_apply_move(id, t)
			# sync stats
			if data.has("hp"): e.hp = int(data["hp"])
			if data.has("max_hp"): e.max_hp = int(data["max_hp"])
			if data.has("mp"): e.move_points = int(data["mp"])
			if data.has("statuses"): e.set_statuses(data["statuses"])
			if e.billboard:
				e.billboard.set_max_hp(e.max_hp)
				e.billboard.set_hp(e.hp)
	_refresh_reachable()

# ----------------- Helpers -----------------

func _is_host() -> bool:
	if Net and Net.has_method("is_host"): return Net.is_host()
	var mp := get_tree().get_multiplayer()
	return mp.multiplayer_peer == null || mp.is_server()

# Returns Vector2i tile or null (Variant) if no hit
func _mouse_tile() -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null: return null
	var mpos := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mpos)
	var dir := cam.project_ray_normal(mpos)
	# Ray to XZ plane (y=0)
	if absf(dir.y) <= 0.0001:
		return null
	var t := -from.y / dir.y
	if t <= 0.0:
		return null
	var hit := from + dir * t
	return grid.world_to_tile(hit)

func _reachable_from(start: Vector2i, mp: int, is_blocked: Callable) -> Array:
	var q := []
	var dist := {}  # tile -> steps
	var tiles := []

	q.append(start)
	dist[start] = 0
	tiles.append(start)

	while q.size() > 0:
		var cur: Vector2i = q.pop_front()
		var d := int(dist[cur])
		if d == mp:
			continue
		var neigh := Pathfinder3D.neighbors4(cur)
		for n in neigh:
			if not grid.in_bounds(n):
				continue
			if is_blocked.call(n):
				continue
			var nd := d + 1
			if not dist.has(n) or nd < int(dist[n]):
				dist[n] = nd
				q.append(n)
				tiles.append(n)

	return tiles  # includes start

func _make_blocker(active_id: StringName) -> Callable:
	return func(p: Vector2i) -> bool:
		if not grid.in_bounds(p): return true
		# occupied by others?
		for id in entities.keys():
			if id == active_id: continue
			var e: Entity3D = entities[id]
			if e.tile == p: return true
		# terrain blocked?
		if grid.has_method("is_blocked") and grid.is_blocked(p): return true
		return false

func _refresh_reachable() -> void:
	if turn_order.is_empty(): return
	var active_id := turn_order[active_index]
	var pawn: Entity3D = entities[active_id]
	if pawn == null: return
	var reach := _reachable_from(pawn.tile, pawn.move_points, _make_blocker(active_id))
	grid.show_reachable(reach)

func _entity_id_at_tile(t: Vector2i) -> StringName:
	for id in entities.keys():
		if entities[id].tile == t:
			return id
	return StringName("")

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _tiles_in_radius(center: Vector2i, r: int) -> Array:
	var out := []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := Vector2i(center.x + dx, center.y + dy)
			if _manhattan(center, p) <= r and grid.in_bounds(p):
				out.append(p)
	return out
