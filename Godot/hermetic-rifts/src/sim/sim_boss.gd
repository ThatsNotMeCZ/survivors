class_name SimBoss
extends RefCounted


static func init_state(world: SimWorld, enemy_index: int, ai: Dictionary) -> void:
	var boss: BossState = world.boss
	boss.reset()
	boss.enemy_index = enemy_index
	var attacks: Array = DictUtil.a(ai, "attacks")
	for k: int in mini(attacks.size(), BossState.MAX_ATTACKS):
		var atk: Dictionary = attacks[k]
		var t: String = String(atk.get("type", ""))
		if t == "chain_anchor":
			boss.tether_dps = float(atk.get("tetherDps", 18.0))
			boss.tether_range = float(atk.get("range", 280.0))
		var initial: float = float(atk.get("initialCooldown", 0.0))
		if initial > 0.0:
			boss.cooldowns[k] = initial
			continue
		if t == "bolt" or t == "fan":
			boss.cooldowns[k] = 0.8
		elif t == "summon" or t == "chain_anchor":
			boss.cooldowns[k] = 2.4 + float(k) * 0.6
		else:
			boss.cooldowns[k] = 1.6 + float(k) * 1.1


static func default_anim(type: String) -> String:
	match type:
		"bolt":
			return "attack-bolt"
		"fan":
			return "attack-fan"
		"meteor", "geyser":
			return "attack-meteor"
		"cone":
			return "attack-sweep"
		"prison":
			return "attack-prison"
		"pulse", "ring_wave":
			return "attack-pulse"
		"laser":
			return "attack-laser"
		"summon", "chain_anchor":
			return "summon"
		"dash_slam":
			return "attack"
		_:
			return "attack"


static func _boss_hazard_style(def_id: String) -> int:
	if def_id == "cinder-heart" or def_id == "arch-alchemist":
		return BossHazardPool.STYLE_LAVA
	if def_id == "viridian-alchemist" or def_id == "voltaic-regent":
		return BossHazardPool.STYLE_AETHER
	return BossHazardPool.STYLE_FROST


static func boss_tint(def_id: String) -> int:
	if def_id == "cinder-heart":
		return 0xFF7A3A
	if def_id == "viridian-alchemist":
		return 0x4AB864
	if def_id == "voltaic-regent":
		return 0xE5B84B
	if def_id == "arch-alchemist":
		return 0xFFAE42
	return 0x7AD4FF


static func _boss_tint(def_id: String) -> int:
	return boss_tint(def_id)


static func step(
	world: SimWorld,
	i: int,
	ai: Dictionary,
	dx: float,
	dy: float,
	dist: float,
	dt: float,
	speed: float,
) -> void:
	var enemies: EnemyPool = world.enemies
	var boss: BossState = world.boss
	if boss.enemy_index != i:
		init_state(world, i, ai)
	if boss.emerge_remain > 0.0:
		boss.emerge_remain = maxf(0.0, boss.emerge_remain - dt)
		return
	var enrage: Dictionary = DictUtil.d(ai, "enrage")
	if not enrage.is_empty() and not boss.enraged and enemies.max_hp[i] > 0.0 and enemies.hp[i] / enemies.max_hp[i] <= float(enrage.get("hpPct", 0.5)):
		boss.enraged = true
		var attacks: Array = DictUtil.a(ai, "attacks")
		for k: int in mini(attacks.size(), BossState.MAX_ATTACKS):
			boss.cooldowns[k] *= float(enrage.get("cooldownMul", 0.75))
		world.fx.emit(FxIds.DEATH, enemies.x[i], enemies.y[i], 0xFF5533)
	var attacks_all: Array = DictUtil.a(ai, "attacks")
	for k: int in mini(attacks_all.size(), BossState.MAX_ATTACKS):
		if boss.cooldowns[k] > 0.0:
			boss.cooldowns[k] = maxf(0.0, boss.cooldowns[k] - dt)
	_tick_spire_tethers(world, i, ai, dt)
	if boss.phase == &"windup":
		_tick_windup(world, i, ai, dt)
		return
	if boss.phase == &"channel":
		_tick_channel(world, i, ai, dt)
		return
	if boss.phase == &"dash":
		_tick_dash(world, i, ai, dt)
		return
	if dist > 0.001:
		var nx: float = dx / dist
		var ny: float = dy / dist
		var mx: float = 0.0
		var my: float = 0.0
		var keep: float = float(ai.get("keep", 420.0))
		if dist > keep + 70.0:
			mx = nx * speed * dt
			my = ny * speed * dt
		elif dist < keep - 50.0:
			mx = -nx * speed * 0.75 * dt
			my = -ny * speed * 0.75 * dt
		else:
			mx = -ny * speed * 0.45 * dt
			my = nx * speed * 0.45 * dt
		enemies.x[i] += mx
		enemies.y[i] += my
	var dir_cfg: Dictionary = DictUtil.d(world.catalog.loop, "director")
	var max_fodder: int = int(dir_cfg.get("maxFodderCap", world.catalog.loop.get("maxFodder", 42)))
	for k: int in mini(attacks_all.size(), BossState.MAX_ATTACKS):
		if boss.cooldowns[k] > 0.0:
			continue
		var atk: Dictionary = attacks_all[k]
		var t: String = String(atk.get("type", ""))
		if t == "summon" or t == "chain_anchor":
			if world.counts_fodder >= max_fodder or _count_id(world, String(atk.get("entity", ""))) >= int(atk.get("maxAlive", 0)):
				boss.cooldowns[k] = 1.5
				continue
		if t == "cone" and dist > float(atk.get("range", 0.0)) * 1.15:
			continue
		_start_windup(world, i, ai, k, atk)
		break


static func _tick_spire_tethers(world: SimWorld, boss_idx: int, ai: Dictionary, dt: float) -> void:
	var enemies: EnemyPool = world.enemies
	var boss: BossState = world.boss
	var tether_dps: float = boss.tether_dps
	if tether_dps <= 0.0:
		for atk_v: Variant in DictUtil.a(ai, "attacks"):
			var atk: Dictionary = atk_v
			if String(atk.get("type", "")) == "chain_anchor":
				tether_dps = float(atk.get("tetherDps", 18.0))
				break
	if tether_dps <= 0.0:
		return
	var player: PlayerState = world.player
	if player.iframe_remain > 0.0 or player.dash_remain > 0.0 or player.parry_remain > 0.0:
		return
	var bx: float = enemies.x[boss_idx]
	var by: float = enemies.y[boss_idx]
	var hit_reach: float = player.radius + 10.0
	var dmg: float = tether_dps * SimLoop.difficulty_coeff(world) * dt
	for s: int in enemies.cap:
		if enemies.alive[s] == 0 or enemies.def_id[s] != "voltaic-spire":
			continue
		if SimCollision.point_to_segment(player.x, player.y, bx, by, enemies.x[s], enemies.y[s]) <= hit_reach:
			world.damage_player(dmg)
			return


static func _tick_windup(world: SimWorld, i: int, ai: Dictionary, dt: float) -> void:
	var enemies: EnemyPool = world.enemies
	var boss: BossState = world.boss
	boss.elapsed += dt
	var attacks: Array = DictUtil.a(ai, "attacks")
	if boss.active_attack < 0 or boss.active_attack >= attacks.size():
		boss.phase = &"none"
		boss.active_attack = -1
		enemies.windup[i] = 0.0
		return
	var atk: Dictionary = attacks[boss.active_attack]
	var t: String = String(atk.get("type", ""))
	if t == "bolt" or t == "laser":
		var follow: float = minf(1.0, dt * 8.0)
		boss.aim_x += (world.player.x - boss.aim_x) * follow
		boss.aim_y += (world.player.y - boss.aim_y) * follow
		enemies.aim_x[i] = boss.aim_x
		enemies.aim_y[i] = boss.aim_y
		var hit: Vector2 = _clamp_beam(world, enemies.x[i], enemies.y[i], boss.aim_x, boss.aim_y)
		boss.laser_end_x = hit.x
		boss.laser_end_y = hit.y
	enemies.windup[i] = maxf(0.01, boss.duration - boss.elapsed)
	if boss.elapsed >= boss.duration:
		_finish_windup(world, i, ai, atk)


static func _tick_channel(world: SimWorld, i: int, ai: Dictionary, dt: float) -> void:
	var enemies: EnemyPool = world.enemies
	var boss: BossState = world.boss
	var player: PlayerState = world.player
	boss.elapsed += dt
	var attacks: Array = DictUtil.a(ai, "attacks")
	if boss.active_attack < 0 or boss.active_attack >= attacks.size():
		boss.phase = &"none"
		return
	var atk: Dictionary = attacks[boss.active_attack]
	if String(atk.get("type", "")) != "laser":
		boss.phase = &"none"
		boss.active_attack = -1
		enemies.windup[i] = 0.0
		return
	enemies.windup[i] = maxf(0.01, boss.duration - boss.elapsed)
	var to_x: float = player.x - boss.aim_x
	var to_y: float = player.y - boss.aim_y
	var to_d: float = sqrt(to_x * to_x + to_y * to_y)
	if to_d > 0.001:
		var step_v: float = minf(to_d, float(atk.get("trackSpeed", 90.0)) * dt)
		boss.aim_x += (to_x / to_d) * step_v
		boss.aim_y += (to_y / to_d) * step_v
	if world.arena_shape == "circle":
		var clamped_aim: Vector2 = SimCollision.clamp_to_circle(boss.aim_x, boss.aim_y, maxf(64.0, world.arena_radius - 40.0))
		boss.aim_x = clamped_aim.x
		boss.aim_y = clamped_aim.y
	else:
		var bounds: Dictionary = world.catalog.world
		boss.aim_x = clampf(boss.aim_x, 40.0, float(bounds.get("width", 6000.0)) - 40.0)
		boss.aim_y = clampf(boss.aim_y, 40.0, float(bounds.get("height", 6000.0)) - 40.0)
	enemies.aim_x[i] = boss.aim_x
	enemies.aim_y[i] = boss.aim_y
	var end: Vector2 = _clamp_beam(world, enemies.x[i], enemies.y[i], boss.aim_x, boss.aim_y)
	boss.laser_end_x = end.x
	boss.laser_end_y = end.y
	var dist_end: float = sqrt((player.x - end.x) * (player.x - end.x) + (player.y - end.y) * (player.y - end.y))
	var dist_beam: float = SimCollision.point_to_segment(player.x, player.y, enemies.x[i], enemies.y[i], end.x, end.y)
	var hit_r: float = float(atk.get("hitRadius", 18.0)) + player.radius
	var coeff: float = SimLoop.difficulty_coeff(world)
	if player.iframe_remain <= 0.0 and (dist_end <= hit_r or dist_beam <= float(atk.get("hitRadius", 18.0)) * 0.75 + player.radius):
		world.damage_player(float(atk.get("dps", 22.0)) * coeff * dt)
	boss.trail_timer += dt
	var trail: Dictionary = DictUtil.d(atk, "trailPool")
	if boss.trail_timer >= float(atk.get("trailInterval", 0.28)):
		boss.trail_timer -= float(atk.get("trailInterval", 0.28))
		world.boss_hazards.spawn_pool(
			end.x,
			end.y,
			float(trail.get("radius", 46.0)),
			float(trail.get("duration", 3.2)),
			float(trail.get("dps", 10.0)) * coeff,
			float(trail.get("slowMul", 0.72)),
			_boss_hazard_style(enemies.def_id[i]),
		)
	if boss.elapsed >= boss.duration:
		_apply_recovery(world, ai, boss.active_attack, float(atk.get("recovery", 0.0)))
		boss.phase = &"none"
		boss.active_attack = -1
		enemies.windup[i] = 0.0
		enemies.anim_name[i] = ""


static func _tick_dash(world: SimWorld, i: int, ai: Dictionary, dt: float) -> void:
	var enemies: EnemyPool = world.enemies
	var boss: BossState = world.boss
	var attacks: Array = DictUtil.a(ai, "attacks")
	if boss.active_attack < 0 or boss.active_attack >= attacks.size():
		boss.phase = &"none"
		boss.active_attack = -1
		enemies.ai_state[i] = EnemyPool.AI_STATE_DEFAULT
		return
	var atk: Dictionary = attacks[boss.active_attack]
	if String(atk.get("type", "")) != "dash_slam":
		boss.phase = &"none"
		boss.active_attack = -1
		enemies.ai_state[i] = EnemyPool.AI_STATE_DEFAULT
		return
	boss.elapsed += dt
	var dash_spd: float = float(atk.get("dashSpeed", 520.0))
	enemies.x[i] += boss.dash_dir_x * dash_spd * dt
	enemies.y[i] += boss.dash_dir_y * dash_spd * dt
	if world.arena_shape == "circle":
		var clamped: Vector2 = SimCollision.clamp_to_circle(enemies.x[i], enemies.y[i], maxf(0.0, world.arena_radius - enemies.radius[i] - 6.0))
		enemies.x[i] = clamped.x
		enemies.y[i] = clamped.y
	if boss.elapsed >= boss.duration:
		var slam_r: float = float(atk.get("slamRadius", 96.0))
		var slam_dmg: float = float(atk.get("damage", 26.0)) * SimLoop.difficulty_coeff(world)
		var tint: int = _boss_tint(enemies.def_id[i])
		world.fx.emit(FxIds.STRIKE, enemies.x[i], enemies.y[i], tint, slam_r)
		var player: PlayerState = world.player
		if player.iframe_remain <= 0.0 and player.dash_remain <= 0.0 and player.parry_remain <= 0.0:
			if SimCollision.circles_overlap(enemies.x[i], enemies.y[i], slam_r, player.x, player.y, player.radius):
				world.fx.emit(FxIds.HURT, player.x, player.y, tint)
				world.damage_player(slam_dmg)
		boss.counts["dash_slam"] = int(boss.counts.get("dash_slam", 0)) + 1
		_apply_recovery(world, ai, boss.active_attack, float(atk.get("recovery", 0.0)))
		boss.phase = &"none"
		boss.active_attack = -1
		enemies.ai_state[i] = EnemyPool.AI_STATE_DEFAULT
		enemies.attack_remain[i] = 0.25
		enemies.anim_name[i] = ""


static func _start_windup(world: SimWorld, i: int, ai: Dictionary, attack_index: int, atk: Dictionary) -> void:
	var enemies: EnemyPool = world.enemies
	var boss: BossState = world.boss
	var player: PlayerState = world.player
	var cd_mul: float = float(DictUtil.d(ai, "enrage").get("cooldownMul", 1.0)) if boss.enraged else 1.0
	boss.cooldowns[attack_index] = float(atk.get("cooldown", 1.0)) * cd_mul
	boss.active_attack = attack_index
	boss.phase = &"windup"
	boss.elapsed = 0.0
	boss.duration = maxf(0.1, float(atk.get("windup", 0.35)))
	boss.aim_x = player.x
	boss.aim_y = player.y
	boss.laser_end_x = player.x
	boss.laser_end_y = player.y
	enemies.aim_x[i] = player.x
	enemies.aim_y[i] = player.y
	enemies.windup[i] = boss.duration
	var t: String = String(atk.get("type", ""))
	enemies.anim_name[i] = String(atk.get("anim", default_anim(t)))
	var bx: float = enemies.x[i]
	var by: float = enemies.y[i]
	var dx: float = player.x - bx
	var dy: float = player.y - by
	var dist: float = sqrt(dx * dx + dy * dy)
	if dist <= 0.0:
		dist = 1.0
	var dir_x: float = dx / dist
	var dir_y: float = dy / dist
	boss.dash_dir_x = dir_x
	boss.dash_dir_y = dir_y
	var coeff: float = SimLoop.difficulty_coeff(world)
	if t == "meteor" or t == "geyser":
		_spawn_geysers(world, i, atk, t, coeff)
	elif t == "prison":
		world.boss_hazards.spawn_prison(
			player.x,
			player.y,
			float(atk.get("radius", 70.0)),
			float(atk.get("delay", 0.7)),
			float(atk.get("damage", 16.0)) * coeff,
			float(atk.get("rootDuration", 1.35)),
		)
		boss.counts["prison"] = int(boss.counts.get("prison", 0)) + 1
	elif t == "cone":
		world.boss_hazards.spawn_cone(
			bx,
			by,
			dir_x,
			dir_y,
			float(atk.get("range", 340.0)),
			float(atk.get("angle", 70.0)) * PI / 180.0,
			boss.duration,
			float(atk.get("lingering", 0.55)),
			float(atk.get("damage", 16.0)) * coeff,
			float(atk.get("slowMul", 0.55)),
			float(atk.get("slowDuration", 1.4)),
		)
		boss.counts["cone"] = int(boss.counts.get("cone", 0)) + 1
	elif t == "pulse":
		world.boss_hazards.spawn_pulse(
			bx,
			by,
			float(atk.get("radius", 620.0)),
			boss.duration,
			float(atk.get("damage", 22.0)) * coeff,
			float(atk.get("slowMul", 0.6)),
			float(atk.get("slowDuration", 1.2)),
		)
		boss.counts["pulse"] = int(boss.counts.get("pulse", 0)) + 1


static func _spawn_geysers(world: SimWorld, i: int, atk: Dictionary, t: String, coeff: float) -> void:
	var enemies: EnemyPool = world.enemies
	var boss: BossState = world.boss
	var player: PlayerState = world.player
	var bx: float = enemies.x[i]
	var by: float = enemies.y[i]
	var count: int = maxi(1, int(atk.get("count", 1)))
	var rad: float = float(atk.get("radius", 52.0))
	var delay: float = float(atk.get("delay", 1.0))
	var dmg: float = float(atk.get("damage", 22.0)) * coeff
	var pool_cfg: Dictionary = DictUtil.d(atk, "pool")
	var p_dur: float = float(pool_cfg.get("duration", 0.0))
	var p_rad: float = float(pool_cfg.get("radius", rad))
	var p_dps: float = float(pool_cfg.get("dps", 0.0)) * coeff
	var p_slow: float = float(pool_cfg.get("slowMul", 1.0))
	var fx_style: int = _boss_hazard_style(enemies.def_id[i])
	var pred_x: float = player.x + player.vx * 0.4
	var pred_y: float = player.y + player.vy * 0.4
	var pred_count: int = 1 if count <= 4 else 2
	var is_circle: bool = world.arena_shape == "circle"
	var max_r: float = maxf(64.0, world.arena_radius - rad - 8.0)
	var bounds: Dictionary = world.catalog.world
	var pad: float = rad + 16.0
	var width: float = float(bounds.get("width", 6000.0))
	var height: float = float(bounds.get("height", 6000.0))
	for k: int in count:
		var gx: float = pred_x
		var gy: float = pred_y
		if k > 0 and k < pred_count:
			var p_ang: float = world.randf() * TAU
			gx = pred_x + cos(p_ang) * (rad * 1.45)
			gy = pred_y + sin(p_ang) * (rad * 1.45)
		elif k >= pred_count:
			var ring_idx: int = k - pred_count
			var ring_total: int = maxi(1, count - pred_count)
			var ang: float = (float(ring_idx) / float(ring_total)) * TAU + world.run_time * 0.9
			var ring_r: float = 140.0 + world.randf() * 140.0
			gx = bx + cos(ang) * ring_r
			gy = by + sin(ang) * ring_r
		if is_circle:
			var clamped: Vector2 = SimCollision.clamp_to_circle(gx, gy, max_r)
			gx = clamped.x
			gy = clamped.y
		else:
			gx = clampf(gx, pad, width - pad)
			gy = clampf(gy, pad, height - pad)
		world.boss_hazards.spawn_meteor(gx, gy, rad, delay, dmg, fx_style, p_dur, p_rad, p_dps, p_slow)
	var count_key: String = "geyser" if t == "geyser" else "meteor"
	boss.counts[count_key] = int(boss.counts.get(count_key, 0)) + 1


static func _finish_windup(world: SimWorld, i: int, ai: Dictionary, atk: Dictionary) -> void:
	var enemies: EnemyPool = world.enemies
	var boss: BossState = world.boss
	var bx: float = enemies.x[i]
	var by: float = enemies.y[i]
	var dx: float = boss.aim_x - bx
	var dy: float = boss.aim_y - by
	var base_angle: float = atan2(dy, dx)
	var muzzle: float = enemies.radius[i] + 10.0
	var tint: int = _boss_tint(enemies.def_id[i])
	var coeff: float = SimLoop.difficulty_coeff(world)
	var t: String = String(atk.get("type", ""))
	if t == "bolt":
		var nx: float = cos(base_angle)
		var ny: float = sin(base_angle)
		var px: float = bx + nx * muzzle
		var py: float = by + ny * muzzle
		var proj: Dictionary = DictUtil.d(atk, "projectile")
		world.projectiles.spawn(
			px, py, nx, ny,
			float(proj.get("speed", 380.0)),
			float(proj.get("lifetime", 1.75)),
			float(proj.get("radius", 9.0)),
			float(proj.get("damage", 15.0)) * coeff,
			ProjectilePool.TEAM_ENEMY,
		)
		world.fx.emit(FxIds.MUZZLE, px, py, tint)
		boss.counts["bolt"] = int(boss.counts.get("bolt", 0)) + 1
	elif t == "fan":
		var spread_rad: float = float(atk.get("spread", 70.0)) * PI / 180.0
		var count: int = maxi(1, int(atk.get("count", 5)))
		var proj: Dictionary = DictUtil.d(atk, "projectile")
		for k: int in count:
			var frac: float = 0.0 if count == 1 else float(k) / float(count - 1) - 0.5
			var ang: float = base_angle + frac * spread_rad
			var nx: float = cos(ang)
			var ny: float = sin(ang)
			var px: float = bx + nx * muzzle
			var py: float = by + ny * muzzle
			world.projectiles.spawn(
				px, py, nx, ny,
				float(proj.get("speed", 260.0)),
				float(proj.get("lifetime", 1.8)),
				float(proj.get("radius", 8.0)),
				float(proj.get("damage", 11.0)) * coeff,
				ProjectilePool.TEAM_ENEMY,
			)
		world.fx.emit(FxIds.MUZZLE, bx + cos(base_angle) * muzzle, by + sin(base_angle) * muzzle, tint)
		boss.counts["fan"] = int(boss.counts.get("fan", 0)) + 1
	elif t == "summon":
		var alive: int = _count_id(world, String(atk.get("entity", "")))
		var can_spawn: int = maxi(0, mini(int(atk.get("count", 0)), int(atk.get("maxAlive", 0)) - alive))
		var def: Dictionary = world.catalog.entity(String(atk.get("entity", "")))
		var ent_rad: float = float(DictUtil.d(def, "stats").get("radius", 12.0))
		var ring: float = enemies.radius[i] + ent_rad + 28.0
		for s: int in can_spawn:
			var ang: float = (float(s) / float(maxi(1, can_spawn))) * TAU + world.run_time * 1.7
			var pos: Vector2 = _clamp_summon_pos(world, bx + cos(ang) * ring, by + sin(ang) * ring, ent_rad + 24.0)
			if SimEnemies.spawn(world, def, pos.x, pos.y) >= 0:
				world.fx.emit(FxIds.MUZZLE, pos.x, pos.y, tint)
		boss.counts["summon"] = int(boss.counts.get("summon", 0)) + 1
	elif t == "chain_anchor":
		var entity_id: String = String(atk.get("entity", "voltaic-spire"))
		var alive: int = _count_id(world, entity_id)
		var can_spawn: int = maxi(0, mini(int(atk.get("count", 2)), int(atk.get("maxAlive", 4)) - alive))
		var def: Dictionary = world.catalog.entity(entity_id)
		var ent_rad: float = float(DictUtil.d(def, "stats").get("radius", 14.0))
		for s: int in can_spawn:
			var ang: float = (float(s) / float(maxi(1, can_spawn))) * TAU + world.run_time * 1.3
			var ring_dist: float = 220.0 + world.randf() * 80.0
			var pos: Vector2 = _clamp_summon_pos(world, bx + cos(ang) * ring_dist, by + sin(ang) * ring_dist, ent_rad + 24.0)
			if SimEnemies.spawn(world, def, pos.x, pos.y) >= 0:
				world.fx.emit(FxIds.MUZZLE, pos.x, pos.y, tint)
		boss.tether_dps = float(atk.get("tetherDps", 18.0))
		boss.tether_range = float(atk.get("range", 280.0))
		boss.counts["chain_anchor"] = int(boss.counts.get("chain_anchor", 0)) + 1
	elif t == "ring_wave":
		var proj: Dictionary = DictUtil.d(atk, "projectile")
		var ring_speed: float = float(atk.get("speed", proj.get("speed", 240.0)))
		var max_r: float = float(atk.get("maxRadius", 520.0))
		var thick: float = float(atk.get("thickness", 28.0))
		var ring_dmg: float = float(atk.get("damage", proj.get("damage", 14.0))) * coeff
		world.boss_hazards.spawn_ring(
			bx,
			by,
			enemies.radius[i],
			max_r,
			thick,
			ring_speed,
			ring_dmg,
			_boss_hazard_style(enemies.def_id[i]),
		)
		var p_count: int = int(atk.get("count", 0))
		if not proj.is_empty() and p_count > 0:
			var p_speed: float = float(proj.get("speed", 240.0))
			var p_life: float = float(proj.get("lifetime", 2.2))
			var p_rad: float = float(proj.get("radius", 8.0))
			var p_dmg: float = float(proj.get("damage", 13.0)) * coeff
			for k: int in p_count:
				var ang: float = base_angle + (float(k) / float(p_count)) * TAU
				var nx: float = cos(ang)
				var ny: float = sin(ang)
				world.projectiles.spawn(
					bx + nx * muzzle,
					by + ny * muzzle,
					nx,
					ny,
					p_speed,
					p_life,
					p_rad,
					p_dmg,
					ProjectilePool.TEAM_ENEMY,
				)
		world.fx.emit(FxIds.MUZZLE, bx, by, tint)
		boss.counts["ring_wave"] = int(boss.counts.get("ring_wave", 0)) + 1
	elif t == "dash_slam":
		boss.phase = &"dash"
		boss.elapsed = 0.0
		boss.duration = maxf(0.1, float(atk.get("dashDuration", 0.42)))
		enemies.windup[i] = 0.0
		enemies.ai_state[i] = EnemyPool.AI_STATE_ACTIVE
		var dist_d: float = sqrt(dx * dx + dy * dy)
		if dist_d > 0.001:
			boss.dash_dir_x = dx / dist_d
			boss.dash_dir_y = dy / dist_d
		return
	elif t == "laser":
		boss.phase = &"channel"
		boss.elapsed = 0.0
		boss.duration = float(atk.get("duration", 1.8))
		boss.trail_timer = 0.0
		enemies.windup[i] = boss.duration
		boss.counts["laser"] = int(boss.counts.get("laser", 0)) + 1
		var nx: float = cos(base_angle)
		var ny: float = sin(base_angle)
		boss.aim_x = bx + nx * muzzle
		boss.aim_y = by + ny * muzzle
		var hit: Vector2 = _clamp_beam(world, bx, by, boss.aim_x, boss.aim_y)
		boss.laser_end_x = hit.x
		boss.laser_end_y = hit.y
		return
	_apply_recovery(world, ai, boss.active_attack, float(atk.get("recovery", 0.0)))
	boss.phase = &"none"
	boss.active_attack = -1
	enemies.windup[i] = 0.0
	enemies.attack_remain[i] = 0.25


static func _clamp_summon_pos(world: SimWorld, px: float, py: float, pad: float) -> Vector2:
	if world.arena_shape == "circle":
		return SimCollision.clamp_to_circle(px, py, maxf(64.0, world.arena_radius - pad))
	var bounds: Dictionary = world.catalog.world
	return Vector2(
		clampf(px, pad, float(bounds.get("width", 6000.0)) - pad),
		clampf(py, pad, float(bounds.get("height", 6000.0)) - pad),
	)


static func _apply_recovery(world: SimWorld, ai: Dictionary, except_index: int, recovery: float) -> void:
	if recovery <= 0.0:
		return
	var boss: BossState = world.boss
	var attacks: Array = DictUtil.a(ai, "attacks")
	for k: int in mini(attacks.size(), BossState.MAX_ATTACKS):
		if k == except_index:
			continue
		boss.cooldowns[k] = maxf(boss.cooldowns[k], recovery)


static func _count_id(world: SimWorld, def_id: String) -> int:
	var n: int = 0
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0:
			continue
		if world.enemies.def_id[i] == def_id:
			n += 1
	return n


static func _clamp_beam(world: SimWorld, x0: float, y0: float, x1: float, y1: float) -> Vector2:
	var dx: float = x1 - x0
	var dy: float = y1 - y0
	var dist: float = sqrt(dx * dx + dy * dy)
	if dist < 0.001:
		return Vector2(x1, y1)
	var ux: float = dx / dist
	var uy: float = dy / dist
	var best_t: float = dist
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		if obs.type != &"pillar":
			continue
		var ox: float = obs.x - x0
		var oy: float = obs.y - y0
		var proj: float = ox * ux + oy * uy
		if proj <= 0.0 or proj >= best_t:
			continue
		var perp_sq: float = ox * ox + oy * oy - proj * proj
		var r_sq: float = obs.radius * obs.radius
		if perp_sq <= r_sq:
			var hit_t: float = maxf(0.0, proj - sqrt(r_sq - perp_sq))
			if hit_t < best_t:
				best_t = hit_t
	return Vector2(x0 + ux * best_t, y0 + uy * best_t)
