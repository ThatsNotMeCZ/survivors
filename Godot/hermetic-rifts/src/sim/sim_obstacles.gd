class_name SimObstacles
extends RefCounted


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
		spawn(world, type, point.x, point.y, String(names.get(String(type), "")))
		placed.append(point)
	_rebuild_hash(world)


static func spawn(world: SimWorld, type: StringName, x: float, y: float, biome: String, timer: float = 0.0) -> void:
	var obstacles: ObstaclePool = world.obstacles
	var target: int = -1
	for i: int in obstacles.cap:
		if obstacles.alive[i] == 0:
			target = i
			break
	if target < 0 and timer > 0.0:
		var min_timer: float = INF
		for i: int in obstacles.cap:
			if obstacles.alive[i] != 0 and obstacles.items[i].type == &"hazard" and obstacles.items[i].timer > 0.0:
				if obstacles.items[i].timer < min_timer:
					min_timer = obstacles.items[i].timer
					target = i
	if target < 0:
		return
	var cfg: Dictionary = world.catalog.obstacles
	var radius: float = float(DictUtil.d(cfg, "pillar").get("radius", 28.0))
	if type == &"hazard":
		radius = float(DictUtil.d(cfg, "hazard").get("radius", 68.0))
	elif type == &"volatile":
		radius = float(DictUtil.d(cfg, "volatile").get("radius", 14.0))
	var hp: float = float(DictUtil.d(cfg, "volatile").get("hp", 25.0)) * world.coefficient if type == &"volatile" else 0.0
	var item: SimObstacle = obstacles.items[target]
	item.id = obstacles.next_id
	obstacles.next_id += 1
	item.type = type
	item.x = x
	item.y = y
	item.radius = radius
	item.hp = hp
	item.max_hp = hp
	item.state = &"intact"
	item.timer = timer
	item.biome_variant = biome
	obstacles.alive[target] = 1


static func spawn_acid_pool(world: SimWorld, x: float, y: float) -> void:
	var duration: float = float(DictUtil.d(world.catalog.loop, "noxious").get("poolDuration", 6.0))
	spawn(world, &"hazard", x, y, "Caustic Acid Pool", duration)
	_rebuild_hash(world)


static func overlapping_hazard(world: SimWorld, x: float, y: float, radius: float) -> bool:
	var n: int = world.obstacles.grid.query(x, y, radius + float(DictUtil.d(world.catalog.obstacles, "hazard").get("radius", 68.0)))
	for k: int in n:
		var idx: int = world.obstacles.grid.hits[k]
		if world.obstacles.alive[idx] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[idx]
		if obs.type != &"hazard":
			continue
		if SimCollision.circles_overlap(x, y, radius, obs.x, obs.y, obs.radius):
			return true
	return false


static func resolve_bodies(world: SimWorld) -> void:
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		if obs.type == &"hazard":
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
	for i: int in world.projectiles.alive.size():
		if world.projectiles.alive[i] == 0:
			continue
		var n: int = world.obstacles.grid.query(world.projectiles.x[i], world.projectiles.y[i], world.projectiles.radius[i] + 56.0)
		var hit: int = -1
		var best: float = INF
		for k: int in n:
			var idx: int = world.obstacles.grid.hits[k]
			if world.obstacles.alive[idx] == 0:
				continue
			var obs: SimObstacle = world.obstacles.items[idx]
			if obs.type == &"hazard":
				continue
			if not SimCollision.aabb_overlap(world.projectiles.x[i], world.projectiles.y[i], world.projectiles.radius[i], obs.x, obs.y, obs.radius):
				continue
			if not SimCollision.circles_overlap(world.projectiles.x[i], world.projectiles.y[i], world.projectiles.radius[i], obs.x, obs.y, obs.radius):
				continue
			var dist: float = (obs.x - world.projectiles.x[i]) ** 2.0 + (obs.y - world.projectiles.y[i]) ** 2.0
			if dist < best:
				best = dist
				hit = idx
		if hit < 0:
			continue
		if (world.projectiles.flags[i] & ProjectilePool.FLAG_FLYOVER) != 0:
			continue
		world.fx.emit(FxIds.HIT, world.projectiles.x[i], world.projectiles.y[i], 0xFFF4C8)
		if world.projectiles.team[i] == ProjectilePool.TEAM_PLAYER:
			var dmg: float = world.projectiles.damage[i] if world.projectiles.damage[i] > 0.0 else world.projectiles.tether_dps[i]
			if dmg > 0.0:
				damage_volatile(world, hit, dmg)
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


static func hit_aoe(world: SimWorld, x: float, y: float, radius: float, damage: float) -> void:
	var n: int = world.obstacles.grid.query(x, y, radius + 56.0)
	for k: int in n:
		var idx: int = world.obstacles.grid.hits[k]
		if world.obstacles.alive[idx] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[idx]
		if obs.type != &"volatile" or obs.state != &"intact":
			continue
		if not SimCollision.circles_overlap(x, y, radius, obs.x, obs.y, obs.radius):
			continue
		damage_volatile(world, idx, damage)


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
		if obs.type == &"hazard" and obs.timer > 0.0:
			obs.timer -= dt
			if obs.timer <= 0.0:
				obs.timer = 0.0
				world.obstacles.alive[i] = 0
				rebuild = true
			continue
		if obs.type != &"volatile" or obs.state != &"primed":
			continue
		obs.timer -= dt
		if obs.timer > 0.0:
			continue
		_detonate(world, i)
		rebuild = true
	if rebuild:
		_rebuild_hash(world)


static func _detonate(world: SimWorld, index: int) -> void:
	var cfg: Dictionary = DictUtil.d(world.catalog.obstacles, "volatile")
	var obs: SimObstacle = world.obstacles.items[index]
	var rime: bool = String(SimLoop.current_stage(world).get("id", "")) == "rime-dock"
	var blast: float = float(cfg.get("explosionRadius", 110.0))
	var enemy_dmg: float = float(cfg.get("enemyDamage", 45.0)) * world.coefficient
	world.fx.emit(FxIds.DEATH, obs.x, obs.y, 0xFF8844)
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0:
			continue
		if not SimCollision.circles_overlap(obs.x, obs.y, blast, world.enemies.x[i], world.enemies.y[i], world.enemies.radius[i]):
			continue
		SimEnemies.apply_damage(world, i, enemy_dmg)
		if rime:
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
	var width: float = float(world.catalog.world.get("width", 2560.0))
	var height: float = float(world.catalog.world.get("height", 2560.0))
	var tel_keep: float = float(cfg.get("volatileTeleporterKeepOut", 200.0)) if type == &"volatile" else float(cfg.get("teleporterKeepOut", 230.0))
	for _a: int in int(cfg.get("placeRetries", 80)):
		var x: float = float(cfg.get("borderPad", 160.0)) + rng.next() * (width - float(cfg.get("borderPad", 160.0)) * 2.0)
		var y: float = float(cfg.get("borderPad", 160.0)) + rng.next() * (height - float(cfg.get("borderPad", 160.0)) * 2.0)
		if sqrt((x - world.player.x) * (x - world.player.x) + (y - world.player.y) * (y - world.player.y)) < float(cfg.get("playerKeepOut", 200.0)):
			continue
		if sqrt((x - world.teleporter_x) * (x - world.teleporter_x) + (y - world.teleporter_y) * (y - world.teleporter_y)) < tel_keep:
			continue
		var blocked: bool = false
		for p: Vector2 in placed:
			if sqrt((x - p.x) * (x - p.x) + (y - p.y) * (y - p.y)) < float(cfg.get("minSpacing", 190.0)):
				blocked = true
				break
		if blocked:
			continue
		return Vector2(x, y)
	return Vector2.INF


static func _rebuild_hash(world: SimWorld) -> void:
	world.obstacles.grid.clear()
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		world.obstacles.grid.insert(world.obstacles.items[i].x, world.obstacles.items[i].y, i)
