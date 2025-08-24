extends Control

@onready var lobby_list: ItemList = %LobbyList
@onready var lobby_name: LineEdit = %LobbyName

func _ready() -> void:
	Networking.connected_as_host.connect(_go_game)
	Networking.connected_as_client.connect(_go_game)
	_refresh()

func _go_game() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_host_pressed() -> void:
	Networking.host_lobby(lobby_name.text.strip_edges())

func _on_refresh_pressed() -> void:
	_refresh()

func _on_join_pressed() -> void:
	if lobby_list.get_selected_items().is_empty():
		return
	var idx := lobby_list.get_selected_items()[0]
	var data: Dictionary = lobby_list.get_item_metadata(idx)
	Networking.join_lobby(data["id"])


func _refresh() -> void:
	lobby_list.clear()
	for l in Networking.find_lobbies():
		var i := lobby_list.add_item(l["name"])
		lobby_list.set_item_metadata(i, l)
