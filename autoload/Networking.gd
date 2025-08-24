# res://autoload/Network.gd
extends Node
class_name Network

## Facade over a hot-swappable network adapter.
## Start with ENet; later you can swap to Steam by setting NetworkingConfig.default_adapter = "Steam".

signal connected_as_host
signal connected_as_client
signal state_received(state: Dictionary)
signal chat_received(sender: String, text: String)
signal lobbies_updated(lobbies: Array)

var adapter: Node = null
var _lobbies_cache: Array = []

func _ready() -> void:
	# Pick adapter from NetworkingConfig (Autoload) or fall back to ENet.
	var name := "ENet"
	if Engine.has_singleton("NetworkingConfig"):
		name = String(NetworkingConfig.default_adapter)
	set_adapter(name)

func set_adapter(name: StringName) -> void:
	# Clean up previous adapter
	if adapter:
		_disconnect_adapter_signals()
		remove_child(adapter)
		adapter.queue_free()
		adapter = null

	# Instantiate chosen adapter
	match String(name):
		"ENet":
			adapter = preload("res://net/adapters/ENetworkAdapter.gd").new()
		"Steam":
			adapter = preload("res://net/adapters/SteamNetworkAdapter.gd").new()
		_:
			push_error("Unknown network adapter: %s (defaulting to ENet)" % name)
			adapter = preload("res://net/adapters/ENetworkAdapter.gd").new()

	add_child(adapter)
	_connect_adapter_signals()

func _connect_adapter_signals() -> void:
	if not adapter: return
	# These signals must exist on the adapter (see ENetworkAdapter.gd stub).
	if adapter.has_signal("connected_as_host"):
		adapter.connected_as_host.connect(func(): connected_as_host.emit())
	if adapter.has_signal("connected_as_client"):
		adapter.connected_as_client.connect(func(): connected_as_client.emit())
	if adapter.has_signal("state_received"):
		adapter.state_received.connect(func(s): state_received.emit(s))
	if adapter.has_signal("chat_received"):
		adapter.chat_received.connect(func(u, t): chat_received.emit(u, t))

func _disconnect_adapter_signals() -> void:
	if not adapter: return
	if adapter.has_signal("connected_as_host"):
		adapter.connected_as_host.disconnect_all()
	if adapter.has_signal("connected_as_client"):
		adapter.connected_as_client.disconnect_all()
	if adapter.has_signal("state_received"):
		adapter.state_received.disconnect_all()
	if adapter.has_signal("chat_received"):
		adapter.chat_received.disconnect_all()

# ---------- Lobby lifecycle ----------

func host_lobby(lobby_name: String) -> void:
	if not adapter or not adapter.has_method("host_lobby"):
		push_error("Adapter doesn't support host_lobby")
		return
	adapter.host_lobby(lobby_name)

func find_lobbies() -> Array:
	if not adapter or not adapter.has_method("find_lobbies"):
		push_error("Adapter doesn't support find_lobbies")
		return []
	var found: Array = adapter.find_lobbies()
	if typeof(found) != TYPE_ARRAY:
		found = []
	_lobbies_cache = found
	lobbies_updated.emit(found)
	return found

func join_lobby(id) -> void:
	if not adapter or not adapter.has_method("join_lobby"):
		push_error("Adapter doesn't support join_lobby")
		return
	adapter.join_lobby(id)

# ---------- Game RPCs / messaging ----------

func send_action(msg: Dictionary) -> void:
	if not adapter or not adapter.has_method("send_action"):
		push_error("Adapter doesn't support send_action")
		return
	adapter.send_action(msg)

func broadcast_state(state: Dictionary) -> void:
	# Host should call this after applying a move/cast to push authoritative state.
	if not adapter or not adapter.has_method("broadcast_state"):
		push_error("Adapter doesn't support broadcast_state")
		return
	adapter.broadcast_state(state)

func send_chat(text: String) -> void:
	if not adapter or not adapter.has_method("send_chat"):
		push_error("Adapter doesn't support send_chat")
		return
	adapter.send_chat(text)

# ---------- Utility ----------

func get_cached_lobbies() -> Array:
	return _lobbies_cache.duplicate()
