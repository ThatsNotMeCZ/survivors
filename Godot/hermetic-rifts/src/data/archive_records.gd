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
	return bool(check_unlock(unlock_v, null).get("unlocked", true))


func is_entity_seen(entity_id: String) -> bool:
	return int(DictUtil.d(data, "entityEncounters").get(entity_id, 0)) > 0 or int(DictUtil.d(data, "entityKills").get(entity_id, 0)) > 0


func is_stage_visited(stage_id: String) -> bool:
	return int(DictUtil.d(data, "stageVisits").get(stage_id, 0)) > 0 or int(DictUtil.d(data, "stageClears").get(stage_id, 0)) > 0


func is_item_bound(item_id: String) -> bool:
	return int(DictUtil.d(data, "itemPicks").get(item_id, 0)) > 0


func has_lore(entity_id: String) -> bool:
	return int(DictUtil.d(data, "entityLores").get(entity_id, 0)) > 0


func survivor_record(survivor_id: String) -> Dictionary:
	var by: Dictionary = DictUtil.d(data, "bySurvivor")
	var rec: Dictionary = DictUtil.d(by, survivor_id)
	if rec.is_empty():
		return _empty_survivor()
	return rec


func check_unlock(unlock_v: Variant, catalog: Catalog) -> Dictionary:
	if unlock_v == null or typeof(unlock_v) != TYPE_DICTIONARY:
		return {"unlocked": true, "progress": tr("ui.archives.unlock.unlocked"), "label": tr("ui.archives.unlock.unlocked")}
	var unlock: Dictionary = unlock_v
	var t: String = String(unlock.get("type", ""))
	var count: int = int(unlock.get("count", 1))
	var label: String = _unlock_label(unlock, catalog)
	match t:
		"stage-clear":
			var stage_id: String = String(unlock.get("stageId", ""))
			var have: int = int(DictUtil.d(data, "stageClears").get(stage_id, 0))
			var stage_name: String = Loc.unseen()
			if catalog != null and is_stage_visited(stage_id):
				stage_name = Loc.stage_name(stage_id)
			var progress: String = tr("ui.archives.unlock.cleared") if have >= 1 else tr("ui.archives.unlock.cleared_none")
			if count > 1:
				progress = tr("ui.archives.unlock.clears_n").replace("{have}", str(mini(have, count))).replace("{need}", str(count)).replace("{stage}", stage_name)
			return {"unlocked": have >= count, "progress": progress, "label": label}
		"boss-kill":
			var entity_id: String = String(unlock.get("entityId", ""))
			var slain: int = int(DictUtil.d(data, "entityKills").get(entity_id, 0))
			var progress_boss: String = tr("ui.archives.unlock.slain") if slain >= 1 else tr("ui.archives.unlock.slain_none")
			if count > 1:
				progress_boss = tr("ui.archives.unlock.slain_n").replace("{have}", str(mini(slain, count))).replace("{need}", str(count))
			return {"unlocked": slain >= count, "progress": progress_boss, "label": label}
		"total-kills":
			var kills: int = int(data.get("totalKills", 0))
			return {
				"unlocked": kills >= count,
				"progress": tr("ui.archives.unlock.slain_n").replace("{have}", str(mini(kills, count))).replace("{need}", str(count)),
				"label": label,
			}
		"elite-kills":
			var elites: int = int(data.get("eliteKills", 0))
			return {
				"unlocked": elites >= count,
				"progress": tr("ui.archives.unlock.elites_n").replace("{have}", str(mini(elites, count))).replace("{need}", str(count)),
				"label": label,
			}
		"victories":
			var wins: int = int(data.get("victories", 0))
			return {
				"unlocked": wins >= count,
				"progress": tr("ui.archives.unlock.wins_n").replace("{have}", str(mini(wins, count))).replace("{need}", str(count)),
				"label": label,
			}
		_:
			return {"unlocked": true, "progress": tr("ui.archives.unlock.unlocked"), "label": label}


func record_item_pick(item_id: String) -> void:
	if item_id == "":
		return
	data["totalItemsCollected"] = int(data.get("totalItemsCollected", 0)) + 1
	var picks: Dictionary = data.get("itemPicks", {})
	picks[item_id] = int(picks.get(item_id, 0)) + 1
	data["itemPicks"] = picks
	save()


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
	data["totalLevelsGained"] = int(data.get("totalLevelsGained", 0)) + maxi(0, world.level - 1)
	data["stagesCleared"] = int(data.get("stagesCleared", 0)) + world.stages_cleared
	data["longestRunTime"] = maxf(float(data.get("longestRunTime", 0.0)), world.run_time)
	data["highestLevel"] = maxi(int(data.get("highestLevel", 1)), world.level)
	data["highestCoefficient"] = maxf(float(data.get("highestCoefficient", 1.0)), world.coefficient)
	data["mostKillsInRun"] = maxi(int(data.get("mostKillsInRun", 0)), world.kills_total)
	data["mostDamageInRun"] = maxf(float(data.get("mostDamageInRun", 0.0)), world.damage_dealt)
	data["furthestStageIndex"] = maxi(int(data.get("furthestStageIndex", 0)), world.stage_index)
	_record_survivor(world, outcome)
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


func _record_survivor(world: SimWorld, outcome: String) -> void:
	var survivor_id: String = String(world.survivor.get("id", ""))
	if survivor_id == "":
		return
	var by: Dictionary = data.get("bySurvivor", {})
	var surv: Dictionary = DictUtil.d(by, survivor_id)
	if surv.is_empty():
		surv = _empty_survivor()
	surv["runs"] = int(surv.get("runs", 0)) + 1
	if outcome == "victory":
		surv["victories"] = int(surv.get("victories", 0)) + 1
		var fastest: Variant = surv.get("fastestVictory", null)
		if fastest == null or world.run_time < float(fastest):
			surv["fastestVictory"] = world.run_time
	elif outcome == "defeat":
		surv["defeats"] = int(surv.get("defeats", 0)) + 1
	elif outcome == "abandon":
		surv["abandons"] = int(surv.get("abandons", 0)) + 1
	surv["kills"] = int(surv.get("kills", 0)) + world.kills_total
	surv["bossesDefeated"] = int(surv.get("bossesDefeated", 0)) + world.bosses_defeated
	surv["totalPlayTime"] = float(surv.get("totalPlayTime", 0.0)) + world.run_time
	surv["totalDamageDealt"] = float(surv.get("totalDamageDealt", 0.0)) + world.damage_dealt
	surv["bestTime"] = maxf(float(surv.get("bestTime", 0.0)), world.run_time)
	surv["highestLevel"] = maxi(int(surv.get("highestLevel", 1)), world.level)
	by[survivor_id] = surv
	data["bySurvivor"] = by


func _unlock_label(unlock: Dictionary, catalog: Catalog) -> String:
	var t: String = String(unlock.get("type", ""))
	var key: String = "unlock.unlocked"
	match t:
		"stage-clear":
			key = "unlock.stage-clear.%s" % String(unlock.get("stageId", ""))
		"boss-kill":
			key = "unlock.boss-kill.%s" % String(unlock.get("entityId", ""))
		"total-kills":
			key = "unlock.total-kills.%d" % int(unlock.get("count", 0))
		"elite-kills":
			key = "unlock.elite-kills.%d" % int(unlock.get("count", 0))
		"victories":
			key = "unlock.victories.%d" % int(unlock.get("count", 0))
	var text: String = tr(key)
	if catalog == null:
		return text
	if t == "stage-clear":
		var stage_id: String = String(unlock.get("stageId", ""))
		if not is_stage_visited(stage_id):
			text = text.replace(Loc.stage_name(stage_id), Loc.unseen())
	elif t == "boss-kill":
		var entity_id: String = String(unlock.get("entityId", ""))
		if not is_entity_seen(entity_id):
			text = text.replace(Loc.entity_name(entity_id), Loc.unseen())
		var stage_id2: String = String(unlock.get("stageId", ""))
		if stage_id2 == "":
			for stage_v: Variant in DictUtil.a(catalog.loop, "stages"):
				var st: Dictionary = stage_v
				if String(st.get("boss", "")) == entity_id:
					stage_id2 = String(st.get("id", ""))
					break
		if stage_id2 != "" and not is_stage_visited(stage_id2):
			text = text.replace(Loc.stage_name(stage_id2), Loc.unseen())
	return text


static func _empty_survivor() -> Dictionary:
	return {
		"runs": 0,
		"victories": 0,
		"defeats": 0,
		"abandons": 0,
		"kills": 0,
		"bossesDefeated": 0,
		"bestTime": 0.0,
		"fastestVictory": null,
		"highestLevel": 1,
		"totalPlayTime": 0.0,
		"totalDamageDealt": 0.0,
	}


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
