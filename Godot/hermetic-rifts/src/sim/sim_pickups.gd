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
