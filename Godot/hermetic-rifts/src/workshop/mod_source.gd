class_name IModSource
extends RefCounted


func load_pack(path: String) -> Dictionary:
	var ext: String = path.get_extension().to_lower()
	if ext in ["gd", "cs", "dll", "so", "dylib"]:
		push_error("Workshop pack rejected script/native: %s" % path)
		return {}
	return {}
