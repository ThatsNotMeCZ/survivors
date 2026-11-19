class_name SimEnemies
extends RefCounted


static func chase_attack_range(body_radius: float, target_radius: float) -> float:
	return body_radius + target_radius + EnemyPool.CHASE_ATTACK_RANGE_PAD


static func chase_contact_range(body_radius: float, target_radius: float) -> float:
	return body_radius + target_radius + EnemyPool.CHASE_CONTACT_RANGE_PAD


static func is_chase(world: SimWorld, index: int) -> bool:
	var def_id: String = world.enemies.def_id[index]
	if def_id == "":
		return true
	var ai: Dictionary = DictUtil.d(world.catalog.entity(def_id), "ai")
	var ai_type: String = String(ai.get("type", "chase"))
	return ai_type == "chase" or ai_type == "cleaver" or ai_type == "charger"


static func is_specialist_def(def: Dictionary) -> bool:
	var ai: Dictionary = DictUtil.d(def, "ai")
	var ai_type: String = String(ai.get("type", "chase"))
	if ai_type == "ranged" or ai_type == "sniper" or ai_type == "cleaver" or ai_type == "charger" or ai_type == "hexer":
		return true
	for tag_v: Variant in DictUtil.a(def, "tags"):
		var tag: String = String(tag_v)
		if tag == "specialist" or tag == "ranged" or tag == "sniper" or tag == "cleaver" or tag == "charger" or tag == "hexer":
			return true
	return false


static func clear(world: SimWorld) -> void:
	world.enemies.clear()
	world.counts_fodder = 0
	world.counts_elite = 0
	world.counts_boss = 0


static func spawn(
	world: SimWorld,
	def: Dictionary,
	px: float,
	py: float,
	is_elite: bool = false,
	elite_affix: String = "",
) -> int:
	if world.boss_defeated or def.is_empty():
		return -1
	var role: int = EnemyPool.ROLE_FODDER
	if String(def.get("role", "")) == "boss":
		role = EnemyPool.ROLE_BOSS
	elif is_elite:
		role = EnemyPool.ROLE_ELITE
	var dir: Dictionary = DictUtil.d(world.catalog.loop, "director")
	var max_fodder: int = int(dir.get("maxFodderCap", world.catalog.loop.get("maxFodder", 42)))
	var max_elites: int = int(dir.get("maxElitesCap", world.catalog.loop.get("maxElites", 12)))
	if role == EnemyPool.ROLE_FODDER and world.counts_fodder >= max_fodder:
		return -1
	if role == EnemyPool.ROLE_ELITE and world.counts_elite >= max_elites:
		return -1
	if role == EnemyPool.ROLE_BOSS and world.counts_boss >= 1:
		return -1
	var enemies: EnemyPool = world.enemies
	for i: int in enemies.cap:
		if enemies.alive[i] != 0:
			continue
		var coeff: float = SimLoop.difficulty_coeff(world)
		var speed_mul: float = 1.0 + float(DictUtil.d(world.catalog.loop, "difficulty").get("speedPerCoeff", 0.0)) * (coeff - 1.0)
		var elite_cfg: Dictionary = DictUtil.d(world.catalog.loop, "elite")
		var hp_mul: float = float(elite_cfg.get("hpMul", 1.0)) if role == EnemyPool.ROLE_ELITE else 1.0
		var dmg_mul: float = float(elite_cfg.get("damageMul", 1.0)) if role == EnemyPool.ROLE_ELITE else 1.0
		var xp_mul: float = float(elite_cfg.get("xpMul", 1.0)) if role == EnemyPool.ROLE_ELITE else 1.0
		var cred_mul: float = float(elite_cfg.get("creditsMul", 1.0)) if role == EnemyPool.ROLE_ELITE else 1.0
		var rad_mul: float = float(elite_cfg.get("radiusMul", 1.0)) if role == EnemyPool.ROLE_ELITE else 1.0
		var stats: Dictionary = DictUtil.d(def, "stats")
		var hp: float = float(stats.get("maxHp", 1.0)) * coeff * hp_mul
		var rad: float = float(stats.get("radius", 12.0)) * rad_mul
		var spawn_x: float = px
		var spawn_y: float = py
		if world.arena_shape == "circle":
			var clamped: Vector2 = SimCollision.clamp_to_circle(px, py, maxf(0.0, world.arena_radius - rad - 6.0))
			spawn_x = clamped.x
			spawn_y = clamped.y
		enemies.alive[i] = 1
		enemies.role[i] = role
		enemies.x[i] = spawn_x
		enemies.y[i] = spawn_y
		enemies.facing[i] = 255 if world.player.x < spawn_x else 1
		enemies.radius[i] = rad
		enemies.hp[i] = hp
		enemies.max_hp[i] = hp
		enemies.speed[i] = float(stats.get("speed", 80.0)) * speed_mul
		enemies.contact_dps[i] = float(DictUtil.d(def, "contact").get("dps", 0.0)) * coeff * dmg_mul
		enemies.xp[i] = float(DictUtil.d(def, "rewards").get("xp", 0.0)) * xp_mul
		enemies.credits[i] = float(DictUtil.d(def, "rewards").get("credits", 0.0)) * cred_mul
		var ai: Dictionary = DictUtil.d(def, "ai")
		var ai_type: String = String(ai.get("type", "chase"))
		if ai_type == "chase" or ai_type == "boss" or ai_type == "spire":
			enemies.attack_cd[i] = 0.0
		else:
			enemies.attack_cd[i] = float(ai.get("cooldown", 1.0)) * world.randf()
		enemies.windup[i] = 0.0
		enemies.aim_x[i] = spawn_x
		enemies.aim_y[i] = spawn_y
		enemies.slow_remain[i] = 0.0
		enemies.slow_mul[i] = 1.0
		enemies.source_obstacle_id[i] = -1
		enemies.ai_state[i] = EnemyPool.AI_STATE_DEFAULT
		enemies.state_timer[i] = 0.0
		enemies.vel_x[i] = 0.0
		enemies.vel_y[i] = 0.0
		enemies.chain_cd[i] = 1.0 + world.randf() * 1.5
		enemies.trail_cd[i] = 0.25
		enemies.burn_remain[i] = 0.0
		enemies.burn_dps[i] = 0.0
		enemies.is_specialist[i] = 1 if is_specialist_def(def) else 0
		if role == EnemyPool.ROLE_ELITE:
			var chosen: String = elite_affix
			if chosen == "":
				var affixes: Array = DictUtil.a(world.catalog.loop, "eliteAffixes")
				if affixes.is_empty():
					var fallback_affixes: PackedStringArray = PackedStringArray(["noxious", "shielder", "burn", "chain_lightning"])
					chosen = fallback_affixes[world.randi_range(0, fallback_affixes.size() - 1)]
				else:
					chosen = String(affixes[world.randi_range(0, affixes.size() - 1)])
			enemies.affix[i] = chosen
			if chosen == "shielder":
				enemies.shielder[i] = 1
				enemies.noxious[i] = 0
				enemies.shield_hp[i] = hp * float(DictUtil.d(world.catalog.loop, "shielder").get("percentHp", 0.3))
				enemies.shield_delay_remain[i] = 0.0
			elif chosen == "noxious":
				enemies.shielder[i] = 0
				enemies.noxious[i] = 1
				enemies.shield_hp[i] = 0.0
				enemies.shield_delay_remain[i] = 0.0
			else:
				enemies.shielder[i] = 0
				enemies.noxious[i] = 0
				enemies.shield_hp[i] = 0.0
				enemies.shield_delay_remain[i] = 0.0
		else:
			enemies.affix[i] = ""
			enemies.shielder[i] = 0
			enemies.noxious[i] = 0
			enemies.shield_hp[i] = 0.0
			enemies.shield_delay_remain[i] = 0.0
		enemies.corpse_remain[i] = 0.0
		enemies.root_remain[i] = 0.0
		enemies.root_duration[i] = 0.0
		enemies.tether_dps[i] = 0.0
		enemies.attack_remain[i] = 0.0
		enemies.hurt_remain[i] = 0.0
		enemies.anim_name[i] = ""
		var id: String = String(def.get("id", ""))
		enemies.def_id[i] = id
		world.encounters_by_entity[id] = int(world.encounters_by_entity.get(id, 0)) + 1
		if role == EnemyPool.ROLE_FODDER:
			world.counts_fodder += 1
		elif role == EnemyPool.ROLE_ELITE:
			world.counts_elite += 1
		else:
			world.counts_boss += 1
		return i
	return -1


static func pick_spawn_point(world: SimWorld, radius: float) -> Vector2:
	var dir: Dictionary = DictUtil.d(world.catalog.loop, "director")
	var spawn_min: float = float(dir.get("spawnMin", 920.0))
	var spawn_max: float = float(dir.get("spawnMax", 1800.0))
	var spawn_safe: float = float(dir.get("spawnSafeRadius", spawn_min))
	var px: float = world.player.x
	var py: float = world.player.y
	var min_d: float = maxf(spawn_min, spawn_safe)
	var range_v: float = maxf(0.0, spawn_max - min_d)
	if world.arena_shape == "circle":
		var max_r: float = maxf(64.0, world.arena_radius - radius - 8.0)
		for _a: int in 24:
			var dist: float = min_d + world.randf() * range_v
			var ang: float = world.randf() * TAU
			var x: float = px + cos(ang) * dist
			var y: float = py + sin(ang) * dist
			if hypot(x, y) <= max_r:
				return Vector2(x, y)
		for _b: int in 24:
			var r_c: float = sqrt(world.randf()) * max_r
			var ang_c: float = world.randf() * TAU
			var x2: float = cos(ang_c) * r_c
			var y2: float = sin(ang_c) * r_c
			if hypot(x2 - px, y2 - py) >= spawn_safe:
				return Vector2(x2, y2)
		return Vector2.INF
	var bounds: Dictionary = world.catalog.world
	var pad_x: float = float(bounds.get("borderInsetX", 0.0)) + radius + 8.0
	var pad_y: float = float(bounds.get("borderInsetY", 0.0)) + radius + 8.0
	var width: float = float(bounds.get("width", 6000.0))
	var height: float = float(bounds.get("height", 6000.0))
	for _a: int in 24:
		var dist: float = min_d + world.randf() * range_v
		var ang: float = world.randf() * TAU
		var x: float = px + cos(ang) * dist
		var y: float = py + sin(ang) * dist
		if x < pad_x or x > width - pad_x or y < pad_y or y > height - pad_y:
			continue
		return Vector2(x, y)
	for _b: int in 24:
		var x2: float = pad_x + world.randf() * (width - 2.0 * pad_x)
		var y2: float = pad_y + world.randf() * (height - 2.0 * pad_y)
		if hypot(x2 - px, y2 - py) >= spawn_safe:
			return Vector2(x2, y2)
	return Vector2.INF


static func spawn_group_around(
	world: SimWorld,
	def: Dictionary,
	count: int,
	is_elite: bool = false,
	elite_affix: String = "",
) -> int:
	if count <= 0 or def.is_empty():
		return 0
	var elite_cfg: Dictionary = DictUtil.d(world.catalog.loop, "elite")
	var radius: float = float(DictUtil.d(def, "stats").get("radius", 12.0))
	if is_elite:
		radius *= float(elite_cfg.get("radiusMul", 1.0))
	var center: Vector2 = pick_spawn_point(world, radius)
	if center.x == INF:
		return 0
	var spread: float = float(DictUtil.d(world.catalog.loop, "director").get("groupSpreadRadius", 56.0))
	var is_circle: bool = world.arena_shape == "circle"
	var max_r: float = maxf(0.0, world.arena_radius - radius - 6.0)
	var bounds: Dictionary = world.catalog.world
	var pad_x: float = float(bounds.get("borderInsetX", 0.0)) + radius + 8.0
	var pad_y: float = float(bounds.get("borderInsetY", 0.0)) + radius + 8.0
	var width: float = float(bounds.get("width", 6000.0))
	var height: float = float(bounds.get("height", 6000.0))
	var spawned: int = 0
	for s: int in count:
		var sx: float = center.x
		var sy: float = center.y
		if s > 0:
			var angle: float = world.randf() * TAU
			var dist: float = world.randf() * spread
			sx = center.x + cos(angle) * dist
			sy = center.y + sin(angle) * dist
		if is_circle:
			var clamped: Vector2 = SimCollision.clamp_to_circle(sx, sy, max_r)
			sx = clamped.x
			sy = clamped.y
		else:
			sx = clampf(sx, pad_x, width - pad_x)
			sy = clampf(sy, pad_y, height - pad_y)
		var idx: int = spawn(world, def, sx, sy, is_elite, elite_affix)
		if idx >= 0:
			spawned += 1
		else:
			break
	return spawned


static func start_death(world: SimWorld, index: int) -> void:
	var enemies: EnemyPool = world.enemies
	if enemies.alive[index] == 0:
		return
	if enemies.corpse_remain[index] > 0.0:
		return
	if enemies.noxious[index] != 0:
		enemies.corpse_remain[index] = float(DictUtil.d(world.catalog.loop, "noxious").get("corpseDelay", 0.5))
		enemies.hp[index] = 0.0
		enemies.speed[index] = 0.0
		enemies.windup[index] = 0.0
		enemies.ai_state[index] = EnemyPool.AI_STATE_DEFAULT
		enemies.state_timer[index] = 0.0
		return
	kill(world, index)


static func kill(world: SimWorld, index: int) -> void:
	var enemies: EnemyPool = world.enemies
	if enemies.alive[index] == 0:
		return
	var role: int = enemies.role[index]
	var def_id: String = enemies.def_id[index]
	var px: float = enemies.x[index]
	var py: float = enemies.y[index]
	var xp: float = enemies.xp[index]
	var src_obs: int = enemies.source_obstacle_id[index]
	var spec: bool = enemies.is_specialist[index] != 0
	world.credits += enemies.credits[index]
	var heal: float = SimStats.on_kill_heal(world.inventory, world.catalog)
	if heal > 0.0:
		world.heal_player(heal)
	world.fx.emit(FxIds.DEATH, px, py, 0xFFD35A)
	enemies.alive[index] = 0
	enemies.source_obstacle_id[index] = -1
	enemies.affix[index] = ""
	enemies.burn_remain[index] = 0.0
	enemies.burn_dps[index] = 0.0
	enemies.vel_x[index] = 0.0
	enemies.vel_y[index] = 0.0
	enemies.ai_state[index] = EnemyPool.AI_STATE_DEFAULT
	enemies.state_timer[index] = 0.0
	world.kills_total += 1
	if def_id != "":
		world.kills_by_entity[def_id] = int(world.kills_by_entity.get(def_id, 0)) + 1
	if role == EnemyPool.ROLE_FODDER:
		world.counts_fodder -= 1
		world.kills_fodder += 1
	elif role == EnemyPool.ROLE_ELITE:
		world.counts_elite -= 1
		world.kills_elite += 1
	elif role == EnemyPool.ROLE_BOSS:
		world.counts_boss -= 1
		world.kills_boss += 1
		world.bosses_defeated += 1
		world.boss_defeated = true
		world.portal_x = px
		world.portal_y = py
		if float(world.player.hp) / maxf(1.0, world.player.max_hp) < 0.10:
			world.low_hp_boss_kills_run += 1
	if src_obs > 0:
		SimObstacles.on_enemy_killed(world, src_obs)
	SimPickups.spawn_enemy_drops(
		world,
		px,
		py,
		xp,
		role == EnemyPool.ROLE_ELITE,
		role == EnemyPool.ROLE_BOSS,
		spec,
	)
	if def_id != "" and not world.collected_lores.has(def_id) and not world.lores.has_active(def_id):
		var role_key: String = "boss" if role == EnemyPool.ROLE_BOSS else ("elite" if role == EnemyPool.ROLE_ELITE else "fodder")
		var chance: float = float(DictUtil.d(world.catalog.loop, "loreDropChance").get(role_key, 0.0))
		if chance > 0.0 and world.randf() < chance:
			world.lores.spawn_drop(px, py, def_id)


static func count_snipers(world: SimWorld) -> int:
	var n: int = 0
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0:
			continue
		var id: String = world.enemies.def_id[i]
		if id != "" and String(DictUtil.d(world.catalog.entity(id), "ai").get("type", "")) == "sniper":
			n += 1
	return n


static func count_specialists(world: SimWorld) -> int:
	var n: int = 0
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0:
			continue
		if world.enemies.is_specialist[i] != 0:
			n += 1
	return n


static func apply_damage(world: SimWorld, index: int, damage: float) -> void:
	var enemies: EnemyPool = world.enemies
	if enemies.alive[index] == 0 or damage <= 0.0:
		return
	enemies.hurt_remain[index] = 0.12
	var final_damage: float = damage
	if enemies.role[index] == EnemyPool.ROLE_ELITE or enemies.role[index] == EnemyPool.ROLE_BOSS:
		final_damage *= world.stats.elite_damage_mul
	if enemies.role[index] == EnemyPool.ROLE_ELITE and enemies.shielder[index] != 0:
		enemies.shield_delay_remain[index] = float(DictUtil.d(world.catalog.loop, "shielder").get("delay", 5.0))
		if enemies.shield_hp[index] > 0.0:
			if final_damage <= enemies.shield_hp[index]:
				enemies.shield_hp[index] -= final_damage
				world.damage_dealt += final_damage
				return
			world.damage_dealt += enemies.shield_hp[index]
			final_damage -= enemies.shield_hp[index]
			enemies.shield_hp[index] = 0.0
	var dealt: float = minf(maxf(0.0, enemies.hp[index]), final_damage)
	world.damage_dealt += dealt
	enemies.hp[index] -= final_damage
	if enemies.hp[index] <= 0.0:
		start_death(world, index)


static func apply_noxious_contact(world: SimWorld, index: int) -> void:
	if world.enemies.noxious[index] == 0:
		return
	var cfg: Dictionary = DictUtil.d(world.catalog.loop, "noxious")
	SimStatus.apply_slow(world.player, float(cfg.get("contactSlowMul", 0.5)), float(cfg.get("contactSlowDuration", 1.1)))


static func apply_burn_to_player(world: SimWorld, attacker_idx: int) -> void:
	if attacker_idx < 0 or attacker_idx >= world.enemies.cap:
		return
	if world.enemies.alive[attacker_idx] == 0:
		return
	if world.enemies.affix[attacker_idx] != "burn":
		return
	apply_burn_stack(world)


static func apply_burn_stack(world: SimWorld) -> void:
	if world.player.iframe_remain > 0.0 or world.player.hp <= 0.0:
		return
	var cfg: Dictionary = DictUtil.d(world.catalog.loop, "burn")
	var max_stacks: int = maxi(1, int(cfg.get("maxStacks", 2)))
	var coeff: float = SimLoop.difficulty_coeff(world)
	var stack_dps: float = float(cfg.get("dpsCoeff", 4.5)) * coeff
	var dur: float = float(cfg.get("duration", 3.0))
	world.player.burn_stacks = mini(max_stacks, world.player.burn_stacks + 1)
	world.player.burn_dps = stack_dps * float(world.player.burn_stacks)
	world.player.burn_remain = maxf(world.player.burn_remain, dur)


static func pillar_blocks_shot(world: SimWorld, x0: float, y0: float, x1: float, y1: float) -> bool:
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		if obs.type != &"pillar":
			continue
		if _segment_hits_circle(x0, y0, x1, y1, obs.x, obs.y, obs.radius + EnemyPool.PILLAR_COVER_EXTRA_RADIUS):
			return true
	return false


static func ring_point(world: SimWorld, ox: float, oy: float, radius: float) -> Vector2:
	var dir: Dictionary = DictUtil.d(world.catalog.loop, "director")
	var spawn_min: float = float(dir.get("spawnMin", 920.0))
	var spawn_max: float = float(dir.get("spawnMax", 1800.0))
	if world.arena_shape == "circle":
		var max_r: float = maxf(64.0, world.arena_radius - radius - 8.0)
		for _a: int in 10:
			var dist: float = spawn_min + world.randf() * maxf(0.0, spawn_max - spawn_min)
			var ang: float = world.randf() * TAU
			var clamped: Vector2 = SimCollision.clamp_to_circle(ox + cos(ang) * dist, oy + sin(ang) * dist, max_r)
			if hypot(clamped.x - ox, clamped.y - oy) >= spawn_min * 0.7:
				return clamped
		var in_ang: float = atan2(-oy, -ox) if hypot(ox, oy) > 1.0 else 0.0
		return SimCollision.clamp_to_circle(ox + cos(in_ang) * spawn_min, oy + sin(in_ang) * spawn_min, max_r)
	var bounds: Dictionary = world.catalog.world
	var pad: float = radius + 8.0
	var width: float = float(bounds.get("width", 6000.0))
	var height: float = float(bounds.get("height", 6000.0))
	for _a: int in 10:
		var dist: float = spawn_min + world.randf() * maxf(0.0, spawn_max - spawn_min)
		var ang: float = world.randf() * TAU
		var x: float = clampf(ox + cos(ang) * dist, pad, width - pad)
		var y: float = clampf(oy + sin(ang) * dist, pad, height - pad)
		if hypot(x - ox, y - oy) >= spawn_min * 0.7:
			return Vector2(x, y)
	return Vector2(clampf(ox + spawn_min, pad, width - pad), clampf(oy, pad, height - pad))


static func knockback_radial(
	world: SimWorld,
	ox: float,
	oy: float,
	radius: float,
	impulse: float,
	stun_dur: float = 0.32,
	min_exit_radius: float = 0.0,
) -> void:
	if radius <= 0.0 or impulse <= 0.0:
		return
	var r2: float = radius * radius
	var is_circ: bool = world.arena_shape == "circle"
	var bounds: Dictionary = world.catalog.world
	var width: float = float(bounds.get("width", 6000.0))
	var height: float = float(bounds.get("height", 6000.0))
	for e: int in world.enemies.cap:
		if world.enemies.alive[e] == 0 or world.enemies.corpse_remain[e] > 0.0:
			continue
		if world.enemies.role[e] == EnemyPool.ROLE_BOSS:
			continue
		var edx: float = world.enemies.x[e] - ox
		var edy: float = world.enemies.y[e] - oy
		var d2: float = edx * edx + edy * edy
		if d2 > r2:
			continue
		var dist: float = sqrt(d2)
		var nx: float = 1.0 if dist <= 0.001 else edx / dist
		var ny: float = 0.0 if dist <= 0.001 else edy / dist
		world.enemies.apply_knockback(e, nx * impulse, ny * impulse)
		if stun_dur > 0.0:
			world.enemies.apply_stun(e, stun_dur)
		if min_exit_radius > 0.0 and dist < min_exit_radius:
			var tx: float = ox + nx * min_exit_radius
			var ty: float = oy + ny * min_exit_radius
			var pad: float = world.enemies.radius[e] + 8.0
			if is_circ:
				var max_r: float = maxf(64.0, world.arena_radius - pad)
				var cl: Vector2 = SimCollision.clamp_to_circle(tx, ty, max_r)
				world.enemies.x[e] = cl.x
				world.enemies.y[e] = cl.y
			else:
				world.enemies.x[e] = clampf(tx, pad, width - pad)
				world.enemies.y[e] = clampf(ty, pad, height - pad)


static func facing_sign(value: int) -> int:
	return -1 if value == 255 else 1


static func _segment_hits_circle(x0: float, y0: float, x1: float, y1: float, cx: float, cy: float, radius: float) -> bool:
	return SimCollision.point_to_segment(cx, cy, x0, y0, x1, y1) <= radius


static func hypot(dx: float, dy: float) -> float:
	return sqrt(dx * dx + dy * dy)
