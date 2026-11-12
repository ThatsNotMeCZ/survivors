class_name ArchiveRecords
extends RefCounted

const PATH: String = "user://records.v1.json"
const VERSION: int = 1
const MAX_RECENT: int = 10

var data: Dictionary = {}


static func load_or_default() -> ArchiveRecords:
	var rec := ArchiveRecords.new()
	rec.data = _empty()
	if not FileAccess.file_exists(PATH):
		return rec
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return rec
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		rec.data = parsed
		rec.data["version"] = VERSION
	return rec


func save() -> void:
	var tmp: String = PATH + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))


func unlocked_item_ids(catalog: Catalog) -> Array[String]:
	var ids: Array[String] = []
	for item_def: Dictionary in catalog.items:
		if meets_unlock(item_def.get("unlock", null)):
			ids.append(String(item_def.get("id", "")))
	return ids


func collected_lore_ids() -> Array[String]:
	var ids: Array[String] = []
	var lores: Dictionary = data.get("entityLores", {})
	for id: Variant in lores.keys():
		ids.append(String(id))
	return ids


func meets_unlock(unlock_v: Variant) -> bool:
	if unlock_v == null or typeof(unlock_v) != TYPE_DICTIONARY:
		return true
	var unlock: Dictionary = unlock_v
	var t: String = String(unlock.get("type", ""))
	var count: int = int(unlock.get("count", 1))
	match t:
		"stage-clear":
			return int(DictUtil.d(data, "stageClears").get(String(unlock.get("stageId", "")), 0)) >= count
		"boss-kill":
			return int(DictUtil.d(data, "entityKills").get(String(unlock.get("entityId", "")), 0)) >= count
		"total-kills":
			return int(data.get("totalKills", 0)) >= count
		"elite-kills":
			return int(data.get("eliteKills", 0)) >= count
		"victories":
			return int(data.get("victories", 0)) >= count
		_:
			return true


func record_lore(entity_id: String) -> void:
	var lores: Dictionary = data.get("entityLores", {})
	lores[entity_id] = 1
	data["entityLores"] = lores
	save()


func record_run_end(world: SimWorld, outcome: String) -> void:
	data["totalRuns"] = int(data.get("totalRuns", 0)) + 1
	if outcome == "victory":
		data["victories"] = int(data.get("victories", 0)) + 1
	elif outcome == "defeat":
		data["defeats"] = int(data.get("defeats", 0)) + 1
	elif outcome == "abandon":
		data["abandons"] = int(data.get("abandons", 0)) + 1
	data["totalPlayTime"] = float(data.get("totalPlayTime", 0.0)) + world.run_time
	data["totalKills"] = int(data.get("totalKills", 0)) + world.kills_total
	data["fodderKills"] = int(data.get("fodderKills", 0)) + world.kills_fodder
	data["eliteKills"] = int(data.get("eliteKills", 0)) + world.kills_elite
	data["bossKills"] = int(data.get("bossKills", 0)) + world.kills_boss
	data["totalDamageDealt"] = float(data.get("totalDamageDealt", 0.0)) + world.damage_dealt
	data["totalDamageTaken"] = float(data.get("totalDamageTaken", 0.0)) + world.damage_taken
	data["totalHealingDone"] = float(data.get("totalHealingDone", 0.0)) + world.healing_done
	data["totalGemsCollected"] = int(data.get("totalGemsCollected", 0)) + world.gems_collected
	data["stagesCleared"] = int(data.get("stagesCleared", 0)) + world.stages_cleared
	data["longestRunTime"] = maxf(float(data.get("longestRunTime", 0.0)), world.run_time)
	data["highestLevel"] = maxi(int(data.get("highestLevel", 1)), world.level)
	data["highestCoefficient"] = maxf(float(data.get("highestCoefficient", 1.0)), world.coefficient)
	data["mostKillsInRun"] = maxi(int(data.get("mostKillsInRun", 0)), world.kills_total)
	data["furthestStageIndex"] = maxi(int(data.get("furthestStageIndex", 0)), world.stage_index)
	var ek: Dictionary = data.get("entityKills", {})
	for id: Variant in world.kills_by_entity.keys():
		ek[String(id)] = int(ek.get(String(id), 0)) + int(world.kills_by_entity[id])
	data["entityKills"] = ek
	var ee: Dictionary = data.get("entityEncounters", {})
	for id: Variant in world.encounters_by_entity.keys():
		ee[String(id)] = int(ee.get(String(id), 0)) + int(world.encounters_by_entity[id])
	data["entityEncounters"] = ee
	var el: Dictionary = data.get("entityLores", {})
	for id: Variant in world.collected_lores.keys():
		el[String(id)] = 1
	data["entityLores"] = el
	var visits: Dictionary = data.get("stageVisits", {})
	var stages: Array = DictUtil.a(world.catalog.loop, "stages")
	if world.stage_index < stages.size():
		var sid: String = String(stages[world.stage_index].get("id", ""))
		visits[sid] = int(visits.get(sid, 0)) + 1
	data["stageVisits"] = visits
	if world.won:
		var clears: Dictionary = data.get("stageClears", {})
		for stage_v: Variant in stages:
			var st: Dictionary = stage_v
			var id: String = String(st.get("id", ""))
			clears[id] = int(clears.get(id, 0)) + 1
		data["stageClears"] = clears
		var fastest: Variant = data.get("fastestVictoryTime", null)
		if fastest == null or world.run_time < float(fastest):
			data["fastestVictoryTime"] = world.run_time
	var recent: Array = data.get("recentRuns", [])
	var items: Array = []
	for inst: ItemInstance in world.inventory:
		items.append({"id": inst.id, "stacks": inst.stacks})
	var stage_name: String = ""
	if world.stage_index < stages.size():
		stage_name = String(stages[world.stage_index].get("name", ""))
	recent.push_front({
		"timestamp": Time.get_unix_time_from_system(),
		"outcome": outcome,
		"survivorId": String(world.survivor.get("id", "")),
		"stageId": String(stages[world.stage_index].get("id", "")) if world.stage_index < stages.size() else "",
		"stageName": stage_name,
		"runTime": world.run_time,
		"level": world.level,
		"coefficient": world.coefficient,
		"kills": world.kills_total,
		"bossesDefeated": world.bosses_defeated,
		"damageDealt": world.damage_dealt,
		"items": items,
		"cycleIndex": world.cycle_index,
		"seedTag": SimRng.format_seed_tag(world.run_seed),
		"dailyDate": world.daily_date,
	})
	while recent.size() > MAX_RECENT:
		recent.pop_back()
	data["recentRuns"] = recent
	save()


func reset() -> void:
	data = _empty()
	save()


static func _empty() -> Dictionary:
	return {
		"version": VERSION,
		"totalRuns": 0,
		"victories": 0,
		"defeats": 0,
		"abandons": 0,
		"totalPlayTime": 0.0,
		"totalKills": 0,
		"fodderKills": 0,
		"eliteKills": 0,
		"bossKills": 0,
		"totalDamageDealt": 0.0,
		"totalDamageTaken": 0.0,
		"totalHealingDone": 0.0,
		"totalGemsCollected": 0,
		"totalItemsCollected": 0,
		"totalLevelsGained": 0,
		"stagesCleared": 0,
		"longestRunTime": 0.0,
		"fastestVictoryTime": null,
		"highestLevel": 1,
		"highestCoefficient": 1.0,
		"mostKillsInRun": 0,
		"mostDamageInRun": 0,
		"furthestStageIndex": 0,
		"bySurvivor": {},
		"entityKills": {},
		"entityEncounters": {},
		"entityLores": {},
		"itemPicks": {},
		"stageVisits": {},
		"stageClears": {},
		"recentRuns": [],
	}
