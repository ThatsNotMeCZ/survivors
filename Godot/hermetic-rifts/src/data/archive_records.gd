class_name ArchiveRecords
extends RefCounted

const PATH: String = "user://records.v1.json"
const VERSION: int = 1
const MAX_RECENT: int = 10
const STAGE_ORDER: PackedStringArray = [
	"cinder-yard",
	"rime-dock",
	"putrid-conservatory",
	"fulmination-foundry",
	"glacial-tomb",
	"aether-vault",
	"prima-materia-core",
]
const LEGACY_STAGE_ORDER: PackedStringArray = ["cinder-yard", "rime-dock", "glacial-tomb"]
const MAX_ASCENSION_TIER: int = 5

var data: Dictionary = {}


static func load_or_default() -> ArchiveRecords:
	var rec: ArchiveRecords = ArchiveRecords.new()
	rec.data = _empty()
	if not FileAccess.file_exists(PATH):
		return rec
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return rec
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		rec.data = parsed
		rec.data["version"] = VERSION
		var visits_dirty: bool = rec._backfill_chamber_visits()
		var defaults_dirty: bool = rec._backfill_defaults()
		if visits_dirty or defaults_dirty:
			rec.save()
	return rec


func save() -> void:
	var tmp: String = PATH + ".tmp"
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))


func essence_balance() -> int:
	return maxi(0, int(data.get("residualEssence", 0)))


func spend_essence(amount: int) -> bool:
	if amount < 0:
		return false
	var bal: int = essence_balance()
	if bal < amount:
		return false
	if amount > 0:
		data["residualEssence"] = bal - amount
		save()
	return true


func grant_essence(amount: int) -> void:
	if amount <= 0:
		return
	data["residualEssence"] = essence_balance() + amount
	data["totalEssenceEarned"] = maxi(0, int(data.get("totalEssenceEarned", 0))) + amount
	save()


func upgrade_level(upgrade_id: String) -> int:
	if upgrade_id == "":
		return 0
	return maxi(0, int(DictUtil.d(data, "crucibleUpgrades").get(upgrade_id, 0)))


func set_upgrade_level(upgrade_id: String, lvl: int) -> void:
	if upgrade_id == "":
		return
	var upgrades: Dictionary = DictUtil.d(data, "crucibleUpgrades")
	upgrades[upgrade_id] = maxi(0, lvl)
	data["crucibleUpgrades"] = upgrades
	save()


func loadout_for(survivor_id: String) -> Dictionary:
	var out: Dictionary = {
		"primary": "A",
		"secondary": "A",
		"utility": "A",
		"special": "A",
	}
	if survivor_id == "":
		return out
	var loadouts: Dictionary = DictUtil.d(data, "selectedLoadouts")
	var stored: Dictionary = DictUtil.d(loadouts, survivor_id)
	for slot: String in Catalog.SLOTS:
		var variant: String = String(stored.get(slot, "A"))
		out[slot] = "B" if variant == "B" else "A"
	return out


func set_slot_variant(survivor_id: String, slot: String, variant: String) -> void:
	if survivor_id == "" or not Catalog.SLOTS.has(slot):
		return
	var clean_variant: String = "B" if variant == "B" else "A"
	var loadouts: Dictionary = DictUtil.d(data, "selectedLoadouts")
	var cur: Dictionary = loadout_for(survivor_id)
	cur[slot] = clean_variant
	loadouts[survivor_id] = cur
	data["selectedLoadouts"] = loadouts
	save()


func is_alt_skill_unlocked(skill_id: String) -> bool:
	if skill_id == "":
		return false
	return bool(DictUtil.d(data, "unlockedAltSkills").get(skill_id, false))


func unlock_alt_skill(skill_id: String) -> void:
	if skill_id == "":
		return
	var unlocked: Dictionary = DictUtil.d(data, "unlockedAltSkills")
	if bool(unlocked.get(skill_id, false)):
		return
	unlocked[skill_id] = true
	data["unlockedAltSkills"] = unlocked
	save()


func max_ascension_unlocked() -> int:
	return clampi(upgrade_level("ascension-seals"), 0, MAX_ASCENSION_TIER)


func ascension_tier() -> int:
	return clampi(int(data.get("ascensionTier", 0)), 0, MAX_ASCENSION_TIER)


func set_ascension_tier(tier: int) -> void:
	data["ascensionTier"] = clampi(tier, 0, max_ascension_unlocked())
	save()


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
		"low-hp-boss-kills", "single-run-low-hp-boss-kills":
			var low_hp_kills: int = int(data.get("maxLowHpBossKillsInSingleRun", 0))
			return {
				"unlocked": low_hp_kills >= count,
				"progress": _format_count_progress("ui.archives.unlock.low_hp_boss_kills_n", "ui.archives.unlock.slain_n", low_hp_kills, count),
				"label": label,
			}
		"obelisk-clears":
			var obelisks: int = int(data.get("obeliskClears", 0))
			var prog_obelisk: String = _format_binary_or_count_progress("ui.archives.unlock.obelisks_n", "ui.archives.unlock.cleared", "ui.archives.unlock.cleared_none", obelisks, count)
			return {
				"unlocked": obelisks >= count,
				"progress": prog_obelisk,
				"label": label,
			}
		"true-endings":
			var endings: int = int(data.get("trueEndings", 0))
			var prog_ending: String = _format_binary_or_count_progress("ui.archives.unlock.true_endings_n", "ui.archives.unlock.cleared", "ui.archives.unlock.cleared_none", endings, count)
			return {
				"unlocked": endings >= count,
				"progress": prog_ending,
				"label": label,
			}
		"ascension-clear":
			var need_tier: int = maxi(1, int(unlock.get("tier", unlock.get("ascensionTier", count))))
			var max_asc: int = int(data.get("maxAscensionCleared", 0))
			var prog_asc: String = _format_count_progress("ui.archives.unlock.ascension_n", "", max_asc, need_tier)
			return {
				"unlocked": max_asc >= need_tier,
				"progress": prog_asc,
				"label": label,
			}
		_:
			return {"unlocked": true, "progress": tr("ui.archives.unlock.unlocked"), "label": label}


func finalize_run_essence(world: SimWorld, outcome: String = "") -> int:
	return _finalize_run_essence(world, outcome)


func _finalize_run_essence(world: SimWorld, outcome: String = "") -> int:
	if world == null:
		return 0
	var raw_collected: Variant = world.get("run_essence_collected")
	var collected: int = maxi(0, int(raw_collected)) if raw_collected != null else 0
	var xp_ratio: float = clampf(world.xp / maxf(world.xp_need, 1.0), 0.0, 1.0)
	var xp_bonus: int = int(floor(xp_ratio * 6.0))
	var coeff_bonus: int = int(floor(maxf(0.0, world.coefficient - 1.0) * 5.0))
	var attunement_lvl: int = upgrade_level("distillation-attunement")
	var base_total: float = float(collected + xp_bonus + coeff_bonus) * (1.0 + 0.05 * float(attunement_lvl))
	var raw_portal: Variant = world.get("exited_via_victory_portal")
	var exited_portal: bool = bool(raw_portal) if raw_portal != null else false
	var victory_portal: bool = outcome == "victory" or outcome == "true_victory" or exited_portal or world.won
	if victory_portal:
		base_total *= 1.25
	var raw_asc: Variant = world.get("ascension_tier")
	var asc_tier: int = maxi(0, int(raw_asc)) if raw_asc != null else 0
	base_total *= (1.0 + 0.15 * float(asc_tier))
	return maxi(0, int(floor(base_total)))


func record_item_pick(item_id: String) -> void:
	if item_id == "":
		return
	data["totalItemsCollected"] = int(data.get("totalItemsCollected", 0)) + 1
	var picks: Dictionary = DictUtil.d(data, "itemPicks")
	picks[item_id] = int(picks.get(item_id, 0)) + 1
	data["itemPicks"] = picks
	save()


func record_lore(entity_id: String) -> void:
	var lores: Dictionary = DictUtil.d(data, "entityLores")
	lores[entity_id] = 1
	data["entityLores"] = lores
	save()


func record_run_end(world: SimWorld, outcome: String) -> void:
	if world == null:
		return
	var is_victory: bool = outcome == "victory" or outcome == "true_victory"
	data["totalRuns"] = int(data.get("totalRuns", 0)) + 1
	if is_victory:
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
	var stages: Array = DictUtil.a(world.catalog.loop, "stages") if world.catalog != null else []
	if world.stage_index >= 0:
		var safe_stage_idx: int = mini(world.stage_index, stages.size() - 1) if not stages.is_empty() else world.stage_index
		data["furthestStageIndex"] = maxi(int(data.get("furthestStageIndex", 0)), safe_stage_idx)
	var low_hp_kills_v: Variant = world.get("low_hp_boss_kills")
	if low_hp_kills_v != null:
		data["maxLowHpBossKillsInSingleRun"] = maxi(
			int(data.get("maxLowHpBossKillsInSingleRun", 0)),
			maxi(0, int(low_hp_kills_v))
		)
	var obelisks_v: Variant = world.get("obelisks_completed")
	if obelisks_v != null:
		data["obeliskClears"] = maxi(0, int(data.get("obeliskClears", 0))) + maxi(0, int(obelisks_v))
	_record_survivor(world, outcome)
	var ek: Dictionary = DictUtil.d(data, "entityKills")
	for id: Variant in world.kills_by_entity.keys():
		ek[String(id)] = int(ek.get(String(id), 0)) + int(world.kills_by_entity[id])
	data["entityKills"] = ek
	var ee: Dictionary = DictUtil.d(data, "entityEncounters")
	for id: Variant in world.encounters_by_entity.keys():
		ee[String(id)] = int(ee.get(String(id), 0)) + int(world.encounters_by_entity[id])
	data["entityEncounters"] = ee
	var el: Dictionary = DictUtil.d(data, "entityLores")
	for id: Variant in world.collected_lores.keys():
		el[String(id)] = 1
	data["entityLores"] = el
	var visited_list: Array[String] = _extract_stage_id_list(world.get("visited_stage_ids"))
	var stage_info: Dictionary = _resolve_stage_info(world, stages, visited_list)
	var current_stage_id: String = String(stage_info.get("id", ""))
	var current_stage_name: String = String(stage_info.get("name", ""))
	var visits: Dictionary = DictUtil.d(data, "stageVisits")
	var seen_visits: Dictionary = {}
	if not visited_list.is_empty():
		for sid: String in visited_list:
			if sid == "" or seen_visits.has(sid):
				continue
			seen_visits[sid] = true
			visits[sid] = int(visits.get(sid, 0)) + 1
	elif not stages.is_empty() and world.stage_index >= 0:
		var last_visited: int = mini(world.stage_index, stages.size() - 1)
		for i: int in range(last_visited + 1):
			var sid: String = String((stages[i] as Dictionary).get("id", ""))
			if sid == "" or seen_visits.has(sid):
				continue
			seen_visits[sid] = true
			visits[sid] = int(visits.get(sid, 0)) + 1
	if current_stage_id != "" and visited_list.is_empty() and not seen_visits.has(current_stage_id):
		visits[current_stage_id] = int(visits.get(current_stage_id, 0)) + 1
	data["stageVisits"] = visits
	var clears: Dictionary = DictUtil.d(data, "stageClears")
	var cleared_list: Array[String] = _extract_stage_id_list(world.get("cleared_stage_ids"))
	var seen_clears: Dictionary = {}
	if not cleared_list.is_empty():
		for cid: String in cleared_list:
			if cid == "" or seen_clears.has(cid):
				continue
			seen_clears[cid] = true
			clears[cid] = int(clears.get(cid, 0)) + 1
	elif not visited_list.is_empty():
		var clear_limit: int = visited_list.size() if (world.won or is_victory) else mini(maxi(0, world.stages_cleared), visited_list.size())
		for i: int in range(clear_limit):
			var cid: String = visited_list[i]
			if cid == "" or seen_clears.has(cid):
				continue
			seen_clears[cid] = true
			clears[cid] = int(clears.get(cid, 0)) + 1
	elif not stages.is_empty():
		var cleared_n: int = mini(maxi(0, world.stages_cleared), stages.size())
		if world.won or is_victory:
			cleared_n = stages.size()
		for i: int in range(cleared_n):
			var cid: String = String((stages[i] as Dictionary).get("id", ""))
			if cid == "" or seen_clears.has(cid):
				continue
			seen_clears[cid] = true
			clears[cid] = int(clears.get(cid, 0)) + 1
	if (world.won or is_victory) and current_stage_id != "" and visited_list.is_empty() and cleared_list.is_empty() and not seen_clears.has(current_stage_id):
		clears[current_stage_id] = int(clears.get(current_stage_id, 0)) + 1
	data["stageClears"] = clears
	var raw_asc: Variant = world.get("ascension_tier")
	var asc_tier: int = maxi(0, int(raw_asc)) if raw_asc != null else 0
	if world.won or is_victory:
		data["maxAscensionCleared"] = maxi(int(data.get("maxAscensionCleared", 0)), asc_tier)
		var is_true_ending: bool = (
			outcome == "true_victory"
			or bool(_world_prop(world, "true_victory", false))
			or bool(_world_prop(world, "true_ending", false))
			or current_stage_id == "prima-materia-core"
		)
		if is_true_ending:
			data["trueEndings"] = maxi(0, int(data.get("trueEndings", 0))) + 1
		var fastest: Variant = data.get("fastestVictoryTime", null)
		if fastest == null or world.run_time < float(fastest):
			data["fastestVictoryTime"] = world.run_time
	var gained: int = _finalize_run_essence(world, outcome)
	data["residualEssence"] = essence_balance() + gained
	data["totalEssenceEarned"] = maxi(0, int(data.get("totalEssenceEarned", 0))) + gained
	data["lastRunEssence"] = gained
	_sync_unlocked_alt_skills(world)
	var recent: Array = DictUtil.a(data, "recentRuns")
	var items: Array = []
	for inst: ItemInstance in world.inventory:
		items.append({"id": inst.id, "stacks": inst.stacks})
	recent.push_front({
		"timestamp": Time.get_unix_time_from_system(),
		"outcome": outcome,
		"survivorId": String(world.survivor.get("id", "")),
		"stageId": current_stage_id,
		"stageName": current_stage_name,
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
		"lastRunEssence": gained,
		"ascensionTier": asc_tier,
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
	var by: Dictionary = DictUtil.d(data, "bySurvivor")
	var surv: Dictionary = DictUtil.d(by, survivor_id)
	if surv.is_empty():
		surv = _empty_survivor()
	surv["runs"] = int(surv.get("runs", 0)) + 1
	if outcome == "victory" or outcome == "true_victory":
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
	var count: int = int(unlock.get("count", 1))
	var key: String = "unlock.unlocked"
	match t:
		"stage-clear":
			var sid: String = String(unlock.get("stageId", ""))
			key = "unlock.stage-clear.%s.%d" % [sid, count] if count > 1 else "unlock.stage-clear.%s" % sid
		"boss-kill":
			var eid: String = String(unlock.get("entityId", ""))
			key = "unlock.boss-kill.%s.%d" % [eid, count] if count > 1 else "unlock.boss-kill.%s" % eid
		"total-kills":
			key = "unlock.total-kills.%d" % int(unlock.get("count", 0))
		"elite-kills":
			key = "unlock.elite-kills.%d" % int(unlock.get("count", 0))
		"victories":
			key = "unlock.victories.%d" % int(unlock.get("count", 0))
		"low-hp-boss-kills", "single-run-low-hp-boss-kills":
			key = "unlock.%s.%d" % [t, count]
		"obelisk-clears":
			key = "unlock.obelisk-clears.%d" % count
		"true-endings":
			key = "unlock.true-endings.%d" % count
		"ascension-clear":
			var need_tier: int = maxi(1, int(unlock.get("tier", unlock.get("ascensionTier", count))))
			key = "unlock.ascension-clear.%d" % need_tier
	var text: String = tr(key)
	if text == key:
		var json_label: String = String(unlock.get("label", ""))
		if t == "boss-kill" and count > 1:
			var base_boss_key: String = "unlock.boss-kill.%s" % String(unlock.get("entityId", ""))
			var base_boss_text: String = tr(base_boss_key)
			if json_label != "":
				text = json_label
			elif base_boss_text != base_boss_key:
				text = base_boss_text
		elif t == "stage-clear" and count > 1:
			var base_stage_key: String = "unlock.stage-clear.%s" % String(unlock.get("stageId", ""))
			var base_stage_text: String = tr(base_stage_key)
			if json_label != "":
				text = json_label
			elif base_stage_text != base_stage_key:
				text = base_stage_text
		elif t == "low-hp-boss-kills" or t == "single-run-low-hp-boss-kills":
			var alt_key: String = "unlock.low-hp-boss-kills.%d" % count
			var alt_text: String = tr(alt_key)
			if alt_text != alt_key:
				text = alt_text
			elif json_label != "":
				text = json_label
		elif json_label != "":
			text = json_label
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


func _format_count_progress(loc_key: String, fallback_key: String, have: int, need: int) -> String:
	var capped: int = mini(have, need)
	var tmpl: String = tr(loc_key)
	if tmpl != loc_key:
		return tmpl.replace("{have}", str(capped)).replace("{need}", str(need))
	if fallback_key != "":
		var fb: String = tr(fallback_key)
		if fb != fallback_key:
			return fb.replace("{have}", str(capped)).replace("{need}", str(need))
	return "%d / %d" % [capped, need]


func _format_binary_or_count_progress(loc_key: String, done_key: String, none_key: String, have: int, need: int) -> String:
	if need <= 1:
		return tr(done_key) if have >= 1 else tr(none_key)
	return _format_count_progress(loc_key, "", have, need)


func _sync_unlocked_alt_skills(world: SimWorld) -> void:
	var extra_v: Variant = world.get("unlocked_alt_skills")
	if typeof(extra_v) == TYPE_ARRAY or extra_v is PackedStringArray:
		var unlocked_map: Dictionary = DictUtil.d(data, "unlockedAltSkills")
		for sid_v: Variant in extra_v:
			var sid: String = String(sid_v)
			if sid != "":
				unlocked_map[sid] = true
		data["unlockedAltSkills"] = unlocked_map
	if world.catalog == null:
		return
	var skills_v: Variant = world.catalog.get("skills")
	if typeof(skills_v) != TYPE_ARRAY:
		return
	var unlocked_skills: Dictionary = DictUtil.d(data, "unlockedAltSkills")
	for skill_v: Variant in skills_v:
		if typeof(skill_v) != TYPE_DICTIONARY:
			continue
		var skill_def: Dictionary = skill_v
		var skill_id: String = String(skill_def.get("id", ""))
		var unlock_v: Variant = skill_def.get("unlock", null)
		if skill_id == "" or unlock_v == null or typeof(unlock_v) != TYPE_DICTIONARY:
			continue
		var unlock_type: String = String((unlock_v as Dictionary).get("type", ""))
		if unlock_type == "":
			continue
		if meets_unlock(unlock_v):
			unlocked_skills[skill_id] = true
	data["unlockedAltSkills"] = unlocked_skills


static func _world_prop(world: SimWorld, prop: StringName, default_val: Variant) -> Variant:
	var val: Variant = world.get(prop)
	if val == null:
		return default_val
	return val


static func _extract_stage_id_list(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) == TYPE_ARRAY or raw is PackedStringArray:
		for item: Variant in raw:
			var sid: String = String(item)
			if sid != "":
				out.append(sid)
	elif typeof(raw) == TYPE_DICTIONARY:
		var raw_dict: Dictionary = raw
		for key: Variant in raw_dict.keys():
			if bool(raw_dict[key]):
				var sid: String = String(key)
				if sid != "":
					out.append(sid)
	return out


static func _resolve_stage_info(world: SimWorld, stages: Array, visited_list: Array[String]) -> Dictionary:
	var sid: String = String(_world_prop(world, &"current_stage_id", ""))
	if sid == "":
		sid = String(_world_prop(world, &"stage_id", ""))
	var sname: String = ""
	if sid == "" and world.stage_index >= 0 and world.stage_index < stages.size():
		var st_obj: Variant = stages[world.stage_index]
		if typeof(st_obj) == TYPE_DICTIONARY:
			var st: Dictionary = st_obj
			sid = String(st.get("id", ""))
			sname = String(st.get("name", ""))
	if sid == "" and not visited_list.is_empty():
		sid = visited_list[visited_list.size() - 1]
	if sname == "" and sid != "" and world.catalog != null:
		for pool_key: String in ["stages", "branchStages", "specialStages"]:
			for st_v: Variant in DictUtil.a(world.catalog.loop, pool_key):
				if typeof(st_v) != TYPE_DICTIONARY:
					continue
				var st_row: Dictionary = st_v
				if String(st_row.get("id", "")) == sid:
					sname = String(st_row.get("name", ""))
					break
			if sname != "":
				break
	if sname == "" and sid != "":
		var loc_key: String = "stage.%s.name" % sid
		var loc_name: String = TranslationServer.translate(loc_key)
		sname = loc_name if loc_name != loc_key else sid
	return {"id": sid, "name": sname}


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


func _backfill_chamber_visits() -> bool:
	if data.has("residualEssence"):
		return false
	var visits: Dictionary = DictUtil.d(data, "stageVisits")
	var clears: Dictionary = DictUtil.d(data, "stageClears")
	if int(data.get("totalRuns", 0)) <= 0 and visits.is_empty() and clears.is_empty():
		return false
	var furthest: int = clampi(int(data.get("furthestStageIndex", 0)), 0, LEGACY_STAGE_ORDER.size() - 1)
	var last: int = furthest
	for i: int in LEGACY_STAGE_ORDER.size():
		var sid: String = LEGACY_STAGE_ORDER[i]
		if int(visits.get(sid, 0)) > 0 or int(clears.get(sid, 0)) > 0:
			last = maxi(last, i)
	var dirty: bool = false
	for i: int in range(last + 1):
		if i >= LEGACY_STAGE_ORDER.size():
			break
		var sid2: String = LEGACY_STAGE_ORDER[i]
		if int(visits.get(sid2, 0)) <= 0 and int(clears.get(sid2, 0)) <= 0:
			visits[sid2] = 1
			dirty = true
	if dirty:
		data["stageVisits"] = visits
	return dirty


func _backfill_defaults() -> bool:
	var defaults: Dictionary = _empty()
	var dirty: bool = false
	for k: Variant in defaults.keys():
		var key: String = String(k)
		var def_val: Variant = defaults[key]
		if not data.has(key) or (data[key] == null and def_val != null):
			data[key] = def_val
			dirty = true
		elif typeof(def_val) == TYPE_DICTIONARY and typeof(data[key]) != TYPE_DICTIONARY:
			data[key] = {}
			dirty = true
		elif typeof(def_val) == TYPE_ARRAY and typeof(data[key]) != TYPE_ARRAY:
			data[key] = []
			dirty = true
	for int_key: String in [
		"totalRuns",
		"victories",
		"defeats",
		"abandons",
		"totalKills",
		"fodderKills",
		"eliteKills",
		"bossKills",
		"totalGemsCollected",
		"totalItemsCollected",
		"totalLevelsGained",
		"stagesCleared",
		"highestLevel",
		"mostKillsInRun",
		"furthestStageIndex",
		"residualEssence",
		"totalEssenceEarned",
		"lastRunEssence",
		"ascensionTier",
		"maxAscensionCleared",
		"maxLowHpBossKillsInSingleRun",
		"obeliskClears",
		"trueEndings",
	]:
		if typeof(data.get(int_key, 0)) != TYPE_INT:
			data[int_key] = int(data.get(int_key, 0))
	data["ascensionTier"] = clampi(int(data.get("ascensionTier", 0)), 0, MAX_ASCENSION_TIER)
	data["maxAscensionCleared"] = clampi(int(data.get("maxAscensionCleared", 0)), 0, MAX_ASCENSION_TIER)
	data["residualEssence"] = maxi(0, int(data.get("residualEssence", 0)))
	data["totalEssenceEarned"] = maxi(0, int(data.get("totalEssenceEarned", 0)))
	data["lastRunEssence"] = maxi(0, int(data.get("lastRunEssence", 0)))
	data["maxLowHpBossKillsInSingleRun"] = maxi(0, int(data.get("maxLowHpBossKillsInSingleRun", 0)))
	data["obeliskClears"] = maxi(0, int(data.get("obeliskClears", 0)))
	data["trueEndings"] = maxi(0, int(data.get("trueEndings", 0)))
	var upgrades: Dictionary = DictUtil.d(data, "crucibleUpgrades")
	var clean_upgrades: Dictionary = {}
	for uid: Variant in upgrades.keys():
		var u_key: String = String(uid)
		if u_key != "":
			clean_upgrades[u_key] = maxi(0, int(upgrades[uid]))
	data["crucibleUpgrades"] = clean_upgrades
	var alt_skills: Dictionary = DictUtil.d(data, "unlockedAltSkills")
	var clean_alts: Dictionary = {}
	for skid: Variant in alt_skills.keys():
		var s_key: String = String(skid)
		if s_key != "":
			clean_alts[s_key] = bool(alt_skills[skid])
	data["unlockedAltSkills"] = clean_alts
	var loadouts: Dictionary = DictUtil.d(data, "selectedLoadouts")
	var clean_loadouts: Dictionary = {}
	for surv_id: Variant in loadouts.keys():
		var sid: String = String(surv_id)
		if sid == "":
			continue
		var raw_l: Dictionary = DictUtil.d(loadouts, sid)
		var norm_l: Dictionary = {}
		for slot: String in Catalog.SLOTS:
			norm_l[slot] = "B" if String(raw_l.get(slot, "A")) == "B" else "A"
		clean_loadouts[sid] = norm_l
	data["selectedLoadouts"] = clean_loadouts
	return dirty


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
		"residualEssence": 0,
		"totalEssenceEarned": 0,
		"lastRunEssence": 0,
		"crucibleUpgrades": {},
		"unlockedAltSkills": {},
		"selectedLoadouts": {},
		"ascensionTier": 0,
		"maxAscensionCleared": 0,
		"maxLowHpBossKillsInSingleRun": 0,
		"obeliskClears": 0,
		"trueEndings": 0,
		"bySurvivor": {},
		"entityKills": {},
		"entityEncounters": {},
		"entityLores": {},
		"itemPicks": {},
		"stageVisits": {},
		"stageClears": {},
		"recentRuns": [],
	}
