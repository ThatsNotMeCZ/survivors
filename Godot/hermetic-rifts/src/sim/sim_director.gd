class_name SimDirector
extends RefCounted


static func elite_chance(world: SimWorld) -> float:
	var dir: Dictionary = DictUtil.d(world.catalog.loop, "director")
	var coeff: float = SimLoop.difficulty_coeff(world)
	var chance: float = float(dir.get("eliteChanceBase", 0.02)) + maxf(0.0, coeff - 1.0) * float(dir.get("eliteChancePerCoeff", 0.12))
	return clampf(chance, 0.0, float(dir.get("eliteChanceMax", 0.40)))


static func current_fodder_cap(world: SimWorld) -> int:
	var dir: Dictionary = DictUtil.d(world.catalog.loop, "director")
	var coeff: float = SimLoop.difficulty_coeff(world)
	return mini(
		int(dir.get("maxFodderCap", 42)),
		roundi(float(dir.get("maxFodderBase", 18)) + float(dir.get("maxFodderPerCoeff", 7.0)) * maxf(0.0, coeff - 1.0)),
	)


static func current_elite_cap(world: SimWorld) -> int:
	var dir: Dictionary = DictUtil.d(world.catalog.loop, "director")
	var coeff: float = SimLoop.difficulty_coeff(world)
	var pre_activation: bool = world.teleporter_state == &"hidden" or world.teleporter_state == &"ready"
	var max_cap: int = int(dir.get("maxElitesCap", 12))
	var base_cap: int = int(dir.get("preActivationEliteCap", 1)) if pre_activation else mini(
		max_cap,
		roundi(float(dir.get("maxElitesBase", 4)) + float(dir.get("maxElitesPerCoeff", 2.0)) * maxf(0.0, coeff - 1.0)),
	)
	if world.teleporter_state == &"charging" and world.ritual_tier >= 1:
		base_cap = mini(max_cap, roundi(float(base_cap) * 1.5))
	return base_cap


static func current_specialist_cap(world: SimWorld) -> int:
	var dir: Dictionary = DictUtil.d(world.catalog.loop, "director")
	var coeff: float = SimLoop.difficulty_coeff(world)
	return mini(
		int(dir.get("maxSpecialistsCap", 9)),
		roundi(float(dir.get("maxSpecialistsBase", 2)) + float(dir.get("maxSpecialistsPerCoeff", 2.0)) * maxf(0.0, coeff - 1.0)),
	)


static func step(world: SimWorld, dt: float) -> void:
	if world.boss_spawned or world.boss_defeated:
		return
	var loop: Dictionary = world.catalog.loop
	var dir: Dictionary = DictUtil.d(loop, "director")
	var coeff: float = SimLoop.difficulty_coeff(world)
	world.credits += float(dir.get("creditRate", 3.0)) * coeff * dt
	_try_fodder(world)
	_try_sniper(world)
	var stage: Dictionary = SimLoop.current_stage(world)
	if world.stage_time >= float(stage.get("firstEliteAt", 0.0)):
		_try_warden(world)


static func _try_fodder(world: SimWorld) -> void:
	var dir: Dictionary = DictUtil.d(world.catalog.loop, "director")
	if world.stage_time - world.last_fodder_at < float(dir.get("fodderInterval", 1.6)):
		return
	var f_cap: int = current_fodder_cap(world)
	if world.counts_fodder >= f_cap:
		return
	var stage: Dictionary = SimLoop.current_stage(world)
	var coeff: float = SimLoop.difficulty_coeff(world)
	var s_cap: int = current_specialist_cap(world)
	var active_spec: int = SimEnemies.count_specialists(world)
	var allow_spec: bool = active_spec < s_cap
	var def: Dictionary = _pick_weighted_fodder(world, coeff, stage, allow_spec)
	if def.is_empty():
		var fallback_id: String = String(stage.get("fodder", ""))
		if fallback_id == "":
			return
		def = world.catalog.entity(fallback_id)
	var hard_cap: int = -1
	if SimEnemies.is_specialist_def(def):
		hard_cap = maxi(0, s_cap - active_spec)
		if String(DictUtil.d(def, "ai").get("type", "")) == "sniper":
			hard_cap = mini(hard_cap, maxi(0, int(dir.get("maxSnipers", 3)) - SimEnemies.count_snipers(world)))
	if _try_group(world, def, float(dir.get("fodderCost", 6.0)), hard_cap):
		world.last_fodder_at = world.stage_time


static func _try_sniper(world: SimWorld) -> void:
	var dir: Dictionary = DictUtil.d(world.catalog.loop, "director")
	var stage: Dictionary = SimLoop.current_stage(world)
	var sniper_id: String = String(stage.get("sniper", ""))
	if sniper_id == "":
		return
	var s_cap: int = current_specialist_cap(world)
	var active_spec: int = SimEnemies.count_specialists(world)
	if active_spec >= s_cap:
		return
	var active: int = SimEnemies.count_snipers(world)
	var max_snipers: int = int(dir.get("maxSnipers", 3))
	if active >= max_snipers:
		return
	if world.stage_time - world.last_sniper_at < float(dir.get("sniperInterval", 7.5)):
		return
	var sniper_def: Dictionary = world.catalog.entity(sniper_id)
	var coeff: float = SimLoop.difficulty_coeff(world)
	if float(sniper_def.get("minCoeff", 1.0)) > coeff:
		return
	var hard_cap: int = mini(max_snipers - active, s_cap - active_spec)
	if _try_group(world, sniper_def, float(dir.get("sniperCost", 18.0)), hard_cap):
		world.last_sniper_at = world.stage_time


static func _try_warden(world: SimWorld) -> void:
	var dir: Dictionary = DictUtil.d(world.catalog.loop, "director")
	if world.stage_time - world.last_elite_at < float(dir.get("eliteInterval", 14.0)):
		return
	var stage: Dictionary = SimLoop.current_stage(world)
	var elite_id: String = String(stage.get("elite", ""))
	if elite_id == "":
		return
	var def: Dictionary = world.catalog.entity(elite_id)
	var coeff: float = SimLoop.difficulty_coeff(world)
	if float(def.get("minCoeff", 1.0)) > coeff:
		return
	var hard_cap: int = -1
	if SimEnemies.is_specialist_def(def):
		hard_cap = maxi(0, current_specialist_cap(world) - SimEnemies.count_specialists(world))
	var fodder_cost: float = float(dir.get("fodderCost", 6.0))
	if _try_group(world, def, fodder_cost, hard_cap):
		world.last_elite_at = world.stage_time


static func _pick_weighted_fodder(
	world: SimWorld,
	coeff: float,
	stage: Dictionary,
	allow_spec: bool,
) -> Dictionary:
	var dir: Dictionary = DictUtil.d(world.catalog.loop, "director")
	var max_snipers: int = int(dir.get("maxSnipers", 3))
	var active_snipers: int = SimEnemies.count_snipers(world)
	var native_fodder: String = String(stage.get("fodder", ""))
	var native_ranged: String = String(stage.get("ranged", ""))
	var native_elite: String = String(stage.get("elite", ""))
	var candidates: Array[Dictionary] = []
	var weights: PackedFloat32Array = PackedFloat32Array()
	var total_weight: float = 0.0
	for def: Dictionary in world.catalog.entities:
		if String(def.get("role", "")) != "fodder":
			continue
		var base_w: float = float(def.get("poolWeight", 0.0))
		if base_w <= 0.0:
			continue
		var id: String = String(def.get("id", ""))
		if id != native_fodder and float(def.get("minCoeff", 1.0)) > coeff:
			continue
		var is_spec: bool = SimEnemies.is_specialist_def(def)
		if is_spec and not allow_spec:
			continue
		if String(DictUtil.d(def, "ai").get("type", "")) == "sniper" and active_snipers >= max_snipers:
			continue
		var w: float = base_w
		if id == native_fodder or id == native_ranged or id == native_elite:
			w *= 2.5
		candidates.append(def)
		weights.append(w)
		total_weight += w
	if candidates.is_empty() or total_weight <= 0.0:
		return {}
	var roll: float = world.randf() * total_weight
	for k: int in candidates.size():
		roll -= weights[k]
		if roll <= 0.0:
			return candidates[k]
	return candidates[candidates.size() - 1]


static func _try_group(world: SimWorld, def: Dictionary, base_cost: float, hard_cap: int = -1) -> bool:
	if def.is_empty():
		return false
	var loop: Dictionary = world.catalog.loop
	var stage: Dictionary = SimLoop.current_stage(world)
	var dir: Dictionary = DictUtil.d(loop, "director")
	var is_spec: bool = SimEnemies.is_specialist_def(def)
	var spec_rem: int = maxi(0, current_specialist_cap(world) - SimEnemies.count_specialists(world)) if is_spec else 999
	var elite_cap: int = current_elite_cap(world)
	var elite_cost: float = maxf(float(dir.get("eliteCost", 18.0)), base_cost * float(dir.get("eliteCostMul", 3.0)))
	var can_elite: bool = world.stage_time >= float(stage.get("firstEliteAt", 0.0)) and world.counts_elite < elite_cap and world.credits >= elite_cost and (not is_spec or spec_rem > 0)
	var roll_elite: bool = can_elite and world.randf() < elite_chance(world)
	if roll_elite:
		var remaining: int = elite_cap - world.counts_elite
		var target: int = world.randi_range(int(dir.get("eliteGroupSizeMin", 1)), int(dir.get("eliteGroupSizeMax", 1)))
		target = mini(target, remaining)
		if is_spec:
			target = mini(target, spec_rem)
		target = mini(target, int(floor(world.credits / maxf(1.0, elite_cost))))
		if target <= 0:
			return false
		var spawned: int = SimEnemies.spawn_group_around(world, def, target, true)
		if spawned <= 0:
			return false
		world.credits -= float(spawned) * elite_cost
		return true
	if is_spec and spec_rem <= 0:
		return false
	var fodder_cap: int = current_fodder_cap(world)
	if world.counts_fodder >= fodder_cap:
		return false
	if world.credits < base_cost:
		return false
	var remaining_f: int = fodder_cap - world.counts_fodder
	var target_n: int = world.randi_range(int(dir.get("groupSizeMin", 3)), int(dir.get("groupSizeMax", 6)))
	if hard_cap >= 0:
		target_n = mini(target_n, hard_cap)
	if is_spec:
		target_n = mini(target_n, spec_rem)
	target_n = mini(target_n, remaining_f)
	target_n = mini(target_n, int(floor(world.credits / maxf(1.0, base_cost))))
	if target_n <= 0:
		return false
	var spawned_n: int = SimEnemies.spawn_group_around(world, def, target_n, false)
	if spawned_n <= 0:
		return false
	world.credits -= float(spawned_n) * base_cost
	return true
