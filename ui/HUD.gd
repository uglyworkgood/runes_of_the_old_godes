# res://ui/HUD.gd
extends Control

@onready var turn_label: Label = %TurnLabel
@onready var end_btn: Button = %EndTurnBtn

var Net: Node

func _ready() -> void:
	# Autoloads live under /root by their Autoload name
	if has_node("/root/Networking"):
		Net = get_node("/root/Networking")
	elif has_node("/root/Network"):
		Net = get_node("/root/Network")
	else:
		push_error("HUD.gd: No 'Networking' or 'Network' autoload found under /root. Check Project > Project Settings > Autoload.")
		return

	Net.connect("state_received", Callable(self, "_on_state_received"))
	_set_turn_text("—")

func _on_state_received(s: Dictionary) -> void:
	if s.get("type") != "state":
		return
	var p: Variant = s.get("payload", {})
	var active := str(p.get("active", "—"))

	var mp_text := ""
	if p.has("entities") and p["entities"].has(active):
		mp_text = "  MP: %d" % int(p["entities"][active].get("mp", -1))

	_set_turn_text("%s%s" % [active, mp_text])


func _set_turn_text(active_id: String) -> void:
	if is_instance_valid(turn_label):
		turn_label.text = "Turn: %s" % active_id

func _on_end_turn_pressed() -> void:
	# host requests a turn advance; send a lightweight intent
	if Net == null: return
	if Net.has_method("send_action"):
		Net.send_action({"kind":"end_turn"})
