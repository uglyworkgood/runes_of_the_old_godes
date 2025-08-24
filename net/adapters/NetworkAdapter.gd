# res://net/adapters/NetworkAdapter.gd
extends Node
class_name NetworkAdapter
## Base interface for hot-swappable networking backends.
## Concrete adapters (ENet, Steam) MUST:
##  - Emit: connected_as_host, connected_as_client, state_received, chat_received
##  - Implement: host_lobby, find_lobbies, join_lobby, send_action, broadcast_state, send_chat

# ---- Signals exposed to Network.gd and the game ----
signal connected_as_host
signal connected_as_client
signal state_received(state: Dictionary)     # { "type": "action"|"state", "payload": {...} }
signal chat_received(sender: String, text: String)

# Optional: adapters may keep internal state (e.g., peer, is_host), but the base stays minimal.

# ---- Lobby / connection lifecycle ----

## Start hosting a lobby/session.
## Backends decide how to use the name (ENet ignores; Steam uses it for the lobby).
func host_lobby(_name: String) -> void:
	push_warning("%s.host_lobby() not implemented" % [get_class()])

## Return a list of available lobbies/servers to join.
## Each item should at least contain an 'id' and 'name' field.
func find_lobbies() -> Array:
	push_warning("%s.find_lobbies() not implemented" % [get_class()])
	return []

## Join a lobby/session by its identifier (string or backend-specific type).
func join_lobby(_id) -> void:
	push_warning("%s.join_lobby() not implemented" % [get_class()])

# ---- Messaging API ----

## Send a player intent/action to the host.
## The host adapter should receive it and emit `state_received({"type":"action","payload": msg})`
## so game logic can validate/apply and then broadcast an authoritative state.
func send_action(_msg: Dictionary) -> void:
	push_warning("%s.send_action() not implemented" % [get_class()])

## Host-only: broadcast the authoritative state snapshot to all peers.
## Clients should receive it and emit `state_received({"type":"state","payload": state})`.
func broadcast_state(_state: Dictionary) -> void:
	push_warning("%s.broadcast_state() not implemented" % [get_class()])

## Send a chat line (client → host → everyone).
func send_chat(_text: String) -> void:
	push_warning("%s.send_chat() not implemented" % [get_class()])
