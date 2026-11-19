class_name SimSkills
extends RefCounted


static func tick_cooldowns(world: SimWorld, dt: float) -> void:
	for slot: StringName in InputFrame.SLOTS:
		world.player.skill_cd[slot] = maxf(0.0, float(world.player.skill_cd[slot]) - dt)


static func slot_skill_id(world: SimWorld, slot: StringName) -> String:
	var slot_key: String = String(slot)
	var variant: String = String(world.loadout.get(slot_key, "A"))
	if variant == "B":
		var alt_skills: Dictionary = world.survivor.get("altSkills", {})
		var alt_id: String = String(alt_skills.get(slot_key, ""))
		if alt_id != "":
			return alt_id
	var skills: Dictionary = world.survivor.get("skills", {})
	return String(skills.get(slot_key, ""))


static func try_skills(world: SimWorld, input: InputFrame) -> void:
	var overheat_cfg: Dictionary = world.catalog.loop.get("overheat", {})
	var refund_pct: float = float(overheat_cfg.get("criticalVentCooldownRefund", 0.25))
	for slot: StringName in InputFrame.SLOTS:
		if slot == InputFrame.SLOT_PRIMARY and world.player.overheat_lockout_remain > 0.0:
			continue
		var skill_id: String = slot_skill_id(world, slot)
		if skill_id == "":
			continue
		var skill: Dictionary = world.catalog.skill(skill_id)
		var want: bool = bool(input.held[slot]) if String(skill.get("input", "press")) == "hold" else bool(input.pressed[slot])
		if not want or float(world.player.skill_cd[slot]) > 0.0:
			continue
		if slot == InputFrame.SLOT_UTILITY and world.player.dash_remain > 0.0:
			continue
		var element: String = String(skill.get("element", ""))
		var is_vent: bool = false
		if slot == InputFrame.SLOT_SECONDARY:
			is_vent = world.player.try_critical_vent(overheat_cfg, world.fx, world.player.x, world.player.y)
		for effect_v: Variant in skill.get("effects", []):
			_apply(world, input, effect_v, slot, element, is_vent)
		if slot == InputFrame.SLOT_PRIMARY:
			world.player.add_primary_heat(float(skill.get("heatGain", 0.065)), world)
		var cd: float = float(skill.get("cooldown", 1.0)) * world.stats.cooldown_mul
		if is_vent:
			cd *= maxf(0.0, 1.0 - refund_pct)
		world.player.skill_cd[slot] = cd


static func _apply(
	world: SimWorld,
	input: InputFrame,
	effect_v: Variant,
	slot: StringName,
	element: String,
	is_vent: bool,
) -> void:
	var effect: Dictionary = effect_v
	var t: String = String(effect.get("type", ""))
	var is_primary: bool = slot == InputFrame.SLOT_PRIMARY
	var is_sec_or_spec: bool = slot == InputFrame.SLOT_SECONDARY or slot == InputFrame.SLOT_SPECIAL
	var overheat_cfg: Dictionary = world.catalog.loop.get("overheat", {})
	var width_mul: float = float(overheat_cfg.get("criticalVentWidthMul", 1.35)) if is_vent else 1.0
	var range_mul: float = float(overheat_cfg.get("criticalVentRangeMul", 1.35)) if is_vent else 1.0
	match t:
		"projectile":
			_fire_projectile(world, effect, is_primary, is_sec_or_spec, element, width_mul, range_mul)
		"dash":
			_start_dash(world, input, effect)
		"self-slow":
			SimStatus.apply_slow(world.player, float(effect.get("mul", 1.0)), float(effect.get("duration", 0.0)))
		"delayed-strike":
			world.zones.spawn_delayed_strike(
				world.aim_x,
				world.aim_y,
				float(effect.get("radius", 70.0)) * world.stats.aoe_radius_mul * width_mul,
				float(effect.get("delay", 0.55)),
				float(effect.get("damage", 28.0)) * world.stats.damage_mul,
				is_sec_or_spec,
				element,
			)
		"slow-line":
			_lay_slow_line(world, effect, is_sec_or_spec, element, width_mul, range_mul)
		"tether":
			_fire_tether(world, effect, is_sec_or_spec, element)
		"melee-arc":
			_swing_melee_arc(world, effect, is_sec_or_spec, element)
		"harpoon":
			_fire_harpoon(world, effect, is_sec_or_spec, element, width_mul, range_mul)
		"calcinatio-slam":
			_perform_calcinatio_slam(world, effect, is_sec_or_spec, element)
		"prism":
			_cast_prism(world, effect, is_sec_or_spec, element, width_mul, range_mul)
		"solar-beam":
			_cast_solar_beam(world, effect, element)
		"parry":
			_activate_parry(world, effect)
		"censure-bell":
			_ring_censure_bell(world, effect, is_sec_or_spec, element)
		"iron-bulwark":
			_activate_iron_bulwark(world, effect)
		"celestial-swap":
			_perform_celestial_swap(world, effect, element)
		"nova-burst":
			_cast_nova_burst(world, effect, is_sec_or_spec, element, width_mul)


static func _aim_dir(world: SimWorld) -> Vector2:
	var dir_x: float = world.aim_x - world.player.x
	var dir_y: float = world.aim_y - world.player.y
	var dist: float = sqrt(dir_x * dir_x + dir_y * dir_y)
	if dist <= 0.001:
		return Vector2.RIGHT
	return Vector2(dir_x / dist, dir_y / dist)


static func _slot_flags(is_primary: bool, is_sec_or_spec: bool) -> int:
	var f: int = 0
	if is_primary:
		f |= ProjectilePool.FLAG_PRIMARY
	if is_sec_or_spec:
		f |= ProjectilePool.FLAG_SECONDARY_OR_SPECIAL
	return f


static func _fire_projectile(
	world: SimWorld,
	effect: Dictionary,
	is_primary: bool,
	is_sec_or_spec: bool,
	element: String,
	width_mul: float,
	range_mul: float,
) -> void:
	var aim: Vector2 = _aim_dir(world)
	var muzzle: float = world.player.radius + 8.0
	var flags: int = _slot_flags(is_primary, is_sec_or_spec)
	if bool(effect.get("pierce", false)):
		flags |= ProjectilePool.FLAG_PIERCE
	if bool(effect.get("flyOver", false)):
		flags |= ProjectilePool.FLAG_FLYOVER
	var impact_r: float = float(effect.get("impactRadius", 0.0)) * world.stats.aoe_radius_mul * width_mul
	if impact_r > 0.0:
		flags |= ProjectilePool.FLAG_IMPACT | ProjectilePool.FLAG_FLYOVER
	var count: int = maxi(1, int(effect.get("count", 1)))
	var spread_rad: float = deg_to_rad(float(effect.get("spreadDeg", 0.0)))
	var base_ang: float = atan2(aim.y, aim.x)
	var speed: float = float(effect.get("speed", 780.0)) * world.stats.proj_speed_mul
	var lifetime: float = float(effect.get("lifetime", 0.85)) * range_mul
	var rad: float = float(effect.get("radius", 5.0)) * width_mul
	var dmg: float = float(effect.get("damage", 10.0)) * world.stats.damage_mul
	var has_dest: bool = impact_r > 0.0
	for k: int in count:
		var frac: float = 0.0 if count == 1 else float(k) / float(count - 1) - 0.5
		var ang: float = base_ang + frac * spread_rad
		var dx: float = cos(ang)
		var dy: float = sin(ang)
		world.projectiles.spawn(
			world.player.x + dx * muzzle,
			world.player.y + dy * muzzle,
			dx,
			dy,
			speed,
			lifetime,
			rad,
			dmg,
			ProjectilePool.TEAM_PLAYER,
			flags,
			world.aim_x,
			world.aim_y,
			impact_r,
			0.0,
			0.0,
			has_dest,
			element,
		)


static func _fire_tether(world: SimWorld, effect: Dictionary, is_sec_or_spec: bool, element: String) -> void:
	var aim: Vector2 = _aim_dir(world)
	var muzzle: float = world.player.radius + 8.0
	var flags: int = ProjectilePool.FLAG_TETHER | _slot_flags(false, is_sec_or_spec)
	world.projectiles.spawn(
		world.player.x + aim.x * muzzle,
		world.player.y + aim.y * muzzle,
		aim.x,
		aim.y,
		float(effect.get("speed", 900.0)) * world.stats.proj_speed_mul,
		float(effect.get("lifetime", 0.55)),
		float(effect.get("radius", 8.0)),
		float(effect.get("fodderDamage", 18.0)) * world.stats.damage_mul,
		ProjectilePool.TEAM_PLAYER,
		flags,
		0.0,
		0.0,
		0.0,
		float(effect.get("rootDuration", 2.4)) * world.stats.control_duration_mul,
		float(effect.get("fodderContactDps", 22.0)) * world.stats.damage_mul,
		false,
		element,
		"tether",
	)


static func _lay_slow_line(
	world: SimWorld,
	effect: Dictionary,
	is_sec_or_spec: bool,
	element: String,
	width_mul: float,
	range_mul: float,
) -> void:
	var aim: Vector2 = _aim_dir(world)
	var offset: float = float(effect.get("offset", 56.0))
	var line_len: float = float(effect.get("length", 520.0)) * world.stats.aoe_radius_mul * range_mul
	var line_width: float = float(effect.get("width", 46.0)) * world.stats.aoe_radius_mul * width_mul
	var cx: float = world.player.x + aim.x * offset
	var cy: float = world.player.y + aim.y * offset
	world.zones.spawn_slow_line(
		cx,
		cy,
		-aim.y,
		aim.x,
		line_len,
		line_width,
		float(effect.get("duration", 2.4)) * world.stats.control_duration_mul,
		float(effect.get("slowMul", 0.45)),
		float(effect.get("damage", 18.0)) * world.stats.damage_mul,
		bool(effect.get("fodderOnly", true)),
		element,
		is_sec_or_spec,
	)
	if is_sec_or_spec:
		SimAlchemy.trigger_surface_reaction(world, cx, cy, maxf(line_len * 0.5, line_width), true, element)


static func _swing_melee_arc(
	world: SimWorld,
	effect: Dictionary,
	is_sec_or_spec: bool,
	element: String,
) -> void:
	var aim: Vector2 = _aim_dir(world)
	var range_v: float = float(effect.get("range", 86.0)) * world.stats.aoe_radius_mul
	var arc_deg: float = float(effect.get("arcDeg", 120.0))
	var cos_half: float = cos(deg_to_rad(arc_deg * 0.5))
	var base_dmg: float = float(effect.get("damage", 15.0)) * world.stats.damage_mul
	var kb: float = float(effect.get("knockback", 90.0))
	var deflect: bool = bool(effect.get("deflectProjectiles", false))
	var hit_x: float = world.player.x + aim.x * (range_v * 0.5)
	var hit_y: float = world.player.y + aim.y * (range_v * 0.5)
	world.fx.emit(FxIds.STRIKE, hit_x, hit_y, 0xFFAA55, range_v * 0.55)
	var any_crit: bool = false
	for e: int in world.enemies.cap:
		if world.enemies.alive[e] == 0 or world.enemies.corpse_remain[e] > 0.0:
			continue
		var dx: float = world.enemies.x[e] - world.player.x
		var dy: float = world.enemies.y[e] - world.player.y
		var dist: float = sqrt(dx * dx + dy * dy)
		if dist > range_v + world.enemies.radius[e]:
			continue
		if dist > world.player.radius + world.enemies.radius[e] + 8.0 and dist > 0.001:
			if (dx / dist) * aim.x + (dy / dist) * aim.y < cos_half:
				continue
		var is_crit: bool = world.randf() < world.stats.crit_chance
		var dmg: float = base_dmg * (world.stats.crit_mul if is_crit else 1.0)
		SimEnemies.apply_damage(world, e, dmg)
		world.fx.emit(FxIds.HIT, world.enemies.x[e], world.enemies.y[e], 0xFF4422 if is_crit else 0xFFF4C8)
		if is_crit:
			any_crit = true
		if kb > 0.0 and world.enemies.alive[e] != 0 and world.enemies.role[e] != EnemyPool.ROLE_BOSS:
			_push_enemy(world, e, world.player.x, world.player.y, kb)
	if any_crit:
		world.trigger_on_crit()
	if deflect:
		var projs: ProjectilePool = world.projectiles
		for p: int in projs.alive.size():
			if projs.alive[p] == 0 or projs.team[p] != ProjectilePool.TEAM_ENEMY:
				continue
			var pdx: float = projs.x[p] - world.player.x
			var pdy: float = projs.y[p] - world.player.y
			var pdist: float = sqrt(pdx * pdx + pdy * pdy)
			if pdist > range_v + projs.radius[p]:
				continue
			if pdist <= world.player.radius + projs.radius[p] + 8.0 or (pdist > 0.001 and (pdx / pdist) * aim.x + (pdy / pdist) * aim.y >= cos_half):
				world.fx.emit(FxIds.HIT, projs.x[p], projs.y[p], 0xFFD35A)
				projs.kill_at(p)
	SimObstacles.hit_aoe(world, hit_x, hit_y, range_v * 0.65, base_dmg, is_sec_or_spec, element)
	if is_sec_or_spec:
		SimAlchemy.trigger_surface_reaction(world, hit_x, hit_y, range_v * 0.65, true, element)


static func _fire_harpoon(
	world: SimWorld,
	effect: Dictionary,
	is_sec_or_spec: bool,
	element: String,
	width_mul: float,
	range_mul: float,
) -> void:
	var aim: Vector2 = _aim_dir(world)
	var muzzle: float = world.player.radius + 8.0
	var flags: int = ProjectilePool.FLAG_PULL_HARPOON | _slot_flags(false, is_sec_or_spec)
	var pull_dist: float = float(effect.get("pullDistance", 180.0))
	var stun_dur: float = float(effect.get("stunDuration", 0.4)) * world.stats.control_duration_mul
	if world.projectiles.spawn(
		world.player.x + aim.x * muzzle,
		world.player.y + aim.y * muzzle,
		aim.x,
		aim.y,
		float(effect.get("speed", 980.0)) * world.stats.proj_speed_mul,
		float(effect.get("lifetime", 0.45)) * range_mul,
		float(effect.get("radius", 8.0)) * width_mul,
		float(effect.get("damage", 24.0)) * world.stats.damage_mul,
		ProjectilePool.TEAM_PLAYER,
		flags,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		false,
		element,
		"harpoon",
		pull_dist,
	):
		if world.projectiles.last_spawned >= 0:
			world.projectiles.extra_float2[world.projectiles.last_spawned] = stun_dur


static func _perform_calcinatio_slam(
	world: SimWorld,
	effect: Dictionary,
	is_sec_or_spec: bool,
	element: String,
) -> void:
	var max_range: float = float(effect.get("range", 220.0))
	var dx: float = world.aim_x - world.player.x
	var dy: float = world.aim_y - world.player.y
	var dist: float = sqrt(dx * dx + dy * dy)
	var leap_d: float = minf(dist, max_range)
	var dest_x: float = world.player.x + (dx / dist) * leap_d if dist > 0.001 else world.player.x
	var dest_y: float = world.player.y + (dy / dist) * leap_d if dist > 0.001 else world.player.y
	var clamped: Vector2 = _clamp_pos(world, dest_x, dest_y, world.player.radius)
	clamped = _push_out_pillars(world, clamped.x, clamped.y, world.player.radius)
	world.fx.emit(FxIds.DASH, world.player.x, world.player.y, 0xFF7A3A)
	world.player.x = clamped.x
	world.player.y = clamped.y
	world.player.iframe_remain = maxf(world.player.iframe_remain, 0.25)
	var slam_r: float = float(effect.get("radius", 96.0)) * world.stats.aoe_radius_mul
	var base_dmg: float = float(effect.get("damage", 85.0)) * world.stats.damage_mul
	var kb: float = float(effect.get("knockback", 240.0))
	var burn_dps: float = float(effect.get("burnDps", 12.0)) * world.stats.damage_mul
	var burn_dur: float = float(effect.get("burnDuration", 3.0)) * world.stats.control_duration_mul
	world.fx.emit(FxIds.CRUCIBLE_IMPACT, clamped.x, clamped.y, 0xFF6622, slam_r)
	var any_crit: bool = false
	for e: int in world.enemies.cap:
		if world.enemies.alive[e] == 0 or world.enemies.corpse_remain[e] > 0.0:
			continue
		if not SimCollision.circles_overlap(clamped.x, clamped.y, slam_r, world.enemies.x[e], world.enemies.y[e], world.enemies.radius[e]):
			continue
		var is_crit: bool = world.randf() < world.stats.crit_chance
		var dmg: float = base_dmg * (world.stats.crit_mul if is_crit else 1.0)
		SimEnemies.apply_damage(world, e, dmg)
		world.fx.emit(FxIds.HIT, world.enemies.x[e], world.enemies.y[e], 0xFF4422 if is_crit else 0xFFAA55)
		if is_crit:
			any_crit = true
		if world.enemies.alive[e] != 0:
			if kb > 0.0 and world.enemies.role[e] != EnemyPool.ROLE_BOSS:
				_push_enemy(world, e, clamped.x, clamped.y, kb)
			if burn_dps > 0.0 and burn_dur > 0.0:
				world.enemies.apply_burn(e, burn_dps, burn_dur)
	if any_crit:
		world.trigger_on_crit()
	if bool(effect.get("ventsOverheat", false)):
		world.player.heat = 0.0
		world.player.heat_decay_delay_remain = 0.0
		world.player.overheat_lockout_remain = 0.0
	SimObstacles.hit_aoe(world, clamped.x, clamped.y, slam_r, base_dmg, is_sec_or_spec, element)
	if is_sec_or_spec:
		SimAlchemy.trigger_surface_reaction(world, clamped.x, clamped.y, slam_r, true, element)


static func _cast_prism(
	world: SimWorld,
	effect: Dictionary,
	is_sec_or_spec: bool,
	element: String,
	width_mul: float,
	range_mul: float,
) -> void:
	var deploy_dur: float = float(effect.get("deployDuration", 0.0))
	var split_count: int = maxi(2, int(effect.get("splitCount", 3)))
	var split_spread: float = float(effect.get("splitSpreadDeg", 18.0))
	var split_dmg: float = float(effect.get("splitDamage", 12.0)) * world.stats.damage_mul
	if deploy_dur > 0.0:
		var deploy_r: float = float(effect.get("deployRadius", 28.0)) * world.stats.aoe_radius_mul * width_mul
		var dx: float = world.aim_x - world.player.x
		var dy: float = world.aim_y - world.player.y
		var dist: float = sqrt(dx * dx + dy * dy)
		var max_deploy: float = 480.0
		var tx: float = world.aim_x
		var ty: float = world.aim_y
		if dist > max_deploy and dist > 0.001:
			tx = world.player.x + (dx / dist) * max_deploy
			ty = world.player.y + (dy / dist) * max_deploy
		var clamped: Vector2 = _clamp_pos(world, tx, ty, deploy_r)
		world.zones.spawn_prism(clamped.x, clamped.y, deploy_r, deploy_dur, split_count, split_spread, split_dmg, element)
		return
	var aim: Vector2 = _aim_dir(world)
	var muzzle: float = world.player.radius + 8.0
	var flags: int = _slot_flags(false, is_sec_or_spec)
	if world.projectiles.spawn(
		world.player.x + aim.x * muzzle,
		world.player.y + aim.y * muzzle,
		aim.x,
		aim.y,
		float(effect.get("speed", 1100.0)) * world.stats.proj_speed_mul,
		float(effect.get("lifetime", 0.55)) * range_mul,
		float(effect.get("radius", 6.0)) * width_mul,
		float(effect.get("damage", 20.0)) * world.stats.damage_mul,
		ProjectilePool.TEAM_PLAYER,
		flags,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		false,
		element,
		"prism",
		split_dmg,
	):
		if world.projectiles.last_spawned >= 0:
			world.projectiles.extra_float2[world.projectiles.last_spawned] = split_spread
			world.projectiles.extra_int[world.projectiles.last_spawned] = split_count


static func _cast_solar_beam(world: SimWorld, effect: Dictionary, element: String) -> void:
	var aim: Vector2 = _aim_dir(world)
	var muzzle: float = world.player.radius + 6.0
	var beam_len: float = float(effect.get("length", 520.0)) * world.stats.aoe_radius_mul
	var beam_w: float = float(effect.get("width", 28.0)) * world.stats.aoe_radius_mul
	var dur: float = float(effect.get("duration", 1.6))
	var dps: float = float(effect.get("dps", 68.0)) * world.stats.damage_mul
	var tick_iv: float = float(effect.get("tickInterval", 0.16))
	world.zones.spawn_solar_beam(
		world.player.x + aim.x * muzzle,
		world.player.y + aim.y * muzzle,
		aim.x,
		aim.y,
		beam_len,
		beam_w,
		dur,
		dps,
		tick_iv,
		element,
	)


static func _activate_parry(world: SimWorld, effect: Dictionary) -> void:
	world.player.parry_remain = float(effect.get("duration", 0.28))
	world.player.iframe_remain = maxf(world.player.iframe_remain, float(effect.get("iframe", 0.28)))
	world.player.parry_triggered = false
	world.player.parry_shard_count = int(effect.get("shardCount", 3))
	world.player.parry_shard_damage = float(effect.get("shardDamage", 20.0))
	world.player.parry_cooldown_refund = float(effect.get("cooldownRefund", 1.8))


static func _ring_censure_bell(
	world: SimWorld,
	effect: Dictionary,
	is_sec_or_spec: bool,
	element: String,
) -> void:
	var rad: float = float(effect.get("radius", 125.0)) * world.stats.aoe_radius_mul
	var kb: float = float(effect.get("knockback", 260.0))
	var salt_dur: float = float(effect.get("saltDuration", 2.5)) * world.stats.control_duration_mul
	var slow_m: float = float(effect.get("slowMul", 0.45))
	var base_dmg: float = float(effect.get("damage", 22.0)) * world.stats.damage_mul
	var px: float = world.player.x
	var py: float = world.player.y
	world.zones.spawn_censure_bell(px, py, rad, 0.45, element)
	world.fx.emit(FxIds.STRIKE, px, py, 0xDFF6FF, rad)
	var any_crit: bool = false
	for e: int in world.enemies.cap:
		if world.enemies.alive[e] == 0 or world.enemies.corpse_remain[e] > 0.0:
			continue
		if not SimCollision.circles_overlap(px, py, rad, world.enemies.x[e], world.enemies.y[e], world.enemies.radius[e]):
			continue
		var is_crit: bool = world.randf() < world.stats.crit_chance
		var dmg: float = base_dmg * (world.stats.crit_mul if is_crit else 1.0)
		SimEnemies.apply_damage(world, e, dmg)
		if is_crit:
			any_crit = true
		if world.enemies.alive[e] != 0:
			world.enemies.apply_slow(e, slow_m, salt_dur)
			if kb > 0.0 and world.enemies.role[e] != EnemyPool.ROLE_BOSS:
				_push_enemy(world, e, px, py, kb)
	if any_crit:
		world.trigger_on_crit()
	if bool(effect.get("destroyProjectiles", true)):
		var projs: ProjectilePool = world.projectiles
		for p: int in projs.alive.size():
			if projs.alive[p] == 0 or projs.team[p] != ProjectilePool.TEAM_ENEMY:
				continue
			if SimCollision.circles_overlap(px, py, rad, projs.x[p], projs.y[p], projs.radius[p]):
				world.fx.emit(FxIds.HIT, projs.x[p], projs.y[p], 0xDFF6FF)
				projs.kill_at(p)
	world.player.bell_armor_remain = maxf(world.player.bell_armor_remain, 2.0)
	SimObstacles.hit_aoe(world, px, py, rad, base_dmg, is_sec_or_spec, element)
	if is_sec_or_spec:
		SimAlchemy.trigger_surface_reaction(world, px, py, rad, true, element)


static func _activate_iron_bulwark(world: SimWorld, effect: Dictionary) -> void:
	world.player.bulwark_remain = float(effect.get("duration", 0.55))
	world.player.bulwark_dr = float(effect.get("damageReduction", 0.85))
	world.player.bulwark_knockback_immune = bool(effect.get("knockbackImmune", true))
	world.player.bulwark_stored_damage = 0.0
	world.player.bulwark_counter_damage = float(effect.get("counterDamage", 32.0))
	world.player.bulwark_counter_range = float(effect.get("counterRange", 140.0))
	world.player.bulwark_counter_arc_deg = float(effect.get("counterArcDeg", 90.0))


static func _perform_celestial_swap(world: SimWorld, effect: Dictionary, element: String) -> void:
	var max_range: float = float(effect.get("range", 420.0))
	var old_x: float = world.player.x
	var old_y: float = world.player.y
	var prism_idx: int = -1
	var best_prism_d: float = INF
	for z: int in world.zones.cap:
		if world.zones.alive[z] == 0 or world.zones.kind[z] != ZonePool.ZONE_PRISM:
			continue
		var p_dist: float = sqrt((world.zones.x[z] - old_x) ** 2.0 + (world.zones.y[z] - old_y) ** 2.0)
		if p_dist > max_range * 1.35:
			continue
		var c_dist: float = (world.zones.x[z] - world.aim_x) ** 2.0 + (world.zones.y[z] - world.aim_y) ** 2.0
		if c_dist < best_prism_d:
			best_prism_d = c_dist
			prism_idx = z
	var new_x: float = old_x
	var new_y: float = old_y
	if prism_idx >= 0:
		new_x = world.zones.x[prism_idx]
		new_y = world.zones.y[prism_idx]
		world.zones.x[prism_idx] = old_x
		world.zones.y[prism_idx] = old_y
	else:
		var fodder_idx: int = -1
		var best_fodder_d: float = INF
		for e: int in world.enemies.cap:
			if world.enemies.alive[e] == 0 or world.enemies.corpse_remain[e] > 0.0:
				continue
			if world.enemies.role[e] != EnemyPool.ROLE_FODDER:
				continue
			var from_p: float = sqrt((world.enemies.x[e] - old_x) ** 2.0 + (world.enemies.y[e] - old_y) ** 2.0)
			if from_p > max_range:
				continue
			var from_cur: float = sqrt((world.enemies.x[e] - world.aim_x) ** 2.0 + (world.enemies.y[e] - world.aim_y) ** 2.0)
			if from_cur <= max_range and from_cur < best_fodder_d:
				best_fodder_d = from_cur
				fodder_idx = e
		if fodder_idx >= 0:
			new_x = world.enemies.x[fodder_idx]
			new_y = world.enemies.y[fodder_idx]
			world.enemies.x[fodder_idx] = old_x
			world.enemies.y[fodder_idx] = old_y
		else:
			var dx: float = world.aim_x - old_x
			var dy: float = world.aim_y - old_y
			var dist: float = sqrt(dx * dx + dy * dy)
			var step_d: float = minf(dist, max_range * 0.65)
			if dist > 0.001:
				new_x = old_x + (dx / dist) * step_d
				new_y = old_y + (dy / dist) * step_d
	var clamped: Vector2 = _clamp_pos(world, new_x, new_y, world.player.radius)
	clamped = _push_out_pillars(world, clamped.x, clamped.y, world.player.radius)
	world.player.x = clamped.x
	world.player.y = clamped.y
	world.player.iframe_remain = maxf(world.player.iframe_remain, float(effect.get("iframe", 0.22)))
	world.zones.spawn_swap_anchor(old_x, old_y, 32.0, 0.45, element)
	world.fx.emit(FxIds.DASH, old_x, old_y, 0x9B6BFF)
	var arr_r: float = float(effect.get("arrivalRadius", 90.0)) * world.stats.aoe_radius_mul
	var arr_dmg: float = float(effect.get("arrivalDamage", 28.0)) * world.stats.damage_mul
	var stun_dur: float = float(effect.get("stunDuration", 1.2)) * world.stats.control_duration_mul
	world.fx.emit(FxIds.STRIKE, clamped.x, clamped.y, 0x9B6BFF, arr_r)
	var any_crit: bool = false
	for e: int in world.enemies.cap:
		if world.enemies.alive[e] == 0 or world.enemies.corpse_remain[e] > 0.0:
			continue
		if not SimCollision.circles_overlap(clamped.x, clamped.y, arr_r, world.enemies.x[e], world.enemies.y[e], world.enemies.radius[e]):
			continue
		var is_crit: bool = world.randf() < world.stats.crit_chance
		var dmg: float = arr_dmg * (world.stats.crit_mul if is_crit else 1.0)
		SimEnemies.apply_damage(world, e, dmg)
		if is_crit:
			any_crit = true
		if world.enemies.alive[e] != 0:
			world.enemies.apply_stun(e, stun_dur)
	if any_crit:
		world.trigger_on_crit()


static func _cast_nova_burst(
	world: SimWorld,
	effect: Dictionary,
	is_sec_or_spec: bool,
	element: String,
	width_mul: float,
) -> void:
	var rad: float = float(effect.get("radius", 170.0)) * world.stats.aoe_radius_mul * width_mul
	var base_dmg: float = float(effect.get("damage", 80.0)) * world.stats.damage_mul
	var kb: float = float(effect.get("knockback", 200.0))
	var slow_m: float = float(effect.get("slowMul", 1.0))
	var slow_dur: float = float(effect.get("slowDuration", 0.0)) * world.stats.control_duration_mul
	var burn_dps: float = float(effect.get("burnDps", 0.0)) * world.stats.damage_mul
	var burn_dur: float = float(effect.get("burnDuration", 0.0)) * world.stats.control_duration_mul
	var heal_pct: float = float(effect.get("selfHealPct", 0.0))
	if heal_pct > 0.0:
		world.heal_player(world.player.max_hp * heal_pct)
	var px: float = world.player.x
	var py: float = world.player.y
	world.fx.emit(FxIds.CRUCIBLE_IMPACT, px, py, 0xFFAA55 if element == "fire" else 0xDFF6FF, rad)
	var any_crit: bool = false
	for e: int in world.enemies.cap:
		if world.enemies.alive[e] == 0 or world.enemies.corpse_remain[e] > 0.0:
			continue
		if not SimCollision.circles_overlap(px, py, rad, world.enemies.x[e], world.enemies.y[e], world.enemies.radius[e]):
			continue
		var is_crit: bool = world.randf() < world.stats.crit_chance
		var dmg: float = base_dmg * (world.stats.crit_mul if is_crit else 1.0)
		SimEnemies.apply_damage(world, e, dmg)
		world.fx.emit(FxIds.HIT, world.enemies.x[e], world.enemies.y[e], 0xFF4422 if is_crit else 0xFFF4C8)
		if is_crit:
			any_crit = true
		if world.enemies.alive[e] != 0:
			if kb > 0.0 and world.enemies.role[e] != EnemyPool.ROLE_BOSS:
				_push_enemy(world, e, px, py, kb)
			if slow_dur > 0.0 and slow_m < 1.0:
				world.enemies.apply_slow(e, slow_m, slow_dur)
			if burn_dps > 0.0 and burn_dur > 0.0:
				world.enemies.apply_burn(e, burn_dps, burn_dur)
	if any_crit:
		world.trigger_on_crit()
	SimObstacles.hit_aoe(world, px, py, rad, base_dmg, is_sec_or_spec, element)
	if is_sec_or_spec:
		SimAlchemy.trigger_surface_reaction(world, px, py, rad, true, element)


static func _push_enemy(world: SimWorld, enemy_idx: int, ox: float, oy: float, impulse: float) -> void:
	if impulse <= 0.0:
		return
	var dx: float = world.enemies.x[enemy_idx] - ox
	var dy: float = world.enemies.y[enemy_idx] - oy
	var dist: float = sqrt(dx * dx + dy * dy)
	if dist <= 0.001:
		return
	world.enemies.apply_knockback(enemy_idx, (dx / dist) * impulse, (dy / dist) * impulse)


static func _clamp_pos(world: SimWorld, px: float, py: float, r: float) -> Vector2:
	if world.arena_shape == "circle":
		return SimCollision.clamp_to_circle(px, py, maxf(1.0, world.arena_radius - world.arena_rim_thickness - r))
	var bounds: Dictionary = world.catalog.world
	var pad_x: float = float(bounds.get("borderInsetX", 0.0)) + r
	var pad_y: float = float(bounds.get("borderInsetY", 0.0)) + r
	return Vector2(
		clampf(px, pad_x, float(bounds.get("width", 6000.0)) - pad_x),
		clampf(py, pad_y, float(bounds.get("height", 6000.0)) - pad_y),
	)


static func _push_out_pillars(world: SimWorld, px: float, py: float, r: float) -> Vector2:
	var out_x: float = px
	var out_y: float = py
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		if obs.type != &"pillar":
			continue
		if SimCollision.circles_overlap(out_x, out_y, r, obs.x, obs.y, obs.radius):
			var split: Vector4 = SimCollision.push_circles(out_x, out_y, r, obs.x, obs.y, obs.radius, 1.0, 0.0)
			out_x = split.x
			out_y = split.y
	return _clamp_pos(world, out_x, out_y, r)


static func _start_dash(world: SimWorld, input: InputFrame, effect: Dictionary) -> void:
	if float(effect.get("duration", 0.0)) <= 0.0:
		return
	var dx: float = input.move_x
	var dy: float = input.move_y
	if sqrt(dx * dx + dy * dy) < 0.01:
		dx = world.aim_x - world.player.x
		dy = world.aim_y - world.player.y
	var dist: float = sqrt(dx * dx + dy * dy)
	if dist < 0.001:
		return
	var speed: float = float(effect.get("distance", 210.0)) / float(effect.get("duration", 0.16))
	var decoy_dur: float = float(effect.get("decoyDuration", 0.0))
	if decoy_dur > 0.0:
		world.decoy.spawn(world.player.x, world.player.y, decoy_dur * world.stats.control_duration_mul)
	world.player.dash_vx = (dx / dist) * speed
	world.player.dash_vy = (dy / dist) * speed
	world.player.dash_remain = float(effect.get("duration", 0.16))
	world.player.iframe_remain = float(effect.get("iframe", 0.22))
	world.fx.emit(FxIds.DASH, world.player.x, world.player.y, 0x9AD4FF)
