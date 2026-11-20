class_name SimLoop
extends RefCounted


static func current_stage(world: SimWorld) -> Dictionary:
	if world.stage_id != "" and world.catalog.has_stage(world.stage_id):
		return world.catalog.stage(world.stage_id)
	var stages: Array = DictUtil.a(world.catalog.loop, "stages")
	if stages.is_empty():
		return {}
	return stages[clampi(world.stage_index, 0, stages.size() - 1)]


static func is_last_stage(world: SimWorld) -> bool:
	if world.stage_id == "glacial-tomb" or world.stage_id == "prima-materia-core":
		return true
	if world.stage_id == "putrid-conservatory" or world.stage_id == "aether-vault":
		return false
	if world.stage_id != "":
		return false
	var stages: Array = DictUtil.a(world.catalog.loop, "stages")
	return not stages.is_empty() and world.stage_index >= stages.size() - 1


static func difficulty_coeff(world: SimWorld) -> float:
	var diff: Dictionary = DictUtil.d(world.catalog.loop, "difficulty")
	return (
		1.0
		+ world.run_time * float(diff.get("perSecond", 0.0022))
		+ float(world.stage_index) * float(diff.get("stageBonus", 0.22))
		+ float(world.ascension_tier) * 0.12
	)


static func can_seal(world: SimWorld) -> bool:
	return world.portal_open and is_last_stage(world) and not world.won


static func current_objective(world: SimWorld) -> Dictionary:
	if world.portal_open:
		return {
			"kind": &"portal",
			"pct": 1.0 if world.portal_hold > 0.0 else 0.0,
			"target_x": world.portal_x,
			"target_y": world.portal_y,
			"has_target": true,
			"name": "",
		}
	if world.boss_spawned and world.counts_boss > 0:
		for i: int in world.enemies.cap:
			if world.enemies.alive[i] == 0 or world.enemies.role[i] != EnemyPool.ROLE_BOSS:
				continue
			var max_hp: float = world.enemies.max_hp[i] if world.enemies.max_hp[i] > 0.0 else 1.0
			return {
				"kind": &"boss",
				"pct": clampf(world.enemies.hp[i] / max_hp, 0.0, 1.0),
				"target_x": world.enemies.x[i],
				"target_y": world.enemies.y[i],
				"has_target": true,
				"name": world.enemies.def_id[i],
			}
	if world.teleporter_state == &"charging":
		return {
			"kind": &"hold",
			"pct": clampf(world.teleporter_charge / maxf(world.teleporter_hold, 0.001), 0.0, 1.0),
			"target_x": world.teleporter_x,
			"target_y": world.teleporter_y,
			"has_target": true,
			"name": "",
		}
	var tel_cfg: Dictionary = DictUtil.d(world.catalog.loop, "teleporter")
	var show_target: bool = world.teleporter_discovered or bool(tel_cfg.get("showChevronBeforeDiscovery", false))
	if world.teleporter_state == &"ready":
		return {
			"kind": &"wait",
			"pct": 1.0,
			"target_x": world.teleporter_x if show_target else 0.0,
			"target_y": world.teleporter_y if show_target else 0.0,
			"has_target": show_target,
			"name": "",
		}
	var stage: Dictionary = current_stage(world)
	var at: float = float(stage.get("teleporterAt", 55.0))
	return {
		"kind": &"wait",
		"pct": clampf(world.stage_time / maxf(at, 0.001), 0.0, 1.0) if at > 0.0 else 0.0,
		"target_x": world.teleporter_x if show_target else 0.0,
		"target_y": world.teleporter_y if show_target else 0.0,
		"has_target": show_target,
		"name": "",
	}


static func collect_pending_lores(world: SimWorld) -> void:
	for i: int in world.lores.cap:
		if world.lores.alive[i] == 0:
			continue
		var entity_id: String = world.lores.entity_id[i]
		world.lores.alive[i] = 0
		world.lores.entity_id[i] = ""
		if entity_id != "" and not world.collected_lores.has(entity_id):
			world.collected_lores[entity_id] = true
			world.newly_collected_lores.append(entity_id)


static func complete_working(world: SimWorld) -> bool:
	if world.won:
		return false
	collect_pending_lores(world)
	_record_stage_clear(world, String(current_stage(world).get("id", world.stage_id)))
	world.won = true
	world.stages_cleared += 1
	if world.phase == &"play" or world.phase == &"levelup":
		world.phase = &"victory"
	return true


static func begin_stage(world: SimWorld, index: int) -> void:
	var stages: Array = DictUtil.a(world.catalog.loop, "stages")
	if stages.is_empty():
		return
	var safe_idx: int = clampi(index, 0, stages.size() - 1)
	var stage: Dictionary = stages[safe_idx]
	begin_stage_by_id(world, String(stage.get("id", "")), safe_idx)


static func begin_stage_by_id(world: SimWorld, target_id: String, next_stage_index: int = -1) -> void:
	var stages: Array = DictUtil.a(world.catalog.loop, "stages")
	var resolved_idx: int = next_stage_index
	if resolved_idx < 0:
		var found_idx: int = _main_stage_index(stages, target_id)
		if found_idx >= 0:
			resolved_idx = found_idx
		elif target_id == "putrid-conservatory":
			resolved_idx = 1
		else:
			resolved_idx = world.stage_index
	var stage: Dictionary = {}
	if target_id != "" and world.catalog.has_stage(target_id):
		stage = world.catalog.stage(target_id)
	elif not stages.is_empty():
		stage = stages[clampi(resolved_idx, 0, stages.size() - 1)]
	var resolved_id: String = String(stage.get("id", target_id))
	world.stage_index = resolved_idx
	world.stage_id = resolved_id
	world.stage_time = 0.0
	world.stage_gen += 1
	world.boss_spawned = false
	world.boss_defeated = false
	world.last_fodder_at = -99.0
	world.last_elite_at = -99.0
	world.last_sniper_at = -99.0
	world.credits = 0.0
	world.teleporter_state = &"hidden"
	world.teleporter_charge = 0.0
	world.teleporter_hold = float(stage.get("teleporterHold", 50.0))
	world.teleporter_radius = float(stage.get("teleporterRadius", 160.0))
	world.teleporter_discovered = false
	world.teleporter_flawless_hold = true
	world.ritual_tier = 0
	world.portal_open = false
	world.portal_hold = 0.0
	world.portal_x = 0.0
	world.portal_y = 0.0
	world.portals.clear()
	world.stage_obelisks_total = 0
	world.stage_obelisks_completed = 0
	world.stage_rng = SimRng.new(
		world.run_seed
		^ SimRng.hash_string(resolved_id)
		^ ((world.stage_index + 3) * 0x9E3779B9)
		^ (world.stage_gen * 0x27D4EB2D)
	)
	world.coefficient = difficulty_coeff(world)
	SimEnemies.clear(world)
	world.gems.clear()
	world.lores.clear()
	world.projectiles.clear()
	world.obstacles.clear()
	if world.arena_shape == "circle":
		world.player.x = 0.0
		world.player.y = 0.0
	else:
		world.player.x = float(world.catalog.world.get("width", 6000.0)) * 0.5
		world.player.y = float(world.catalog.world.get("height", 6000.0)) * 0.5
	world.player.hp = world.stats.max_hp
	world.player.reset_stage_states()
	world.decoy.reset()
	world.zones.clear()
	world.boss_hazards.clear()
	world.boss.reset()
	_reserve_teleporter(world)
	SimObstacles.place_stage(world)
	var tel_cfg: Dictionary = DictUtil.d(world.catalog.loop, "teleporter")
	if bool(tel_cfg.get("spawnFromStart", true)) and float(stage.get("teleporterAt", 0.0)) <= 0.0:
		world.teleporter_state = &"ready"
	_record_stage_visit(world, resolved_id)


static func effective_teleporter_radius(world: SimWorld) -> float:
	return world.teleporter_radius * (0.78 if world.ascension_tier >= 5 else 1.0)


static func activate_teleporter(world: SimWorld) -> bool:
	if world.teleporter_state != &"ready":
		return false
	world.teleporter_state = &"charging"
	world.teleporter_charge = 0.0
	world.teleporter_discovered = true
	world.teleporter_flawless_hold = true
	world.ritual_tier = 0
	return true


static func step(world: SimWorld, dt: float) -> void:
	world.coefficient = difficulty_coeff(world)
	_step_teleporter(world, dt)
	_step_portal(world, dt)
	_update_focus(world)
	if world.player.hp <= 0.0 and not world.won:
		if not world.dying:
			world.dying = true
			world.death_linger_remain = float(world.catalog.loop.get("deathLinger", 2.0))
		world.death_linger_remain -= dt
		if world.death_linger_remain <= 0.0:
			world.phase = &"defeat"


static func spawn_stage_boss(world: SimWorld) -> void:
	if world.boss_spawned:
		return
	var stage: Dictionary = current_stage(world)
	var boss_id: String = String(stage.get("boss", ""))
	if boss_id == "":
		return
	var def: Dictionary = world.catalog.entity(boss_id)
	var boss_r: float = float(DictUtil.d(def, "stats").get("radius", 28.0))
	var point: Vector2 = Vector2(world.teleporter_x, world.teleporter_y)
	if world.arena_shape == "circle":
		var max_r: float = maxf(0.0, world.arena_radius - boss_r - 16.0)
		point = SimCollision.clamp_to_circle(point.x, point.y, max_r)
	var idx: int = SimEnemies.spawn(world, def, point.x, point.y)
	if idx < 0:
		return
	if String(DictUtil.d(def, "ai").get("type", "")) == "boss":
		SimBoss.init_state(world, idx, DictUtil.d(def, "ai"))
	world.boss.emerge_remain = BossState.EMERGE_DURATION
	world.boss_spawned = true
	world.fx.emit(FxIds.BOSS_EMERGE, point.x, point.y, SimBoss.boss_tint(boss_id), boss_r * 2.5)


static func open_stage_portals(world: SimWorld) -> void:
	world.portals.clear()
	var main_stages: Array = DictUtil.a(world.catalog.loop, "stages")
	var portal_r: float = float(world.catalog.loop.get("portalRadius", 70.0))
	var ax: float = world.teleporter_x
	var ay: float = world.teleporter_y
	if ax == 0.0 and ay == 0.0 and (world.portal_x != 0.0 or world.portal_y != 0.0):
		ax = world.portal_x
		ay = world.portal_y
	if world.stage_id == "aether-vault":
		SimLevel.grant_specific_item(world, "philosophers-catalyst")
	if world.demo_mode and (
		world.stage_id == "rime-dock"
		or world.stage_id == "putrid-conservatory"
		or (world.stage_id == "aether-vault" and world.return_stage_index >= 2)
	):
		world.portals.append(_make_portal(world, "demo-seal", ax, ay, portal_r, "", -1))
	elif world.stage_id == "prima-materia-core":
		world.portals.append(_make_portal(world, "true-ending", ax, ay, portal_r, "", -1))
	elif world.stage_id == "glacial-tomb":
		world.portals.append(_make_portal(world, "silver", ax - 85.0, ay, portal_r, "", -1))
		world.portals.append(_make_portal(world, "gold", ax + 85.0, ay, portal_r, "cinder-yard", 0))
		if _owns_true_ending_relics(world):
			world.portals.append(_make_portal(world, "crimson", ax, ay - 95.0, portal_r, "prima-materia-core", 4))
	elif world.stage_id == "cinder-yard":
		var go_branch: bool = false
		if world.stage_obelisks_total > 0 and world.stage_obelisks_completed >= world.stage_obelisks_total:
			go_branch = true
		else:
			if world.stage_rng == null:
				world.stage_rng = SimRng.new(world.run_seed ^ SimRng.hash_string(world.stage_id))
			var branch_chance: float = float(current_stage(world).get("branchChance", 0.25))
			go_branch = world.stage_rng.next() < branch_chance
		if go_branch:
			world.portals.append(_make_portal(world, "branch", ax, ay, portal_r, "putrid-conservatory", 1))
		else:
			world.portals.append(_make_portal(world, "next", ax, ay, portal_r, "rime-dock", 1))
		if world.teleporter_flawless_hold and not world.demo_mode:
			world.return_stage_index = 1
			world.portals.append(_make_portal(world, "secret", ax, ay + 100.0, portal_r, "aether-vault", world.stage_index))
	elif world.stage_id == "aether-vault":
		var max_main: int = maxi(0, main_stages.size() - 1)
		var ret_idx: int = clampi(world.return_stage_index, 0, max_main)
		var ret_id: String = String((main_stages[ret_idx] as Dictionary).get("id", "rime-dock")) if not main_stages.is_empty() else "rime-dock"
		world.portals.append(_make_portal(world, "next", ax, ay, portal_r, ret_id, ret_idx))
	else:
		var next_idx: int = world.stage_index + 1
		var next_id: String = ""
		if next_idx >= 0 and next_idx < main_stages.size():
			next_id = String((main_stages[next_idx] as Dictionary).get("id", ""))
		else:
			next_idx = clampi(next_idx, 0, maxi(0, main_stages.size() - 1))
			if not main_stages.is_empty():
				next_id = String((main_stages[next_idx] as Dictionary).get("id", ""))
		world.portals.append(_make_portal(world, "next", ax, ay, portal_r, next_id, next_idx))
		if world.teleporter_flawless_hold and world.stage_index >= 0 and world.stage_index <= 2:
			world.return_stage_index = next_idx
			world.portals.append(_make_portal(world, "secret", ax, ay + 100.0, portal_r, "aether-vault", world.stage_index))
	if not world.portals.is_empty():
		var primary: Dictionary = world.portals[0]
		world.portal_open = true
		world.portal_hold = 0.0
		world.portal_x = float(primary.get("x", ax))
		world.portal_y = float(primary.get("y", ay))


static func _step_teleporter(world: SimWorld, dt: float) -> void:
	var stage: Dictionary = current_stage(world)
	var tel_cfg: Dictionary = DictUtil.d(world.catalog.loop, "teleporter")
	if world.teleporter_state == &"hidden" and world.stage_time >= float(stage.get("teleporterAt", 55.0)):
		world.teleporter_state = &"ready"
	var dist: float = sqrt((world.player.x - world.teleporter_x) ** 2.0 + (world.player.y - world.teleporter_y) ** 2.0)
	if world.teleporter_state == &"ready":
		var disc_r: float = float(tel_cfg.get("discoveryRadius", 340.0))
		if dist <= disc_r or dist <= world.teleporter_radius:
			world.teleporter_discovered = true
		if dist <= world.teleporter_radius and (world.interact_pressed or world.interact_held):
			activate_teleporter(world)
		return
	if world.teleporter_state != &"charging":
		return
	var eff_r: float = effective_teleporter_radius(world)
	if dist <= eff_r:
		world.teleporter_charge += dt
	else:
		world.teleporter_flawless_hold = false
		world.teleporter_charge = maxf(0.0, world.teleporter_charge - 0.5 * dt)
	var hold: float = maxf(world.teleporter_hold, 0.001)
	var pct: float = world.teleporter_charge / hold
	var tiers: Array = DictUtil.a(tel_cfg, "ritualTiers")
	var t1: float = float(tiers[0]) if tiers.size() > 0 else 0.33
	var t2: float = float(tiers[1]) if tiers.size() > 1 else 0.66
	if pct >= t1 and world.ritual_tier < 1:
		world.ritual_tier = 1
		world.fx.emit(FxIds.RITUAL_TIER_1, world.teleporter_x, world.teleporter_y, 0xE5C878, eff_r)
		world.credits += 35.0 * world.coefficient
	if pct >= t2 and world.ritual_tier < 2:
		world.ritual_tier = 2
		world.fx.emit(FxIds.RITUAL_TIER_2, world.teleporter_x, world.teleporter_y, 0xFFB347, eff_r)
		world.credits += 55.0 * world.coefficient
		var elite_cap: int = int(world.catalog.loop.get("maxElites", 12))
		if world.counts_elite < elite_cap:
			var elite_id: String = String(stage.get("elite", ""))
			if elite_id != "" and world.catalog.has_entity(elite_id):
				SimEnemies.spawn_group_around(world, world.catalog.entity(elite_id), 1, true)
	if world.teleporter_charge >= world.teleporter_hold and world.ritual_tier < 3:
		world.ritual_tier = 3
		var pad: float = float(tel_cfg.get("ruptureKnockbackPad", 72.0))
		var imp: float = float(tel_cfg.get("ruptureKnockbackImpulse", 720.0))
		var kb_r: float = eff_r + pad
		world.fx.emit(FxIds.RITUAL_RUPTURE, world.teleporter_x, world.teleporter_y, 0xFFF0B8, kb_r)
		world.hit_stop_remain = maxf(world.hit_stop_remain, float(tel_cfg.get("ruptureHitstop", 0.14)))
		SimEnemies.knockback_radial(world, world.teleporter_x, world.teleporter_y, kb_r, imp, 0.35, kb_r)
		world.teleporter_state = &"done"
		spawn_stage_boss(world)


static func _step_portal(world: SimWorld, dt: float) -> void:
	if (world.boss_defeated or (world.boss_spawned and world.counts_boss == 0)) and world.portals.is_empty() and not world.won:
		open_stage_portals(world)
	if not world.portal_open or world.portals.is_empty():
		return
	var in_any: bool = false
	for i: int in world.portals.size():
		var portal: Dictionary = world.portals[i]
		var px: float = float(portal.get("x", 0.0))
		var py: float = float(portal.get("y", 0.0))
		var pr: float = float(portal.get("radius", float(world.catalog.loop.get("portalRadius", 70.0))))
		var dist: float = sqrt((world.player.x - px) ** 2.0 + (world.player.y - py) ** 2.0)
		portal["hold"] = 0.0
		if dist <= pr:
			in_any = true
			if world.interact_pressed and world.player.hp > 0.0:
				_activate_portal(world, portal)
				return
	world.portal_hold = 1.0 if in_any else 0.0


static func _activate_portal(world: SimWorld, portal: Dictionary) -> void:
	var kind: String = String(portal.get("kind", "next"))
	var bonus_mul: float = float(DictUtil.d(world.catalog.loop, "essenceEconomy").get("victoryPortalBonusMul", 1.25))
	if kind == "demo-seal":
		collect_pending_lores(world)
		world.demo_completed = true
		complete_working(world)
		return
	if kind == "true-ending":
		collect_pending_lores(world)
		world.run_essence = roundi(float(world.run_essence) * bonus_mul)
		_set_world_flag(world, &"exited_via_victory_portal", true)
		_set_world_flag(world, &"true_victory", true)
		complete_working(world)
		return
	if kind == "silver":
		collect_pending_lores(world)
		world.run_essence = roundi(float(world.run_essence) * bonus_mul)
		_set_world_flag(world, &"exited_via_victory_portal", true)
		complete_working(world)
		return
	_record_stage_clear(world, String(current_stage(world).get("id", world.stage_id)))
	world.stages_cleared += 1
	collect_pending_lores(world)
	if kind == "gold":
		world.cycle_index += 1
		begin_stage_by_id(world, "cinder-yard", 0)
		return
	var target_id: String = String(portal.get("target_stage_id", ""))
	var target_idx: int = int(portal.get("target_stage_index", world.stage_index + 1))
	if target_id != "":
		begin_stage_by_id(world, target_id, target_idx)
	else:
		begin_stage(world, target_idx)


static func _make_portal(
	world: SimWorld,
	kind: String,
	px: float,
	py: float,
	radius: float,
	target_stage_id: String,
	target_stage_index: int,
) -> Dictionary:
	var pos: Vector2 = _clamp_portal_pos(world, px, py, radius)
	return {
		"kind": kind,
		"x": pos.x,
		"y": pos.y,
		"radius": radius,
		"hold": 0.0,
		"target_stage_id": target_stage_id,
		"target_stage_index": target_stage_index,
	}


static func _clamp_portal_pos(world: SimWorld, px: float, py: float, radius: float) -> Vector2:
	var bounds: Dictionary = world.catalog.world
	if world.arena_shape == "circle":
		var arena_r: float = world.arena_radius
		var max_r: float = maxf(0.0, arena_r - radius - 16.0)
		return SimCollision.clamp_to_circle(px, py, max_r)
	var pad: float = radius + 16.0
	var width: float = float(bounds.get("width", 6000.0))
	var height: float = float(bounds.get("height", 6000.0))
	return Vector2(clampf(px, pad, width - pad), clampf(py, pad, height - pad))


static func _owns_true_ending_relics(world: SimWorld) -> bool:
	var has_catalyst: bool = false
	var has_lunar: bool = false
	for inst: ItemInstance in world.inventory:
		if inst.id == "philosophers-catalyst":
			has_catalyst = true
		if inst.id.begins_with("lun"):
			has_lunar = true
		elif world.catalog.has_item(inst.id) and String(world.catalog.item(inst.id).get("rarity", "")) == "lunar":
			has_lunar = true
	return has_catalyst and has_lunar


static func _main_stage_index(stages: Array, stage_id: String) -> int:
	if stage_id == "":
		return -1
	for i: int in stages.size():
		if typeof(stages[i]) == TYPE_DICTIONARY and String((stages[i] as Dictionary).get("id", "")) == stage_id:
			return i
	return -1


static func _record_stage_visit(world: SimWorld, sid: String) -> void:
	if sid == "":
		return
	var visited_v: Variant = world.get(&"visited_stage_ids")
	if typeof(visited_v) == TYPE_ARRAY:
		var arr: Array = visited_v
		if not arr.has(sid):
			arr.append(sid)


static func _record_stage_clear(world: SimWorld, sid: String) -> void:
	if sid == "":
		return
	var cleared_v: Variant = world.get(&"cleared_stage_ids")
	if typeof(cleared_v) == TYPE_ARRAY:
		var arr: Array = cleared_v
		if not arr.has(sid):
			arr.append(sid)


static func _set_world_flag(world: SimWorld, prop: StringName, val: Variant) -> void:
	if world.get(prop) != null:
		world.set(prop, val)


static func _reserve_teleporter(world: SimWorld) -> void:
	var stage: Dictionary = current_stage(world)
	var tel_cfg: Dictionary = DictUtil.d(world.catalog.loop, "teleporter")
	var bounds: Dictionary = world.catalog.world
	if world.stage_rng == null:
		world.stage_rng = SimRng.new(
			world.run_seed
			^ SimRng.hash_string(String(stage.get("id", "")))
			^ ((world.stage_index + 3) * 0x9E3779B9)
			^ (world.stage_gen * 0x27D4EB2D)
		)
	var pad: float = float(stage.get("teleporterRadius", 160.0)) + 48.0
	if world.arena_shape == "circle":
		var arena_r: float = world.arena_radius
		var min_d: float = float(tel_cfg.get("minDistFromCenter", 1200.0))
		var max_d: float = minf(float(tel_cfg.get("maxDistFromCenter", 2400.0)), maxf(min_d, arena_r - pad))
		var dist: float = min_d + world.stage_rng.next() * maxf(0.0, max_d - min_d)
		var ang: float = world.stage_rng.next() * TAU
		world.teleporter_x = cos(ang) * dist
		world.teleporter_y = sin(ang) * dist
		return
	var ox: float = world.player.x
	var oy: float = world.player.y
	var width: float = float(bounds.get("width", 6000.0))
	var height: float = float(bounds.get("height", 6000.0))
	for _a: int in 24:
		var dist_r: float = 480.0 + world.stage_rng.next() * 320.0
		var ang_r: float = world.stage_rng.next() * TAU
		var x: float = clampf(ox + cos(ang_r) * dist_r, pad, width - pad)
		var y: float = clampf(oy + sin(ang_r) * dist_r, pad, height - pad)
		if sqrt((x - ox) * (x - ox) + (y - oy) * (y - oy)) >= 360.0:
			world.teleporter_x = x
			world.teleporter_y = y
			return
	world.teleporter_x = clampf(ox + 520.0, pad, width - pad)
	world.teleporter_y = clampf(oy, pad, height - pad)


static func _update_focus(world: SimWorld) -> void:
	world.focus_kind = &"none"
	world.focus_hp = 0.0
	world.focus_max_hp = 0.0
	world.focus_id = ""
	var elite: int = -1
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0:
			continue
		if world.enemies.role[i] == EnemyPool.ROLE_BOSS:
			world.focus_kind = &"boss"
			world.focus_hp = world.enemies.hp[i]
			world.focus_max_hp = world.enemies.max_hp[i]
			world.focus_id = world.enemies.def_id[i]
			return
		if elite < 0 and world.enemies.role[i] == EnemyPool.ROLE_ELITE:
			elite = i
	if elite >= 0:
		world.focus_kind = &"elite"
		world.focus_hp = world.enemies.hp[elite]
		world.focus_max_hp = world.enemies.max_hp[elite]
		world.focus_id = world.enemies.def_id[elite]
