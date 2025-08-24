# res://autoload/Config.gd
extends Node
class_name Config

# --- Gameplay / presentation ---
@export var tile_size: int = 48          # pixels per tile
@export var max_players: int = 6

# --- Networking selection ---
# "ENet" for local/LAN and quick tests. Later you can switch to "Steam".
@export var default_adapter: StringName = "ENet"

# --- ENet defaults (for the ENetNetworkAdapter) ---
@export var enet_port: int = 1911
@export var enet_max_clients: int = 8

# Optional helpers
func get_enet_server_params() -> Dictionary:
	return {
		"port": enet_port,
		"max_clients": enet_max_clients
	}

func is_enet() -> bool:
	return String(default_adapter) == "ENet"

func is_steam() -> bool:
	return String(default_adapter) == "Steam"
