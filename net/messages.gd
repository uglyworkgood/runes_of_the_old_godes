extends Node
class_name Msg


static func move(entity_id: StringName, to: Vector2i) -> Dictionary:
	return {"kind":"move","entity":entity_id,"to":to}


static func cast(entity_id: StringName, ability_id: StringName, tiles: Array) -> Dictionary:
	return {"kind":"cast","entity":entity_id,"ability":ability_id,"tiles":tiles}
