class_name SimPickups
extends RefCounted


static func step_gems(world: SimWorld, dt: float) -> void:
	var loop: Dictionary = world.catalog.loop
	var pickup: float = float(loop.get("gemPickup", 28.0)) * world.stats.pickup_radius_mul
	var base_magnet: float = float(loop.get("gemMagnetBonus", 88.0)) if world.stats.pickup_radius_mul > 1.0 else float(loop.get("gemMagnet", 110.0))
	var magnet: float = base_magnet * world.stats.pickup_radius_mul
	var magnet_speed: float = float(loop.get("gemMagnetSpeed", 420.0)) * maxf(1.0, world.stats.pickup_radius_mul)
	for i: int in world.gems.cap:
		if world.gems.alive[i] == 0:
			continue
		var dx: float = world.player.x - world.gems.x[i]
		var dy: float = world.player.y - world.gems.y[i]
		var dist: float = sqrt(dx * dx + dy * dy)
		if dist <= pickup:
			world.gems.alive[i] = 0
			if world.gems.kind[i] == GemPool.KIND_ESSENCE:
				world.run_essence += maxi(1, roundi(world.gems.xp[i] * world.essence_gain_mul))
				world.fx.emit(FxIds.ESSENCE_PICKUP, world.gems.x[i], world.gems.y[i], 0xFF5577)
			else:
				world.gems_collected += 1
				world.fx.emit(FxIds.GEM, world.gems.x[i], world.gems.y[i], 0x88DDFF)
				SimLevel.grant_xp(world, world.gems.xp[i] * world.stats.xp_mul)
			continue
		if dist < magnet and dist > 0.001:
			var step_v: float = (magnet_speed * dt) / dist
			world.gems.x[i] += dx * step_v
			world.gems.y[i] += dy * step_v


static func step_lores(world: SimWorld, dt: float) -> void:
	var loop: Dictionary = world.catalog.loop
	var pickup: float = float(loop.get("gemPickup", 28.0)) * world.stats.pickup_radius_mul
	var base_magnet: float = float(loop.get("gemMagnetBonus", 88.0)) if world.stats.pickup_radius_mul > 1.0 else float(loop.get("gemMagnet", 110.0))
	var magnet: float = base_magnet * world.stats.pickup_radius_mul
	var magnet_speed: float = float(loop.get("gemMagnetSpeed", 420.0)) * maxf(1.0, world.stats.pickup_radius_mul)
	for i: int in world.lores.cap:
		if world.lores.alive[i] == 0:
			continue
		var dx: float = world.player.x - world.lores.x[i]
		var dy: float = world.player.y - world.lores.y[i]
		var dist: float = sqrt(dx * dx + dy * dy)
		if dist <= pickup:
			var entity_id: String = world.lores.entity_id[i]
			world.lores.alive[i] = 0
			world.lores.entity_id[i] = ""
			world.fx.emit(FxIds.GEM, world.lores.x[i], world.lores.y[i], 0xFFD35A)
			if entity_id != "" and not world.collected_lores.has(entity_id):
				world.collected_lores[entity_id] = true
				world.newly_collected_lores.append(entity_id)
			continue
		if dist < magnet and dist > 0.001:
			var step_v: float = (magnet_speed * dt) / dist
			world.lores.x[i] += dx * step_v
			world.lores.y[i] += dy * step_v


static func spawn_enemy_drops(
	world: SimWorld,
	px: float,
	py: float,
	base_xp: float,
	is_elite: bool,
	is_boss: bool,
	is_specialist: bool = false,
) -> void:
	var drops_cfg: Dictionary = DictUtil.d(world.catalog.loop, "drops")
	var ess_cfg: Dictionary = DictUtil.d(world.catalog.loop, "essenceEconomy")
	var variance: float = float(drops_cfg.get("xpVariancePct", 0.35))
	var xp_mul: float = (1.0 - variance) + world.randf() * (variance * 2.0)
	var total_xp: float = maxf(0.0, base_xp * xp_mul)
	if total_xp > 0.0:
		if is_boss:
			var boss_min: int = int(drops_cfg.get("bossDropsMin", 12))
			var boss_max: int = int(drops_cfg.get("bossDropsMax", 18))
			var count: int = world.randi_range(mini(boss_min, boss_max), maxi(boss_min, boss_max))
			_spawn_boss_xp(world, px, py, count, total_xp)
		elif is_elite:
			var cluster_chance: float = float(drops_cfg.get("eliteClusterChance", 0.12))
			if world.randf() < cluster_chance:
				var cluster_count: int = maxi(1, int(drops_cfg.get("eliteClusterCount", 3)))
				_spawn_weighted_xp(world, px, py, cluster_count, total_xp, 42.0, GemPool.KIND_XP_CLUSTER)
			else:
				var e_min: int = int(drops_cfg.get("eliteDropsMin", 4))
				var e_max: int = int(drops_cfg.get("eliteDropsMax", 7))
				var e_count: int = world.randi_range(mini(e_min, e_max), maxi(e_min, e_max))
				_spawn_weighted_xp(world, px, py, e_count, total_xp, 38.0, -1)
		elif is_specialist:
			var s_min: int = int(drops_cfg.get("specialistDropsMin", 2))
			var s_max: int = int(drops_cfg.get("specialistDropsMax", 4))
			var s_count: int = world.randi_range(mini(s_min, s_max), maxi(s_min, s_max))
			_spawn_weighted_xp(world, px, py, s_count, total_xp, 28.0, -1)
		else:
			var rich_chance: float = float(drops_cfg.get("fodderRichVeinChance", 0.15))
			if world.randf() < rich_chance:
				var f_min: int = int(drops_cfg.get("fodderRichDropsMin", 2))
				var f_max: int = int(drops_cfg.get("fodderRichDropsMax", 3))
				var f_count: int = world.randi_range(mini(f_min, f_max), maxi(f_min, f_max))
				_spawn_weighted_xp(world, px, py, f_count, total_xp, 24.0, -1)
			else:
				var pos: Vector2 = _clamp_drop_pos(world, px, py)
				if not world.gems.spawn_gem(pos.x, pos.y, total_xp):
					SimLevel.grant_xp(world, total_xp * world.stats.xp_mul)
	if is_boss:
		var ess_min: int = int(ess_cfg.get("bossMin", 10))
		var ess_max: int = int(ess_cfg.get("bossMax", 18))
		var total_ess: int = maxi(1, world.randi_range(mini(ess_min, ess_max), maxi(ess_min, ess_max)))
		var crystal_count: int = world.randi_range(2, 3)
		_spawn_split_essence(world, px, py, crystal_count, total_ess, 56.0)
	elif is_elite:
		if world.randf() < float(ess_cfg.get("eliteChance", 1.0)):
			var emin: int = int(ess_cfg.get("eliteMin", 2))
			var emax: int = int(ess_cfg.get("eliteMax", 3))
			spawn_essence_drops(world, px, py, 1, emin, emax)
	elif is_specialist:
		if world.randf() < float(ess_cfg.get("specialistChance", 0.18)):
			var smin: int = int(ess_cfg.get("specialistMin", 1))
			var smax: int = int(ess_cfg.get("specialistMax", 2))
			spawn_essence_drops(world, px, py, 1, smin, smax)
	else:
		if world.randf() < float(ess_cfg.get("fodderChance", 0.04)):
			var famt: int = maxi(1, int(ess_cfg.get("fodderAmount", 1)))
			spawn_essence_drops(world, px, py, 1, famt, famt)


static func spawn_xp_drops(world: SimWorld, px: float, py: float, count: int, total_xp: float) -> void:
	if count <= 0 or total_xp <= 0.0:
		return
	_spawn_weighted_xp(world, px, py, count, total_xp, 44.0, -1)


static func spawn_essence_drops(world: SimWorld, px: float, py: float, count: int, min_each: int, max_each: int) -> void:
	if count <= 0:
		return
	var lo: int = mini(min_each, max_each)
	var hi: int = maxi(min_each, max_each)
	var spread: float = 16.0 if count <= 1 else 36.0
	for i: int in count:
		var amt: int = maxi(1, world.randi_range(lo, hi))
		var pos: Vector2 = _scatter_drop_pos(world, px, py, spread, i > 0 or count > 1)
		if not world.gems.spawn_typed(pos.x, pos.y, float(amt), GemPool.KIND_ESSENCE):
			world.run_essence += maxi(1, roundi(float(amt) * world.essence_gain_mul))


static func _spawn_boss_xp(world: SimWorld, px: float, py: float, count: int, total_xp: float) -> void:
	var n: int = maxi(1, count)
	var weights: PackedFloat32Array = PackedFloat32Array()
	weights.resize(n)
	var is_cluster: PackedByteArray = PackedByteArray()
	is_cluster.resize(n)
	var weight_sum: float = 0.0
	for i: int in n:
		var cluster: bool = (i % 3 == 0) or world.randf() < 0.3
		is_cluster[i] = 1 if cluster else 0
		var w: float = (1.6 if cluster else 1.0) * (0.85 + world.randf() * 0.3)
		weights[i] = w
		weight_sum += w
	var overflow: float = 0.0
	for i: int in n:
		var val: float = total_xp * (weights[i] / maxf(weight_sum, 0.001))
		var drop_kind: int = GemPool.KIND_XP_CLUSTER if is_cluster[i] != 0 else GemPool.KIND_XP_MEDIUM
		var pos: Vector2 = _scatter_drop_pos(world, px, py, 68.0, true)
		if not world.gems.spawn_typed(pos.x, pos.y, val, drop_kind):
			overflow += val
	if overflow > 0.0:
		SimLevel.grant_xp(world, overflow * world.stats.xp_mul)


static func _spawn_weighted_xp(
	world: SimWorld,
	px: float,
	py: float,
	count: int,
	total_xp: float,
	spread: float,
	forced_kind: int,
) -> void:
	var n: int = maxi(1, count)
	var weights: PackedFloat32Array = PackedFloat32Array()
	weights.resize(n)
	var weight_sum: float = 0.0
	for i: int in n:
		var w: float = 0.75 + world.randf() * 0.5
		weights[i] = w
		weight_sum += w
	var overflow: float = 0.0
	for i: int in n:
		var val: float = total_xp * (weights[i] / maxf(weight_sum, 0.001))
		var pos: Vector2 = _scatter_drop_pos(world, px, py, spread, n > 1)
		var ok: bool = false
		if forced_kind >= 0:
			ok = world.gems.spawn_typed(pos.x, pos.y, val, forced_kind)
		else:
			ok = world.gems.spawn_gem(pos.x, pos.y, val)
		if not ok:
			overflow += val
	if overflow > 0.0:
		SimLevel.grant_xp(world, overflow * world.stats.xp_mul)


static func _spawn_split_essence(world: SimWorld, px: float, py: float, count: int, total_amount: int, spread: float) -> void:
	var n: int = clampi(count, 1, maxi(1, total_amount))
	var remaining: int = maxi(n, total_amount)
	for i: int in n:
		var slots_left: int = n - i
		var share: int = remaining
		if slots_left > 1:
			var avg: float = float(remaining) / float(slots_left)
			var lo: int = maxi(1, int(floor(avg * 0.7)))
			var hi: int = maxi(lo, mini(remaining - (slots_left - 1), int(ceil(avg * 1.3))))
			share = world.randi_range(lo, hi)
		remaining -= share
		var pos: Vector2 = _scatter_drop_pos(world, px, py, spread, n > 1)
		if not world.gems.spawn_typed(pos.x, pos.y, float(share), GemPool.KIND_ESSENCE):
			world.run_essence += maxi(1, roundi(float(share) * world.essence_gain_mul))


static func _scatter_drop_pos(world: SimWorld, px: float, py: float, spread: float, jitter: bool) -> Vector2:
	if not jitter:
		return _clamp_drop_pos(world, px, py)
	var ang: float = world.randf() * TAU
	var dist: float = 8.0 + world.randf() * spread
	return _clamp_drop_pos(world, px + cos(ang) * dist, py + sin(ang) * dist)


static func _clamp_drop_pos(world: SimWorld, px: float, py: float) -> Vector2:
	var bounds: Dictionary = world.catalog.world
	if world.arena_shape == "circle":
		var max_r: float = maxf(0.0, float(bounds.get("arenaRadius", 1500.0)) - 24.0)
		return SimCollision.clamp_to_circle(px, py, max_r)
	var width: float = float(bounds.get("width", 3000.0))
	var height: float = float(bounds.get("height", 3000.0))
	return Vector2(clampf(px, 24.0, width - 24.0), clampf(py, 24.0, height - 24.0))
