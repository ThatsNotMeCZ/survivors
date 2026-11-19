class_name Loc
extends RefCounted

const CSV_PATH: String = "res://locale/en.csv"


static func load_en() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return
	var translation := Translation.new()
	translation.locale = "en"
	var header: PackedStringArray = file.get_csv_line()
	if header.size() < 2 or header[0] != "keys":
		return
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2:
			continue
		translation.add_message(row[0], row[1])
	TranslationServer.clear()
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("en")


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func item_name(id: String) -> String:
	return t("item.%s.name" % id)


static func entity_name(id: String) -> String:
	return t("entity.%s.name" % id)


static func survivor_name(id: String) -> String:
	return t("survivor.%s.name" % id)


static func skill_name(id: String) -> String:
	return t("skill.%s.name" % id)


static func skill_hook(id: String) -> String:
	return t("skill.%s.hook" % id)


static func skill_lore(id: String) -> String:
	return t("skill.%s.lore" % id)


static func entity_title(id: String) -> String:
	return t("entity.%s.title" % id)


static func entity_lore(id: String) -> String:
	return t("entity.%s.lore" % id)


static func item_lore(id: String) -> String:
	return t("item.%s.lore" % id)


static func survivor_title(id: String) -> String:
	return t("survivor.%s.title" % id)


static func survivor_lore(id: String) -> String:
	return t("survivor.%s.lore" % id)


static func stage_name(id: String) -> String:
	return t("stage.%s.name" % id)


static func stage_kicker(id: String) -> String:
	return t("stage.%s.kicker" % id)


static func stage_lore(id: String) -> String:
	return t("stage.%s.lore" % id)


static func unseen() -> String:
	return t("ui.prompt.???")


static func format_time(seconds: float) -> String:
	var total: int = maxi(0, int(floor(seconds)))
	var minutes: int = int(floor(float(total) / 60.0))
	return "%d:%02d" % [minutes, total % 60]
