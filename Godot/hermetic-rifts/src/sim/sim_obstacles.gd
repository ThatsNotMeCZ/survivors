class_name SimObstacles
extends RefCounted

const GEODE_CRACK_DURATION: float = 1.5
const BURN_TRAIL_REFRESH: float = 0.5


static func is_solid(type: StringName) -> bool:
	return (
		type == &"pillar"
		or type == &"volatile"
		or type == &"conduit"
		or type == &"obelisk"
		or type == &"geode"
	)


static func player_phasing(world: SimWorld) -> bool:
	return world.player.dash_remain > 0.0 or world.player.iframe_remain > 0.0


static func player_speed_mul(world: SimWorld) -> float:
	var mul: float = world.player.slow_mul
	if not player_phasing(world) and overlapping_hazard(world, world.player.x, world.player.y, world.player.radius):
		var raw: float = float(DictUtil.d(world.catalog.obstacles, "hazard").get("playerSpeedMul", 0.65))
		mul *= 1.0 - (1.0 - raw) * (1.0 - world.stats.hazard_resist)
	return mul


static func place_stage(world: SimWorld) -> void:
	var cfg: Dictionary = world.catalog.obstacles
	world.obstacles.clear()
	world.stage_obelisks_total = 0
	world.stage_obelisks_completed = 0
	world.obelisk_armor_debuff = 0.0
	var stage: Dictionary = SimLoop.current_stage(world)
	var names: Dictionary = DictUtil.d(DictUtil.d(cfg, "biomes"), String(stage.get("id", "")))
	var rng := SimRng.new(
		world.run_seed
		^ SimRng.hash_string(String(stage.get("id", "")))
		^ ((world.stage_index + 1) * 0x9E3779B9)
		^ (world.stage_gen * 0x85EBCA6B)
	)
	var counts: Dictionary = cfg.get("counts", {})
	var order: Array[StringName] = []
	for _p: int in int(counts.get("pillar", 0)):
		order.append(&"pillar")
	for _h: int in int(counts.get("hazard", 0)):
		order.append(&"hazard")
	for _v: int in int(counts.get("volatile", 0)):
		order.append(&"volatile")
	var placed: Array[Vector2] = []
	for type: StringName in order:
		var point: Vector2 = _try_place(world, type, rng, placed)
		if point.x == INF:
			continue
		if spawn(world, type, point.x, point.y, String(names.get(String(type), ""))) >= 0:
			placed.append(point)
	var vent_cfg: Dictionary = DictUtil.d(cfg, "alchemicalVent")
	var vent_count: int = int(vent_cfg.get("count", 4))
	var vent_cycle: float = float(vent_cfg.get("cycleInterval", 9.0))
	for _vc: int in vent_count:
		var v_pt: Vector2 = _try_place(world, &"vent", rng, placed)
		if v_pt.x == INF:
			continue
		var init_cycle: float = rng.next() * vent_cycle
		if spawn(world, &"vent", v_pt.x, v_pt.y, "Alchemical Vent", 0.0, "", init_cycle) >= 0:
			placed.append(v_pt)
	var conduit_cfg: Dictionary = DictUtil.d(cfg, "resonanceConduit")
	var conduit_count: int = int(conduit_cfg.get("count", 3))
	for _cc: int in conduit_count:
		var c_pt: Vector2 = _try_place(world, &"conduit", rng, placed)
		if c_pt.x == INF:
			continue
		if spawn(world, &"conduit", c_pt.x, c_pt.y, "Resonance Conduit") >= 0:
			placed.append(c_pt)
	var ob_cfg: Dictionary = DictUtil.d(cfg, "siphonObelisk")
	var ob_range: Dictionary = DictUtil.d(ob_cfg, "countPerStage")
	var ob_min: int = int(ob_range.get("min", 1))
	var ob_max: int = maxi(ob_min, int(ob_range.get("max", 2)))
	var ob_count: int = mini(ob_max, ob_min + int(floor(rng.next() * float(ob_max - ob_min + 1))))
	var variants: Array[String] = []
	for v_item: Variant in DictUtil.a(ob_cfg, "variants"):
		variants.append(String(v_item))
	if variants.is_empty():
		variants = ["obelisk-essence", "obelisk-reliquary", "obelisk-blood"]
	for k: int in range(variants.size() - 1, 0, -1):
		var swap_idx: int = mini(k, int(floor(rng.next() * float(k + 1))))
		var tmp: String = variants[k]
		variants[k] = variants[swap_idx]
		variants[swap_idx] = tmp
	for oi: int in mini(ob_count, variants.size()):
		var o_pt: Vector2 = _try_place(world, &"obelisk", rng, placed)
		if o_pt.x == INF:
			continue
		var sub_kind: String = variants[oi]
		if spawn(world, &"obelisk", o_pt.x, o_pt.y, _obelisk_label(sub_kind), 0.0, sub_kind) >= 0:
			placed.append(o_pt)
			world.stage_obelisks_total += 1
	var geode_cfg: Dictionary = DictUtil.d(world.catalog.loop, "mercuryGeode")
	var geode_chance: float = float(geode_cfg.get("spawnChancePerStage", 0.30))
	if rng.next() < geode_chance:
		var g_pt: Vector2 = _try_place(world, &"geode", rng, placed)
		if g_pt.x != INF:
			if spawn(world, &"geode", g_pt.x, g_pt.y, "Mercury Geode") >= 0:
				placed.append(g_pt)
	rebuild_hash(world)


static func spawn(
	world: SimWorld,
	type: StringName,
	x: float,
	y: float,
	biome: String,
	timer: float = 0.0,
	sub_kind: String = "",
	cycle_timer: float = 0.0,
) -> int:
	var obstacles: ObstaclePool = world.obstacles
	var cfg: Dictionary = world.catalog.obstacles
	var target: int = -1
	if type == &"hazard" and timer > 0.0:
		var max_dyn: int = int(cfg.get("dynamicHazards", 8))
		if obstacles.count_dynamic_hazards() >= max_dyn:
			target = _oldest_dynamic_hazard(obstacles)
	if target < 0:
		for i: int in obstacles.cap:
			if obstacles.alive[i] == 0:
				target = i
				break
	if target < 0 and type == &"hazard" and timer > 0.0:
		target = _oldest_dynamic_hazard(obstacles)
	if target < 0 and type == &"burn_trail":
		target = _oldest_burn_trail(obstacles)
	if target < 0:
		return -1
	var radius: float = _radius_for(world, type)
	var hp: float = 0.0
	if type == &"volatile":
		hp = float(DictUtil.d(cfg, "volatile").get("hp", 25.0)) * world.coefficient
	elif type == &"geode":
		hp = float(DictUtil.d(world.catalog.loop, "mercuryGeode").get("baseHp", 60.0)) * world.coefficient
	var init_state: StringName = &"intact"
	if type == &"vent" or type == &"conduit" or type == &"obelisk":
		init_state = &"idle"
	var item: SimObstacle = obstacles.items[target]
	item.reset()
	item.id = obstacles.next_id
	obstacles.next_id += 1
	item.type = type
	item.x = x
	item.y = y
	item.radius = radius
	item.hp = hp
	item.max_hp = hp
	item.state = init_state
	item.timer = timer
	item.biome_variant = biome
	item.sub_kind = sub_kind
	item.cycle_timer = cycle_timer
	item.collapse_timer = -1.0
	obstacles.alive[target] = 1
	return target


static func spawn_acid_pool(world: SimWorld, x: float, y: float) -> void:
	var duration: float = float(DictUtil.d(world.catalog.loop, "noxious").get("poolDuration", 6.0))
	spawn(world, &"hazard", x, y, "Caustic Acid Pool", duration)
	rebuild_hash(world)


static func spawn_burn_trail(world: SimWorld, px: float, py: float, dur: float = 2.2, rad: float = 22.0) -> void:
	var idx: int = spawn(world, &"burn_trail", px, py, "Burn Trail", dur, "burn")
	if idx >= 0:
		world.obstacles.items[idx].radius = rad
		rebuild_hash(world)


static func overlapping_hazard(world: SimWorld, x: float, y: float, radius: float) -> bool:
	var hazard_r: float = float(DictUtil.d(world.catalog.obstacles, "hazard").get("radius", 68.0))
	var n: int = world.obstacles.grid.query(x, y, radius + hazard_r)
	for k: int in n:
		var idx: int = world.obstacles.grid.hits[k]
		if world.obstacles.alive[idx] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[idx]
		if obs.type != &"hazard" or obs.sub_kind == "frozen":
			continue
		if SimCollision.circles_overlap(x, y, radius, obs.x, obs.y, obs.radius):
			return true
	return false


static func resolve_bodies(world: SimWorld) -> void:
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		if not is_solid(obs.type):
			continue
		if SimCollision.circles_overlap(world.player.x, world.player.y, world.player.radius, obs.x, obs.y, obs.radius):
			var split: Vector4 = SimCollision.push_circles(world.player.x, world.player.y, world.player.radius, obs.x, obs.y, obs.radius, 1.0, 0.0)
			world.player.x = split.x
			world.player.y = split.y
		for e: int in world.enemies.cap:
			if world.enemies.alive[e] == 0:
				continue
			if SimCollision.circles_overlap(world.enemies.x[e], world.enemies.y[e], world.enemies.radius[e], obs.x, obs.y, obs.radius):
				var es: Vector4 = SimCollision.push_circles(world.enemies.x[e], world.enemies.y[e], world.enemies.radius[e], obs.x, obs.y, obs.radius, 1.0, 0.0)
				world.enemies.x[e] = es.x
				world.enemies.y[e] = es.y


static func hit_projectiles(world: SimWorld) -> void:
	_prune_conduit_hits(world)
	var proj_count: int = world.projectiles.alive.size()
	for i: int in proj_count:
		if world.projectiles.alive[i] == 0:
			continue
		var p_flags: int = int(world.projectiles.flags[i])
		if (p_flags & ProjectilePool.FLAG_FLYOVER) != 0:
			continue
		var px: float = world.projectiles.x[i]
		var py: float = world.projectiles.y[i]
		var pr: float = world.projectiles.radius[i]
		var p_team: int = int(world.projectiles.team[i])
		var is_primary: bool = (p_flags & ProjectilePool.FLAG_PRIMARY) != 0
		var is_sec_spec: bool = (p_flags & ProjectilePool.FLAG_SECONDARY_OR_SPECIAL) != 0
		var is_pierce: bool = (p_flags & (ProjectilePool.FLAG_PIERCE | ProjectilePool.FLAG_TETHER)) != 0
		var elem: String = world.projectiles.element[i] if i < world.projectiles.element.size() else ""
		var n: int = world.obstacles.grid.query(px, py, pr + 76.0)
		var blocker: int = -1
		var blocker_dist: float = INF
		var candidates: Array[int] = []
		var cand_dists: Array[float] = []
		for k: int in n:
			var idx: int = world.obstacles.grid.hits[k]
			if world.obstacles.alive[idx] == 0:
				continue
			var obs: SimObstacle = world.obstacles.items[idx]
			if not SimCollision.aabb_overlap(px, py, pr, obs.x, obs.y, obs.radius):
				continue
			if not SimCollision.circles_overlap(px, py, pr, obs.x, obs.y, obs.radius):
				continue
			var dist_sq: float = (obs.x - px) * (obs.x - px) + (obs.y - py) * (obs.y - py)
			candidates.append(idx)
			cand_dists.append(dist_sq)
			if _blocks_projectile(obs, p_team, is_primary, is_pierce) and dist_sq < blocker_dist:
				blocker_dist = dist_sq
				blocker = idx
		for c: int in candidates.size():
			var idx: int = candidates[c]
			if blocker >= 0 and cand_dists[c] > blocker_dist:
				continue
			var obs: SimObstacle = world.obstacles.items[idx]
			if obs.type == &"conduit" and obs.state != &"depleted":
				if p_team == ProjectilePool.TEAM_PLAYER and is_sec_spec and not is_primary:
					if not obs.hit_proj_ids.has(i):
						obs.hit_proj_ids.append(i)
						world.fx.emit(FxIds.HIT, px, py, 0x88EEFF)
						charge_conduit(world, idx, 2)
			elif obs.type == &"hazard" and obs.reaction_cooldown <= 0.0 and obs.sub_kind != "frozen":
				if p_team == ProjectilePool.TEAM_PLAYER and is_sec_spec and not is_primary and elem != "":
					SimAlchemy.trigger_surface_reaction(world, px, py, pr, true, elem)
		if blocker < 0:
			continue
		var hit_obs: SimObstacle = world.obstacles.items[blocker]
		world.fx.emit(FxIds.HIT, px, py, 0xFFF4C8)
		var dmg: float = world.projectiles.damage[i] if world.projectiles.damage[i] > 0.0 else world.projectiles.tether_dps[i]
		if hit_obs.type == &"volatile":
			if p_team == ProjectilePool.TEAM_PLAYER and dmg > 0.0:
				damage_volatile(world, blocker, dmg)
		elif hit_obs.type == &"geode":
			if p_team == ProjectilePool.TEAM_PLAYER and dmg > 0.0:
				damage_geode(world, blocker, dmg)
		elif hit_obs.type == &"conduit":
			if p_team == ProjectilePool.TEAM_ENEMY:
				charge_conduit(world, blocker, 1)
		world.projectiles.kill_at(i)


static func damage_volatile(world: SimWorld, index: int, damage: float) -> bool:
	var obs: SimObstacle = world.obstacles.items[index]
	if obs.type != &"volatile" or obs.state != &"intact":
		return false
	obs.hp -= damage
	if obs.hp <= 0.0:
		obs.hp = 0.0
		obs.state = &"primed"
		obs.timer = float(DictUtil.d(world.catalog.obstacles, "volatile").get("prime", 0.4))
	return true


static func damage_geode(world: SimWorld, index: int, damage: float) -> bool:
	if index < 0 or index >= world.obstacles.cap or world.obstacles.alive[index] == 0:
		return false
	var obs: SimObstacle = world.obstacles.items[index]
	if obs.type != &"geode" or obs.state != &"intact" or damage <= 0.0:
		return false
	var cfg: Dictionary = DictUtil.d(world.catalog.loop, "mercuryGeode")
	if obs.collapse_timer < 0.0:
		obs.collapse_timer = float(cfg.get("collapseDuration", 12.0))
	obs.hp -= damage
	if obs.hp <= 0.0:
		obs.hp = 0.0
		obs.state = &"cracked"
		obs.timer = GEODE_CRACK_DURATION
		world.fx.emit(FxIds.GEODE_CRACK, obs.x, obs.y, 0xFFE896, obs.radius * 2.0)
		var xp_min: int = int(cfg.get("xpDropsMin", 6))
		var xp_max: int = maxi(xp_min, int(cfg.get("xpDropsMax", 10)))
		var xp_count: int = world.randi_range(xp_min, xp_max)
		SimPickups.spawn_xp_drops(world, obs.x, obs.y, xp_count, float(xp_count) * 5.0 * world.coefficient)
		var ess_min: int = int(cfg.get("essenceMin", 5))
		var ess_max: int = maxi(ess_min, int(cfg.get("essenceMax", 12)))
		SimPickups.spawn_essence_drops(world, obs.x, obs.y, 1, ess_min, ess_max)
		world.geodes_cracked_run += 1
	return true


static func charge_conduit(world: SimWorld, index: int, delta: int) -> void:
	if delta <= 0 or index < 0 or index >= world.obstacles.cap:
		return
	if world.obstacles.alive[index] == 0:
		return
	var obs: SimObstacle = world.obstacles.items[index]
	if obs.type != &"conduit" or obs.state == &"depleted":
		return
	var cfg: Dictionary = DictUtil.d(world.catalog.obstacles, "resonanceConduit")
	var req: int = maxi(1, int(cfg.get("chargesRequired", 3)))
	obs.charges += delta
	if obs.charges < req:
		return
	obs.charges = 0
	obs.state = &"depleted"
	obs.timer = float(cfg.get("rechargeDuration", 8.0))
	var rad: float = float(cfg.get("dischargeRadius", 140.0))
	var dmg: float = float(cfg.get("dischargeDamageCoeff", 22.0)) * world.coefficient
	var stun_dur: float = float(cfg.get("dischargeStunDuration", 0.45))
	world.fx.emit(FxIds.CONDUIT_DISCHARGE, obs.x, obs.y, 0x66EEFF, rad)
	for e: int in world.enemies.cap:
		if world.enemies.alive[e] == 0 or world.enemies.corpse_remain[e] > 0.0:
			continue
		if not SimCollision.circles_overlap(obs.x, obs.y, rad, world.enemies.x[e], world.enemies.y[e], world.enemies.radius[e]):
			continue
		SimEnemies.apply_damage(world, e, dmg)
		if world.enemies.alive[e] != 0 and world.enemies.corpse_remain[e] <= 0.0:
			world.enemies.apply_stun(e, stun_dur)


static func detonate_volatile(world: SimWorld, index: int) -> void:
	if index < 0 or index >= world.obstacles.cap or world.obstacles.alive[index] == 0:
		return
	var obs: SimObstacle = world.obstacles.items[index]
	if obs.type != &"volatile" or obs.state == &"detonated":
		return
	_detonate(world, index)
	rebuild_hash(world)


static func hit_aoe(
	world: SimWorld,
	x: float,
	y: float,
	radius: float,
	damage: float,
	is_secondary_or_special: bool = false,
	element: String = "",
) -> void:
	var n: int = world.obstacles.grid.query(x, y, radius + 56.0)
	for k: int in n:
		var idx: int = world.obstacles.grid.hits[k]
		if world.obstacles.alive[idx] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[idx]
		if not SimCollision.circles_overlap(x, y, radius, obs.x, obs.y, obs.radius):
			continue
		if obs.type == &"volatile" and obs.state == &"intact":
			damage_volatile(world, idx, damage)
		elif obs.type == &"geode" and obs.state == &"intact":
			damage_geode(world, idx, damage)
		elif obs.type == &"conduit" and obs.state != &"depleted" and is_secondary_or_special:
			charge_conduit(world, idx, 2)
	SimAlchemy.trigger_surface_reaction(world, x, y, radius, is_secondary_or_special, element)


static func on_enemy_killed(world: SimWorld, obs_id: int) -> void:
	if obs_id <= 0:
		return
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		if obs.id != obs_id or obs.type != &"obelisk" or obs.state != &"trial_active":
			continue
		obs.trial_remaining = maxi(0, obs.trial_remaining - 1)
		if obs.trial_remaining <= 0:
			_complete_combat_obelisk(world, obs)
		return


static func step(world: SimWorld, dt: float) -> void:
	SimStatus.tick_slow(world.player, dt)
	SimStatus.tick_root(world.player, dt)
	if not player_phasing(world) and overlapping_hazard(world, world.player.x, world.player.y, world.player.radius):
		world.damage_player(float(DictUtil.d(world.catalog.obstacles, "hazard").get("dps", 4.0)) * world.coefficient * dt, true)
	var rebuild: bool = false
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		if obs.reaction_cooldown > 0.0:
			obs.reaction_cooldown = maxf(0.0, obs.reaction_cooldown - dt)
			if obs.reaction_cooldown <= 0.0 and obs.sub_kind == "frozen":
				obs.sub_kind = ""
		if obs.type == &"hazard":
			if obs.timer > 0.0:
				obs.timer -= dt
				if obs.timer <= 0.0:
					obs.timer = 0.0
					world.obstacles.alive[i] = 0
					rebuild = true
		elif obs.type == &"volatile":
			if obs.state == &"primed":
				obs.timer -= dt
				if obs.timer <= 0.0:
					_detonate(world, i)
					rebuild = true
		elif obs.type == &"vent":
			_step_vent(world, obs, dt)
		elif obs.type == &"conduit":
			if obs.state == &"depleted":
				obs.timer -= dt
				if obs.timer <= 0.0:
					obs.timer = 0.0
					obs.state = &"idle"
					obs.charges = 0
		elif obs.type == &"geode":
			if obs.state == &"intact" and obs.collapse_timer >= 0.0:
				obs.collapse_timer -= dt
				if obs.collapse_timer <= 0.0:
					obs.collapse_timer = 0.0
					obs.state = &"depleted"
			elif obs.state == &"cracked":
				obs.timer -= dt
				if obs.timer <= 0.0:
					obs.timer = 0.0
					obs.state = &"depleted"
		elif obs.type == &"obelisk":
			_step_obelisk(world, i, obs, dt)
		elif obs.type == &"burn_trail":
			obs.cycle_timer = maxf(0.0, obs.cycle_timer - dt)
			if not player_phasing(world) and SimCollision.circles_overlap(world.player.x, world.player.y, world.player.radius, obs.x, obs.y, obs.radius):
				if obs.cycle_timer <= 0.0:
					SimEnemies.apply_burn_stack(world)
					obs.cycle_timer = BURN_TRAIL_REFRESH
			obs.timer -= dt
			if obs.timer <= 0.0:
				obs.timer = 0.0
				world.obstacles.alive[i] = 0
				rebuild = true
	_prune_conduit_hits(world)
	if rebuild:
		rebuild_hash(world)


static func rebuild_hash(world: SimWorld) -> void:
	world.obstacles.grid.clear()
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		world.obstacles.grid.insert(world.obstacles.items[i].x, world.obstacles.items[i].y, i)


static func _rebuild_hash(world: SimWorld) -> void:
	rebuild_hash(world)


static func _step_vent(world: SimWorld, obs: SimObstacle, dt: float) -> void:
	var cfg: Dictionary = DictUtil.d(world.catalog.obstacles, "alchemicalVent")
	var cycle_interval: float = float(cfg.get("cycleInterval", 9.0))
	var telegraph_dur: float = float(cfg.get("telegraphDuration", 1.2))
	var active_dur: float = float(cfg.get("activeDuration", 1.0))
	var telegraph_start: float = maxf(0.0, cycle_interval - telegraph_dur)
	if obs.state == &"idle" or obs.state == &"telegraph":
		obs.cycle_timer += dt
		if obs.cycle_timer >= cycle_interval:
			obs.state = &"erupting"
			obs.timer = active_dur
			obs.cycle_timer = 0.0
			obs.erupt_hit_player = false
			obs.erupt_hit_enemies.clear()
			world.fx.emit(FxIds.VENT_ERUPT, obs.x, obs.y, 0xFF8844, obs.radius)
		elif obs.cycle_timer >= telegraph_start:
			obs.state = &"telegraph"
			obs.timer = cycle_interval - obs.cycle_timer
		else:
			obs.state = &"idle"
			obs.timer = 0.0
	if obs.state == &"erupting":
		var slow_mul: float = float(cfg.get("slowMul", 0.75))
		var slow_dur: float = float(cfg.get("slowDuration", 1.5))
		if not obs.erupt_hit_player and not player_phasing(world):
			if SimCollision.circles_overlap(world.player.x, world.player.y, world.player.radius, obs.x, obs.y, obs.radius):
				obs.erupt_hit_player = true
				world.fx.emit(FxIds.HURT, world.player.x, world.player.y, 0xFF7A3A)
				world.damage_player(float(cfg.get("playerFlatDamage", 12.0)))
				SimStatus.apply_slow(world.player, slow_mul, slow_dur)
		var enemy_dmg: float = float(cfg.get("damageCoeff", 10.0)) * world.coefficient
		var kb: float = float(cfg.get("knockbackImpulse", 260.0))
		for e: int in world.enemies.cap:
			if world.enemies.alive[e] == 0 or world.enemies.corpse_remain[e] > 0.0:
				continue
			if obs.erupt_hit_enemies.has(e):
				continue
			if not SimCollision.circles_overlap(obs.x, obs.y, obs.radius, world.enemies.x[e], world.enemies.y[e], world.enemies.radius[e]):
				continue
			obs.erupt_hit_enemies.append(e)
			var kdx: float = world.enemies.x[e] - obs.x
			var kdy: float = world.enemies.y[e] - obs.y
			var kdist: float = sqrt(kdx * kdx + kdy * kdy)
			var knx: float = 1.0 if kdist <= 0.001 else kdx / kdist
			var kny: float = 0.0 if kdist <= 0.001 else kdy / kdist
			world.enemies.apply_knockback(e, knx * kb, kny * kb)
			world.enemies.apply_slow(e, slow_mul, slow_dur)
			SimEnemies.apply_damage(world, e, enemy_dmg)
		obs.timer -= dt
		if obs.timer <= 0.0:
			obs.timer = 0.0
			obs.state = &"idle"
			obs.cycle_timer = 0.0
			obs.erupt_hit_player = false
			obs.erupt_hit_enemies.clear()


static func _step_obelisk(world: SimWorld, index: int, obs: SimObstacle, dt: float) -> void:
	var ob_cfg: Dictionary = DictUtil.d(world.catalog.obstacles, "siphonObelisk")
	var blocked: bool = world.teleporter_state == &"charging" or (world.boss_spawned and not world.boss_defeated)
	if obs.state == &"idle" or obs.state == &"channeling":
		var interact_r: float = float(ob_cfg.get("interactRadius", 64.0))
		var channel_dur: float = float(ob_cfg.get("channelDuration", 2.0))
		var dx: float = world.player.x - obs.x
		var dy: float = world.player.y - obs.y
		var in_range: bool = dx * dx + dy * dy <= interact_r * interact_r
		if not blocked and in_range and world.interact_held:
			obs.state = &"channeling"
			obs.progress = minf(channel_dur, obs.progress + dt)
			if obs.progress >= channel_dur:
				_start_obelisk_trial(world, index)
		else:
			obs.progress = maxf(0.0, obs.progress - dt)
			if obs.progress <= 0.0:
				obs.state = &"idle"
	elif obs.state == &"trial_active":
		if obs.sub_kind == "obelisk-reliquary":
			var rel_cfg: Dictionary = DictUtil.d(ob_cfg, "reliquary")
			world.obelisk_armor_debuff = float(rel_cfg.get("armorDebuff", -0.25))
			obs.trial_timer -= dt
			if obs.trial_timer <= 0.0:
				obs.trial_timer = 0.0
				obs.state = &"completed"
				world.obelisk_armor_debuff = 0.0
				world.stage_obelisks_completed += 1
				world.pending_bonus_drafts += 1
				world.fx.emit(FxIds.GEM, obs.x, obs.y, 0xFFE896, obs.radius * 2.0)
				SimLevel.open_bonus_draft_if_ready(world)


static func _start_obelisk_trial(world: SimWorld, index: int) -> void:
	var obs: SimObstacle = world.obstacles.items[index]
	var ob_cfg: Dictionary = DictUtil.d(world.catalog.obstacles, "siphonObelisk")
	obs.state = &"trial_active"
	obs.progress = float(ob_cfg.get("channelDuration", 2.0))
	if obs.sub_kind == "obelisk-reliquary":
		var rel_cfg: Dictionary = DictUtil.d(ob_cfg, "reliquary")
		obs.trial_timer = float(rel_cfg.get("trialDuration", 20.0))
		obs.trial_remaining = 0
		world.obelisk_armor_debuff = float(rel_cfg.get("armorDebuff", -0.25))
		return
	var stage: Dictionary = SimLoop.current_stage(world)
	var elite_id: String = String(stage.get("elite", "ember-chaser"))
	var def: Dictionary = world.catalog.entity(elite_id)
	var count_cfg: Dictionary = DictUtil.d(ob_cfg, "blood" if obs.sub_kind == "obelisk-blood" else "essence")
	var e_min: int = int(count_cfg.get("eliteMin", 2))
	var e_max: int = maxi(e_min, int(count_cfg.get("eliteMax", 4 if obs.sub_kind == "obelisk-blood" else 5)))
	var target_count: int = world.randi_range(e_min, e_max)
	var e_rad: float = float(DictUtil.d(def, "stats").get("radius", 18.0)) * float(DictUtil.d(world.catalog.loop, "elite").get("radiusMul", 1.25))
	var spawned: int = 0
	for k: int in target_count:
		var ang: float = (float(k) / float(maxi(1, target_count))) * TAU + world.randf() * 0.4
		var dist: float = obs.radius + e_rad + 68.0 + world.randf() * 44.0
		var sx: float = obs.x + cos(ang) * dist
		var sy: float = obs.y + sin(ang) * dist
		if world.arena_shape == "circle":
			var clamped: Vector2 = SimCollision.clamp_to_circle(sx, sy, maxf(0.0, world.arena_radius - e_rad - 16.0))
			sx = clamped.x
			sy = clamped.y
		var enemy_idx: int = SimEnemies.spawn(world, def, sx, sy, true, "")
		if enemy_idx >= 0:
			world.enemies.source_obstacle_id[enemy_idx] = obs.id
			spawned += 1
	obs.trial_remaining = spawned
	if obs.trial_remaining <= 0:
		_complete_combat_obelisk(world, obs)


static func _complete_combat_obelisk(world: SimWorld, obs: SimObstacle) -> void:
	obs.state = &"completed"
	world.stage_obelisks_completed += 1
	if obs.sub_kind == "obelisk-essence":
		var ess_econ: Dictionary = DictUtil.d(world.catalog.loop, "essenceEconomy")
		var min_v: int = int(ess_econ.get("obeliskMin", 4))
		var max_v: int = maxi(min_v, int(ess_econ.get("obeliskMax", 8)))
		var count: int = world.randi_range(2, 3)
		SimPickups.spawn_essence_drops(world, obs.x, obs.y, count, min_v, max_v)
		world.fx.emit(FxIds.GEM, obs.x, obs.y, 0xFFE896, obs.radius * 2.0)
	elif obs.sub_kind == "obelisk-blood":
		var heal_pct: float = float(DictUtil.d(DictUtil.d(world.catalog.obstacles, "siphonObelisk"), "blood").get("healPct", 0.35))
		world.heal_player(world.player.max_hp * heal_pct)
		world.fx.emit(FxIds.GEM, obs.x, obs.y, 0xFF4466, obs.radius * 2.0)


static func _detonate(world: SimWorld, index: int) -> void:
	var cfg: Dictionary = DictUtil.d(world.catalog.obstacles, "volatile")
	var obs: SimObstacle = world.obstacles.items[index]
	var rime: bool = String(SimLoop.current_stage(world).get("id", "")) == "rime-dock"
	var blast: float = float(cfg.get("explosionRadius", 110.0))
	var enemy_dmg: float = float(cfg.get("enemyDamage", 45.0)) * world.coefficient
	world.fx.emit(FxIds.DEATH, obs.x, obs.y, 0xFF8844)
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0 or world.enemies.corpse_remain[i] > 0.0:
			continue
		if not SimCollision.circles_overlap(obs.x, obs.y, blast, world.enemies.x[i], world.enemies.y[i], world.enemies.radius[i]):
			continue
		SimEnemies.apply_damage(world, i, enemy_dmg)
		if rime and world.enemies.alive[i] != 0:
			world.enemies.apply_slow(i, float(cfg.get("rimeSlowMul", 0.7)), float(cfg.get("rimeSlowDuration", 2.0)))
	if SimCollision.circles_overlap(obs.x, obs.y, blast, world.player.x, world.player.y, world.player.radius):
		if world.player.iframe_remain <= 0.0:
			world.fx.emit(FxIds.HURT, world.player.x, world.player.y, 0xFF3355)
			world.damage_player(float(cfg.get("playerDamage", 18.0)))
		if rime:
			SimStatus.apply_slow(world.player, float(cfg.get("rimeSlowMul", 0.7)), float(cfg.get("rimeSlowDuration", 2.0)))
	obs.state = &"detonated"
	obs.timer = 0.0
	world.obstacles.alive[index] = 0


static func _try_place(world: SimWorld, type: StringName, rng: SimRng, placed: Array[Vector2]) -> Vector2:
	var cfg: Dictionary = world.catalog.obstacles
	var retries: int = int(cfg.get("placeRetries", 80))
	if world.arena_shape == "circle":
		var circ: Dictionary = DictUtil.d(cfg, "circularPlacement")
		var rim_pad: float = float(circ.get("rimPad", 140.0))
		var max_r: float = maxf(0.0, world.arena_radius - rim_pad)
		var p_keep: float = float(circ.get("playerKeepOut", cfg.get("playerKeepOut", 200.0)))
		var t_keep: float = float(circ.get("teleporterKeepOut", cfg.get("teleporterKeepOut", 230.0)))
		var spacing: float = float(circ.get("minSpacing", cfg.get("minSpacing", 185.0)))
		for _a: int in retries:
			var r: float = sqrt(rng.next()) * max_r
			var ang: float = rng.next() * TAU
			var x: float = cos(ang) * r
			var y: float = sin(ang) * r
			if sqrt((x - world.player.x) * (x - world.player.x) + (y - world.player.y) * (y - world.player.y)) < p_keep:
				continue
			if sqrt((x - world.teleporter_x) * (x - world.teleporter_x) + (y - world.teleporter_y) * (y - world.teleporter_y)) < t_keep:
				continue
			var blocked: bool = false
			for p: Vector2 in placed:
				if sqrt((x - p.x) * (x - p.x) + (y - p.y) * (y - p.y)) < spacing:
					blocked = true
					break
			if blocked:
				continue
			return Vector2(x, y)
		return Vector2.INF
	var width: float = float(world.catalog.world.get("width", 2560.0))
	var height: float = float(world.catalog.world.get("height", 2560.0))
	var border_pad: float = float(cfg.get("borderPad", 160.0))
	var p_keep_rect: float = float(cfg.get("playerKeepOut", 200.0))
	var tel_keep: float = float(cfg.get("volatileTeleporterKeepOut", 200.0)) if type == &"volatile" else float(cfg.get("teleporterKeepOut", 230.0))
	var spacing_rect: float = float(cfg.get("minSpacing", 190.0))
	for _a: int in retries:
		var x: float = border_pad + rng.next() * (width - border_pad * 2.0)
		var y: float = border_pad + rng.next() * (height - border_pad * 2.0)
		if sqrt((x - world.player.x) * (x - world.player.x) + (y - world.player.y) * (y - world.player.y)) < p_keep_rect:
			continue
		if sqrt((x - world.teleporter_x) * (x - world.teleporter_x) + (y - world.teleporter_y) * (y - world.teleporter_y)) < tel_keep:
			continue
		var blocked_rect: bool = false
		for p: Vector2 in placed:
			if sqrt((x - p.x) * (x - p.x) + (y - p.y) * (y - p.y)) < spacing_rect:
				blocked_rect = true
				break
		if blocked_rect:
			continue
		return Vector2(x, y)
	return Vector2.INF


static func _blocks_projectile(obs: SimObstacle, proj_team: int, is_primary: bool, is_pierce: bool) -> bool:
	if obs.type == &"pillar" or obs.type == &"obelisk" or obs.type == &"volatile":
		return true
	if obs.type == &"geode":
		return obs.state == &"intact"
	if obs.type == &"conduit":
		if obs.state == &"depleted":
			return false
		if proj_team == ProjectilePool.TEAM_ENEMY:
			return true
		if is_primary or is_pierce:
			return false
		return true
	return false


static func _prune_conduit_hits(world: SimWorld) -> void:
	var p_size: int = world.projectiles.alive.size()
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		if obs.type != &"conduit" or obs.hit_proj_ids.is_empty():
			continue
		for k: int in range(obs.hit_proj_ids.size() - 1, -1, -1):
			var pid: int = obs.hit_proj_ids[k]
			if pid < 0 or pid >= p_size or world.projectiles.alive[pid] == 0:
				obs.hit_proj_ids.remove_at(k)


static func _oldest_dynamic_hazard(obstacles: ObstaclePool) -> int:
	var best: int = -1
	var min_timer: float = INF
	for i: int in obstacles.cap:
		if obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = obstacles.items[i]
		if obs.type == &"hazard" and obs.timer > 0.0 and obs.timer < min_timer:
			min_timer = obs.timer
			best = i
	return best


static func _oldest_burn_trail(obstacles: ObstaclePool) -> int:
	var best: int = -1
	var min_timer: float = INF
	for i: int in obstacles.cap:
		if obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = obstacles.items[i]
		if obs.type == &"burn_trail" and obs.timer < min_timer:
			min_timer = obs.timer
			best = i
	return best


static func _radius_for(world: SimWorld, type: StringName) -> float:
	var cfg: Dictionary = world.catalog.obstacles
	if type == &"hazard":
		return float(DictUtil.d(cfg, "hazard").get("radius", 68.0))
	if type == &"volatile":
		return float(DictUtil.d(cfg, "volatile").get("radius", 14.0))
	if type == &"vent":
		return float(DictUtil.d(cfg, "alchemicalVent").get("radius", 55.0))
	if type == &"conduit":
		return float(DictUtil.d(cfg, "resonanceConduit").get("radius", 22.0))
	if type == &"obelisk":
		return float(DictUtil.d(cfg, "siphonObelisk").get("radius", 24.0))
	if type == &"geode":
		return float(DictUtil.d(world.catalog.loop, "mercuryGeode").get("radius", 24.0))
	if type == &"burn_trail":
		return float(DictUtil.d(world.catalog.loop, "burn").get("trailRadius", 22.0))
	return float(DictUtil.d(cfg, "pillar").get("radius", 28.0))


static func _obelisk_label(sub_kind: String) -> String:
	if sub_kind == "obelisk-reliquary":
		return "Reliquary Obelisk"
	if sub_kind == "obelisk-blood":
		return "Blood Obelisk"
	return "Essence Obelisk"
