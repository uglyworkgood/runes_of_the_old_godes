extends Window
class_name CharacterSheet

var _entity: Entity3D
var _name_label: Label
var _hp_label: Label
var _mp_label: Label
var _status_label: Label

func _ready() -> void:
        title = "Character Sheet"
        size = Vector2i(240, 160)
        var vb := VBoxContainer.new()
        vb.anchor_right = 1.0
        vb.anchor_bottom = 1.0
        vb.offset_left = 10
        vb.offset_top = 10
        vb.offset_right = -10
        vb.offset_bottom = -10
        add_child(vb)
        _name_label = Label.new()
        vb.add_child(_name_label)
        _hp_label = Label.new()
        vb.add_child(_hp_label)
        _mp_label = Label.new()
        vb.add_child(_mp_label)
        _status_label = Label.new()
        vb.add_child(_status_label)

func set_entity(e: Entity3D) -> void:
        _entity = e
        title = str(e.entity_id)
        _name_label.text = "Name: %s" % e.entity_id
        _hp_label.text = "HP: %d / %d" % [e.hp, e.max_hp]
        _mp_label.text = "MP: %d" % e.move_points
        _status_label.text = "Statuses: %s" % ", ".join(e.status_effects)
