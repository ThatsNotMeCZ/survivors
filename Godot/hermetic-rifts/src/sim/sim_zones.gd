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
		if world.zones.kind[i] == ZonePool.ZONE_LINE:
			_tick_line(world, i, dt)
			if world.zones.remain[i] <= 0.0:
				world.zones.alive[i] = 0
			continue
		if world.zones.remain[i] <= 0.0:
			_detonate_strike(world, i)
			world.zones.alive[i] = 0


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
	SimObstacles.hit_aoe(world, x, y, radius, damage)


static func _on_line(zones: ZonePool, index: int, x: float, y: float, reach: float, half: float) -> bool:
	var dx: float = x - zones.x[index]
	var dy: float = y - zones.y[index]
	var along: float = dx * zones.dir_x[index] + dy * zones.dir_y[index]
	if along < -half or along > half:
		return false
	var px: float = dx - along * zones.dir_x[index]
	var py: float = dy - along * zones.dir_y[index]
	return px * px + py * py <= reach * reach
