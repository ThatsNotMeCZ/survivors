class_name SimEnemiesStep
extends RefCounted


static func step(world: SimWorld, dt: float) -> void:
	var enemies: EnemyPool = world.enemies
	var bounds: Dictionary = world.catalog.world
	var shielder_cfg: Dictionary = DictUtil.d(world.catalog.loop, "shielder")
	var burn_cfg: Dictionary = DictUtil.d(world.catalog.loop, "burn")
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
		if absf(enemies.vel_x[i]) > 0.01 or absf(enemies.vel_y[i]) > 0.01:
			var kvx: float = enemies.vel_x[i] * dt
			var kvy: float = enemies.vel_y[i] * dt
			var kdef: Vector2 = _deflect(world, enemies.x[i], enemies.y[i], enemies.radius[i], kvx, kvy, enemies.x[i] + kvx, enemies.y[i] + kvy)
			enemies.x[i] += kdef.x
			enemies.y[i] += kdef.y
			var decay: float = maxf(0.0, 1.0 - 6.0 * dt)
			enemies.vel_x[i] *= decay
			enemies.vel_y[i] *= decay
			if absf(enemies.vel_x[i]) < 0.5:
				enemies.vel_x[i] = 0.0
			if absf(enemies.vel_y[i]) < 0.5:
				enemies.vel_y[i] = 0.0
		if enemies.burn_remain[i] > 0.0:
			var burn_dt: float = minf(dt, enemies.burn_remain[i])
			enemies.burn_remain[i] = maxf(0.0, enemies.burn_remain[i] - dt)
			if enemies.burn_dps[i] > 0.0 and enemies.corpse_remain[i] <= 0.0:
				SimEnemies.apply_damage(world, i, enemies.burn_dps[i] * burn_dt)
				if enemies.alive[i] == 0:
					continue
			if enemies.burn_remain[i] <= 0.0:
				enemies.burn_dps[i] = 0.0
		if enemies.root_remain[i] > 0.0:
			enemies.root_remain[i] = maxf(0.0, enemies.root_remain[i] - dt)
			if enemies.root_remain[i] <= 0.0:
				enemies.tether_dps[i] = 0.0
				if enemies.ai_state[i] == EnemyPool.AI_STATE_STUN:
					enemies.ai_state[i] = EnemyPool.AI_STATE_DEFAULT
					enemies.state_timer[i] = 0.0
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
		var p_dx: float = world.player.x - enemies.x[i]
		var p_dy: float = world.player.y - enemies.y[i]
		var p_dist: float = sqrt(p_dx * p_dx + p_dy * p_dy)
		var rooted: bool = enemies.root_remain[i] > 0.0
		var speed: float = 0.0 if rooted else enemies.speed[i] * _local_speed_mul(world, i)
		var start_x: float = enemies.x[i]
		var start_y: float = enemies.y[i]
		if enemies.role[i] == EnemyPool.ROLE_ELITE and enemies.affix[i] == "chain_lightning":
			_tick_chain_lightning(world, i, p_dist, dt)
		var chain_winding: bool = enemies.role[i] == EnemyPool.ROLE_ELITE and enemies.affix[i] == "chain_lightning" and enemies.chain_cd[i] < 0.0
		var ai_type: String = String(ai.get("type", "chase"))
		if ai_type == "ranged":
			if not chain_winding:
				_step_ranged(world, i, ai, p_dx, p_dy, p_dist, dt, speed)
		elif ai_type == "sniper":
			if not chain_winding:
				_step_sniper(world, i, ai, p_dx, p_dy, p_dist, dt, speed)
		elif ai_type == "cleaver":
			if not chain_winding:
				_step_cleaver(world, i, ai, target, dx, dy, dist, dt, speed, rooted)
		elif ai_type == "charger":
			if not chain_winding:
				_step_charger(world, i, ai, target, dx, dy, dist, dt, speed, rooted)
		elif ai_type == "hexer":
			if not chain_winding:
				_step_hexer(world, i, ai, p_dx, p_dy, p_dist, dt, speed, rooted)
		elif ai_type == "spire":
			pass
		elif ai_type == "boss":
			SimBoss.step(world, i, ai, p_dx, p_dy, p_dist, dt, speed)
		else:
			_step_chase(world, i, ai, target, dx, dy, dist, dt, speed, rooted)
		if enemies.alive[i] == 0:
			continue
		if enemies.role[i] == EnemyPool.ROLE_ELITE and enemies.affix[i] == "burn":
			var moved_sq: float = (enemies.x[i] - start_x) * (enemies.x[i] - start_x) + (enemies.y[i] - start_y) * (enemies.y[i] - start_y)
			if speed > 0.0 and not rooted and moved_sq > 0.04:
				enemies.trail_cd[i] -= dt
				if enemies.trail_cd[i] <= 0.0:
					enemies.trail_cd[i] = float(burn_cfg.get("trailInterval", 0.55))
					SimObstacles.spawn_burn_trail(
						world,
						enemies.x[i],
						enemies.y[i],
						float(burn_cfg.get("trailDuration", 2.2)),
						float(burn_cfg.get("trailRadius", 22.0)),
					)
		if world.arena_shape == "circle":
			var max_r: float = maxf(0.0, world.arena_radius - enemies.radius[i] - 6.0)
			var clamped: Vector2 = SimCollision.clamp_to_circle(enemies.x[i], enemies.y[i], max_r)
			enemies.x[i] = clamped.x
			enemies.y[i] = clamped.y
		else:
			var inset_x: float = float(bounds.get("borderInsetX", 0.0))
			var inset_y: float = float(bounds.get("borderInsetY", 0.0))
			var pad_x: float = inset_x + enemies.radius[i] + 8.0
			var pad_y: float = inset_y + enemies.radius[i] + 8.0
			enemies.x[i] = clampf(enemies.x[i], pad_x, float(bounds.get("width", 6000.0)) - pad_x)
			enemies.y[i] = clampf(enemies.y[i], pad_y, float(bounds.get("height", 6000.0)) - pad_y)
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


static func _tick_chain_lightning(world: SimWorld, i: int, player_dist: float, dt: float) -> void:
	var enemies: EnemyPool = world.enemies
	var cfg: Dictionary = DictUtil.d(world.catalog.loop, "chainLightning")
	var interval: float = float(cfg.get("interval", 2.6))
	var range_v: float = float(cfg.get("range", 230.0))
	var windup_dur: float = float(cfg.get("windup", 0.65))
	if enemies.ai_state[i] == EnemyPool.AI_STATE_STUN:
		if enemies.chain_cd[i] < 0.0:
			enemies.chain_cd[i] = interval
			enemies.windup[i] = 0.0
		return
	if enemies.chain_cd[i] < 0.0:
		enemies.chain_cd[i] += dt
		enemies.windup[i] = maxf(0.0, -enemies.chain_cd[i])
		if enemies.chain_cd[i] >= 0.0:
			enemies.chain_cd[i] = interval
			enemies.windup[i] = 0.0
			_fire_chain_lightning(world, i, cfg, range_v, player_dist)
		return
	if enemies.chain_cd[i] > 0.0:
		enemies.chain_cd[i] = maxf(0.0, enemies.chain_cd[i] - dt)
	if enemies.chain_cd[i] <= 0.0 and enemies.ai_state[i] == EnemyPool.AI_STATE_DEFAULT and enemies.windup[i] <= 0.0 and enemies.root_remain[i] <= 0.0:
		if player_dist <= range_v:
			enemies.chain_cd[i] = -windup_dur
			enemies.windup[i] = windup_dur
			enemies.aim_x[i] = world.player.x
			enemies.aim_y[i] = world.player.y
			enemies.anim_name[i] = "attack"


static func _fire_chain_lightning(
	world: SimWorld,
	i: int,
	cfg: Dictionary,
	range_v: float,
	player_dist: float,
) -> void:
	var enemies: EnemyPool = world.enemies
	var ex: float = enemies.x[i]
	var ey: float = enemies.y[i]
	var player: PlayerState = world.player
	var hit_player: bool = false
	if player.iframe_remain <= 0.0 and player.dash_remain <= 0.0 and player.parry_remain <= 0.0:
		if player_dist <= range_v + player.radius + 20.0 and not SimEnemies.pillar_blocks_shot(world, ex, ey, player.x, player.y):
			var dmg: float = float(cfg.get("damageCoeff", 12.0)) * SimLoop.difficulty_coeff(world)
			world.fx.emit(FxIds.HURT, player.x, player.y, 0xFFE870)
			world.damage_player(dmg)
			hit_player = true
	var max_bounces: int = int(cfg.get("maxBounces", 2))
	var bounce_range: float = float(cfg.get("bounceRange", 160.0))
	var bx: float = player.x if hit_player else ex
	var by: float = player.y if hit_player else ey
	var hit_obs: Dictionary = {}
	for _b: int in max_bounces:
		var best_idx: int = -1
		var best_d2: float = bounce_range * bounce_range
		for obs_idx: int in world.obstacles.cap:
			if world.obstacles.alive[obs_idx] == 0 or hit_obs.has(obs_idx):
				continue
			var obs: SimObstacle = world.obstacles.items[obs_idx]
			if obs.type != &"conduit" and obs.type != &"volatile":
				continue
			if obs.type == &"conduit" and obs.state == &"depleted":
				continue
			if obs.type == &"volatile" and obs.state == &"detonated":
				continue
			var odx: float = obs.x - bx
			var ody: float = obs.y - by
			var d2: float = odx * odx + ody * ody
			if d2 <= best_d2:
				best_d2 = d2
				best_idx = obs_idx
		if best_idx < 0:
			break
		hit_obs[best_idx] = true
		var target_obs: SimObstacle = world.obstacles.items[best_idx]
		if target_obs.type == &"conduit":
			SimObstacles.charge_conduit(world, best_idx, 1)
		elif target_obs.type == &"volatile":
			if target_obs.state == &"intact":
				target_obs.state = &"primed"
				target_obs.timer = float(DictUtil.d(world.catalog.obstacles, "volatile").get("prime", 0.4))
			else:
				target_obs.timer = minf(target_obs.timer, 0.4)
		world.fx.emit(FxIds.HIT, target_obs.x, target_obs.y, 0xFFE870)
		bx = target_obs.x
		by = target_obs.y


static func _step_chase(
	world: SimWorld,
	i: int,
	ai: Dictionary,
	target: Vector2,
	dx: float,
	dy: float,
	dist: float,
	dt: float,
	speed: float,
	rooted: bool,
) -> void:
	var enemies: EnemyPool = world.enemies
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
	var contact: float = SimEnemies.chase_contact_range(enemies.radius[i], target_r)
	if not rooted and held <= contact:
		if enemies.attack_remain[i] <= 0.0 and enemies.attack_cd[i] <= 0.0:
			enemies.attack_remain[i] = EnemyPool.CHASE_ATTACK_DURATION
			enemies.attack_cd[i] = EnemyPool.CHASE_ATTACK_COOLDOWN
			enemies.anim_name[i] = String(ai.get("anim", "attack"))


static func _step_cleaver(
	world: SimWorld,
	i: int,
	ai: Dictionary,
	target: Vector2,
	dx: float,
	dy: float,
	dist: float,
	dt: float,
	speed: float,
	rooted: bool,
) -> void:
	var enemies: EnemyPool = world.enemies
	if enemies.ai_state[i] == EnemyPool.AI_STATE_STUN:
		enemies.windup[i] = 0.0
		return
	if enemies.ai_state[i] == EnemyPool.AI_STATE_WINDUP or enemies.windup[i] > 0.0:
		enemies.windup[i] -= dt
		if enemies.windup[i] <= 0.0:
			enemies.windup[i] = 0.0
			enemies.ai_state[i] = EnemyPool.AI_STATE_DEFAULT
			enemies.attack_remain[i] = 0.35
			enemies.attack_cd[i] = float(ai.get("cooldown", 1.5))
			_execute_cleave(world, i, ai)
		return
	var trig: float = float(ai.get("triggerRange", 72.0))
	if not rooted and dist <= trig and enemies.attack_cd[i] <= 0.0:
		enemies.ai_state[i] = EnemyPool.AI_STATE_WINDUP
		enemies.windup[i] = float(ai.get("windup", 0.65))
		enemies.aim_x[i] = target.x
		enemies.aim_y[i] = target.y
		enemies.anim_name[i] = String(ai.get("anim", "attack"))
		return
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


static func _execute_cleave(world: SimWorld, i: int, ai: Dictionary) -> void:
	var enemies: EnemyPool = world.enemies
	var ex: float = enemies.x[i]
	var ey: float = enemies.y[i]
	var adx: float = enemies.aim_x[i] - ex
	var ady: float = enemies.aim_y[i] - ey
	var alen: float = sqrt(adx * adx + ady * ady)
	var ux: float = float(SimEnemies.facing_sign(enemies.facing[i])) if alen <= 0.001 else adx / alen
	var uy: float = 0.0 if alen <= 0.001 else ady / alen
	var slash_r: float = float(ai.get("slashRadius", 88.0))
	var arc_rad: float = deg_to_rad(float(ai.get("arcDeg", 120.0)))
	var player: PlayerState = world.player
	if player.iframe_remain <= 0.0 and player.dash_remain <= 0.0 and player.parry_remain <= 0.0:
		if BossHazardPool.point_in_cone(player.x, player.y, player.radius, ex, ey, ux, uy, slash_r, arc_rad):
			if not SimEnemies.pillar_blocks_shot(world, ex, ey, player.x, player.y):
				var dmg_mul: float = float(DictUtil.d(world.catalog.loop, "elite").get("damageMul", 1.0)) if enemies.role[i] == EnemyPool.ROLE_ELITE else 1.0
				var dmg: float = float(ai.get("damage", 18.0)) * SimLoop.difficulty_coeff(world) * dmg_mul
				world.fx.emit(FxIds.HURT, player.x, player.y, 0xFF7A3A)
				world.damage_player(dmg)
				SimEnemies.apply_burn_to_player(world, i)
				SimEnemies.apply_noxious_contact(world, i)
	for obs_idx: int in world.obstacles.cap:
		if world.obstacles.alive[obs_idx] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[obs_idx]
		if obs.type != &"volatile" or obs.state == &"detonated":
			continue
		if BossHazardPool.point_in_cone(obs.x, obs.y, obs.radius, ex, ey, ux, uy, slash_r, arc_rad):
			SimObstacles.detonate_volatile(world, obs_idx)


static func _step_charger(
	world: SimWorld,
	i: int,
	ai: Dictionary,
	target: Vector2,
	dx: float,
	dy: float,
	dist: float,
	dt: float,
	speed: float,
	rooted: bool,
) -> void:
	var enemies: EnemyPool = world.enemies
	if enemies.ai_state[i] == EnemyPool.AI_STATE_STUN:
		enemies.windup[i] = 0.0
		return
	if enemies.ai_state[i] == EnemyPool.AI_STATE_WINDUP:
		enemies.windup[i] -= dt
		if enemies.windup[i] <= 0.0:
			enemies.windup[i] = 0.0
			enemies.ai_state[i] = EnemyPool.AI_STATE_ACTIVE
			enemies.state_timer[i] = float(ai.get("dashDuration", 0.48))
			enemies.attack_remain[i] = enemies.state_timer[i]
			enemies.anim_name[i] = String(ai.get("anim", "attack"))
			var ldx: float = enemies.aim_x[i] - enemies.x[i]
			var ldy: float = enemies.aim_y[i] - enemies.y[i]
			var llen: float = sqrt(ldx * ldx + ldy * ldy)
			var lux: float = float(SimEnemies.facing_sign(enemies.facing[i])) if llen <= 0.001 else ldx / llen
			var luy: float = 0.0 if llen <= 0.001 else ldy / llen
			enemies.aim_x[i] = enemies.x[i] + lux * 1000.0
			enemies.aim_y[i] = enemies.y[i] + luy * 1000.0
		return
	if enemies.ai_state[i] == EnemyPool.AI_STATE_ACTIVE:
		if rooted:
			enemies.ai_state[i] = EnemyPool.AI_STATE_DEFAULT
			enemies.state_timer[i] = 0.0
			enemies.attack_cd[i] = float(ai.get("cooldown", 2.2))
			return
		var cdx: float = enemies.aim_x[i] - enemies.x[i]
		var cdy: float = enemies.aim_y[i] - enemies.y[i]
		var clen: float = sqrt(cdx * cdx + cdy * cdy)
		var cux: float = float(SimEnemies.facing_sign(enemies.facing[i])) if clen <= 0.001 else cdx / clen
		var cuy: float = 0.0 if clen <= 0.001 else cdy / clen
		var dash_spd: float = float(ai.get("dashSpeed", 540.0))
		var prev_x: float = enemies.x[i]
		var prev_y: float = enemies.y[i]
		enemies.x[i] += cux * dash_spd * dt
		enemies.y[i] += cuy * dash_spd * dt
		for obs_idx: int in world.obstacles.cap:
			if world.obstacles.alive[obs_idx] == 0:
				continue
			var obs: SimObstacle = world.obstacles.items[obs_idx]
			if obs.type != &"pillar":
				continue
			if SimCollision.point_to_segment(obs.x, obs.y, prev_x, prev_y, enemies.x[i], enemies.y[i]) <= obs.radius + enemies.radius[i]:
				var split: Vector4 = SimCollision.push_circles(enemies.x[i], enemies.y[i], enemies.radius[i], obs.x, obs.y, obs.radius, 1.0, 0.0)
				enemies.x[i] = split.x
				enemies.y[i] = split.y
				var coeff: float = SimLoop.difficulty_coeff(world)
				world.fx.emit(FxIds.HIT, enemies.x[i], enemies.y[i], 0xFFAA44)
				SimEnemies.apply_damage(world, i, 15.0 * coeff)
				if enemies.alive[i] != 0 and enemies.corpse_remain[i] <= 0.0:
					enemies.apply_stun(i, float(ai.get("pillarStunDuration", 0.8)))
					enemies.attack_cd[i] = float(ai.get("cooldown", 2.2))
				return
		var player: PlayerState = world.player
		if player.iframe_remain <= 0.0 and player.dash_remain <= 0.0 and player.parry_remain <= 0.0:
			if SimCollision.circles_overlap(enemies.x[i], enemies.y[i], enemies.radius[i] + 4.0, player.x, player.y, player.radius):
				var dmg_mul: float = float(DictUtil.d(world.catalog.loop, "elite").get("damageMul", 1.0)) if enemies.role[i] == EnemyPool.ROLE_ELITE else 1.0
				var dmg: float = float(ai.get("damage", 18.0)) * SimLoop.difficulty_coeff(world) * dmg_mul
				world.fx.emit(FxIds.HURT, player.x, player.y, 0xFF7A3A)
				world.damage_player(dmg)
				SimEnemies.apply_burn_to_player(world, i)
				SimEnemies.apply_noxious_contact(world, i)
				enemies.ai_state[i] = EnemyPool.AI_STATE_DEFAULT
				enemies.state_timer[i] = 0.0
				enemies.attack_cd[i] = float(ai.get("cooldown", 2.2))
				return
		enemies.state_timer[i] -= dt
		if enemies.state_timer[i] <= 0.0:
			enemies.ai_state[i] = EnemyPool.AI_STATE_DEFAULT
			enemies.state_timer[i] = 0.0
			enemies.attack_cd[i] = float(ai.get("cooldown", 2.2))
		return
	var lock_min: float = float(ai.get("lockMin", 140.0))
	var lock_max: float = float(ai.get("lockMax", 260.0))
	if not rooted and enemies.attack_cd[i] <= 0.0 and dist >= lock_min and dist <= lock_max:
		enemies.ai_state[i] = EnemyPool.AI_STATE_WINDUP
		enemies.windup[i] = float(ai.get("windup", 0.55))
		enemies.aim_x[i] = target.x
		enemies.aim_y[i] = target.y
		enemies.anim_name[i] = String(ai.get("anim", "attack"))
		return
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


static func _step_hexer(
	world: SimWorld,
	i: int,
	ai: Dictionary,
	dx: float,
	dy: float,
	dist: float,
	dt: float,
	speed: float,
	rooted: bool,
) -> void:
	var enemies: EnemyPool = world.enemies
	if enemies.ai_state[i] == EnemyPool.AI_STATE_STUN:
		enemies.windup[i] = 0.0
		return
	if enemies.windup[i] > 0.0:
		enemies.windup[i] -= dt
		if enemies.windup[i] <= 0.0:
			enemies.windup[i] = 0.0
			enemies.ai_state[i] = EnemyPool.AI_STATE_DEFAULT
			enemies.attack_cd[i] = float(ai.get("cooldown", 2.8))
			var hex_r: float = float(ai.get("hexRadius", 44.0))
			var pred_x: float = world.player.x + world.player.vx * 0.45
			var pred_y: float = world.player.y + world.player.vy * 0.45
			if world.arena_shape == "circle":
				var c: Vector2 = SimCollision.clamp_to_circle(pred_x, pred_y, maxf(0.0, world.arena_radius - hex_r - 6.0))
				pred_x = c.x
				pred_y = c.y
			var dmg_mul: float = float(DictUtil.d(world.catalog.loop, "elite").get("damageMul", 1.0)) if enemies.role[i] == EnemyPool.ROLE_ELITE else 1.0
			var dmg: float = float(ai.get("damage", 14.0)) * SimLoop.difficulty_coeff(world) * dmg_mul
			world.zones.spawn_hex_sigil(
				pred_x,
				pred_y,
				hex_r,
				float(ai.get("hexDelay", 1.1)),
				dmg,
				float(ai.get("slowMul", 0.6)),
				float(ai.get("slowDuration", 1.2)),
			)
		return
	var keep_min: float = float(ai.get("keepMin", 240.0))
	var keep_max: float = float(ai.get("keepMax", 340.0))
	if not rooted and dist > 0.001:
		var nx: float = dx / dist
		var ny: float = dy / dist
		var mx: float = 0.0
		var my: float = 0.0
		if dist > keep_max:
			mx = nx * speed * dt
			my = ny * speed * dt
		elif dist < keep_min:
			mx = -nx * speed * dt
			my = -ny * speed * dt
		else:
			mx = -ny * speed * 0.45 * dt
			my = nx * speed * 0.45 * dt
		var defl: Vector2 = _deflect(world, enemies.x[i], enemies.y[i], enemies.radius[i], mx, my, world.player.x, world.player.y)
		enemies.x[i] += defl.x
		enemies.y[i] += defl.y
	if not rooted and enemies.attack_cd[i] <= 0.0 and dist <= keep_max * 1.4:
		enemies.ai_state[i] = EnemyPool.AI_STATE_WINDUP
		enemies.windup[i] = float(ai.get("windup", 0.5))
		enemies.aim_x[i] = world.player.x + world.player.vx * 0.45
		enemies.aim_y[i] = world.player.y + world.player.vy * 0.45
		enemies.anim_name[i] = String(ai.get("anim", "attack"))


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
	if enemies.ai_state[i] == EnemyPool.AI_STATE_STUN:
		enemies.windup[i] = 0.0
		return
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
	if enemies.ai_state[i] == EnemyPool.AI_STATE_STUN:
		enemies.windup[i] = 0.0
		return
	if dist > 0.001:
		var nx: float = dx / dist
		var ny: float = dy / dist
		var mx: float = 0.0
		var my: float = 0.0
		if dist < float(ai.get("keep", 480.0)):
			mx = -nx * speed * dt
			my = -ny * speed * dt
		else:
			mx = -ny * speed * 0.25 * dt
			my = nx * speed * 0.25 * dt
		var defl: Vector2 = _deflect(world, enemies.x[i], enemies.y[i], enemies.radius[i], mx, my, world.player.x, world.player.y)
		enemies.x[i] += defl.x
		enemies.y[i] += defl.y
	if enemies.windup[i] > 0.0:
		if enemies.windup[i] > 0.30:
			enemies.aim_x[i] = world.player.x
			enemies.aim_y[i] = world.player.y
		enemies.windup[i] -= dt
		if enemies.windup[i] <= 0.0:
			_fire_sniper(world, i, ai)
			enemies.attack_cd[i] = float(ai.get("cooldown", 3.2))
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
	if player.iframe_remain > 0.0 or player.dash_remain > 0.0 or player.parry_remain > 0.0:
		return
	if SimEnemies.pillar_blocks_shot(world, enemies.x[i], enemies.y[i], player.x, player.y):
		return
	var dist: float = SimCollision.point_to_segment(player.x, player.y, enemies.x[i], enemies.y[i], enemies.aim_x[i], enemies.aim_y[i])
	if dist > float(ai.get("lineWidth", 10.0)) + player.radius:
		return
	world.fx.emit(FxIds.HURT, player.x, player.y, 0xFF3355)
	var dmg_mul: float = float(DictUtil.d(world.catalog.loop, "elite").get("damageMul", 1.0)) if enemies.role[i] == EnemyPool.ROLE_ELITE else 1.0
	world.damage_player(float(ai.get("damage", 28.0)) * SimLoop.difficulty_coeff(world) * dmg_mul)
	SimEnemies.apply_burn_to_player(world, i)


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
	var p_elem: String = "burn" if enemies.affix[i] == "burn" else ""
	world.projectiles.spawn(
		px,
		py,
		nx,
		ny,
		float(proj.get("speed", 260.0)),
		float(proj.get("lifetime", 1.6)),
		float(proj.get("radius", 6.0)),
		float(proj.get("damage", 8.0)) * SimLoop.difficulty_coeff(world) * dmg_mul,
		ProjectilePool.TEAM_ENEMY,
		0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		false,
		p_elem,
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
		if not SimObstacles.is_solid(obs.type):
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
	var cfg: Dictionary = DictUtil.d(world.catalog.loop, "noxious")
	var px: float = enemies.x[index]
	var py: float = enemies.y[index]
	world.fx.emit(FxIds.DEATH, px, py, 0x66FF88)
	if world.player.iframe_remain <= 0.0 and SimCollision.circles_overlap(px, py, float(cfg.get("popRadius", 40.0)), world.player.x, world.player.y, world.player.radius):
		world.fx.emit(FxIds.HURT, world.player.x, world.player.y, 0xFF3355)
		world.damage_player(float(cfg.get("popDamage", 8.0)) * SimLoop.difficulty_coeff(world), true)
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
