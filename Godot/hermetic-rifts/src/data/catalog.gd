class_name Catalog
extends RefCounted

const VERSION: int = 1
const IMPLEMENTED_EFFECTS: Array[String] = [
	"projectile", "dash", "self-slow", "delayed-strike", "slow-line", "tether",
]
const IMPLEMENTED_HOOK_OPS: Array[String] = ["add", "pct", "on-kill", "on-crit"]
const SLOTS: Array[String] = ["primary", "secondary", "utility", "special"]

var world: Dictionary = {}
var loop: Dictionary = {}
var obstacles: Dictionary = {}
var items: Array[Dictionary] = []
var entities: Array[Dictionary] = []
var survivors: Array[Dictionary] = []
var _skills: Dictionary = {}
var _survivors: Dictionary = {}
var _entities: Dictionary = {}
var _items: Dictionary = {}


static func load_from_res(base_path: String = "res://data/catalog") -> Catalog:
	var cat := Catalog.new()
	cat.world = _read_json("%s/world.json" % base_path)
	cat.loop = _read_json("%s/loop.json" % base_path)
	cat.obstacles = _read_json("%s/obstacles.json" % base_path)
	var skills_raw: Dictionary = _read_json("%s/skills.json" % base_path)
	var survivors_raw: Dictionary = _read_json("%s/survivors.json" % base_path)
	var entities_raw: Dictionary = _read_json("%s/entities.json" % base_path)
	var items_raw: Dictionary = _read_json("%s/items.json" % base_path)
	cat._skills = cat._index(skills_raw, "skills.json")
	cat._survivors = cat._index(survivors_raw, "survivors.json")
	cat._entities = cat._index(entities_raw, "entities.json")
	cat._items = cat._index(items_raw, "items.json")
	cat._validate()
	for id: Variant in cat._items.keys():
		cat.items.append(cat._items[id])
	for id: Variant in cat._entities.keys():
		cat.entities.append(cat._entities[id])
	for id: Variant in cat._survivors.keys():
		cat.survivors.append(cat._survivors[id])
	return cat


func skill(id: String) -> Dictionary:
	if not _skills.has(id):
		push_error("Unknown skill \"%s\"" % id)
		return {}
	return _skills[id]


func survivor(id: String) -> Dictionary:
	if not _survivors.has(id):
		push_error("Unknown survivor \"%s\"" % id)
		return {}
	return _survivors[id]


func entity(id: String) -> Dictionary:
	if not _entities.has(id):
		push_error("Unknown entity \"%s\"" % id)
		return {}
	return _entities[id]


func item(id: String) -> Dictionary:
	if not _items.has(id):
		push_error("Unknown item \"%s\"" % id)
		return {}
	return _items[id]


func has_entity(id: String) -> bool:
	return _entities.has(id)


func has_item(id: String) -> bool:
	return _items.has(id)


func has_survivor(id: String) -> bool:
	return _survivors.has(id)


static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing catalog file %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Catalog file %s is not an object" % path)
		return {}
	return parsed


func _index(raw: Dictionary, file: String) -> Dictionary:
	if int(raw.get("version", 0)) != VERSION:
		push_error("%s version %s, expected %s" % [file, raw.get("version", 0), VERSION])
	var map: Dictionary = {}
	for entry: Variant in raw.get("entries", []):
		var row: Dictionary = entry
		var id: String = String(row.get("id", ""))
		if id == "":
			push_error("%s entry missing id" % file)
			continue
		if map.has(id):
			push_error("%s duplicate id \"%s\"" % [file, id])
			continue
		map[id] = row
	return map


func _validate() -> void:
	if int(world.get("version", 0)) != VERSION:
		push_error("world.json version mismatch")
	if int(loop.get("version", 0)) != VERSION:
		push_error("loop.json version mismatch")
	if int(obstacles.get("version", 0)) != VERSION:
		push_error("obstacles.json version mismatch")
	for entity_row: Variant in _entities.values():
		var def: Dictionary = entity_row
		var lore: Variant = def.get("lore", null)
		if typeof(lore) != TYPE_STRING or String(lore) == "":
			push_error("Entity \"%s\" missing lore" % def.get("id", ""))
		var ai: Dictionary = DictUtil.d(def, "ai")
		if String(def.get("role", "")) == "boss":
			if String(ai.get("type", "")) != "boss":
				push_error("Boss \"%s\" must use ai.type boss" % def.get("id", ""))
			var attacks: Array = ai.get("attacks", [])
			if attacks.is_empty():
				push_error("Boss \"%s\" needs at least one attack" % def.get("id", ""))
			for atk_v: Variant in attacks:
				var atk: Dictionary = atk_v
				if float(atk.get("cooldown", 0.0)) <= 0.0:
					push_error("Boss \"%s\" attack missing cooldown" % def.get("id", ""))
				if String(atk.get("type", "")) == "summon":
					var summoned_id: String = String(atk.get("entity", ""))
					if not _entities.has(summoned_id):
						push_error("Boss summon missing entity \"%s\"" % summoned_id)
	for item_row: Variant in _items.values():
		var item_def: Dictionary = item_row
		for hook_v: Variant in item_def.get("hooks", []):
			var hook: Dictionary = hook_v
			var op: String = String(hook.get("op", ""))
			if not IMPLEMENTED_HOOK_OPS.has(op):
				push_error("Item \"%s\" unimplemented hook %s" % [item_def.get("id", ""), op])
	for skill_row: Variant in _skills.values():
		var skill_def: Dictionary = skill_row
		for effect_v: Variant in skill_def.get("effects", []):
			var effect: Dictionary = effect_v
			if not IMPLEMENTED_EFFECTS.has(String(effect.get("type", ""))):
				push_error("Skill \"%s\" unimplemented effect" % skill_def.get("id", ""))
	for surv_row: Variant in _survivors.values():
		var surv: Dictionary = surv_row
		var skills: Dictionary = surv.get("skills", {})
		for slot: String in SLOTS:
			var skill_id: String = String(skills.get(slot, ""))
			if skill_id != "" and not _skills.has(skill_id):
				push_error("Survivor \"%s\" missing skill %s" % [surv.get("id", ""), skill_id])
	if not _survivors.has(String(world.get("defaultSurvivor", ""))):
		push_error("world.defaultSurvivor missing")
	if not _entities.has(String(world.get("defaultEnemy", ""))):
		push_error("world.defaultEnemy missing")
	var biomes: Dictionary = obstacles.get("biomes", {})
	for stage_v: Variant in DictUtil.a(loop, "stages"):
		var stage: Dictionary = stage_v
		var sid: String = String(stage.get("id", ""))
		if not biomes.has(sid):
			push_error("obstacles.json missing biome names for %s" % sid)
		_assert_stage_entity(stage, "fodder")
		_assert_stage_entity(stage, "elite")
		_assert_stage_entity(stage, "boss")


func _assert_stage_entity(stage: Dictionary, key: String) -> void:
	var id: String = String(stage.get(key, ""))
	if not _entities.has(id):
		push_error("Stage \"%s\" %s missing: %s" % [stage.get("id", ""), key, id])
