class_name SimEnemiesStep
extends RefCounted


static func step(world: SimWorld, dt: float) -> void:
	var enemies: EnemyPool = world.enemies
	var bounds: Dictionary = world.catalog.world
	var shielder_cfg: Dictionary = world.catalog.loop.get("shielder", {})
	for i: int in enemies.cap:
		if enemies.alive[i] == 0:
			continue
		enemies.hurt_remain[i] = maxf(0.0, enemies.hurt_remain[i] - dt)
		enemies.tick_slow(i, dt)
		if enemies.role[i] == EnemyPool.ROLE_ELITE and enemies.shielder[i] != 0:
			if enemies.shield_delay_remain[i] > 0.0:
				enemies.shield_delay_remain[i] -= dt
				if enemies.shield_delay_remain[i] <= 0.0:
					enemies.shield_hp[i] = enemies.max_hp[i] * float(shielder_cfg.get("percentHp", 0.3))
		if enemies.root_remain[i] > 0.0:
			enemies.root_remain[i] = maxf(0.0, enemies.root_remain[i] - dt)
			if enemies.root_remain[i] <= 0.0:
				enemies.tether_dps[i] = 0.0
		if enemies.corpse_remain[i] > 0.0:
			enemies.corpse_remain[i] -= dt
			if enemies.corpse_remain[i] <= 0.0:
				_explode_noxious(world, i)
			continue
		if enemies.attack_remain[i] > 0.0:
			enemies.attack_remain[i] = maxf(0.0, enemies.attack_remain[i] - dt)
		if enemies.attack_cd[i] > 0.0:
			enemies.attack_cd[i] = maxf(0.0, enemies.attack_cd[i] - dt)
		var def_id: String = enemies.def_id[i]
		var ai: Dictionary = {"type": "chase"}
		if def_id != "":
			var loaded_ai: Dictionary = DictUtil.d(world.catalog.entity(def_id), "ai")
			if not loaded_ai.is_empty():
				ai = loaded_ai
		var target: Vector2 = _chase_target(world, i)
		var dx: float = target.x - enemies.x[i]
		var dy: float = target.y - enemies.y[i]
		var dist: float = sqrt(dx * dx + dy * dy)
		var rooted: bool = enemies.root_remain[i] > 0.0
		var speed: float = 0.0 if rooted else enemies.speed[i] * _local_speed_mul(world, i)
		var start_x: float = enemies.x[i]
		var ai_type: String = String(ai.get("type", "chase"))
		if ai_type == "ranged":
			_step_ranged(world, i, ai, dx, dy, dist, dt, speed)
		elif ai_type == "sniper":
			_step_sniper(world, i, ai, dx, dy, dist, dt, speed)
		elif ai_type == "boss":
			SimBoss.step(world, i, ai, dx, dy, dist, dt, speed)
		else:
			var target_r: float = 14.0 if world.decoy.active and enemies.role[i] == EnemyPool.ROLE_FODDER else world.player.radius
			var hold: float = SimEnemies.chase_attack_range(enemies.radius[i], target_r)
			if not rooted and dist > hold and dist > 0.001:
				var stride: float = minf(speed * dt, dist - hold)
				var mx: float = (dx / dist) * stride
				var my: float = (dy / dist) * stride
				var deflected: Vector2 = _deflect(world, enemies.x[i], enemies.y[i], enemies.radius[i], mx, my, target.x, target.y)
				enemies.x[i] += deflected.x
				enemies.y[i] += deflected.y
			if not rooted:
				_place_at_hold(enemies, i, target, hold)
			var held_dx: float = target.x - enemies.x[i]
			var held_dy: float = target.y - enemies.y[i]
			var held: float = sqrt(held_dx * held_dx + held_dy * held_dy)
			if held <= hold:
				if enemies.attack_remain[i] <= 0.0 and enemies.attack_cd[i] <= 0.0:
					enemies.attack_remain[i] = EnemyPool.CHASE_ATTACK_DURATION
					enemies.attack_cd[i] = EnemyPool.CHASE_ATTACK_COOLDOWN
					enemies.anim_name[i] = String(ai.get("anim", "attack"))
		var inset_x: float = float(bounds.get("borderInsetX", 0.0))
		var inset_y: float = float(bounds.get("borderInsetY", 0.0))
		var pad_x: float = inset_x + enemies.radius[i] + 8.0
		var pad_y: float = inset_y + enemies.radius[i] + 8.0
		enemies.x[i] = clampf(enemies.x[i], pad_x, float(bounds.get("width", 2560.0)) - pad_x)
		enemies.y[i] = clampf(enemies.y[i], pad_y, float(bounds.get("height", 2560.0)) - pad_y)
		var move_x: float = enemies.x[i] - start_x
		if enemies.windup[i] > 0.0:
			var aim_dx: float = enemies.aim_x[i] - enemies.x[i]
			if aim_dx < -0.001:
				enemies.facing[i] = 255
			elif aim_dx > 0.001:
				enemies.facing[i] = 1
		elif move_x < -0.001:
			enemies.facing[i] = 255
		elif move_x > 0.001:
			enemies.facing[i] = 1
		elif enemies.attack_remain[i] > 0.0:
			var tdx: float = target.x - enemies.x[i]
			if tdx < -0.001:
				enemies.facing[i] = 255
			elif tdx > 0.001:
				enemies.facing[i] = 1
	_tick_tether_burn(world, dt)


static func _place_at_hold(enemies: EnemyPool, index: int, target: Vector2, hold: float) -> void:
	var dx: float = target.x - enemies.x[index]
	var dy: float = target.y - enemies.y[index]
	var dist: float = sqrt(dx * dx + dy * dy)
	if dist >= hold:
		return
	if dist <= 0.001:
		enemies.x[index] = target.x - hold
		return
	var nx: float = dx / dist
	var ny: float = dy / dist
	enemies.x[index] = target.x - nx * hold
	enemies.y[index] = target.y - ny * hold


static func _chase_target(world: SimWorld, index: int) -> Vector2:
	if world.enemies.role[index] == EnemyPool.ROLE_FODDER and world.decoy.active:
		return Vector2(world.decoy.x, world.decoy.y)
	return Vector2(world.player.x, world.player.y)


static func _step_ranged(
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
	if enemies.windup[i] > 0.0:
		enemies.windup[i] -= dt
		if enemies.windup[i] <= 0.0:
			_fire_bolt(world, i, ai)
			enemies.attack_cd[i] = float(ai.get("cooldown", 1.0))
			enemies.windup[i] = 0.0
		return
	if dist <= float(ai.get("range", 280.0)) and enemies.attack_cd[i] <= 0.0:
		enemies.windup[i] = float(ai.get("windup", 0.4))
		enemies.aim_x[i] = world.player.x
		enemies.aim_y[i] = world.player.y
		enemies.anim_name[i] = String(ai.get("anim", "attack"))
		return
	if dist > 0.001:
		var nx: float = dx / dist
		var ny: float = dy / dist
		var mx: float = 0.0
		var my: float = 0.0
		if dist > float(ai.get("range", 280.0)):
			mx = nx * speed * dt
			my = ny * speed * dt
		elif dist < float(ai.get("keep", 220.0)):
			mx = -nx * speed * dt
			my = -ny * speed * dt
		else:
			mx = -ny * speed * 0.45 * dt
			my = nx * speed * 0.45 * dt
		var defl: Vector2 = _deflect(world, enemies.x[i], enemies.y[i], enemies.radius[i], mx, my, world.player.x, world.player.y)
		enemies.x[i] += defl.x
		enemies.y[i] += defl.y


static func _step_sniper(
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
	if dist > 0.001:
		var nx: float = dx / dist
		var ny: float = dy / dist
		var mx: float = 0.0
		var my: float = 0.0
		if dist < float(ai.get("keep", 520.0)):
			mx = -nx * speed * dt
			my = -ny * speed * dt
		else:
			mx = -ny * speed * 0.25 * dt
			my = nx * speed * 0.25 * dt
		var defl: Vector2 = _deflect(world, enemies.x[i], enemies.y[i], enemies.radius[i], mx, my, world.player.x, world.player.y)
		enemies.x[i] += defl.x
		enemies.y[i] += defl.y
	if enemies.windup[i] > 0.0:
		enemies.windup[i] -= dt
		if enemies.windup[i] <= 0.0:
			_fire_sniper(world, i, ai)
			enemies.attack_cd[i] = float(ai.get("cooldown", 3.4))
			enemies.windup[i] = 0.0
		return
	if enemies.attack_cd[i] <= 0.0:
		enemies.windup[i] = float(ai.get("windup", 1.5))
		enemies.aim_x[i] = world.player.x
		enemies.aim_y[i] = world.player.y
		enemies.anim_name[i] = String(ai.get("anim", "attack"))


static func _fire_sniper(world: SimWorld, i: int, ai: Dictionary) -> void:
	var enemies: EnemyPool = world.enemies
	var player: PlayerState = world.player
	if player.iframe_remain > 0.0:
		return
	if SimEnemies.pillar_blocks_shot(world, enemies.x[i], enemies.y[i], player.x, player.y):
		return
	var dist: float = SimCollision.point_to_segment(player.x, player.y, enemies.x[i], enemies.y[i], enemies.aim_x[i], enemies.aim_y[i])
	if dist > float(ai.get("lineWidth", 10.0)) + player.radius:
		return
	world.fx.emit(FxIds.HURT, player.x, player.y, 0xFF3355)
	var dmg_mul: float = float(DictUtil.d(world.catalog.loop, "elite").get("damageMul", 1.0)) if enemies.role[i] == EnemyPool.ROLE_ELITE else 1.0
	world.damage_player(float(ai.get("damage", 28.0)) * world.coefficient * dmg_mul)


static func _fire_bolt(world: SimWorld, i: int, ai: Dictionary) -> void:
	var enemies: EnemyPool = world.enemies
	var dx: float = world.player.x - enemies.x[i]
	var dy: float = world.player.y - enemies.y[i]
	var dist: float = sqrt(dx * dx + dy * dy)
	if dist <= 0.001:
		return
	var nx: float = dx / dist
	var ny: float = dy / dist
	var muzzle: float = enemies.radius[i] + 8.0
	var px: float = enemies.x[i] + nx * muzzle
	var py: float = enemies.y[i] + ny * muzzle
	var proj: Dictionary = DictUtil.d(ai, "projectile")
	var dmg_mul: float = float(DictUtil.d(world.catalog.loop, "elite").get("damageMul", 1.0)) if enemies.role[i] == EnemyPool.ROLE_ELITE else 1.0
	world.projectiles.spawn(
		px,
		py,
		nx,
		ny,
		float(proj.get("speed", 260.0)),
		float(proj.get("lifetime", 1.6)),
		float(proj.get("radius", 6.0)),
		float(proj.get("damage", 8.0)) * world.coefficient * dmg_mul,
		ProjectilePool.TEAM_ENEMY,
	)
	world.fx.emit(FxIds.MUZZLE, px, py, 0xFF7A3A)


static func _deflect(
	world: SimWorld,
	x: float,
	y: float,
	radius: float,
	mx: float,
	my: float,
	target_x: float,
	target_y: float,
) -> Vector2:
	var move_len: float = sqrt(mx * mx + my * my)
	if move_len < 0.0001:
		return Vector2(mx, my)
	var out_x: float = mx
	var out_y: float = my
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		if obs.type == &"hazard":
			continue
		var reach: float = obs.radius + radius + 10.0
		var ox: float = x - obs.x
		var oy: float = y - obs.y
		var dist_sq: float = ox * ox + oy * oy
		if dist_sq > reach * reach:
			continue
		var dist: float = sqrt(dist_sq)
		var nx: float = 1.0 if dist <= 0.0001 else ox / dist
		var ny: float = 0.0 if dist <= 0.0001 else oy / dist
		var dot: float = out_x * nx + out_y * ny
		if dot < 0.0:
			out_x -= dot * nx
			out_y -= dot * ny
			var tan_len: float = sqrt(out_x * out_x + out_y * out_y)
			if tan_len > 0.0001:
				out_x = (out_x / tan_len) * move_len
				out_y = (out_y / tan_len) * move_len
			else:
				var cross: float = (target_x - obs.x) * ny - (target_y - obs.y) * nx
				var side: float = 1.0 if cross >= 0.0 else -1.0
				out_x = -ny * side * move_len
				out_y = nx * side * move_len
	return Vector2(out_x, out_y)


static func _explode_noxious(world: SimWorld, index: int) -> void:
	var enemies: EnemyPool = world.enemies
	var cfg: Dictionary = world.catalog.loop.get("noxious", {})
	var px: float = enemies.x[index]
	var py: float = enemies.y[index]
	world.fx.emit(FxIds.DEATH, px, py, 0x66FF88)
	if world.player.iframe_remain <= 0.0 and SimCollision.circles_overlap(px, py, float(cfg.get("popRadius", 40.0)), world.player.x, world.player.y, world.player.radius):
		world.fx.emit(FxIds.HURT, world.player.x, world.player.y, 0xFF3355)
		world.damage_player(float(cfg.get("popDamage", 8.0)) * world.coefficient, true)
	SimObstacles.spawn_acid_pool(world, px, py)
	SimEnemies.kill(world, index)


static func _tick_tether_burn(world: SimWorld, dt: float) -> void:
	var enemies: EnemyPool = world.enemies
	for i: int in enemies.cap:
		if enemies.alive[i] == 0 or enemies.root_remain[i] <= 0.0 or enemies.tether_dps[i] <= 0.0:
			continue
		if enemies.role[i] != EnemyPool.ROLE_ELITE and enemies.role[i] != EnemyPool.ROLE_BOSS:
			continue
		var tx: float = enemies.x[i]
		var ty: float = enemies.y[i]
		var burn_r: float = enemies.radius[i] + 8.0
		for f: int in enemies.cap:
			if f == i or enemies.alive[f] == 0 or enemies.role[f] != EnemyPool.ROLE_FODDER:
				continue
			var fx: float = enemies.x[f]
			var fy: float = enemies.y[f]
			var fr: float = enemies.radius[f]
			var in_circle: bool = SimCollision.circles_overlap(tx, ty, burn_r, fx, fy, fr)
			var on_chain: bool = not in_circle and SimCollision.point_to_segment(fx, fy, world.player.x, world.player.y, tx, ty) <= fr + 12.0
			if not in_circle and not on_chain:
				continue
			SimEnemies.apply_damage(world, f, enemies.tether_dps[i] * dt)


static func _local_speed_mul(world: SimWorld, index: int) -> float:
	var mul: float = world.enemies.slow_mul[index]
	var cfg: Dictionary = world.catalog.obstacles
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		if obs.type != &"hazard":
			continue
		if SimCollision.circles_overlap(world.enemies.x[index], world.enemies.y[index], world.enemies.radius[index], obs.x, obs.y, obs.radius):
			mul *= float(DictUtil.d(cfg, "hazard").get("enemySpeedMul", 0.85))
			break
	return mul
