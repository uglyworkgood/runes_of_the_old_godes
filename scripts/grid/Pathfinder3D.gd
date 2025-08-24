# res://scripts/grid/Pathfinder3D.gd
extends Node
class_name Pathfinder3D

# 4-direction neighbors (Manhattan)
static func neighbors4(t: Vector2i) -> Array:
	return [Vector2i(t.x+1, t.y), Vector2i(t.x-1, t.y), Vector2i(t.x, t.y+1), Vector2i(t.x, t.y-1)]

# A* on a tile grid.
# 'is_blocked' is a Callable taking (Vector2i) -> bool
static func a_star(start: Vector2i, goal: Vector2i, is_blocked: Callable) -> Array:
	if start == goal:
		return [start]

	var open := []                 # array of dicts { "t": Vector2i, "f": int }
	var came := {}                 # tile -> previous tile
	var gscore := {}               # tile -> cost from start
	var fscore := {}               # tile -> g + heuristic
	var closed := {}               # tile -> true

	gscore[start] = 0
	fscore[start] = _heuristic(start, goal)
	_open_push(open, start, fscore[start])

	while open.size() > 0:
		var cur: Dictionary = _open_pop_lowest(open)  # dict {"t","f"}
		var current: Vector2i = cur["t"]

		if current == goal:
			return _reconstruct(came, current)

		closed[current] = true

		var neigh := neighbors4(current)
		for n in neigh:
			if closed.has(n):
				continue
			if is_blocked.call(n):
				continue

			var tentative := int(gscore[current]) + 1
			if not gscore.has(n) or tentative < int(gscore[n]):
				came[n] = current
				gscore[n] = tentative
				fscore[n] = tentative + _heuristic(n, goal)
				_open_set_or_push(open, n, fscore[n])

	return []  # no path found

# ---------- helpers (static, no lambdas / no generics) ----------

static func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

static func _reconstruct(came: Dictionary, cur: Vector2i) -> Array:
	var path := []
	var c := cur
	while came.has(c):
		path.push_front(c)
		c = came[c]
	path.push_front(c)  # start
	return path

static func _open_push(open: Array, t: Vector2i, f: int) -> void:
	open.append({"t": t, "f": f})

static func _open_pop_lowest(open: Array) -> Dictionary:
	var best_i := 0
	var best_f := int(open[0]["f"])
	for i in range(1, open.size()):
		var f := int(open[i]["f"])
		if f < best_f:
			best_f = f
			best_i = i
	return open.pop_at(best_i)

static func _open_set_or_push(open: Array, tile: Vector2i, f: int) -> void:
	for e in open:
		if e["t"] == tile:
			e["f"] = f
			return
	open.append({"t": tile, "f": f})
