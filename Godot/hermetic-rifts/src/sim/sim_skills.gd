class_name SimSkills
extends RefCounted


static func tick_cooldowns(world: SimWorld, dt: float) -> void:
	for slot: StringName in InputFrame.SLOTS:
		world.player.skill_cd[slot] = maxf(0.0, float(world.player.skill_cd[slot]) - dt)


static func try_skills(world: SimWorld, input: InputFrame) -> void:
	var skills: Dictionary = world.survivor.get("skills", {})
	for slot: StringName in InputFrame.SLOTS:
		var skill_id: String = String(skills.get(String(slot), ""))
		if skill_id == "":
			continue
		var skill: Dictionary = world.catalog.skill(skill_id)
		var want: bool = bool(input.held[slot]) if String(skill.get("input", "press")) == "hold" else bool(input.pressed[slot])
		if not want or float(world.player.skill_cd[slot]) > 0.0:
			continue
		if slot == InputFrame.SLOT_UTILITY and world.player.dash_remain > 0.0:
			continue
		for effect_v: Variant in skill.get("effects", []):
			_apply(world, input, effect_v)
		world.player.skill_cd[slot] = float(skill.get("cooldown", 1.0)) * world.stats.cooldown_mul


static func _apply(world: SimWorld, input: InputFrame, effect_v: Variant) -> void:
	var effect: Dictionary = effect_v
	var t: String = String(effect.get("type", ""))
	match t:
		"projectile":
			_fire_projectile(world, effect)
		"dash":
			_start_dash(world, input, effect)
		"self-slow":
			SimStatus.apply_slow(world.player, float(effect.get("mul", 1.0)), float(effect.get("duration", 0.0)))
		"delayed-strike":
			world.zones.spawn_delayed_strike(
				world.aim_x,
				world.aim_y,
				float(effect.get("radius", 70.0)) * world.stats.aoe_radius_mul,
				float(effect.get("delay", 0.55)),
				float(effect.get("damage", 28.0)) * world.stats.damage_mul,
			)
		"slow-line":
			_lay_slow_line(world, effect)
		"tether":
			_fire_tether(world, effect)


static func _aim_dir(world: SimWorld) -> Vector2:
	var dir_x: float = world.aim_x - world.player.x
	var dir_y: float = world.aim_y - world.player.y
	var dist: float = sqrt(dir_x * dir_x + dir_y * dir_y)
	if dist <= 0.001:
		return Vector2.ZERO
	return Vector2(dir_x / dist, dir_y / dist)


static func _fire_projectile(world: SimWorld, effect: Dictionary) -> void:
	var aim: Vector2 = _aim_dir(world)
	if aim == Vector2.ZERO:
		return
	var muzzle: float = world.player.radius + 8.0
	var flags: int = 0
	if bool(effect.get("pierce", false)):
		flags |= ProjectilePool.FLAG_PIERCE
	if bool(effect.get("flyOver", false)):
		flags |= ProjectilePool.FLAG_FLYOVER
	var impact_r: float = float(effect.get("impactRadius", 0.0)) * world.stats.aoe_radius_mul
	if impact_r > 0.0:
		flags |= ProjectilePool.FLAG_IMPACT | ProjectilePool.FLAG_FLYOVER
	world.projectiles.spawn(
		world.player.x + aim.x * muzzle,
		world.player.y + aim.y * muzzle,
		aim.x,
		aim.y,
		float(effect.get("speed", 780.0)) * world.stats.proj_speed_mul,
		float(effect.get("lifetime", 0.85)),
		float(effect.get("radius", 5.0)),
		float(effect.get("damage", 10.0)) * world.stats.damage_mul,
		ProjectilePool.TEAM_PLAYER,
		flags,
		world.aim_x,
		world.aim_y,
		impact_r,
		0.0,
		0.0,
		true,
	)


static func _fire_tether(world: SimWorld, effect: Dictionary) -> void:
	var aim: Vector2 = _aim_dir(world)
	if aim == Vector2.ZERO:
		return
	var muzzle: float = world.player.radius + 8.0
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
		ProjectilePool.FLAG_TETHER,
		0.0,
		0.0,
		0.0,
		float(effect.get("rootDuration", 2.4)) * world.stats.control_duration_mul,
		float(effect.get("fodderContactDps", 22.0)) * world.stats.damage_mul,
		false,
	)


static func _lay_slow_line(world: SimWorld, effect: Dictionary) -> void:
	var aim: Vector2 = _aim_dir(world)
	if aim == Vector2.ZERO:
		return
	var offset: float = float(effect.get("offset", 56.0))
	world.zones.spawn_slow_line(
		world.player.x + aim.x * offset,
		world.player.y + aim.y * offset,
		-aim.y,
		aim.x,
		float(effect.get("length", 520.0)) * world.stats.aoe_radius_mul,
		float(effect.get("width", 46.0)) * world.stats.aoe_radius_mul,
		float(effect.get("duration", 2.4)) * world.stats.control_duration_mul,
		float(effect.get("slowMul", 0.45)),
		float(effect.get("damage", 18.0)) * world.stats.damage_mul,
		bool(effect.get("fodderOnly", true)),
	)


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
