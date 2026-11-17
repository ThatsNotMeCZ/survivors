class_name SimBoss
extends RefCounted


static func init_state(world: SimWorld, enemy_index: int, ai: Dictionary) -> void:
	var boss: BossState = world.boss
	boss.reset()
	boss.enemy_index = enemy_index
	var attacks: Array = DictUtil.a(ai, "attacks")
	for k: int in mini(attacks.size(), BossState.MAX_ATTACKS):
		var atk: Dictionary = attacks[k]
		var initial: float = float(atk.get("initialCooldown", 0.0))
		if initial > 0.0:
			boss.cooldowns[k] = initial
			continue
		var t: String = String(atk.get("type", ""))
		if t == "bolt" or t == "fan":
			boss.cooldowns[k] = 0.8
		elif t == "summon":
			boss.cooldowns[k] = 2.4 + float(k) * 0.6
		else:
			boss.cooldowns[k] = 1.6 + float(k) * 1.1


static func default_anim(type: String) -> String:
	match type:
		"bolt":
			return "attack-bolt"
		"fan":
			return "attack-fan"
		"meteor":
			return "attack-meteor"
		"cone":
			return "attack-sweep"
		"prison":
			return "attack-prison"
		"pulse":
			return "attack-pulse"
		"laser":
			return "attack-laser"
		"summon":
			return "summon"
		_:
			return "attack"


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
	var enrage: Dictionary = DictUtil.d(ai, "enrage")
	if not enrage.is_empty() and not boss.enraged and enemies.max_hp[i] > 0.0 and enemies.hp[i] / enemies.max_hp[i] <= float(enrage.get("hpPct", 0.5)):
		boss.enraged = true
		var attacks: Array = DictUtil.a(ai, "attacks")
		for k: int in attacks.size():
			boss.cooldowns[k] *= float(enrage.get("cooldownMul", 0.75))
		world.fx.emit(FxIds.DEATH, enemies.x[i], enemies.y[i], 0xFF5533)
	var attacks_all: Array = DictUtil.a(ai, "attacks")
	for k: int in mini(attacks_all.size(), BossState.MAX_ATTACKS):
		if boss.cooldowns[k] > 0.0:
			boss.cooldowns[k] = maxf(0.0, boss.cooldowns[k] - dt)
	if boss.phase == &"windup":
		_tick_windup(world, i, ai, dt)
		return
	if boss.phase == &"channel":
		_tick_channel(world, i, ai, dt)
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
	for k: int in mini(attacks_all.size(), BossState.MAX_ATTACKS):
		if boss.cooldowns[k] > 0.0:
			continue
		var atk: Dictionary = attacks_all[k]
		var t: String = String(atk.get("type", ""))
		if t == "summon":
			if world.counts_fodder >= int(world.catalog.loop.get("maxFodder", 24)) or _count_id(world, String(atk.get("entity", ""))) >= int(atk.get("maxAlive", 0)):
				boss.cooldowns[k] = 1.5
				continue
		if t == "cone" and dist > float(atk.get("range", 0.0)) * 1.15:
			continue
		_start_windup(world, i, ai, k, atk)
		break


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
	var bounds: Dictionary = world.catalog.world
	boss.aim_x = clampf(boss.aim_x, 40.0, float(bounds.get("width", 2560.0)) - 40.0)
	boss.aim_y = clampf(boss.aim_y, 40.0, float(bounds.get("height", 2560.0)) - 40.0)
	enemies.aim_x[i] = boss.aim_x
	enemies.aim_y[i] = boss.aim_y
	var end: Vector2 = _clamp_beam(world, enemies.x[i], enemies.y[i], boss.aim_x, boss.aim_y)
	boss.laser_end_x = end.x
	boss.laser_end_y = end.y
	var dist_end: float = sqrt((player.x - end.x) * (player.x - end.x) + (player.y - end.y) * (player.y - end.y))
	var dist_beam: float = SimCollision.point_to_segment(player.x, player.y, enemies.x[i], enemies.y[i], end.x, end.y)
	var hit_r: float = float(atk.get("hitRadius", 18.0)) + player.radius
	if player.iframe_remain <= 0.0 and (dist_end <= hit_r or dist_beam <= float(atk.get("hitRadius", 18.0)) * 0.75 + player.radius):
		world.damage_player(float(atk.get("dps", 22.0)) * world.coefficient * dt)
	boss.trail_timer += dt
	var trail: Dictionary = DictUtil.d(atk, "trailPool")
	if boss.trail_timer >= float(atk.get("trailInterval", 0.28)):
		boss.trail_timer -= float(atk.get("trailInterval", 0.28))
		world.boss_hazards.spawn_pool(
			end.x,
			end.y,
			float(trail.get("radius", 46.0)),
			float(trail.get("duration", 3.2)),
			float(trail.get("dps", 10.0)) * world.coefficient,
			float(trail.get("slowMul", 0.72)),
			BossHazardPool.STYLE_FROST,
		)
	if boss.elapsed >= boss.duration:
		_apply_recovery(world, ai, boss.active_attack, float(atk.get("recovery", 0.0)))
		boss.phase = &"none"
		boss.active_attack = -1
		enemies.windup[i] = 0.0
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
	if t == "meteor":
		var is_cinder: bool = enemies.def_id[i] == "cinder-heart"
		var pool: Dictionary = DictUtil.d(atk, "pool")
		world.boss_hazards.spawn_meteor(
			player.x,
			player.y,
			float(atk.get("radius", 70.0)),
			float(atk.get("delay", 0.85)),
			float(atk.get("damage", 18.0)) * world.coefficient,
			BossHazardPool.STYLE_LAVA if is_cinder else BossHazardPool.STYLE_FROST,
			float(pool.get("duration", 0.0)),
			float(pool.get("radius", atk.get("radius", 70.0))),
			float(pool.get("dps", 0.0)) * world.coefficient,
			float(pool.get("slowMul", 1.0)),
		)
		boss.counts["meteor"] = int(boss.counts.get("meteor", 0)) + 1
	elif t == "prison":
		world.boss_hazards.spawn_prison(
			player.x,
			player.y,
			float(atk.get("radius", 70.0)),
			float(atk.get("delay", 0.7)),
			float(atk.get("damage", 16.0)) * world.coefficient,
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
			float(atk.get("damage", 16.0)) * world.coefficient,
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
			float(atk.get("damage", 22.0)) * world.coefficient,
			float(atk.get("slowMul", 0.6)),
			float(atk.get("slowDuration", 1.2)),
		)
		boss.counts["pulse"] = int(boss.counts.get("pulse", 0)) + 1


static func _finish_windup(world: SimWorld, i: int, ai: Dictionary, atk: Dictionary) -> void:
	var enemies: EnemyPool = world.enemies
	var boss: BossState = world.boss
	var bx: float = enemies.x[i]
	var by: float = enemies.y[i]
	var dx: float = boss.aim_x - bx
	var dy: float = boss.aim_y - by
	var base_angle: float = atan2(dy, dx)
	var muzzle: float = enemies.radius[i] + 10.0
	var tint: int = 0xFF7A3A if enemies.def_id[i] == "cinder-heart" else 0x7AD4FF
	var t: String = String(atk.get("type", ""))
	if t == "bolt":
		var nx: float = cos(base_angle)
		var ny: float = sin(base_angle)
		var px: float = bx + nx * muzzle
		var py: float = by + ny * muzzle
		var proj: Dictionary = DictUtil.d(atk, "projectile")
		world.projectiles.spawn(
			px, py, nx, ny,
			float(proj.get("speed", 420.0)),
			float(proj.get("lifetime", 1.35)),
			float(proj.get("radius", 7.0)),
			float(proj.get("damage", 14.0)) * world.coefficient,
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
				float(proj.get("speed", 360.0)),
				float(proj.get("lifetime", 1.15)),
				float(proj.get("radius", 6.0)),
				float(proj.get("damage", 8.0)) * world.coefficient,
				ProjectilePool.TEAM_ENEMY,
			)
		world.fx.emit(FxIds.MUZZLE, bx + cos(base_angle) * muzzle, by + sin(base_angle) * muzzle, tint)
		boss.counts["fan"] = int(boss.counts.get("fan", 0)) + 1
	elif t == "summon":
		var alive: int = _count_id(world, String(atk.get("entity", "")))
		var can_spawn: int = maxi(0, mini(int(atk.get("count", 0)), int(atk.get("maxAlive", 0)) - alive))
		var def: Dictionary = world.catalog.entity(String(atk.get("entity", "")))
		var bounds: Dictionary = world.catalog.world
		var pad: float = float(DictUtil.d(def, "stats").get("radius", 12.0)) + 24.0
		var ring: float = enemies.radius[i] + float(DictUtil.d(def, "stats").get("radius", 12.0)) + 28.0
		for s: int in can_spawn:
			var ang: float = (float(s) / float(maxi(1, can_spawn))) * TAU + world.run_time * 1.7
			var sx: float = clampf(bx + cos(ang) * ring, pad, float(bounds.get("width", 2560.0)) - pad)
			var sy: float = clampf(by + sin(ang) * ring, pad, float(bounds.get("height", 2560.0)) - pad)
			if SimEnemies.spawn(world, def, sx, sy) >= 0:
				world.fx.emit(FxIds.MUZZLE, sx, sy, tint)
		boss.counts["summon"] = int(boss.counts.get("summon", 0)) + 1
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
