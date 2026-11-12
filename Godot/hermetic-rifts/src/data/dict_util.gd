class_name DictUtil
extends RefCounted


static func d(parent: Dictionary, key: String) -> Dictionary:
	var v: Variant = parent.get(key, {})
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	return v


static func a(parent: Dictionary, key: String) -> Array:
	var v: Variant = parent.get(key, [])
	if typeof(v) != TYPE_ARRAY:
		return []
	return v
