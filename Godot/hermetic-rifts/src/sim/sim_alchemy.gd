class_name SimAlchemy
extends RefCounted


static func trigger_surface_reaction(
	world: SimWorld,
	hit_x: float,
	hit_y: float,
	hit_r: float,
	is_secondary_or_special: bool,
	element: String,
) -> bool:
	if not is_secondary_or_special or element == "":
		return false
	var is_fire: bool = element == "fire" or element == "solar" or element == "heat"
	var is_cold: bool = element == "cold" or element == "aether" or element == "rime" or element == "void"
	if not is_fire and not is_cold:
		return false
	var cfg: Dictionary = DictUtil.d(world.catalog.obstacles, "alchemyReactions")
	var reaction_cd: float = float(cfg.get("reactionCooldown", 4.0))
	var hazard_r: float = float(DictUtil.d(world.catalog.obstacles, "hazard").get("radius", 68.0))
	var n: int = world.obstacles.grid.query(hit_x, hit_y, hit_r + hazard_r + 16.0)
	for k: int in n:
		var idx: int = world.obstacles.grid.hits[k]
		if world.obstacles.alive[idx] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[idx]
		if obs.type != &"hazard" or obs.reaction_cooldown > 0.0 or obs.sub_kind == "frozen":
			continue
		if not SimCollision.circles_overlap(hit_x, hit_y, hit_r, obs.x, obs.y, obs.radius):
			continue
		if is_fire:
			_trigger_vitriol_flash(world, idx, obs, cfg, reaction_cd)
		else:
			_trigger_shatter_frost(world, obs, cfg, reaction_cd)
		world.alchemy_reactions_run += 1
		return true
	return false


static func _trigger_vitriol_flash(
	world: SimWorld,
	obs_idx: int,
	obs: SimObstacle,
	cfg: Dictionary,
	reaction_cd: float,
) -> void:
	var vf: Dictionary = DictUtil.d(cfg, "vitriolFlash")
	var ox: float = obs.x
	var oy: float = obs.y
	obs.reaction_cooldown = reaction_cd
	if obs.timer > 0.0:
		obs.timer = 0.0
		world.obstacles.alive[obs_idx] = 0
		SimObstacles.rebuild_hash(world)
	var aoe_r: float = 95.0
	var dmg: float = float(vf.get("damageCoeff", 18.0)) * world.coefficient
	var burn_dps: float = 6.0 * world.coefficient
	world.fx.emit(FxIds.ALCHEMY_FLASH, ox, oy, 0xFF9933, aoe_r)
	for e: int in world.enemies.cap:
		if world.enemies.alive[e] == 0 or world.enemies.corpse_remain[e] > 0.0:
			continue
		if not SimCollision.circles_overlap(ox, oy, aoe_r, world.enemies.x[e], world.enemies.y[e], world.enemies.radius[e]):
			continue
		SimEnemies.apply_damage(world, e, dmg)
		if world.enemies.alive[e] != 0 and world.enemies.corpse_remain[e] <= 0.0:
			world.enemies.apply_burn(e, burn_dps, 3.0)
	var smoke_r: float = float(vf.get("smokeRadius", 75.0))
	var smoke_dur: float = float(vf.get("smokeDuration", 2.0))
	var proj_slow: float = float(vf.get("projectileSlowMul", 0.5))
	world.zones.spawn_smoke_cloud(ox, oy, smoke_r, smoke_dur, proj_slow)


static func _trigger_shatter_frost(
	world: SimWorld,
	obs: SimObstacle,
	cfg: Dictionary,
	reaction_cd: float,
) -> void:
	var sf: Dictionary = DictUtil.d(cfg, "shatterFrost")
	obs.reaction_cooldown = reaction_cd
	obs.sub_kind = "frozen"
	var frost_r: float = float(sf.get("radius", 75.0))
	var dmg: float = float(sf.get("damageCoeff", 12.0)) * world.coefficient
	var freeze_normal: float = float(sf.get("freezeDuration", 1.2))
	var freeze_heavy: float = float(sf.get("eliteBossFreezeDuration", 0.6))
	world.fx.emit(FxIds.ALCHEMY_FROST, obs.x, obs.y, 0x7AD4FF, frost_r)
	for e: int in world.enemies.cap:
		if world.enemies.alive[e] == 0 or world.enemies.corpse_remain[e] > 0.0:
			continue
		if not SimCollision.circles_overlap(obs.x, obs.y, frost_r, world.enemies.x[e], world.enemies.y[e], world.enemies.radius[e]):
			continue
		SimEnemies.apply_damage(world, e, dmg)
		if world.enemies.alive[e] != 0 and world.enemies.corpse_remain[e] <= 0.0:
			var is_heavy: bool = world.enemies.role[e] == EnemyPool.ROLE_ELITE or world.enemies.role[e] == EnemyPool.ROLE_BOSS
			world.enemies.apply_stun(e, freeze_heavy if is_heavy else freeze_normal)
	world.zones.spawn_frozen_patch(obs.x, obs.y, obs.radius, reaction_cd, 0.0, freeze_normal)
