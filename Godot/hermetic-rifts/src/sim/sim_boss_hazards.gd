class_name SimBossHazards
extends RefCounted


static func step(world: SimWorld, dt: float) -> void:
	var pool: BossHazardPool = world.boss_hazards
	var player: PlayerState = world.player
	if world.boss_defeated or (world.boss_spawned and world.counts_boss == 0):
		pool.clear()
		return
	for i: int in pool.cap:
		if pool.alive[i] == 0:
			continue
		pool.elapsed[i] = pool.elapsed[i] + dt
		var kind: int = pool.kind[i]
		if kind == BossHazardPool.HAZ_METEOR:
			if pool.elapsed[i] >= pool.duration[i]:
				var tint: int = 0xFF7A3A if pool.style[i] == BossHazardPool.STYLE_LAVA else (0x6BD968 if pool.style[i] == BossHazardPool.STYLE_AETHER else 0x7AD4FF)
				world.fx.emit(FxIds.STRIKE, pool.x[i], pool.y[i], tint)
				if player.iframe_remain <= 0.0 and SimCollision.circles_overlap(pool.x[i], pool.y[i], pool.radius[i], player.x, player.y, player.radius):
					world.fx.emit(FxIds.HURT, player.x, player.y, tint)
					world.damage_player(pool.damage[i])
				if pool.pool_duration[i] > 0.0:
					pool.kind[i] = BossHazardPool.HAZ_POOL
					pool.state[i] = 0
					pool.radius[i] = pool.pool_radius[i]
					pool.elapsed[i] = 0.0
					pool.duration[i] = pool.pool_duration[i]
					pool.damage[i] = pool.pool_dps[i]
					pool.slow_mul[i] = pool.pool_slow[i]
				else:
					pool.alive[i] = 0
			continue
		if kind == BossHazardPool.HAZ_POOL:
			if player.iframe_remain <= 0.0 and player.dash_remain <= 0.0 and SimCollision.circles_overlap(pool.x[i], pool.y[i], pool.radius[i], player.x, player.y, player.radius):
				world.damage_player(pool.damage[i] * dt, true)
				var slow: float = 1.0 - (1.0 - pool.slow_mul[i]) * (1.0 - world.stats.hazard_resist)
				SimStatus.apply_slow(player, slow, 0.25)
			if pool.elapsed[i] >= pool.duration[i]:
				pool.alive[i] = 0
			continue
		if kind == BossHazardPool.HAZ_PRISON:
			if pool.state[i] == 0:
				if pool.elapsed[i] >= pool.duration[i]:
					world.fx.emit(FxIds.STRIKE, pool.x[i], pool.y[i], 0x88EEFF)
					if player.iframe_remain <= 0.0 and SimCollision.circles_overlap(pool.x[i], pool.y[i], pool.radius[i], player.x, player.y, player.radius):
						world.fx.emit(FxIds.HURT, player.x, player.y, 0x55DDFF)
						world.damage_player(pool.damage[i])
						SimStatus.apply_root(player, pool.root_duration[i])
					pool.state[i] = 1
					pool.elapsed[i] = 0.0
					pool.duration[i] = 0.45
			elif pool.elapsed[i] >= pool.duration[i]:
				pool.alive[i] = 0
			continue
		if kind == BossHazardPool.HAZ_CONE:
			if pool.state[i] == 0:
				if pool.elapsed[i] >= pool.duration[i]:
					if player.iframe_remain <= 0.0 and BossHazardPool.point_in_cone(player.x, player.y, player.radius, pool.x[i], pool.y[i], pool.dir_x[i], pool.dir_y[i], pool.radius[i], pool.angle[i]):
						world.fx.emit(FxIds.HURT, player.x, player.y, 0x7AD4FF)
						world.damage_player(pool.damage[i])
						SimStatus.apply_slow(player, pool.slow_mul[i], pool.slow_duration[i])
					pool.state[i] = 1
					pool.elapsed[i] = 0.0
					pool.duration[i] = maxf(0.25, pool.pool_duration[i])
			else:
				if player.iframe_remain <= 0.0 and BossHazardPool.point_in_cone(player.x, player.y, player.radius, pool.x[i], pool.y[i], pool.dir_x[i], pool.dir_y[i], pool.radius[i], pool.angle[i]):
					SimStatus.apply_slow(player, pool.slow_mul[i], 0.35)
				if pool.elapsed[i] >= pool.duration[i]:
					pool.alive[i] = 0
			continue
		if kind == BossHazardPool.HAZ_PULSE:
			if pool.state[i] == 0:
				var b_idx: int = world.boss.enemy_index
				if b_idx >= 0 and world.enemies.alive[b_idx] != 0:
					pool.x[i] = world.enemies.x[b_idx]
					pool.y[i] = world.enemies.y[b_idx]
				if pool.elapsed[i] >= pool.duration[i]:
					world.fx.emit(FxIds.STRIKE, pool.x[i], pool.y[i], 0x66DDFF)
					var dist: float = sqrt((player.x - pool.x[i]) ** 2.0 + (player.y - pool.y[i]) ** 2.0)
					if player.iframe_remain <= 0.0 and dist <= pool.radius[i] + player.radius and not SimEnemies.pillar_blocks_shot(world, pool.x[i], pool.y[i], player.x, player.y):
						world.fx.emit(FxIds.HURT, player.x, player.y, 0x55DDFF)
						world.damage_player(pool.damage[i])
						SimStatus.apply_slow(player, pool.slow_mul[i], pool.slow_duration[i])
					pool.state[i] = 1
					pool.elapsed[i] = 0.0
					pool.duration[i] = pool.pool_duration[i]
			elif pool.elapsed[i] >= pool.duration[i]:
				pool.alive[i] = 0
			continue
		if kind == BossHazardPool.HAZ_RING:
			var expand_speed: float = maxf(1.0, pool.pool_dps[i])
			pool.radius[i] += expand_speed * dt
			var dist_ring: float = sqrt((player.x - pool.x[i]) ** 2.0 + (player.y - pool.y[i]) ** 2.0)
			var half_thick: float = maxf(14.0, pool.angle[i] * 0.5)
			if pool.state[i] == 0 and player.iframe_remain <= 0.0 and player.dash_remain <= 0.0 and player.parry_remain <= 0.0:
				if absf(dist_ring - pool.radius[i]) <= half_thick + player.radius:
					world.fx.emit(FxIds.HURT, player.x, player.y, 0xFFE870)
					world.damage_player(pool.damage[i])
					pool.state[i] = 1
			if pool.radius[i] >= pool.pool_radius[i] or pool.elapsed[i] >= pool.duration[i]:
				pool.alive[i] = 0
			continue
		if kind == BossHazardPool.HAZ_SPIRE_TETHER:
			if pool.duration[i] > 0.0 and pool.elapsed[i] >= pool.duration[i]:
				pool.alive[i] = 0
