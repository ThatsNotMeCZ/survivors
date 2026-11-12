class_name SimDirector
extends RefCounted


static func elite_chance(world: SimWorld) -> float:
	var dir: Dictionary = DictUtil.d(world.catalog.loop, "director")
	var chance: float = float(dir.get("eliteChanceBase", 0.08)) + maxf(0.0, world.coefficient - 1.0) * float(dir.get("eliteChancePerCoeff", 0.045))
	return clampf(chance, 0.0, float(dir.get("eliteChanceMax", 0.22)))


static func step(world: SimWorld, dt: float) -> void:
	if world.boss_spawned or world.boss_defeated:
		return
	var loop: Dictionary = world.catalog.loop
	var dir: Dictionary = DictUtil.d(loop, "director")
	world.credits += float(dir.get("creditRate", 9.0)) * world.coefficient * dt
	_try_fodder(world)
	_try_sniper(world)
	var stage: Dictionary = SimLoop.current_stage(world)
	if world.stage_time >= float(stage.get("firstEliteAt", 0.0)):
		_try_warden(world)


static func _try_fodder(world: SimWorld) -> void:
	var loop: Dictionary = world.catalog.loop
	var dir: Dictionary = DictUtil.d(loop, "director")
	var stage: Dictionary = SimLoop.current_stage(world)
	if world.stage_time - world.last_fodder_at < float(dir.get("fodderInterval", 1.35)):
		return
	var ranged_id: String = String(stage.get("ranged", ""))
	var use_ranged: bool = ranged_id != "" and world.randf() < float(stage.get("rangedChance", 0.0))
	var id: String = ranged_id if use_ranged else String(stage.get("fodder", ""))
	if _try_group(world, world.catalog.entity(id), float(dir.get("fodderCost", 6.0))):
		world.last_fodder_at = world.stage_time


static func _try_sniper(world: SimWorld) -> void:
	var loop: Dictionary = world.catalog.loop
	var dir: Dictionary = DictUtil.d(loop, "director")
	var stage: Dictionary = SimLoop.current_stage(world)
	var sniper_id: String = String(stage.get("sniper", ""))
	if sniper_id == "":
		return
	var active: int = SimEnemies.count_snipers(world)
	if active >= int(dir.get("maxSnipers", 3)):
		return
	if world.stage_time - world.last_sniper_at < float(dir.get("sniperInterval", 7.5)):
		return
	if _try_group(world, world.catalog.entity(sniper_id), float(dir.get("sniperCost", 18.0)), int(dir.get("maxSnipers", 3)) - active):
		world.last_sniper_at = world.stage_time


static func _try_warden(world: SimWorld) -> void:
	var loop: Dictionary = world.catalog.loop
	var dir: Dictionary = DictUtil.d(loop, "director")
	var stage: Dictionary = SimLoop.current_stage(world)
	if world.stage_time - world.last_elite_at < float(dir.get("eliteInterval", 11.0)):
		return
	if _try_group(world, world.catalog.entity(String(stage.get("elite", ""))), float(dir.get("eliteCost", 28.0))):
		world.last_elite_at = world.stage_time


static func _try_group(world: SimWorld, def: Dictionary, base_cost: float, hard_cap: int = -1) -> bool:
	var loop: Dictionary = world.catalog.loop
	var stage: Dictionary = SimLoop.current_stage(world)
	var dir: Dictionary = DictUtil.d(loop, "director")
	var elite_cap: int = 1 if world.teleporter_state == &"hidden" else int(loop.get("maxElites", 6))
	var elite_cost: float = base_cost * float(dir.get("eliteCostMul", 3.0))
	var can_elite: bool = world.stage_time >= float(stage.get("firstEliteAt", 0.0)) and world.counts_elite < elite_cap and world.credits >= elite_cost
	var roll_elite: bool = can_elite and world.randf() < elite_chance(world)
	if roll_elite:
		var remaining: int = elite_cap - world.counts_elite
		var target: int = world.randi_range(int(dir.get("eliteGroupSizeMin", 1)), int(dir.get("eliteGroupSizeMax", 1)))
		if hard_cap >= 0:
			target = mini(target, hard_cap)
		target = mini(target, remaining)
		target = mini(target, int(floor(world.credits / elite_cost)))
		if target <= 0:
			return false
		var spawned: int = SimEnemies.spawn_group_around(world, def, target, true)
		if spawned <= 0:
			return false
		world.credits -= float(spawned) * elite_cost
		return true
	if world.counts_fodder >= int(loop.get("maxFodder", 24)):
		return false
	if world.credits < base_cost:
		return false
	var remaining_f: int = int(loop.get("maxFodder", 24)) - world.counts_fodder
	var target_n: int = world.randi_range(int(dir.get("groupSizeMin", 3)), int(dir.get("groupSizeMax", 6)))
	if hard_cap >= 0:
		target_n = mini(target_n, hard_cap)
	target_n = mini(target_n, remaining_f)
	target_n = mini(target_n, int(floor(world.credits / base_cost)))
	if target_n <= 0:
		return false
	var spawned_n: int = SimEnemies.spawn_group_around(world, def, target_n, false)
	if spawned_n <= 0:
		return false
	world.credits -= float(spawned_n) * base_cost
	return true
