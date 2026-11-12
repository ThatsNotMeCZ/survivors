extends SceneTree


func _init() -> void:
	var cat: Catalog = Catalog.load_from_res("res://data/catalog")
	var world: SimWorld = SimWorld.create(cat)
	var input: InputFrame = InputFrame.empty()
	_assert_obstacles(world, "stage-init")
	var init_ids: PackedInt32Array = _obstacle_ids(world)
	var last_phase: StringName = world.phase
	var last_stage: int = world.stage_index
	var last_tel: StringName = world.teleporter_state
	var last_level: int = world.level
	var last_boss: bool = world.boss_spawned
	var encounters_at_boss: Dictionary = {}
	var dt: float = 1.0 / 60.0
	var log_lines: PackedStringArray = PackedStringArray()
	var t: float = 0.0
	while world.run_time < 520.0:
		if world.phase == &"levelup":
			SimLevel.apply_choice(world, _safest_offer(world))
			continue
		if SimLoop.is_last_stage(world) and world.boss_spawned and world.counts_boss > 0:
			for i: int in world.enemies.cap:
				if world.enemies.alive[i] == 0 or world.enemies.role[i] != EnemyPool.ROLE_BOSS:
					continue
				SimEnemies.kill(world, i)
				log_lines.append("%.1fs smoke-slew last seal guardian" % world.run_time)
				break
		if SimLoop.can_seal(world):
			SimLoop.complete_working(world)
			log_lines.append("%.1fs sealed Ouroboros gate cycle=%d" % [world.run_time, world.cycle_index])
			break
		if world.phase == &"victory" or world.phase == &"defeat":
			break
		_steer(world, input, t)
		var frames: Array[InputFrame] = [input]
		world.step(frames, dt)
		t += dt
		if world.phase != last_phase:
			log_lines.append("%.1fs phase %s -> %s" % [world.run_time, last_phase, world.phase])
			last_phase = world.phase
		if world.stage_index != last_stage:
			log_lines.append("%.1fs stage %d" % [world.run_time, world.stage_index])
			_assert_obstacles(world, "stage-wipe")
			var next_ids: PackedInt32Array = _obstacle_ids(world)
			if next_ids.is_empty():
				push_error("obstacles missing after stage wipe")
				quit(1)
				return
			var same: bool = next_ids.size() == init_ids.size()
			if same:
				for i: int in next_ids.size():
					if next_ids[i] != init_ids[i]:
						same = false
						break
			if same:
				push_error("obstacle ids did not reset on stage transition")
				quit(1)
				return
			last_stage = world.stage_index
		if world.teleporter_state != last_tel:
			log_lines.append("%.1fs tel %s -> %s" % [world.run_time, last_tel, world.teleporter_state])
			last_tel = world.teleporter_state
		if world.level != last_level:
			log_lines.append("%.1fs level %d" % [world.run_time, world.level])
			last_level = world.level
		if world.boss_spawned != last_boss:
			if world.boss_spawned:
				encounters_at_boss = world.encounters_by_entity.duplicate()
			last_boss = world.boss_spawned
		if world.boss_spawned and world.counts_boss > 0:
			var stage: Dictionary = SimLoop.current_stage(world)
			var boss_def: Dictionary = world.catalog.entity(String(stage.get("boss", "")))
			var allowed: Dictionary = {String(boss_def.get("id", "")): true}
			if String(DictUtil.d(boss_def, "ai").get("type", "")) == "boss":
				for atk_v: Variant in DictUtil.d(boss_def, "ai").get("attacks", []):
					var atk: Dictionary = atk_v
					if String(atk.get("type", "")) == "summon":
						allowed[String(atk.get("entity", ""))] = true
			for id: Variant in world.encounters_by_entity.keys():
				var count: int = int(world.encounters_by_entity[id])
				var prev: int = int(encounters_at_boss.get(id, 0))
				if count > prev and not allowed.has(String(id)):
					push_error("Director spawned entity \"%s\" during boss fight" % String(id))
					quit(1)
					return
	print("\n".join(log_lines))
	var inv: PackedStringArray = PackedStringArray()
	for inst: ItemInstance in world.inventory:
		inv.append("%s x%d" % [inst.id, inst.stacks])
	print("phase=%s runTime=%.1f won=%s cycle=%d hp=%.1f kills=%d items=%s" % [
		world.phase, world.run_time, world.won, world.cycle_index, world.player.hp, world.kills_total, ",".join(inv),
	])
	if world.phase != &"victory" or not world.won or world.cycle_index != 0:
		push_error("loop-smoke failed: %s won=%s cycle=%d" % [world.phase, world.won, world.cycle_index])
		quit(1)
		return
	quit(0)


func _safest_offer(world: SimWorld) -> int:
	if world.offer.is_empty():
		return 0
	var best: int = 0
	var best_score: float = -INF
	for i: int in world.offer.size():
		var trial: Array[ItemInstance] = []
		for inst: ItemInstance in world.inventory:
			trial.append(ItemInstance.make(inst.id, inst.stacks))
		var existing: ItemInstance = null
		for inst: ItemInstance in trial:
			if inst.id == String(world.offer[i].get("id", "")):
				existing = inst
				break
		if existing != null:
			existing.stacks += 1
		else:
			trial.append(ItemInstance.make(String(world.offer[i].get("id", "")), 1))
		var st: ResolvedStats = SimStats.resolve(world.survivor.get("stats", {}), trial, world.catalog)
		var score: float = st.damage_mul * 10.0 + st.speed / 60.0 + st.max_hp / 25.0
		var oid: String = String(world.offer[i].get("id", ""))
		if oid == "brittle-plate":
			score += 12.0
		if oid == "cinnabar-leech":
			score += 20.0
		if oid == "lead-core":
			score += 15.0
		if st.max_hp < 90.0:
			score -= 20.0
		if st.speed < 240.0:
			score -= 25.0
		if String(world.offer[i].get("rarity", "")) == "lunar":
			score -= 40.0
		if score > best_score:
			best_score = score
			best = i
	return best


func _assert_obstacles(world: SimWorld, tag: String) -> void:
	var pillar: int = world.obstacles.count_type(&"pillar")
	var hazard: int = world.obstacles.count_type(&"hazard")
	var volatile: int = world.obstacles.count_type(&"volatile")
	if pillar != 14 or hazard != 8 or volatile != 9:
		push_error("%s obstacle counts pillar=%d hazard=%d volatile=%d" % [tag, pillar, hazard, volatile])
		quit(1)
	if world.counts_fodder != 0 or world.counts_elite != 0 or world.counts_boss != 0:
		push_error("%s expected empty enemy pools" % tag)
		quit(1)


func _obstacle_ids(world: SimWorld) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		ids.append(world.obstacles.items[i].id)
	return ids


func _steer(world: SimWorld, input: InputFrame, t: float) -> void:
	var player: PlayerState = world.player
	var tx: float = player.x + cos(t * 0.8) * 400.0
	var ty: float = player.y + sin(t * 0.8) * 400.0
	if world.teleporter_state == &"charging":
		var orbit: float = world.teleporter_radius * 0.45
		tx = world.teleporter_x + cos(t * 2.2) * orbit
		ty = world.teleporter_y + sin(t * 2.2) * orbit
	elif world.boss_spawned and world.counts_boss > 0:
		for i: int in world.enemies.cap:
			if world.enemies.alive[i] == 0 or world.enemies.role[i] != EnemyPool.ROLE_BOSS:
				continue
			tx = world.enemies.x[i] + cos(t * 2.6) * 220.0
			ty = world.enemies.y[i] + sin(t * 2.6) * 220.0
			break
	if world.portal_open:
		tx = world.portal_x
		ty = world.portal_y
	var dodge_x: float = 0.0
	var dodge_y: float = 0.0
	var threat: bool = false
	var hazard_threat: bool = SimObstacles.overlapping_hazard(world, player.x, player.y, player.radius + 12.0)
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0 or world.enemies.windup[i] <= 0.0:
			continue
		var def_id: String = world.enemies.def_id[i]
		if def_id == "" or String(DictUtil.d(world.catalog.entity(def_id), "ai").get("type", "")) != "sniper":
			continue
		var sdx: float = world.enemies.aim_x[i] - world.enemies.x[i]
		var sdy: float = world.enemies.aim_y[i] - world.enemies.y[i]
		var slen: float = sqrt(sdx * sdx + sdy * sdy)
		if slen < 0.001:
			slen = 1.0
		var nx: float = sdx / slen
		var ny: float = sdy / slen
		var along: float = (player.x - world.enemies.x[i]) * nx + (player.y - world.enemies.y[i]) * ny
		var px: float = player.x - world.enemies.x[i] - along * nx
		var py: float = player.y - world.enemies.y[i] - along * ny
		var dist: float = sqrt(px * px + py * py)
		if dist < 28.0:
			threat = true
			dodge_x += px
			dodge_y += py
	var aim_x: float = player.x + 80.0
	var aim_y: float = player.y
	var best_role: int = -1
	var nearest: float = INF
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0:
			continue
		var dx: float = world.enemies.x[i] - player.x
		var dy: float = world.enemies.y[i] - player.y
		var d: float = sqrt(dx * dx + dy * dy)
		var role: int = world.enemies.role[i]
		if role > best_role or (role == best_role and d < nearest):
			best_role = role
			nearest = d
			aim_x = world.enemies.x[i]
			aim_y = world.enemies.y[i]
		if role != 0 and d < 110.0:
			threat = true
		if role == 0 and d < 64.0:
			threat = true
	for i: int in world.projectiles.alive.size():
		if world.projectiles.alive[i] == 0 or world.projectiles.team[i] != ProjectilePool.TEAM_ENEMY:
			continue
		var dx: float = world.projectiles.x[i] - player.x
		var dy: float = world.projectiles.y[i] - player.y
		var d: float = sqrt(dx * dx + dy * dy)
		if d < 120.0:
			threat = true
			dodge_x -= dx
			dodge_y -= dy
	if sqrt(dodge_x * dodge_x + dodge_y * dodge_y) > 1.0:
		tx = player.x + dodge_x
		ty = player.y + dodge_y
	var avoid_x: float = 0.0
	var avoid_y: float = 0.0
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		var odx: float = player.x - obs.x
		var ody: float = player.y - obs.y
		var od: float = sqrt(odx * odx + ody * ody)
		var pad: float = obs.radius + 40.0 if obs.type == &"hazard" else obs.radius + player.radius + 20.0
		if od < pad and od > 0.001:
			avoid_x += odx / od
			avoid_y += ody / od
			if obs.type == &"hazard":
				hazard_threat = true
	var bpool: BossHazardPool = world.boss_hazards
	for i: int in bpool.cap:
		if bpool.alive[i] == 0:
			continue
		var bdx: float = player.x - bpool.x[i]
		var bdy: float = player.y - bpool.y[i]
		var bd: float = sqrt(bdx * bdx + bdy * bdy)
		var reach: float = bpool.radius[i] + player.radius + 32.0
		if bd < reach and bd > 0.001:
			avoid_x += (bdx / bd) * 2.2
			avoid_y += (bdy / bd) * 2.2
			hazard_threat = true
	var crowd_x: float = 0.0
	var crowd_y: float = 0.0
	var close_count: int = 0
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0 or world.enemies.corpse_remain[i] > 0.0:
			continue
		var cdx: float = player.x - world.enemies.x[i]
		var cdy: float = player.y - world.enemies.y[i]
		var cd: float = sqrt(cdx * cdx + cdy * cdy)
		if cd < 140.0 and cd > 0.001:
			crowd_x += (cdx / cd) * (140.0 - cd)
			crowd_y += (cdy / cd) * (140.0 - cd)
			close_count += 1
	if close_count >= 3:
		avoid_x += crowd_x * 0.02
		avoid_y += crowd_y * 0.02
		threat = true
	if sqrt(avoid_x * avoid_x + avoid_y * avoid_y) > 0.2:
		tx = player.x + avoid_x * 200.0
		ty = player.y + avoid_y * 200.0
	if world.portal_open:
		tx = world.portal_x
		ty = world.portal_y
	elif world.teleporter_state == &"charging":
		var orbit2: float = world.teleporter_radius * 0.35
		tx = world.teleporter_x + cos(t * 2.2) * orbit2
		ty = world.teleporter_y + sin(t * 2.2) * orbit2
	input.move_x = tx - player.x
	input.move_y = ty - player.y
	var mag: float = sqrt(input.move_x * input.move_x + input.move_y * input.move_y)
	if mag > 1.0:
		input.move_x /= mag
		input.move_y /= mag
	input.aim_x = aim_x
	input.aim_y = aim_y
	input.held[InputFrame.SLOT_PRIMARY] = true
	input.held[InputFrame.SLOT_SECONDARY] = float(player.skill_cd[InputFrame.SLOT_SECONDARY]) <= 0.0
	input.pressed[InputFrame.SLOT_SECONDARY] = float(player.skill_cd[InputFrame.SLOT_SECONDARY]) <= 0.0
	input.held[InputFrame.SLOT_SPECIAL] = float(player.skill_cd[InputFrame.SLOT_SPECIAL]) <= 0.0
	input.pressed[InputFrame.SLOT_SPECIAL] = float(player.skill_cd[InputFrame.SLOT_SPECIAL]) <= 0.0
	input.held[InputFrame.SLOT_UTILITY] = false
	input.pressed[InputFrame.SLOT_UTILITY] = (threat or hazard_threat) and float(player.skill_cd[InputFrame.SLOT_UTILITY]) <= 0.0 and player.dash_remain <= 0.0
