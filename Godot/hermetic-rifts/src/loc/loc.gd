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
