class_name ArenaBiome
extends RefCounted


static func from_stage(stage_id: String) -> String:
	if stage_id == "rime-dock" or stage_id == "glacial-tomb":
		return "rime"
	return "cinder"


static func theme_from_stage(stage_id: String) -> String:
	if stage_id == "glacial-tomb":
		return "glacial"
	if stage_id == "rime-dock":
		return "rime"
	return "cinder"


static func env_id(theme: String, suffix: String) -> String:
	var direct: String = "%s-%s" % [theme, suffix]
	if UiAtlas.env_has(direct):
		return direct
	if theme == "glacial":
		var rime: String = "rime-%s" % suffix
		if UiAtlas.env_has(rime):
			return rime
	return direct
