class_name SimLoop
extends RefCounted


static func current_stage(world: SimWorld) -> Dictionary:
	var stages: Array = DictUtil.a(world.catalog.loop, "stages")
	return stages[world.stage_index]


static func is_last_stage(world: SimWorld) -> bool:
	return world.stage_index >= DictUtil.a(world.catalog.loop, "stages").size() - 1


static func can_seal(world: SimWorld) -> bool:
	return world.portal_open and is_last_stage(world) and not world.won


static func current_objective(world: SimWorld) -> Dictionary:
	if world.portal_open:
		var need: float = float(world.catalog.loop.get("portalHold", 1.4))
		return {
			"kind": &"portal",
			"pct": clampf(world.portal_hold / maxf(need, 0.001), 0.0, 1.0) if need > 0.0 else 0.0,
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
	var stage: Dictionary = current_stage(world)
	var at: float = float(stage.get("teleporterAt", 55.0))
	return {
		"kind": &"wait",
		"pct": clampf(world.stage_time / maxf(at, 0.001), 0.0, 1.0) if at > 0.0 else 0.0,
		"target_x": 0.0,
		"target_y": 0.0,
		"has_target": false,
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
	world.won = true
	world.stages_cleared += 1
	if world.phase == &"play" or world.phase == &"levelup":
		world.phase = &"victory"
	return true


static func begin_stage(world: SimWorld, index: int) -> void:
	var stage: Dictionary = DictUtil.a(world.catalog.loop, "stages")[index]
	world.stage_index = index
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
	world.teleporter_hold = float(stage.get("teleporterHold", 20.0))
	world.teleporter_radius = float(stage.get("teleporterRadius", 160.0))
	world.portal_open = false
	world.portal_hold = 0.0
	world.portal_x = 0.0
	world.portal_y = 0.0
	SimEnemies.clear(world)
	world.gems.clear()
	world.lores.clear()
	world.projectiles.clear()
	world.obstacles.clear()
	world.player.x = float(world.catalog.world.get("width", 2560.0)) * 0.5
	world.player.y = float(world.catalog.world.get("height", 2560.0)) * 0.5
	world.player.hp = world.stats.max_hp
	world.player.dash_remain = 0.0
	world.player.iframe_remain = 0.0
	world.player.slow_remain = 0.0
	world.player.slow_mul = 1.0
	world.player.root_remain = 0.0
	world.decoy.reset()
	world.zones.clear()
	world.boss_hazards.clear()
	world.boss.reset()
	_reserve_teleporter(world)
	SimObstacles.place_stage(world)


static func step(world: SimWorld, dt: float) -> void:
	var diff: Dictionary = world.catalog.loop.get("difficulty", {})
	world.coefficient = 1.0 + world.run_time * float(diff.get("perSecond", 0.014)) + float(world.stage_index) * float(diff.get("stageBonus", 0.0))
	_step_teleporter(world, dt)
	_step_portal(world, dt)
	_update_focus(world)
	if world.player.hp <= 0.0 and not world.won:
		world.phase = &"defeat"


static func spawn_stage_boss(world: SimWorld) -> void:
	if world.boss_spawned:
		return
	var stage: Dictionary = current_stage(world)
	var def: Dictionary = world.catalog.entity(String(stage.get("boss", "")))
	var point: Vector2 = SimEnemies.ring_point(world, world.teleporter_x, world.teleporter_y, float(DictUtil.d(def, "stats").get("radius", 28.0)))
	var idx: int = SimEnemies.spawn(world, def, point.x, point.y)
	if idx < 0:
		return
	if String(DictUtil.d(def, "ai").get("type", "")) == "boss":
		SimBoss.init_state(world, idx, DictUtil.d(def, "ai"))
	world.boss_spawned = true


static func _step_teleporter(world: SimWorld, dt: float) -> void:
	var stage: Dictionary = current_stage(world)
	if world.teleporter_state == &"hidden" and world.stage_time >= float(stage.get("teleporterAt", 55.0)):
		world.teleporter_state = &"charging"
		world.teleporter_charge = 0.0
	if world.teleporter_state != &"charging":
		return
	var dist: float = sqrt((world.player.x - world.teleporter_x) ** 2.0 + (world.player.y - world.teleporter_y) ** 2.0)
	if dist <= world.teleporter_radius:
		world.teleporter_charge += dt
	if world.teleporter_charge >= world.teleporter_hold:
		world.teleporter_state = &"done"
		spawn_stage_boss(world)


static func _step_portal(world: SimWorld, dt: float) -> void:
	if (world.boss_defeated or (world.boss_spawned and world.counts_boss == 0)) and not world.portal_open and not world.won:
		world.portal_open = true
		world.portal_hold = 0.0
		if world.portal_x == 0.0 and world.portal_y == 0.0:
			world.portal_x = world.teleporter_x
			world.portal_y = world.teleporter_y
	if not world.portal_open:
		return
	var radius: float = float(world.catalog.loop.get("portalRadius", 70.0))
	var hold: float = float(world.catalog.loop.get("portalHold", 1.4))
	var dist: float = sqrt((world.player.x - world.portal_x) ** 2.0 + (world.player.y - world.portal_y) ** 2.0)
	if dist <= radius:
		world.portal_hold += dt
		if world.portal_hold >= hold:
			world.stages_cleared += 1
			if is_last_stage(world):
				collect_pending_lores(world)
				world.cycle_index += 1
				begin_stage(world, 0)
			else:
				begin_stage(world, world.stage_index + 1)
	else:
		world.portal_hold = 0.0


static func _reserve_teleporter(world: SimWorld) -> void:
	var stage: Dictionary = current_stage(world)
	var rng := SimRng.new(
		world.run_seed
		^ SimRng.hash_string(String(stage.get("id", "")))
		^ ((world.stage_index + 3) * 0x9E3779B9)
		^ (world.stage_gen * 0x27D4EB2D)
	)
	var bounds: Dictionary = world.catalog.world
	var pad: float = float(stage.get("teleporterRadius", 160.0)) + 48.0
	var ox: float = world.player.x
	var oy: float = world.player.y
	var width: float = float(bounds.get("width", 2560.0))
	var height: float = float(bounds.get("height", 2560.0))
	for _a: int in 24:
		var dist: float = 480.0 + rng.next() * 320.0
		var ang: float = rng.next() * TAU
		var x: float = clampf(ox + cos(ang) * dist, pad, width - pad)
		var y: float = clampf(oy + sin(ang) * dist, pad, height - pad)
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
