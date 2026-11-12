class_name ItemInstance
extends RefCounted

var id: String = ""
var stacks: int = 1


static func make(item_id: String, item_stacks: int = 1) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.id = item_id
	inst.stacks = item_stacks
	return inst
