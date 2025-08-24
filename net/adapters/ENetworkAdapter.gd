# res://net/adapters/ENetNetworkAdapter.gd
extends "res://net/adapters/NetworkAdapter.gd"
class_name ENetNetworkAdapter

var peer: ENetMultiplayerPeer
var is_host := false

# Convenience
func _mp() -> MultiplayerAPI:
	return get_tree().get_multiplayer()

func _ready() -> void:
	# Hook low-level Multiplayer signals (optional, useful for logs)
	_mp().peer_connected.connect(_on_peer_connected)
	_mp().peer_disconnected.connect(_on_peer_disconnected)
	_mp().connected_to_server.connect(_on_connected_to_server)
	_mp().connection_failed.connect(func(): push_error("ENet: connection failed"))

# ---------------- Lobby lifecycle ----------------

func host_lobby(_name: String) -> void:
	# Create server using NetworkingConfig defaults
	var port := NetworkingConfig.enet_port if Engine.has_singleton("NetworkingConfig") else 1911
	var max_clients := NetworkingConfig.enet_max_clients if Engine.has_singleton("NetworkingConfig") else 8

	peer = ENetMultiplayerPeer.new()
	var ok := peer.create_server(port, max_clients)
	if ok != OK:
		push_error("ENet: failed to host on port %s (code %s)" % [port, ok])
		return

	_mp().multiplayer_peer = peer
	is_host = true
	connected_as_host.emit()

func find_lobbies() -> Array:
	# ENet has no discovery; provide a simple local option so UI can list something.
	var port := NetworkingConfig.enet_port if Engine.has_singleton("NetworkingConfig") else 1911
	return [
		{"id": "127.0.0.1:%d" % port, "name": "Local ENet Server :%d" % port},
		{"id": "localhost", "name": "Localhost (quick join)"}
	]

func join_lobby(id) -> void:
	var host := "127.0.0.1"
	var port := NetworkingConfig.enet_port if Engine.has_singleton("NetworkingConfig") else 1911

	if typeof(id) == TYPE_STRING:
		if ":" in String(id):
			var parts := String(id).split(":")
			host = parts[0]
			port = int(parts[1])
		elif String(id) != "localhost":
			host = String(id)

	peer = ENetMultiplayerPeer.new()
	var ok := peer.create_client(host, port)
	if ok != OK:
		push_error("ENet: failed to join %s:%s (code %s)" % [host, port, ok])
		return

	_mp().multiplayer_peer = peer
	is_host = false
	# We emit connected_as_client when the Multiplayer API confirms it.
	# (_on_connected_to_server)

# ---------------- Messaging (Client -> Host) ----------------

## Clients send actions to the host (peer 1). Host receives and emits state_received so game code can apply rules.
func send_action(msg: Dictionary) -> void:
	if is_host:
		# If host calls this (e.g., local player), just loop it into the same path:
		_rpc_client_action(msg) # call locally
	else:
		rpc_id(1, "_rpc_client_action", msg)

## Clients send chat to host; host rebroadcasts to everyone.
func send_chat(text: String) -> void:
	var name := OS.get_unique_id()
	if is_host:
		_rpc_client_chat(name, text)
	else:
		rpc_id(1, "_rpc_client_chat", name, text)

# ---------------- Messaging (Host -> Everyone) ----------------

## Host pushes authoritative snapshots after applying moves/abilities.
func broadcast_state(state: Dictionary) -> void:
	if not is_host:
		return
	# Send to all peers (including host for local update)
	rpc("_rpc_state", state)

# ---------------- RPC Endpoints ----------------
# NOTE: In Godot 4, @rpc("any_peer") allows calls from clients to host.
# Host uses plain rpc(...) to broadcast to all.

@rpc("any_peer")
func _rpc_client_action(msg: Dictionary) -> void:
	# This method runs on the host when a client calls rpc_id(1,...).
	if is_host:
		# Let game code handle/validate the action via Network.state_received
		# (Network.gd relays this signal to listeners)
		state_received.emit({"type": "action", "payload": msg})

@rpc("any_peer")
func _rpc_client_chat(sender: String, text: String) -> void:
	if is_host:
		# Inform local UI
		chat_received.emit(sender, text)
		# Rebroadcast to everyone (including sender)
		rpc("_rpc_chat", sender, text)

@rpc("any_peer", "call_local")
func _rpc_state(state: Dictionary) -> void:
	# Everyone (host+clients) receives authoritative state snapshots here
	state_received.emit({"type": "state", "payload": state})

@rpc("any_peer", "call_local")
func _rpc_chat(sender: String, text: String) -> void:
	chat_received.emit(sender, text)

# ---------------- Multiplayer hooks ----------------

func _on_connected_to_server() -> void:
	connected_as_client.emit()

func _on_peer_connected(id: int) -> void:
	# Useful place to send initial state from host to a late joiner
	# (your game code can ask the host to push a snapshot here)
	if is_host:
		# Optionally: send a hello/snapshot
		pass

func _on_peer_disconnected(id: int) -> void:
	# Cleanup if you track players by peer ID
	if is_host:
		# Optionally: remove entities owned by this peer, then broadcast_state(...)
		pass
