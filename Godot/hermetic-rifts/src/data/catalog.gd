class_name Catalog
extends RefCounted

const VERSION: int = 1
const IMPLEMENTED_EFFECTS: Array[String] = [
	"projectile", "dash", "self-slow", "delayed-strike", "slow-line", "tether",
	"melee-arc", "harpoon", "calcinatio-slam", "prism", "solar-beam",
	"parry", "censure-bell", "iron-bulwark", "celestial-swap", "nova-burst",
]
const IMPLEMENTED_HOOK_OPS: Array[String] = ["add", "pct", "on-kill", "on-crit"]
const SLOTS: Array[String] = ["primary", "secondary", "utility", "special"]

var world: Dictionary = {}
var loop: Dictionary = {}
var obstacles: Dictionary = {}
var stages: Dictionary = {}
var items: Array[Dictionary] = []
var entities: Array[Dictionary] = []
var survivors: Array[Dictionary] = []
var skills: Array[Dictionary] = []
var crucible_upgrades: Array[Dictionary] = []
var _skills: Dictionary = {}
var _survivors: Dictionary = {}
var _entities: Dictionary = {}
var _items: Dictionary = {}
var _stages: Dictionary = {}
var _upgrades: Dictionary = {}


static func load_from_res(base_path: String = "res://data/catalog") -> Catalog:
	var cat := Catalog.new()
	cat.world = _read_json("%s/world.json" % base_path)
	cat.loop = _read_json("%s/loop.json" % base_path)
	cat.obstacles = _read_json("%s/obstacles.json" % base_path)
	cat.stages = _read_json("%s/stages.json" % base_path)
	var skills_raw: Dictionary = _read_json("%s/skills.json" % base_path)
	var survivors_raw: Dictionary = _read_json("%s/survivors.json" % base_path)
	var entities_raw: Dictionary = _read_json("%s/entities.json" % base_path)
	var items_raw: Dictionary = _read_json("%s/items.json" % base_path)
	var upgrades_raw: Dictionary = _read_json("%s/crucible_upgrades.json" % base_path)
	cat._skills = cat._index(skills_raw, "skills.json")
	cat._survivors = cat._index(survivors_raw, "survivors.json")
	cat._entities = cat._index(entities_raw, "entities.json")
	cat._items = cat._index(items_raw, "items.json")
	cat._stages = cat._index_stages(cat.stages, "stages.json")
	cat._upgrades = cat._index(upgrades_raw, "crucible_upgrades.json")
	cat._validate()
	for id: Variant in cat._items.keys():
		cat.items.append(cat._items[id])
	for id: Variant in cat._entities.keys():
		cat.entities.append(cat._entities[id])
	for id: Variant in cat._survivors.keys():
		cat.survivors.append(cat._survivors[id])
	for id: Variant in cat._skills.keys():
		cat.skills.append(cat._skills[id])
	for id: Variant in cat._upgrades.keys():
		cat.crucible_upgrades.append(cat._upgrades[id])
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


func stage(id: String) -> Dictionary:
	if not _stages.has(id):
		push_error("Unknown stage \"%s\"" % id)
		return {}
	return _stages[id]


func upgrade(id: String) -> Dictionary:
	if not _upgrades.has(id):
		push_error("Unknown upgrade \"%s\"" % id)
		return {}
	return _upgrades[id]


func all_stages() -> Array:
	var out: Array = []
	for st_v: Variant in DictUtil.a(stages, "stages"):
		out.append(st_v)
	for sp_v: Variant in DictUtil.a(stages, "specialStages"):
		out.append(sp_v)
	return out


func has_entity(id: String) -> bool:
	return _entities.has(id)


func has_item(id: String) -> bool:
	return _items.has(id)


func has_survivor(id: String) -> bool:
	return _survivors.has(id)


func has_skill(id: String) -> bool:
	return _skills.has(id)


func has_stage(id: String) -> bool:
	return _stages.has(id)


func has_upgrade(id: String) -> bool:
	return _upgrades.has(id)


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


func _index_stages(raw: Dictionary, file: String) -> Dictionary:
	if int(raw.get("version", 0)) != VERSION:
		push_error("%s version %s, expected %s" % [file, raw.get("version", 0), VERSION])
	var map: Dictionary = {}
	for key: String in ["stages", "specialStages"]:
		for entry: Variant in DictUtil.a(raw, key):
			if typeof(entry) != TYPE_DICTIONARY:
				push_error("%s %s entry is not an object" % [file, key])
				continue
			var row: Dictionary = entry
			var id: String = String(row.get("id", ""))
			if id == "":
				push_error("%s %s entry missing id" % [file, key])
				continue
			if map.has(id):
				push_error("%s duplicate stage id \"%s\"" % [file, id])
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
	if int(stages.get("version", 0)) != VERSION:
		push_error("stages.json version mismatch")
	_validate_entities()
	_validate_items()
	_validate_skills()
	_validate_survivors()
	_validate_upgrades()
	if not _survivors.has(String(world.get("defaultSurvivor", ""))):
		push_error("world.defaultSurvivor missing")
	if not _entities.has(String(world.get("defaultEnemy", ""))):
		push_error("world.defaultEnemy missing")
	var biomes: Dictionary = DictUtil.d(obstacles, "biomes")
	_validate_stage_list(DictUtil.a(stages, "stages"), biomes, "stages.json:stages")
	_validate_stage_list(DictUtil.a(stages, "specialStages"), biomes, "stages.json:specialStages")
	_validate_stage_list(DictUtil.a(loop, "stages"), biomes, "loop.json:stages")
	_validate_stage_list(DictUtil.a(loop, "specialStages"), biomes, "loop.json:specialStages")


func _validate_entities() -> void:
	if not _entities.has("voltaic-spire"):
		push_error("entities.json missing required construct \"voltaic-spire\"")
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
				var atk_type: String = String(atk.get("type", ""))
				if atk_type == "summon" or atk_type == "chain_anchor":
					var summoned_id: String = String(atk.get("entity", ""))
					if not _entities.has(summoned_id):
						push_error("Boss %s missing entity \"%s\"" % [atk_type, summoned_id])


func _validate_items() -> void:
	for item_row: Variant in _items.values():
		var item_def: Dictionary = item_row
		for hook_v: Variant in item_def.get("hooks", []):
			var hook: Dictionary = hook_v
			var op: String = String(hook.get("op", ""))
			if not IMPLEMENTED_HOOK_OPS.has(op):
				push_error("Item \"%s\" unimplemented hook %s" % [item_def.get("id", ""), op])


func _validate_skills() -> void:
	for skill_row: Variant in _skills.values():
		var skill_def: Dictionary = skill_row
		for effect_v: Variant in skill_def.get("effects", []):
			var effect: Dictionary = effect_v
			var effect_type: String = String(effect.get("type", ""))
			if not IMPLEMENTED_EFFECTS.has(effect_type):
				push_error("Skill \"%s\" unimplemented effect \"%s\"" % [skill_def.get("id", ""), effect_type])


func _validate_survivors() -> void:
	for surv_row: Variant in _survivors.values():
		var surv: Dictionary = surv_row
		var skills: Dictionary = DictUtil.d(surv, "skills")
		for slot: String in SLOTS:
			var skill_id: String = String(skills.get(slot, ""))
			if skill_id == "" or not _skills.has(skill_id):
				push_error("Survivor \"%s\" missing skill %s" % [surv.get("id", ""), skill_id])
		var alt_skills: Dictionary = DictUtil.d(surv, "altSkills")
		if alt_skills.is_empty():
			push_error("Survivor \"%s\" missing altSkills" % surv.get("id", ""))
		else:
			for slot: String in SLOTS:
				var alt_id: String = String(alt_skills.get(slot, ""))
				if alt_id == "" or not _skills.has(alt_id):
					push_error("Survivor \"%s\" missing altSkill %s" % [surv.get("id", ""), alt_id])


func _validate_upgrades() -> void:
	for upg_row: Variant in _upgrades.values():
		var upg: Dictionary = upg_row
		var max_lv: int = int(upg.get("maxLevel", 0))
		var costs: Array = DictUtil.a(upg, "costs")
		if max_lv <= 0 or costs.size() != max_lv:
			push_error("Upgrade \"%s\" maxLevel (%d) != costs.size() (%d)" % [upg.get("id", ""), max_lv, costs.size()])


func _validate_stage_list(list: Array, biomes: Dictionary, source_name: String) -> void:
	if list.is_empty():
		push_error("%s has no stage entries" % source_name)
		return
	for st_v: Variant in list:
		if typeof(st_v) != TYPE_DICTIONARY:
			push_error("%s contains non-object stage" % source_name)
			continue
		var st: Dictionary = st_v
		var sid: String = String(st.get("id", ""))
		if sid == "":
			push_error("%s stage missing id" % source_name)
			continue
		if not biomes.has(sid):
			push_error("obstacles.json missing biome names for %s" % sid)
		_assert_stage_entity(st, "fodder")
		_assert_stage_entity(st, "elite")
		_assert_stage_entity(st, "boss")
		_assert_optional_stage_entity(st, "ranged")
		_assert_optional_stage_entity(st, "sniper")
		var alt_stage: String = String(st.get("altStageId", ""))
		if alt_stage != "" and not _stages.has(alt_stage):
			push_error("Stage \"%s\" altStageId missing: %s" % [sid, alt_stage])


func _assert_stage_entity(stage_def: Dictionary, key: String) -> void:
	var id: String = String(stage_def.get(key, ""))
	if not _entities.has(id):
		push_error("Stage \"%s\" %s missing: %s" % [stage_def.get("id", ""), key, id])


func _assert_optional_stage_entity(stage_def: Dictionary, key: String) -> void:
	var id: String = String(stage_def.get(key, ""))
	if id != "" and not _entities.has(id):
		push_error("Stage \"%s\" %s missing: %s" % [stage_def.get("id", ""), key, id])
