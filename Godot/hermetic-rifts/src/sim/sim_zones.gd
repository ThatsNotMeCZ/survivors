class_name SimZones
extends RefCounted


static func step(world: SimWorld, dt: float) -> void:
	if world.decoy.active:
		world.decoy.remain -= dt
		if world.decoy.remain <= 0.0:
			world.decoy.reset()
	for i: int in world.zones.cap:
		if world.zones.alive[i] == 0:
			continue
		world.zones.remain[i] -= dt
		var k: int = world.zones.kind[i]
		match k:
			ZonePool.ZONE_LINE:
				_tick_line(world, i, dt)
				if world.zones.remain[i] <= 0.0:
					world.zones.alive[i] = 0
			ZonePool.ZONE_STRIKE:
				if world.zones.remain[i] <= 0.0:
					_detonate_strike(world, i)
					world.zones.alive[i] = 0
			ZonePool.ZONE_PRISM:
				_tick_prism(world, i)
				if world.zones.remain[i] <= 0.0:
					world.zones.alive[i] = 0
			ZonePool.ZONE_SOLAR_BEAM:
				_tick_solar_beam(world, i, dt)
				if world.zones.remain[i] <= 0.0:
					world.zones.alive[i] = 0
			ZonePool.ZONE_SMOKE_CLOUD:
				_tick_smoke_cloud(world, i)
				if world.zones.remain[i] <= 0.0:
					world.zones.alive[i] = 0
			ZonePool.ZONE_HEX_SIGIL:
				if world.zones.remain[i] <= 0.0:
					_detonate_hex_sigil(world, i)
					world.zones.alive[i] = 0
			_:
				if world.zones.remain[i] <= 0.0:
					world.zones.alive[i] = 0


static func player_speed_bonus(world: SimWorld) -> float:
	for i: int in world.zones.cap:
		if world.zones.alive[i] == 0 or world.zones.kind[i] != ZonePool.ZONE_FROZEN_PATCH:
			continue
		if SimCollision.circles_overlap(
			world.player.x,
			world.player.y,
			world.player.radius,
			world.zones.x[i],
			world.zones.y[i],
			world.zones.radius[i],
		):
			return world.zones.slow_mul[i] if world.zones.slow_mul[i] > 1.0 else 1.2
	return 1.0


static func _tick_line(world: SimWorld, index: int, dt: float) -> void:
	var half: float = world.zones.length[index] * 0.5
	var width: float = world.zones.width[index] * 0.5
	var fodder_only: bool = world.zones.fodder_only[index] != 0
	var dps: float = world.zones.damage[index]
	for e: int in world.enemies.cap:
		if world.enemies.alive[e] == 0:
			continue
		if fodder_only and world.enemies.role[e] != EnemyPool.ROLE_FODDER:
			continue
		if not _on_line(world.zones, index, world.enemies.x[e], world.enemies.y[e], world.enemies.radius[e] + width, half):
			continue
		world.enemies.apply_slow(e, world.zones.slow_mul[index], 0.2)
		if dps > 0.0:
			SimEnemies.apply_damage(world, e, dps * dt)
	if dps > 0.0:
		for i: int in world.obstacles.cap:
			if world.obstacles.alive[i] == 0:
				continue
			var obs: SimObstacle = world.obstacles.items[i]
			if obs.type != &"volatile" or obs.state != &"intact":
				continue
			if not _on_line(world.zones, index, obs.x, obs.y, obs.radius + width, half):
				continue
			SimObstacles.damage_volatile(world, i, dps * dt)


static func _detonate_strike(world: SimWorld, index: int) -> void:
	var x: float = world.zones.x[index]
	var y: float = world.zones.y[index]
	var radius: float = world.zones.radius[index]
	var is_crit: bool = world.randf() < world.stats.crit_chance
	var damage: float = world.zones.damage[index] * (world.stats.crit_mul if is_crit else 1.0)
	world.fx.emit(FxIds.CRUCIBLE_IMPACT, x, y, 0xFF4422 if is_crit else 0xFFC070, radius)
	var hit_any: bool = false
	for e: int in world.enemies.cap:
		if world.enemies.alive[e] == 0:
			continue
		if not SimCollision.circles_overlap(x, y, radius, world.enemies.x[e], world.enemies.y[e], world.enemies.radius[e]):
			continue
		world.fx.emit(FxIds.HIT, world.enemies.x[e], world.enemies.y[e], 0xFF4422 if is_crit else 0xFFF4C8)
		SimEnemies.apply_damage(world, e, damage)
		hit_any = true
	if is_crit and hit_any:
		world.trigger_on_crit()
	var is_sec_spec: bool = world.zones.flag_bits[index] != 0
	var elem: String = world.zones.element[index]
	SimObstacles.hit_aoe(world, x, y, radius, damage, is_sec_spec, elem)
	if is_sec_spec:
		SimAlchemy.trigger_surface_reaction(world, x, y, radius, is_sec_spec, elem)


static func _tick_prism(world: SimWorld, index: int) -> void:
	var zx: float = world.zones.x[index]
	var zy: float = world.zones.y[index]
	var zr: float = world.zones.radius[index]
	var split_count: int = maxi(2, int(round(world.zones.extra_a[index])))
	var spread_deg: float = world.zones.extra_b[index] if world.zones.extra_b[index] > 0.0 else 18.0
	var split_dmg: float = world.zones.damage[index]
	var rad_offset: float = deg_to_rad(spread_deg)
	var side_angles: Array[float] = [-rad_offset, rad_offset]
	if split_count > 3:
		var pairs: int = maxi(1, (split_count - 1) / 2)
		side_angles.clear()
		for s: int in range(1, pairs + 1):
			var frac: float = float(s) / float(pairs)
			side_angles.append(-rad_offset * frac)
			side_angles.append(rad_offset * frac)
	var projs: ProjectilePool = world.projectiles
	for p: int in projs.alive.size():
		if projs.alive[p] == 0 or projs.team[p] != ProjectilePool.TEAM_PLAYER:
			continue
		if (projs.flags[p] & ProjectilePool.FLAG_PRIMARY) == 0:
			continue
		if (projs.flags[p] & ProjectilePool.FLAG_SPLIT) != 0:
			continue
		if not SimCollision.circles_overlap(zx, zy, zr, projs.x[p], projs.y[p], projs.radius[p]):
			continue
		var pvx: float = projs.vx[p]
		var pvy: float = projs.vy[p]
		var p_speed: float = sqrt(pvx * pvx + pvy * pvy)
		if p_speed <= 0.001:
			continue
		projs.flags[p] |= ProjectilePool.FLAG_SPLIT
		var ray_dmg: float = split_dmg if split_dmg > 0.0 else projs.damage[p]
		if split_dmg > 0.0:
			projs.damage[p] = split_dmg
		var base_ang: float = atan2(pvy, pvx)
		var px: float = projs.x[p]
		var py: float = projs.y[p]
		var new_flags: int = projs.flags[p] | ProjectilePool.FLAG_SPLIT
		var has_dest: bool = (new_flags & ProjectilePool.FLAG_IMPACT) != 0
		var dest_dist: float = sqrt((projs.dest_x[p] - px) ** 2.0 + (projs.dest_y[p] - py) ** 2.0) if has_dest else 0.0
		for ang_off: float in side_angles:
			var ang: float = base_ang + ang_off
			var dx: float = cos(ang)
			var dy: float = sin(ang)
			var destx: float = px + dx * dest_dist if has_dest else 0.0
			var desty: float = py + dy * dest_dist if has_dest else 0.0
			projs.spawn(
				px,
				py,
				dx,
				dy,
				p_speed,
				projs.life[p],
				projs.radius[p],
				ray_dmg,
				ProjectilePool.TEAM_PLAYER,
				new_flags,
				destx,
				desty,
				projs.impact_radius[p],
				projs.root_duration[p],
				projs.tether_dps[p],
				has_dest,
				projs.element[p],
				projs.skill_tag[p],
				projs.extra_float[p],
			)
		world.fx.emit(FxIds.PARRY_REFLECT, zx, zy, 0xA884F3, zr * 0.6)


static func _tick_solar_beam(world: SimWorld, index: int, dt: float) -> void:
	var tick_iv: float = world.zones.extra_a[index] if world.zones.extra_a[index] > 0.0 else 0.16
	world.zones.tick_accum[index] += dt
	while world.zones.tick_accum[index] >= tick_iv:
		world.zones.tick_accum[index] -= tick_iv
		var x0: float = world.zones.x[index]
		var y0: float = world.zones.y[index]
		var x1: float = x0 + world.zones.dir_x[index] * world.zones.length[index]
		var y1: float = y0 + world.zones.dir_y[index] * world.zones.length[index]
		var half_w: float = world.zones.width[index] * 0.5
		var tick_dmg: float = world.zones.damage[index] * tick_iv
		var any_crit: bool = false
		for e: int in world.enemies.cap:
			if world.enemies.alive[e] == 0 or world.enemies.corpse_remain[e] > 0.0:
				continue
			if SimCollision.point_to_segment(world.enemies.x[e], world.enemies.y[e], x0, y0, x1, y1) > half_w + world.enemies.radius[e]:
				continue
			var is_crit: bool = world.randf() < world.stats.crit_chance
			var dmg: float = tick_dmg * (world.stats.crit_mul if is_crit else 1.0)
			SimEnemies.apply_damage(world, e, dmg)
			world.fx.emit(FxIds.HIT, world.enemies.x[e], world.enemies.y[e], 0xFF4422 if is_crit else 0xFFE896)
			if is_crit:
				any_crit = true
		if any_crit:
			world.trigger_on_crit()
		var elem: String = world.zones.element[index]
		for o: int in world.obstacles.cap:
			if world.obstacles.alive[o] == 0:
				continue
			var obs: SimObstacle = world.obstacles.items[o]
			if SimCollision.point_to_segment(obs.x, obs.y, x0, y0, x1, y1) > half_w + obs.radius:
				continue
			if obs.type == &"volatile" and obs.state == &"intact":
				SimObstacles.damage_volatile(world, o, tick_dmg)
			elif obs.type == &"hazard":
				SimAlchemy.trigger_surface_reaction(world, obs.x, obs.y, half_w + obs.radius, true, elem)


static func _tick_smoke_cloud(world: SimWorld, index: int) -> void:
	var zx: float = world.zones.x[index]
	var zy: float = world.zones.y[index]
	var zr: float = world.zones.radius[index]
	var mul: float = clampf(world.zones.slow_mul[index], 0.1, 1.0)
	var projs: ProjectilePool = world.projectiles
	for p: int in projs.alive.size():
		if projs.alive[p] == 0 or projs.team[p] != ProjectilePool.TEAM_ENEMY:
			continue
		if (projs.flags[p] & ProjectilePool.FLAG_SPLIT) != 0:
			continue
		if SimCollision.circles_overlap(zx, zy, zr, projs.x[p], projs.y[p], projs.radius[p]):
			projs.vx[p] *= mul
			projs.vy[p] *= mul
			projs.flags[p] |= ProjectilePool.FLAG_SPLIT


static func _detonate_hex_sigil(world: SimWorld, index: int) -> void:
	var zx: float = world.zones.x[index]
	var zy: float = world.zones.y[index]
	var zr: float = world.zones.radius[index]
	world.fx.emit(FxIds.STRIKE, zx, zy, 0x9855E8, zr)
	if world.player.iframe_remain > 0.0 or world.player.dash_remain > 0.0 or world.player.parry_remain > 0.0:
		return
	if not SimCollision.circles_overlap(zx, zy, zr, world.player.x, world.player.y, world.player.radius):
		return
	world.fx.emit(FxIds.HURT, world.player.x, world.player.y, 0x9855E8)
	world.damage_player(world.zones.damage[index])
	var slow_dur: float = world.zones.extra_a[index] if world.zones.extra_a[index] > 0.0 else 1.2
	SimStatus.apply_slow(world.player, world.zones.slow_mul[index], slow_dur)


static func _on_line(zones: ZonePool, index: int, x: float, y: float, reach: float, half: float) -> bool:
	var dx: float = x - zones.x[index]
	var dy: float = y - zones.y[index]
	var along: float = dx * zones.dir_x[index] + dy * zones.dir_y[index]
	if along < -half or along > half:
		return false
	var px: float = dx - along * zones.dir_x[index]
	var py: float = dy - along * zones.dir_y[index]
	return px * px + py * py <= reach * reach
