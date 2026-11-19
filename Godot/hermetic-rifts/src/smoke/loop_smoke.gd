extends SceneTree


func _init() -> void:
	var cat: Catalog = Catalog.load_from_res("res://data/catalog")
	var world: SimWorld = SimWorld.create(cat)
	var input: InputFrame = InputFrame.empty()
	_assert_obstacles(world, "stage-init")
	var init_ids: PackedInt32Array = _obstacle_ids(world)
	var last_phase: StringName = world.phase
	var last_stage: int = world.stage_index
	var last_stage_gen: int = world.stage_gen
	var last_tel: StringName = world.teleporter_state
	var last_level: int = world.level
	var last_boss: bool = world.boss_spawned
	var encounters_at_boss: Dictionary = {}
	var dt: float = 1.0 / 60.0
	var log_lines: PackedStringArray = PackedStringArray()
	var t: float = 0.0
	var portal_sweep_t: float = 0.0
	while world.run_time < 720.0:
		if world.phase == &"levelup":
			SimLevel.apply_choice(world, _safest_offer(world))
			continue
		if world.phase == &"victory" or world.phase == &"defeat":
			break
		if world.portal_open:
			portal_sweep_t += dt
		else:
			portal_sweep_t = 0.0
		_steer(world, input, t, portal_sweep_t < 2.2)
		var frames: Array[InputFrame] = [input]
		world.step(frames, dt)
		t += dt
		if world.phase != last_phase:
			log_lines.append("%.1fs phase %s -> %s" % [world.run_time, last_phase, world.phase])
			last_phase = world.phase
		if world.stage_gen != last_stage_gen or world.stage_index != last_stage:
			log_lines.append("%.1fs stage %d (%s)" % [world.run_time, world.stage_index, world.stage_id])
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
			last_stage_gen = world.stage_gen
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
					var atk_t: String = String(atk.get("type", ""))
					if atk_t == "summon" or atk_t == "chain_anchor":
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
	print("phase=%s runTime=%.1f won=%s cycle=%d exitedPortal=%s hp=%.1f kills=%d items=%s" % [
		world.phase, world.run_time, world.won, world.cycle_index, world.exited_via_victory_portal, world.player.hp, world.kills_total, ",".join(inv),
	])
	if world.phase != &"victory" or not world.won or world.cycle_index != 0 or not world.exited_via_victory_portal:
		push_error("loop-smoke failed: %s won=%s cycle=%d exitedPortal=%s" % [world.phase, world.won, world.cycle_index, world.exited_via_victory_portal])
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
		var oid: String = String(world.offer[i].get("id", ""))
		var prev_stacks: int = (existing.stacks - 1) if existing != null else 0
		var st: ResolvedStats = SimStats.resolve(world.survivor.get("stats", {}), trial, world.catalog)
		var score: float = (
			st.damage_mul * 48.0
			+ st.speed / 30.0
			+ st.max_hp / 24.0
			+ st.hp_regen * 24.0
			+ st.armor * 34.0
			+ (1.0 - st.cooldown_mul) * 44.0
			+ st.crit_chance * 46.0
			+ st.crit_mul * 12.0
			+ st.aoe_radius_mul * 10.0
		)
		if oid == "brittle-plate":
			score += 12.0 if prev_stacks == 0 else (4.0 if prev_stacks == 1 else -6.0)
		if oid == "goat-hoof":
			score += 12.0 if prev_stacks == 0 else (2.0 if prev_stacks == 1 else -10.0)
		if oid == "salt-ward":
			score += 2.0 if prev_stacks == 0 else -8.0
		if oid == "wax-wings":
			score += -4.0 if prev_stacks == 0 else -16.0
		if oid == "cinnabar-leech":
			score += 20.0 if prev_stacks == 0 else (10.0 if prev_stacks == 1 else -14.0)
		if oid == "glass-cannon" and st.max_hp >= 72.0 and prev_stacks == 0:
			score += 12.0
		if oid == "lead-core":
			score += 12.0 if (prev_stacks == 0 and st.max_hp < 125.0) else 2.0
		if oid == "hungry-clip":
			score -= 80.0
		if oid == "calcined-lens" and st.speed >= 260.0:
			score += 16.0 if prev_stacks == 0 else 4.0
		if oid == "hair-trigger":
			score += 16.0 if prev_stacks < 3 else 4.0
		if oid == "mercury-vial":
			score += 14.0 if prev_stacks == 0 else -8.0
		if st.max_hp < 72.0:
			score -= 34.0
		if st.speed < 230.0:
			score -= 22.0
		if String(world.offer[i].get("rarity", "")) == "lunar":
			score -= 40.0
		if score > best_score:
			best_score = score
			best = i
	return best


func _assert_obstacles(world: SimWorld, tag: String) -> void:
	var expected: Dictionary = world.catalog.obstacles.get("counts", {})
	var exp_pillar: int = int(expected.get("pillar", 0))
	var exp_hazard: int = int(expected.get("hazard", 0))
	var exp_volatile: int = int(expected.get("volatile", 0))
	var pillar: int = world.obstacles.count_type(&"pillar")
	var hazard: int = world.obstacles.count_type(&"hazard")
	var volatile: int = world.obstacles.count_type(&"volatile")
	if pillar != exp_pillar or hazard != exp_hazard or volatile != exp_volatile:
		push_error("%s obstacle counts pillar=%d hazard=%d volatile=%d (expected %d/%d/%d)" % [tag, pillar, hazard, volatile, exp_pillar, exp_hazard, exp_volatile])
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


func _pick_target_portal(world: SimWorld) -> Dictionary:
	var best: Dictionary = {}
	var last_stage: bool = SimLoop.is_last_stage(world)
	for p_v: Variant in world.portals:
		var p: Dictionary = p_v
		var kind: String = String(p.get("kind", "next"))
		if last_stage:
			if kind == "silver":
				return p
		elif kind != "secret" and kind != "gold" and kind != "crimson":
			return p
	if not world.portals.is_empty():
		best = world.portals[0]
	return best


func _steer(world: SimWorld, input: InputFrame, t: float, allow_portal_gems: bool = false) -> void:
	var player: PlayerState = world.player
	input.interact_held = false
	input.interact_pressed = false
	var eff_r: float = SimLoop.effective_teleporter_radius(world)
	var tx: float = player.x + cos(t * 0.8) * 320.0
	var ty: float = player.y + sin(t * 0.8) * 320.0
	var target_portal: Dictionary = {}
	if world.portal_open:
		target_portal = _pick_target_portal(world)
		tx = float(target_portal.get("x", world.portal_x))
		ty = float(target_portal.get("y", world.portal_y))
	elif world.teleporter_state == &"ready":
		tx = world.teleporter_x
		ty = world.teleporter_y
	elif world.teleporter_state == &"charging":
		var orbit: float = eff_r * 0.72
		var t_ang: float = atan2(player.y - world.teleporter_y, player.x - world.teleporter_x)
		tx = world.teleporter_x + cos(t_ang + 0.48) * orbit
		ty = world.teleporter_y + sin(t_ang + 0.48) * orbit
	elif world.boss_spawned and world.counts_boss > 0:
		for i: int in world.enemies.cap:
			if world.enemies.alive[i] == 0 or world.enemies.role[i] != EnemyPool.ROLE_BOSS:
				continue
			var b_ox: float = world.enemies.x[i]
			var b_oy: float = world.enemies.y[i]
			var bid: String = world.enemies.def_id[i]
			var orbit_r: float = 390.0 if (bid == "voltaic-regent" or bid == "viridian-alchemist" or bid == "arch-alchemist") else 295.0
			var ang: float = atan2(player.y - b_oy, player.x - b_ox)
			var ccw_x: float = b_ox + cos(ang + 0.36) * orbit_r
			var ccw_y: float = b_oy + sin(ang + 0.36) * orbit_r
			var cw_x: float = b_ox + cos(ang - 0.36) * orbit_r
			var cw_y: float = b_oy + sin(ang - 0.36) * orbit_r
			var r2_ccw: float = ccw_x * ccw_x + ccw_y * ccw_y
			var r2_cw: float = cw_x * cw_x + cw_y * cw_y
			var ccw_blk: bool = SimEnemies.pillar_blocks_shot(world, ccw_x, ccw_y, b_ox, b_oy)
			var cw_blk: bool = SimEnemies.pillar_blocks_shot(world, cw_x, cw_y, b_ox, b_oy)
			if world.arena_shape == "circle" and maxf(r2_ccw, r2_cw) > (world.arena_radius - 260.0) ** 2.0:
				if r2_cw < r2_ccw:
					tx = cw_x
					ty = cw_y
				else:
					tx = ccw_x
					ty = ccw_y
			elif ccw_blk and not cw_blk:
				tx = cw_x
				ty = cw_y
			else:
				tx = ccw_x
				ty = ccw_y
			break
	var found_gem: bool = false
	if (not world.portal_open or allow_portal_gems) and world.teleporter_state != &"ready" and world.teleporter_state != &"charging":
		var best_gem_d: float = 250.0
		var gem_tx: float = tx
		var gem_ty: float = ty
		var b_ref_x: float = 0.0
		var b_ref_y: float = 0.0
		var has_boss_ref: bool = false
		if world.boss_spawned and world.counts_boss > 0:
			for bi: int in world.enemies.cap:
				if world.enemies.alive[bi] != 0 and world.enemies.role[bi] == EnemyPool.ROLE_BOSS:
					b_ref_x = world.enemies.x[bi]
					b_ref_y = world.enemies.y[bi]
					has_boss_ref = true
					break
		for g: int in world.gems.cap:
			if world.gems.alive[g] == 0:
				continue
			var gx: float = world.gems.x[g]
			var gy: float = world.gems.y[g]
			if has_boss_ref and sqrt((gx - b_ref_x) ** 2.0 + (gy - b_ref_y) ** 2.0) < 260.0:
				continue
			if world.portal_open:
				var skip_p: bool = false
				var tp_x: float = float(target_portal.get("x", world.portal_x))
				var tp_y: float = float(target_portal.get("y", world.portal_y))
				for op_v: Variant in world.portals:
					var op: Dictionary = op_v
					var opx: float = float(op.get("x", 0.0))
					var opy: float = float(op.get("y", 0.0))
					if absf(opx - tp_x) > 1.0 or absf(opy - tp_y) > 1.0:
						if sqrt((gx - opx) ** 2.0 + (gy - opy) ** 2.0) < 125.0:
							skip_p = true
							break
				if skip_p:
					continue
			var gd: float = sqrt((gx - player.x) ** 2.0 + (gy - player.y) ** 2.0)
			if gd < best_gem_d:
				best_gem_d = gd
				gem_tx = gx
				gem_ty = gy
				found_gem = true
		if found_gem:
			tx = gem_tx
			ty = gem_ty

	var dodge_x: float = 0.0
	var dodge_y: float = 0.0
	var threat: bool = false
	var urgent_beam: bool = false
	var hazard_threat: bool = SimObstacles.overlapping_hazard(world, player.x, player.y, player.radius + 10.0)
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0 or world.enemies.role[i] == EnemyPool.ROLE_BOSS:
			continue
		var is_wind: bool = world.enemies.windup[i] > 0.0
		var is_act: bool = world.enemies.ai_state[i] == EnemyPool.AI_STATE_ACTIVE
		var is_chain: bool = world.enemies.role[i] == EnemyPool.ROLE_ELITE and world.enemies.affix[i] == "chain_lightning" and world.enemies.chain_cd[i] < 0.0
		if not is_wind and not is_act and not is_chain:
			continue
		if is_chain:
			var cdx_c: float = player.x - world.enemies.x[i]
			var cdy_c: float = player.y - world.enemies.y[i]
			var cd_c: float = sqrt(cdx_c * cdx_c + cdy_c * cdy_c)
			if cd_c <= 270.0 and not SimEnemies.pillar_blocks_shot(world, world.enemies.x[i], world.enemies.y[i], player.x, player.y):
				if -world.enemies.chain_cd[i] <= 0.21:
					threat = true
				if cd_c > 0.001:
					dodge_x += (cdx_c / cd_c) * 140.0
					dodge_y += (cdy_c / cd_c) * 140.0
		var def_id: String = world.enemies.def_id[i]
		var ai_t: String = "" if def_id == "" else String(DictUtil.d(world.catalog.entity(def_id), "ai").get("type", ""))
		if ai_t == "cleaver" and is_wind:
			var cl_dx: float = player.x - world.enemies.x[i]
			var cl_dy: float = player.y - world.enemies.y[i]
			var cl_d: float = sqrt(cl_dx * cl_dx + cl_dy * cl_dy)
			if cl_d < 118.0 and cl_d > 0.001:
				var adx: float = world.enemies.aim_x[i] - world.enemies.x[i]
				var ady: float = world.enemies.aim_y[i] - world.enemies.y[i]
				var alen: float = sqrt(adx * adx + ady * ady)
				if alen > 0.001 and BossHazardPool.point_in_cone(player.x, player.y, player.radius + 14.0, world.enemies.x[i], world.enemies.y[i], adx / alen, ady / alen, 92.0, deg_to_rad(125.0)):
					urgent_beam = true
					if world.enemies.windup[i] <= 0.21:
						threat = true
					dodge_x += (cl_dx / cl_d) * 260.0
					dodge_y += (cl_dy / cl_d) * 260.0
			continue
		if ai_t != "sniper" and ai_t != "charger":
			continue
		var sdx: float = world.enemies.aim_x[i] - world.enemies.x[i]
		var sdy: float = world.enemies.aim_y[i] - world.enemies.y[i]
		var slen: float = sqrt(sdx * sdx + sdy * sdy)
		if slen < 0.001:
			slen = 1.0
		var nx: float = sdx / slen
		var ny: float = sdy / slen
		var along: float = (player.x - world.enemies.x[i]) * nx + (player.y - world.enemies.y[i]) * ny
		if along < -15.0 or (ai_t == "charger" and along > 290.0):
			continue
		var px: float = player.x - world.enemies.x[i] - along * nx
		var py: float = player.y - world.enemies.y[i] - along * ny
		var dist: float = sqrt(px * px + py * py)
		var beam_pad: float = 68.0 if ai_t == "charger" else 50.0
		if dist < beam_pad:
			urgent_beam = true
			if ai_t == "sniper":
				if world.enemies.windup[i] <= 0.21:
					threat = true
			elif is_act or world.enemies.windup[i] <= 0.25:
				threat = true
			if dist > 0.001:
				dodge_x += (px / dist) * 260.0
				dodge_y += (py / dist) * 260.0
			else:
				dodge_x += -ny * 260.0
				dodge_y += nx * 260.0

	var aim_x: float = player.x + 80.0
	var aim_y: float = player.y
	var nearest_idx: int = -1
	var nearest_d: float = INF
	var boss_idx: int = -1
	var best_role_idx: int = -1
	var best_role: int = -1
	var best_role_d: float = INF
	var spire_idx: int = -1
	var spire_d: float = INF
	var sniper_idx: int = -1
	var sniper_d: float = INF
	var hexer_idx: int = -1
	var hexer_d: float = INF
	var chain_idx: int = -1
	var chain_d: float = INF
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0 or world.enemies.corpse_remain[i] > 0.0:
			continue
		var dx: float = world.enemies.x[i] - player.x
		var dy: float = world.enemies.y[i] - player.y
		var d: float = sqrt(dx * dx + dy * dy)
		var role: int = world.enemies.role[i]
		if world.enemies.def_id[i] == "enemy-astral-sniper" and d < 640.0 and d < sniper_d:
			if not SimEnemies.pillar_blocks_shot(world, player.x, player.y, world.enemies.x[i], world.enemies.y[i]):
				sniper_d = d
				sniper_idx = i
		elif world.enemies.def_id[i] == "aether-hexer" and d < 460.0 and d < hexer_d:
			if not SimEnemies.pillar_blocks_shot(world, player.x, player.y, world.enemies.x[i], world.enemies.y[i]):
				hexer_d = d
				hexer_idx = i
		if role == EnemyPool.ROLE_ELITE and world.enemies.affix[i] == "chain_lightning" and d < 400.0 and d < chain_d:
			if not SimEnemies.pillar_blocks_shot(world, player.x, player.y, world.enemies.x[i], world.enemies.y[i]):
				chain_d = d
				chain_idx = i
		if world.enemies.def_id[i] == "voltaic-spire" and d < spire_d:
			spire_d = d
			spire_idx = i
		if d < nearest_d:
			nearest_d = d
			nearest_idx = i
		if role == EnemyPool.ROLE_BOSS:
			boss_idx = i
		if role > best_role or (role == best_role and d < best_role_d):
			best_role = role
			best_role_d = d
			best_role_idx = i
		if role == EnemyPool.ROLE_ELITE and d < 78.0:
			threat = true
		elif role == 0 and d < 24.0 and player.hp < world.stats.max_hp * 0.5:
			threat = true
	var boss_clear: bool = boss_idx >= 0 and not SimEnemies.pillar_blocks_shot(world, player.x, player.y, world.enemies.x[boss_idx], world.enemies.y[boss_idx])
	var aim_idx: int = -1
	var close_limit: float = 85.0 if boss_idx >= 0 else 155.0
	if nearest_idx >= 0 and nearest_d < close_limit:
		aim_idx = nearest_idx
	elif sniper_idx >= 0:
		aim_idx = sniper_idx
	elif spire_idx >= 0 and spire_d < 220.0:
		aim_idx = spire_idx
	elif boss_clear:
		aim_idx = boss_idx
	elif chain_idx >= 0:
		aim_idx = chain_idx
	elif hexer_idx >= 0:
		aim_idx = hexer_idx
	elif nearest_idx >= 0 and nearest_d < 260.0:
		aim_idx = nearest_idx
	elif boss_idx >= 0:
		aim_idx = boss_idx
	else:
		aim_idx = best_role_idx if best_role_idx >= 0 else nearest_idx
	if aim_idx >= 0:
		aim_x = world.enemies.x[aim_idx]
		aim_y = world.enemies.y[aim_idx]

	for i: int in world.projectiles.alive.size():
		if world.projectiles.alive[i] == 0 or world.projectiles.team[i] != ProjectilePool.TEAM_ENEMY:
			continue
		var pvx: float = world.projectiles.vx[i]
		var pvy: float = world.projectiles.vy[i]
		var spd: float = sqrt(pvx * pvx + pvy * pvy)
		var rel_x: float = player.x - world.projectiles.x[i]
		var rel_y: float = player.y - world.projectiles.y[i]
		if spd > 1.0:
			var ux: float = pvx / spd
			var uy: float = pvy / spd
			var fwd: float = rel_x * ux + rel_y * uy
			if fwd > -12.0 and fwd < 240.0:
				var lat: float = rel_x * (-uy) + rel_y * ux
				var clear_r: float = player.radius + world.projectiles.radius[i] + 32.0
				if absf(lat) < clear_r:
					var lat_sign: float = 1.0 if lat >= 0.0 else -1.0
					var tti: float = maxf(0.05, fwd / spd)
					var w: float = (1.0 / tti) * 18.0
					dodge_x += (-uy * lat_sign) * w
					dodge_y += (ux * lat_sign) * w
					if tti < 0.22 and absf(lat) < player.radius + world.projectiles.radius[i] + 12.0:
						threat = true
		else:
			var d: float = sqrt(rel_x * rel_x + rel_y * rel_y)
			if d < 120.0 and d > 0.001:
				threat = true
				dodge_x += (rel_x / d) * (120.0 - d)
				dodge_y += (rel_y / d) * (120.0 - d)

	var avoid_x: float = 0.0
	var avoid_y: float = 0.0
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		if obs.type == &"obelisk" or obs.type == &"geode":
			continue
		if obs.type == &"vent" and obs.state == &"idle":
			continue
		if obs.type == &"hazard" and obs.sub_kind == "frozen":
			continue
		var odx: float = player.x - obs.x
		var ody: float = player.y - obs.y
		var od: float = sqrt(odx * odx + ody * ody)
		var pad: float = obs.radius + player.radius + 16.0
		if obs.type == &"volatile":
			pad = (obs.radius + player.radius + 108.0) if obs.state == &"primed" else (obs.radius + player.radius + 16.0)
		elif obs.type == &"hazard" or obs.type == &"burn_trail" or obs.type == &"vent":
			pad = obs.radius + player.radius + 32.0
		if od < pad and od > 0.001:
			var ow: float = 4.6 if (obs.type == &"volatile" and obs.state == &"primed") else (3.6 if (obs.type == &"hazard" or obs.type == &"burn_trail" or obs.type == &"vent") else 1.8)
			avoid_x += (odx / od) * ow
			avoid_y += (ody / od) * ow
			if obs.type == &"volatile" and obs.state == &"primed" and obs.timer <= 0.21:
				hazard_threat = true
			elif (obs.type == &"hazard" or obs.type == &"burn_trail" or obs.type == &"vent") and od < obs.radius + player.radius + 8.0:
				hazard_threat = true

	for z: int in world.zones.cap:
		if world.zones.alive[z] == 0 or int(world.zones.kind[z]) != ZonePool.ZONE_HEX_SIGIL:
			continue
		var zdx: float = player.x - world.zones.x[z]
		var zdy: float = player.y - world.zones.y[z]
		var zd: float = sqrt(zdx * zdx + zdy * zdy)
		var zreach: float = world.zones.radius[z] + player.radius + 34.0
		if zd < zreach and zd > 0.001:
			avoid_x += (zdx / zd) * 5.2
			avoid_y += (zdy / zd) * 5.2
			if world.zones.remain[z] <= 0.21 and zd <= world.zones.radius[z] + player.radius + 8.0:
				hazard_threat = true

	var bpool: BossHazardPool = world.boss_hazards
	for i: int in bpool.cap:
		if bpool.alive[i] == 0:
			continue
		var hkind: int = bpool.kind[i]
		var bdx: float = player.x - bpool.x[i]
		var bdy: float = player.y - bpool.y[i]
		var bd: float = sqrt(bdx * bdx + bdy * bdy)
		if hkind == BossHazardPool.HAZ_RING:
			if bd > bpool.radius[i] - 32.0 and bd < bpool.radius[i] + 68.0 and bd > 0.001:
				hazard_threat = true
				avoid_x += (-bdy / bd) * 2.2 + (bdx / bd) * 1.4
				avoid_y += (bdx / bd) * 2.2 + (bdy / bd) * 1.4
			continue
		if hkind == BossHazardPool.HAZ_PULSE:
			if bpool.state[i] == 0 and bd <= bpool.radius[i] + player.radius + 35.0 and bd > 0.001:
				var pulse_rem: float = bpool.duration[i] - bpool.elapsed[i]
				if pulse_rem <= 0.20 and bd <= bpool.radius[i] + player.radius + 10.0:
					hazard_threat = true
				avoid_x += (bdx / bd) * 6.0
				avoid_y += (bdy / bd) * 6.0
			continue
		if hkind == BossHazardPool.HAZ_CONE:
			if bd < bpool.radius[i] + player.radius + 20.0 and bd > 0.001:
				var cd_dot: float = (bdx / bd) * bpool.dir_x[i] + (bdy / bd) * bpool.dir_y[i]
				if cd_dot >= cos(bpool.angle[i] * 0.55 + 0.25):
					avoid_x += -bpool.dir_y[i] * 3.2 + (bdx / bd) * 1.4
					avoid_y += bpool.dir_x[i] * 3.2 + (bdy / bd) * 1.4
					hazard_threat = true
			continue
		var reach: float = bpool.radius[i] + player.radius + 28.0
		if bd < reach and bd > 0.001:
			avoid_x += (bdx / bd) * 3.8
			avoid_y += (bdy / bd) * 3.8
			if hkind == BossHazardPool.HAZ_POOL or (bpool.duration[i] - bpool.elapsed[i] <= 0.21):
				hazard_threat = true

	if boss_idx >= 0:
		var bx: float = world.enemies.x[boss_idx]
		var by: float = world.enemies.y[boss_idx]
		var b_rel_x: float = player.x - bx
		var b_rel_y: float = player.y - by
		var b_rel_d: float = sqrt(b_rel_x * b_rel_x + b_rel_y * b_rel_y)
		var b_id_a: String = world.enemies.def_id[boss_idx]
		var keep_boss_r: float = 330.0 if (b_id_a == "voltaic-regent" or b_id_a == "viridian-alchemist" or b_id_a == "arch-alchemist") else 245.0
		if b_rel_d < keep_boss_r and b_rel_d > 0.001:
			var b_push: float = ((keep_boss_r - b_rel_d) / keep_boss_r) * 3.2
			avoid_x += (b_rel_x / b_rel_d) * b_push
			avoid_y += (b_rel_y / b_rel_d) * b_push
		var boss_atk_type: String = ""
		if world.boss.active_attack >= 0:
			var b_atks: Array = DictUtil.a(DictUtil.d(world.catalog.entity(world.enemies.def_id[boss_idx]), "ai"), "attacks")
			if world.boss.active_attack < b_atks.size():
				boss_atk_type = String((b_atks[world.boss.active_attack] as Dictionary).get("type", ""))
		if world.boss.phase == &"dash" or (world.boss.phase == &"windup" and boss_atk_type == "dash_slam" and world.enemies.windup[boss_idx] > 0.0):
			var d_sx: float = world.boss.dash_dir_x
			var d_sy: float = world.boss.dash_dir_y
			var side_perp: float = (player.x - bx) * (-d_sy) + (player.y - by) * d_sx
			var side_sign: float = 1.0 if side_perp >= 0.0 else -1.0
			var along_d: float = (player.x - bx) * d_sx + (player.y - by) * d_sy
			if along_d > -40.0 and along_d < 360.0 and absf(side_perp) < 135.0:
				avoid_x += (-d_sy * side_sign) * 3.8
				avoid_y += (d_sx * side_sign) * 3.8
				if world.boss.phase == &"dash" or world.enemies.windup[boss_idx] <= 0.21:
					hazard_threat = true
			if world.boss.phase == &"dash":
				var rem_d: float = maxf(0.0, world.boss.duration - world.boss.elapsed) * 560.0
				var slx: float = player.x - (bx + d_sx * rem_d)
				var sly: float = player.y - (by + d_sy * rem_d)
				var sld: float = sqrt(slx * slx + sly * sly)
				if sld < 145.0 and sld > 0.001:
					avoid_x += (slx / sld) * 4.5
					avoid_y += (sly / sld) * 4.5
					hazard_threat = true
		if world.boss.phase == &"channel":
			var lx: float = world.boss.laser_end_x - bx
			var ly: float = world.boss.laser_end_y - by
			var l_len2: float = lx * lx + ly * ly
			if l_len2 > 1.0:
				var lproj: float = clampf(((player.x - bx) * lx + (player.y - by) * ly) / l_len2, 0.0, 1.0)
				var lcx: float = player.x - (bx + lx * lproj)
				var lcy: float = player.y - (by + ly * lproj)
				var ld: float = sqrt(lcx * lcx + lcy * lcy)
				if ld < 76.0:
					if ld > 0.001:
						avoid_x += (lcx / ld) * 4.2
						avoid_y += (lcy / ld) * 4.2
					else:
						var l_len: float = sqrt(l_len2)
						avoid_x += (-ly / l_len) * 4.2
						avoid_y += (lx / l_len) * 4.2
					if ld < 48.0:
						hazard_threat = true
		for s: int in world.enemies.cap:
			if world.enemies.alive[s] == 0 or world.enemies.def_id[s] != "voltaic-spire":
				continue
			var tsx: float = world.enemies.x[s] - bx
			var tsy: float = world.enemies.y[s] - by
			var tlen2: float = tsx * tsx + tsy * tsy
			if tlen2 > 1.0:
				var tproj: float = clampf(((player.x - bx) * tsx + (player.y - by) * tsy) / tlen2, 0.0, 1.0)
				var tcx: float = player.x - (bx + tsx * tproj)
				var tcy: float = player.y - (by + tsy * tproj)
				var td: float = sqrt(tcx * tcx + tcy * tcy)
				if td < player.radius + 64.0:
					if td > 0.001:
						avoid_x += (tcx / td) * 5.2
						avoid_y += (tcy / td) * 5.2
					else:
						var tlen: float = sqrt(tlen2)
						avoid_x += (-tsy / tlen) * 5.2
						avoid_y += (tsx / tlen) * 5.2
					if td < player.radius + 20.0:
						hazard_threat = true

	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0 or world.enemies.corpse_remain[i] > 0.0:
			continue
		var cdx: float = player.x - world.enemies.x[i]
		var cdy: float = player.y - world.enemies.y[i]
		var cd: float = sqrt(cdx * cdx + cdy * cdy)
		var is_winding: bool = world.enemies.windup[i] > 0.0
		var in_tel_ring: bool = world.teleporter_state == &"charging"
		var pad_e: float = (90.0 if in_tel_ring else 120.0) if is_winding else ((85.0 if in_tel_ring else 105.0) if world.enemies.role[i] != 0 else (56.0 if in_tel_ring else 76.0))
		var safe_d: float = world.enemies.radius[i] + player.radius + pad_e
		if cd < safe_d and cd > 0.001:
			var weight: float = 3.8 if is_winding else 2.5
			avoid_x += (cdx / cd) * ((safe_d - cd) / safe_d) * weight
			avoid_y += (cdy / cd) * ((safe_d - cd) / safe_d) * weight

	if world.arena_shape == "circle":
		var edge_r: float = sqrt(player.x * player.x + player.y * player.y)
		if edge_r > world.arena_radius - 135.0 and edge_r > 1.0:
			var edge_w: float = ((edge_r - (world.arena_radius - 135.0)) / 135.0) * 2.6
			avoid_x += (-player.x / edge_r) * edge_w
			avoid_y += (-player.y / edge_r) * edge_w

	var dodge_mag: float = sqrt(dodge_x * dodge_x + dodge_y * dodge_y)
	if dodge_mag > 1.0:
		var dodge_w: float = 22.0 if urgent_beam else 4.5
		avoid_x += (dodge_x / dodge_mag) * dodge_w
		avoid_y += (dodge_y / dodge_mag) * dodge_w
	var avoid_mag: float = sqrt(avoid_x * avoid_x + avoid_y * avoid_y)
	if avoid_mag > 0.25:
		tx = player.x + (avoid_x / avoid_mag) * 180.0
		ty = player.y + (avoid_y / avoid_mag) * 180.0

	if world.portal_open:
		if not allow_portal_gems or not found_gem or avoid_mag > 0.25:
			tx = float(target_portal.get("x", world.portal_x))
			ty = float(target_portal.get("y", world.portal_y))
		var p_dx: float = float(target_portal.get("x", world.portal_x)) - player.x
		var p_dy: float = float(target_portal.get("y", world.portal_y)) - player.y
		var p_dist: float = sqrt(p_dx * p_dx + p_dy * p_dy)
		var p_rad: float = float(target_portal.get("radius", float(world.catalog.loop.get("portalRadius", 70.0))))
		if p_dist <= p_rad * 0.85:
			input.interact_held = true
			input.interact_pressed = true
	elif world.teleporter_state == &"ready":
		if avoid_mag <= 0.25:
			tx = world.teleporter_x
			ty = world.teleporter_y
		var tel_dx: float = world.teleporter_x - player.x
		var tel_dy: float = world.teleporter_y - player.y
		var tel_dist: float = sqrt(tel_dx * tel_dx + tel_dy * tel_dy)
		if tel_dist <= world.teleporter_radius * 0.85:
			input.interact_held = true
			input.interact_pressed = true
	elif world.teleporter_state == &"charging":
		var rx: float = player.x - world.teleporter_x
		var ry: float = player.y - world.teleporter_y
		var p_tel_dist: float = sqrt(rx * rx + ry * ry)
		if not urgent_beam and avoid_mag > 0.25 and p_tel_dist > eff_r * 0.72 and p_tel_dist > 0.001:
			var t_cw_x: float = -ry / p_tel_dist
			var t_cw_y: float = rx / p_tel_dist
			if t_cw_x * avoid_x + t_cw_y * avoid_y < 0.0:
				t_cw_x = -t_cw_x
				t_cw_y = -t_cw_y
			var bx_in: float = -rx / p_tel_dist
			var by_in: float = -ry / p_tel_dist
			var in_w: float = 2.0 if p_tel_dist > eff_r * 0.98 else (1.0 if p_tel_dist > eff_r * 0.88 else 0.35)
			var steer_x: float = (avoid_x / avoid_mag) * 2.2 + t_cw_x * 1.0 + bx_in * in_w
			var steer_y: float = (avoid_y / avoid_mag) * 2.2 + t_cw_y * 1.0 + by_in * in_w
			tx = player.x + steer_x * 140.0
			ty = player.y + steer_y * 140.0
		if not urgent_beam and ((not hazard_threat and not threat) or p_tel_dist > eff_r * 0.99):
			var clamped_tel: Vector2 = SimCollision.clamp_to_circle(tx - world.teleporter_x, ty - world.teleporter_y, maxf(16.0, eff_r * 0.93))
			tx = world.teleporter_x + clamped_tel.x
			ty = world.teleporter_y + clamped_tel.y

	if world.arena_shape == "circle":
		var safe_arena: Vector2 = SimCollision.clamp_to_circle(tx, ty, maxf(64.0, world.arena_radius - 90.0))
		tx = safe_arena.x
		ty = safe_arena.y

	input.move_x = tx - player.x
	input.move_y = ty - player.y
	var mag: float = sqrt(input.move_x * input.move_x + input.move_y * input.move_y)
	if mag > 1.0:
		input.move_x /= mag
		input.move_y /= mag
	var will_dash: bool = (threat or hazard_threat) and float(player.skill_cd[InputFrame.SLOT_UTILITY]) <= 0.0 and player.dash_remain <= 0.0
	if will_dash and world.teleporter_state == &"charging" and not urgent_beam:
		var land_pt: Vector2 = SimCollision.clamp_to_circle(
			(player.x + input.move_x * 210.0) - world.teleporter_x,
			(player.y + input.move_y * 210.0) - world.teleporter_y,
			maxf(16.0, eff_r * 0.92),
		)
		var dmx: float = world.teleporter_x + land_pt.x - player.x
		var dmy: float = world.teleporter_y + land_pt.y - player.y
		var dmm: float = sqrt(dmx * dmx + dmy * dmy)
		if dmm > 1.0:
			input.move_x = dmx / dmm
			input.move_y = dmy / dmm
	var oh_cfg: Dictionary = DictUtil.d(world.catalog.loop, "overheat")
	var sweet_min: float = float(oh_cfg.get("sweetSpotMin", 0.80))
	var sec_cd: float = float(player.skill_cd[InputFrame.SLOT_SECONDARY])
	var sec_ready: bool = sec_cd <= 0.0
	var spec_ready: bool = float(player.skill_cd[InputFrame.SLOT_SPECIAL]) <= 0.0
	var vent_now: bool = player.heat >= sweet_min and player.overheat_lockout_remain <= 0.0 and sec_ready
	var hold_for_vent: bool = player.heat >= sweet_min and sec_cd <= 0.45
	input.held[InputFrame.SLOT_PRIMARY] = player.overheat_lockout_remain <= 0.0 and not hold_for_vent
	input.pressed[InputFrame.SLOT_PRIMARY] = input.held[InputFrame.SLOT_PRIMARY]
	var use_sec: bool = vent_now or (sec_ready and (player.overheat_lockout_remain > 0.0 or threat))
	input.held[InputFrame.SLOT_SECONDARY] = use_sec
	input.pressed[InputFrame.SLOT_SECONDARY] = use_sec
	var use_spec: bool = spec_ready and (boss_idx < 0 or world.boss.phase != &"dash")
	if use_spec:
		if boss_idx >= 0:
			aim_x = world.enemies.x[boss_idx]
			aim_y = world.enemies.y[boss_idx]
		else:
			var best_c_score: int = 0
			var best_c_idx: int = -1
			for ci: int in world.enemies.cap:
				if world.enemies.alive[ci] == 0 or world.enemies.corpse_remain[ci] > 0.0:
					continue
				var cdx2: float = world.enemies.x[ci] - player.x
				var cdy2: float = world.enemies.y[ci] - player.y
				if cdx2 * cdx2 + cdy2 * cdy2 > 340.0 * 340.0:
					continue
				var cnt: int = 0
				for cj: int in world.enemies.cap:
					if world.enemies.alive[cj] == 0 or world.enemies.corpse_remain[cj] > 0.0:
						continue
					var jdx: float = world.enemies.x[cj] - world.enemies.x[ci]
					var jdy: float = world.enemies.y[cj] - world.enemies.y[ci]
					if jdx * jdx + jdy * jdy <= 72.0 * 72.0:
						cnt += 2 if world.enemies.role[cj] == EnemyPool.ROLE_ELITE else 1
				if cnt > best_c_score:
					best_c_score = cnt
					best_c_idx = ci
			if best_c_idx >= 0:
				aim_x = world.enemies.x[best_c_idx]
				aim_y = world.enemies.y[best_c_idx]
	input.aim_x = aim_x
	input.aim_y = aim_y
	input.held[InputFrame.SLOT_SPECIAL] = use_spec
	input.pressed[InputFrame.SLOT_SPECIAL] = use_spec
	input.held[InputFrame.SLOT_UTILITY] = false
	input.pressed[InputFrame.SLOT_UTILITY] = (threat or hazard_threat) and float(player.skill_cd[InputFrame.SLOT_UTILITY]) <= 0.0 and player.dash_remain <= 0.0
