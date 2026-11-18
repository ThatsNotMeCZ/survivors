class_name ArenaBiome
extends RefCounted


static func from_stage(stage_id: String) -> String:
	if stage_id == "rime-dock" or stage_id == "glacial-tomb" or stage_id == "aether-vault":
		return "rime"
	return "cinder"


static func theme_from_stage(stage_id: String) -> String:
	match stage_id:
		"glacial-tomb":
			return "glacial"
		"rime-dock":
			return "rime"
		"putrid-conservatory":
			return "putrid"
		"fulmination-foundry":
			return "foundry"
		"aether-vault":
			return "aether"
		"prima-materia-core":
			return "prima"
		_:
			return "cinder"


static func env_id(theme: String, suffix: String) -> String:
	var direct: String = "%s-%s" % [theme, suffix]
	if UiAtlas.env_has(direct):
		return direct
	if theme == "glacial" or theme == "aether":
		var rime: String = "rime-%s" % suffix
		if UiAtlas.env_has(rime):
			return rime
	if theme == "putrid" or theme == "foundry" or theme == "prima":
		var cinder: String = "cinder-%s" % suffix
		if UiAtlas.env_has(cinder):
			return cinder
	return direct
