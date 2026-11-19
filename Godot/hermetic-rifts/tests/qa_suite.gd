extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	var cat: Catalog = Catalog.load_from_res("res://data/catalog")
	_run_suite(1, "Headless Sim Purity & Typing", _suite_01_sim_purity)
	_run_suite(2, "Dual RNG Determinism", func() -> bool: return _suite_02_determinism(cat))
	_run_suite(3, "Circular Arena Clamping", func() -> bool: return _suite_03_arena_clamping(cat))
	_run_suite(4, "Interactive Props & Elemental Surface Alchemy", func() -> bool: return _suite_04_props_and_alchemy(cat))
	_run_suite(5, "Open Teleporter, Living Ritual Tiers, Overheat & Drops", func() -> bool: return _suite_05_teleporter_overheat_drops(cat))
	_run_suite(6, "Enemies, Elites & Boss AI", func() -> bool: return _suite_06_enemies_elites_bosses(cat))
	_run_suite(7, "4 Vessels, Loadout A/B, Draft Tools & Branching/Portals", func() -> bool: return _suite_07_vessels_draft_portals(cat))
	_run_suite(8, "Persistence (ArchiveRecords & GameSettings)", func() -> bool: return _suite_08_persistence(cat))
	_run_suite(9, "Shaders & Generated Assets Integrity", _suite_09_shaders_and_assets)
	_run_suite(10, "Anti-Idle Compliance", func() -> bool: return _suite_10_anti_idle(cat))
	_run_suite(11, "SFX Range Fade & Culling", _suite_11_sfx_range_fade)

	if _failures.is_empty():
		print("[SUMMARY] All 11 QA suites passed.")
		quit(0)
	else:
		print("[SUMMARY] %d failure(s):" % _failures.size())
		for msg: String in _failures:
			print("  - %s" % msg)
		quit(1)


func _run_suite(num: int, title: String, fn: Callable) -> void:
	var before: int = _failures.size()
	var ok: bool = bool(fn.call())
	if ok and _failures.size() == before:
		print("[PASS] Suite %d — %s" % [num, title])
	else:
		print("[FAIL] Suite %d — %s" % [num, title])


func _check(cond: bool, label: String) -> bool:
	if not cond:
		_failures.append(label)
		printerr("  [ASSERT FAIL] %s" % label)
	return cond


func _strip_comments_and_strings(src: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	var lines: PackedStringArray = src.split("\n")
	for raw_line: String in lines:
		var line_buf: String = ""
		var in_str: String = ""
		var escaped: bool = false
		var i: int = 0
		while i < raw_line.length():
			var ch: String = raw_line.substr(i, 1)
			if in_str != "":
				if escaped:
					escaped = false
				elif ch == "\\":
					escaped = true
				elif ch == in_str:
					in_str = ""
				i += 1
				continue
			if ch == "#":
				break
			if ch == "\"" or ch == "'":
				in_str = ch
				line_buf += " \"\" "
				i += 1
				continue
			line_buf += ch
			i += 1
		out.append(line_buf)
	return "\n".join(out)


func _suite_01_sim_purity() -> bool:
	var ok: bool = true
	var dir: DirAccess = DirAccess.open("res://src/sim")
	if not _check(dir != null, "Suite 1: open res://src/sim"):
		return false
	var files: Array[String] = []
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".gd"):
			files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	files.sort()
	ok = _check(files.size() >= 20, "Suite 1: found %d sim scripts" % files.size()) and ok

	var rx_input: RegEx = RegEx.new()
	rx_input.compile("\\bInput\\.")
	var rx_engine: RegEx = RegEx.new()
	rx_engine.compile("\\bEngine\\.")
	var rx_tree: RegEx = RegEx.new()
	rx_tree.compile("\\bSceneTree\\b")
	var rx_node: RegEx = RegEx.new()
	rx_node.compile("\\bNode\\b")
	var rx_rand: RegEx = RegEx.new()
	rx_rand.compile("(^|[^A-Za-z0-9_.])(randi|randf|randi_range|randf_range|randfn|randomize)\\s*\\(")

	for fname: String in files:
		var path: String = "res://src/sim/%s" % fname
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if not _check(f != null, "Suite 1: read %s" % path):
			ok = false
			continue
		var raw: String = f.get_as_text()
		var clean: String = _strip_comments_and_strings(raw)
		ok = _check(rx_input.search(clean) == null, "Suite 1: Input. forbidden in %s" % fname) and ok
		ok = _check(rx_engine.search(clean) == null, "Suite 1: Engine. forbidden in %s" % fname) and ok
		ok = _check(rx_tree.search(clean) == null, "Suite 1: SceneTree forbidden in %s" % fname) and ok
		ok = _check(rx_node.search(clean) == null, "Suite 1: Node forbidden in %s" % fname) and ok

		var lines: PackedStringArray = clean.split("\n")
		for li: int in lines.size():
			var ln: String = lines[li]
			var stripped: String = ln.strip_edges()
			var m: RegExMatch = rx_rand.search(ln)
			if m != null:
				var fn_name: String = m.get_string(2)
				var is_simworld_method: bool = fname == "world.gd" and (fn_name == "randf" or fn_name == "randi_range")
				if not is_simworld_method:
					ok = _check(false, "Suite 1: bare %s() in %s:%d" % [fn_name, fname, li + 1]) and ok
			if stripped.begins_with("var ") and not stripped.contains(":"):
				ok = _check(false, "Suite 1: untyped var in %s:%d (%s)" % [fname, li + 1, stripped]) and ok
			if stripped.begins_with("func ") or stripped.begins_with("static func "):
				if stripped.ends_with(":") and not stripped.contains("->"):
					ok = _check(false, "Suite 1: missing return type in %s:%d (%s)" % [fname, li + 1, stripped]) and ok

	var world_file: FileAccess = FileAccess.open("res://src/sim/world.gd", FileAccess.READ)
	if world_file != null:
		var w_txt: String = world_file.get_as_text()
		ok = _check(w_txt.contains("var combat_rng: RandomNumberGenerator"), "Suite 1: world.gd uses RandomNumberGenerator") and ok
		ok = _check(w_txt.contains("return combat_rng.randf()"), "Suite 1: world.gd randf delegates to combat_rng") and ok
	return ok


func _suite_02_determinism(cat: Catalog) -> bool:
	var ok: bool = true
	var seed_val: int = 0xCAFE1234
	var w1: SimWorld = SimWorld.create(cat, "runner", [], [], seed_val)
	var w2: SimWorld = SimWorld.create(cat, "runner", [], [], seed_val)

	ok = _check(w1.run_seed == seed_val and w2.run_seed == seed_val, "Suite 2: fixed run_seed preserved") and ok
	ok = _check(is_equal_approx(w1.teleporter_x, w2.teleporter_x) and is_equal_approx(w1.teleporter_y, w2.teleporter_y), "Suite 2: teleporter position deterministic") and ok

	var obs_types: Array[StringName] = [&"pillar", &"hazard", &"volatile", &"vent", &"conduit", &"obelisk", &"geode"]
	for t: StringName in obs_types:
		ok = _check(w1.obstacles.count_type(t) == w2.obstacles.count_type(t), "Suite 2: obstacle count match for %s" % String(t)) and ok

	ok = _check(w1.obstacles.cap == w2.obstacles.cap, "Suite 2: obstacle cap identical") and ok
	for i: int in w1.obstacles.cap:
		if w1.obstacles.alive[i] != w2.obstacles.alive[i]:
			ok = _check(false, "Suite 2: obstacle alive mismatch at %d" % i) and ok
			break
		if w1.obstacles.alive[i] == 0:
			continue
		var o1: SimObstacle = w1.obstacles.items[i]
		var o2: SimObstacle = w2.obstacles.items[i]
		if o1.type != o2.type or not is_equal_approx(o1.x, o2.x) or not is_equal_approx(o1.y, o2.y) or o1.sub_kind != o2.sub_kind:
			ok = _check(false, "Suite 2: obstacle mismatch at %d (%s vs %s)" % [i, String(o1.type), String(o2.type)]) and ok
			break

	for r: int in 3:
		var c1: Array[Dictionary] = SimLevel.roll_choices(w1)
		var c2: Array[Dictionary] = SimLevel.roll_choices(w2)
		ok = _check(c1.size() == c2.size() and c1.size() == 3, "Suite 2: offer_rng roll %d size == 3" % r) and ok
		for k: int in mini(c1.size(), c2.size()):
			ok = _check(String(c1[k].get("id", "")) == String(c2[k].get("id", "")), "Suite 2: offer_rng roll %d idx %d identical" % [r, k]) and ok

	var w_rand1: SimWorld = SimWorld.create(cat, "runner")
	var w_rand2: SimWorld = SimWorld.create(cat, "runner")
	ok = _check(w_rand1.run_seed != w_rand2.run_seed, "Suite 2: non-Daily run_seeds differ (%d vs %d)" % [w_rand1.run_seed, w_rand2.run_seed]) and ok

	w1.gems.clear()
	w2.gems.clear()
	for _k: int in 25:
		SimPickups.spawn_enemy_drops(w1, 0.0, 0.0, 20.0, true, false)
		SimPickups.spawn_enemy_drops(w2, 0.0, 0.0, 20.0, true, false)
	var drop_diff: bool = false
	for i: int in w1.gems.cap:
		if w1.gems.alive[i] != w2.gems.alive[i] or not is_equal_approx(w1.gems.x[i], w2.gems.x[i]) or not is_equal_approx(w1.gems.xp[i], w2.gems.xp[i]):
			drop_diff = true
			break
	ok = _check(drop_diff, "Suite 2: combat_rng drop rolls differ even under identical run_seed") and ok
	return ok


func _suite_03_arena_clamping(cat: Catalog) -> bool:
	var ok: bool = true
	var world: SimWorld = SimWorld.create(cat, "runner", [], [], 0x1111)
	ok = _check(world.arena_shape == "circle", "Suite 3: arena_shape == circle") and ok
	ok = _check(is_equal_approx(world.arena_radius, 3000.0), "Suite 3: arena_radius == 3000.0") and ok
	ok = _check(is_equal_approx(world.player.x, 0.0) and is_equal_approx(world.player.y, 0.0), "Suite 3: player starts at (0, 0)") and ok
	var tel_d: float = sqrt(world.teleporter_x * world.teleporter_x + world.teleporter_y * world.teleporter_y)
	ok = _check(tel_d >= 1200.0 - 0.5 and tel_d <= 2400.0 + 0.5, "Suite 3: teleporter in [1200, 2400] (%.1f)" % tel_d) and ok
	var sp: Vector2 = SimEnemies.pick_spawn_point(world, 12.0)
	var sp_d: float = sp.distance_to(Vector2(world.player.x, world.player.y))
	ok = _check(sp.x != INF and sp_d >= 920.0 - 0.5 and sp.length() <= world.arena_radius, "Suite 3: spawn point >= 920px from player (%.1f)" % sp_d) and ok

	var input: InputFrame = InputFrame.empty()
	input.move_x = 1.0
	input.move_y = 0.25
	world.player.x = 3300.0
	world.player.y = 600.0
	var dt: float = 1.0 / 60.0
	for _f: int in 10:
		var frames: Array[InputFrame] = [input]
		world.step(frames, dt)
	var p_dist: float = sqrt(world.player.x * world.player.x + world.player.y * world.player.y)
	ok = _check(p_dist <= world.arena_radius - world.player.radius + 0.5, "Suite 3: player clamped inside circle (%.2f)" % p_dist) and ok

	var mite_def: Dictionary = cat.entity("ember-mite")
	var e1: int = SimEnemies.spawn(world, mite_def, 3500.0, 400.0)
	ok = _check(e1 >= 0, "Suite 3: enemy spawned") and ok
	if e1 >= 0:
		world.enemies.x[e1] = 3500.0
		world.enemies.y[e1] = 400.0
		SimEnemiesStep.step(world, dt)
		var d_step: float = sqrt(world.enemies.x[e1] * world.enemies.x[e1] + world.enemies.y[e1] * world.enemies.y[e1])
		ok = _check(d_step <= world.arena_radius - world.enemies.radius[e1] + 0.5, "Suite 3: SimEnemiesStep clamps enemy (%.2f)" % d_step) and ok

		world.enemies.x[e1] = -3360.0
		world.enemies.y[e1] = 800.0
		SimSeparation.resolve(world)
		var d_sep: float = sqrt(world.enemies.x[e1] * world.enemies.x[e1] + world.enemies.y[e1] * world.enemies.y[e1])
		ok = _check(d_sep <= world.arena_radius - world.enemies.radius[e1] + 0.5, "Suite 3: SimSeparation clamps enemy (%.2f)" % d_sep) and ok
	return ok


func _suite_04_props_and_alchemy(cat: Catalog) -> bool:
	var ok: bool = true
	var dt: float = 1.0 / 60.0
	var world: SimWorld = SimWorld.create(cat, "runner", [], [], 0x2222)
	ok = _check(world.obstacles.count_type(&"vent") > 0, "Suite 4: stage placed vents") and ok
	ok = _check(world.obstacles.count_type(&"conduit") > 0, "Suite 4: stage placed conduits") and ok
	ok = _check(world.obstacles.count_type(&"obelisk") > 0, "Suite 4: stage placed obelisks") and ok

	# 1. Vent
	world.obstacles.clear()
	SimObstacles.rebuild_hash(world)
	var vent_idx: int = SimObstacles.spawn(world, &"vent", 0.0, 0.0, "Alchemical Vent", 0.0, "", 8.95)
	ok = _check(vent_idx >= 0, "Suite 4: spawned vent") and ok
	if vent_idx >= 0:
		var prev_hp: float = world.player.hp
		SimObstacles.step(world, 0.1)
		var vent: SimObstacle = world.obstacles.items[vent_idx]
		ok = _check(vent.state == &"erupting", "Suite 4: vent enters erupting state") and ok
		ok = _check(world.player.hp < prev_hp and world.player.slow_remain > 0.0, "Suite 4: erupting vent damages and slows player") and ok

	# 2. Conduit
	world.obstacles.clear()
	SimEnemies.clear(world)
	world.projectiles.clear()
	world.player.x = 0.0
	world.player.y = 0.0
	world.player.hp = world.player.max_hp
	var conduit_idx: int = SimObstacles.spawn(world, &"conduit", 200.0, 0.0, "Resonance Conduit")
	SimObstacles.rebuild_hash(world)
	var chaser_def: Dictionary = cat.entity("ember-chaser")
	var enemy_near: int = SimEnemies.spawn(world, chaser_def, 290.0, 0.0)
	ok = _check(conduit_idx >= 0 and enemy_near >= 0, "Suite 4: spawned conduit + nearby enemy") and ok
	if conduit_idx >= 0 and enemy_near >= 0:
		var conduit: SimObstacle = world.obstacles.items[conduit_idx]
		var hp0: float = world.enemies.hp[enemy_near]
		# Primary shot (+0)
		world.projectiles.spawn(182.0, 0.0, 1.0, 0.0, 600.0, 0.5, 5.0, 10.0, ProjectilePool.TEAM_PLAYER, ProjectilePool.FLAG_PRIMARY)
		world.step([], dt)
		ok = _check(conduit.charges == 0, "Suite 4: Primary shot leaves conduit charges == 0 (got %d)" % conduit.charges) and ok
		# Enemy projectile (+1)
		world.projectiles.spawn(182.0, 0.0, 1.0, 0.0, 600.0, 0.5, 6.0, 10.0, ProjectilePool.TEAM_ENEMY, 0)
		world.step([], dt)
		ok = _check(conduit.charges == 1, "Suite 4: Enemy shot adds +1 conduit charge (got %d)" % conduit.charges) and ok
		# Secondary/Special (+2 -> discharges at 3)
		world.projectiles.spawn(182.0, 0.0, 1.0, 0.0, 600.0, 0.5, 6.0, 10.0, ProjectilePool.TEAM_PLAYER, ProjectilePool.FLAG_SECONDARY_OR_SPECIAL)
		world.step([], dt)
		ok = _check(conduit.state == &"depleted", "Suite 4: Conduit state == depleted after 3 charges") and ok
		ok = _check(conduit.charges == 0 and conduit.timer > 7.5 and conduit.timer <= 8.0, "Suite 4: Conduit recharge timer ~8.0s (got %.2f)" % conduit.timer) and ok
		ok = _check(world.enemies.hp[enemy_near] < hp0, "Suite 4: Conduit discharge damages enemy in 140px") and ok
		ok = _check(world.enemies.ai_state[enemy_near] == EnemyPool.AI_STATE_STUN and world.enemies.root_remain[enemy_near] > 0.25, "Suite 4: Conduit discharge stuns enemy in 140px") and ok

	# 3. Obelisks
	var w_ob: SimWorld = SimWorld.create(cat, "runner", [], [], 0x3333)
	w_ob.obstacles.clear()
	var rel_idx: int = SimObstacles.spawn(w_ob, &"obelisk", 0.0, 200.0, "Reliquary Obelisk", 0.0, "obelisk-reliquary")
	SimObstacles.rebuild_hash(w_ob)
	w_ob.player.x = 0.0
	w_ob.player.y = 200.0
	w_ob.player.iframe_remain = 120.0
	var rel_obs: SimObstacle = w_ob.obstacles.items[rel_idx]
	var hold_in: InputFrame = InputFrame.empty()
	hold_in.interact_held = true

	# Blocked while teleporter charging
	w_ob.teleporter_state = &"charging"
	for _i: int in 20:
		w_ob.step([hold_in], dt)
	ok = _check(rel_obs.state == &"idle" and is_equal_approx(rel_obs.progress, 0.0), "Suite 4: obelisk blocked during teleporter charging") and ok

	# Blocked while boss spawned
	w_ob.teleporter_state = &"ready"
	w_ob.boss_spawned = true
	w_ob.boss_defeated = false
	for _i: int in 20:
		w_ob.step([hold_in], dt)
	ok = _check(rel_obs.state == &"idle" and is_equal_approx(rel_obs.progress, 0.0), "Suite 4: obelisk blocked during boss fight") and ok

	# Unblocked channel 2.0s -> 20s reliquary trial -> bonus 3-card draft without levelup
	w_ob.boss_spawned = false
	for _i: int in 125:
		w_ob.player.iframe_remain = 120.0
		w_ob.step([hold_in], dt)
	ok = _check(rel_obs.state == &"trial_active", "Suite 4: obelisk-reliquary trial_active after 2.0s hold") and ok
	ok = _check(is_equal_approx(w_ob.obelisk_armor_debuff, -0.25), "Suite 4: reliquary sets -0.25 armor debuff") and ok

	hold_in.interact_held = false
	for _i: int in 1220:
		if w_ob.phase != &"play":
			break
		w_ob.player.iframe_remain = 120.0
		w_ob.step([hold_in], dt)
	ok = _check(rel_obs.state == &"completed", "Suite 4: obelisk-reliquary completed after 20s") and ok
	ok = _check(is_equal_approx(w_ob.obelisk_armor_debuff, 0.0), "Suite 4: reliquary clears armor debuff") and ok
	ok = _check(w_ob.phase == &"levelup" and w_ob.is_bonus_draft and w_ob.offer.size() == 3, "Suite 4: reliquary queues bonus 3-card draft") and ok
	ok = _check(w_ob.level == 1, "Suite 4: bonus draft does NOT increment world.level") and ok
	SimLevel.apply_choice(w_ob, 0)
	ok = _check(w_ob.phase == &"play" and w_ob.level == 1, "Suite 4: applying bonus draft returns to play at level 1") and ok

	# Blood obelisk
	w_ob.obstacles.clear()
	SimEnemies.clear(w_ob)
	var blood_idx: int = SimObstacles.spawn(w_ob, &"obelisk", -200.0, 0.0, "Blood Obelisk", 0.0, "obelisk-blood")
	SimObstacles.rebuild_hash(w_ob)
	var blood_obs: SimObstacle = w_ob.obstacles.items[blood_idx]
	w_ob.player.x = -200.0
	w_ob.player.y = 0.0
	hold_in.interact_held = true
	for _i: int in 125:
		w_ob.player.iframe_remain = 120.0
		w_ob.step([hold_in], dt)
	ok = _check(blood_obs.state == &"trial_active" and blood_obs.trial_remaining >= 2, "Suite 4: obelisk-blood spawned elites") and ok
	w_ob.player.hp = w_ob.player.max_hp * 0.4
	var hp_before_blood: float = w_ob.player.hp
	for e: int in w_ob.enemies.cap:
		if w_ob.enemies.alive[e] != 0 and w_ob.enemies.source_obstacle_id[e] == blood_obs.id:
			SimEnemies.kill(w_ob, e)
	ok = _check(blood_obs.state == &"completed", "Suite 4: obelisk-blood completed on elite defeat") and ok
	ok = _check(w_ob.player.hp > hp_before_blood, "Suite 4: obelisk-blood heals player (%.1f -> %.1f)" % [hp_before_blood, w_ob.player.hp]) and ok

	# Essence obelisk
	w_ob.obstacles.clear()
	SimEnemies.clear(w_ob)
	w_ob.gems.clear()
	var ess_idx: int = SimObstacles.spawn(w_ob, &"obelisk", 0.0, -200.0, "Essence Obelisk", 0.0, "obelisk-essence")
	SimObstacles.rebuild_hash(w_ob)
	var ess_obs: SimObstacle = w_ob.obstacles.items[ess_idx]
	w_ob.player.x = 0.0
	w_ob.player.y = -200.0
	for _i: int in 125:
		w_ob.player.iframe_remain = 120.0
		w_ob.step([hold_in], dt)
	ok = _check(ess_obs.state == &"trial_active" and ess_obs.trial_remaining >= 2, "Suite 4: obelisk-essence spawned elites") and ok
	w_ob.gems.clear()
	for e: int in w_ob.enemies.cap:
		if w_ob.enemies.alive[e] != 0 and w_ob.enemies.source_obstacle_id[e] == ess_obs.id:
			SimEnemies.kill(w_ob, e)
	var ess_gems: int = 0
	for g: int in w_ob.gems.cap:
		if w_ob.gems.alive[g] != 0 and w_ob.gems.kind[g] == GemPool.KIND_ESSENCE:
			ess_gems += 1
	ok = _check(ess_obs.state == &"completed" and ess_gems >= 2, "Suite 4: obelisk-essence dropped essence crystals (%d)" % ess_gems) and ok

	# 4. Geode
	var w_geo: SimWorld = SimWorld.create(cat, "runner", [], [], 0x4444)
	w_geo.obstacles.clear()
	w_geo.gems.clear()
	var g1_idx: int = SimObstacles.spawn(w_geo, &"geode", 400.0, 0.0, "Mercury Geode")
	var g2_idx: int = SimObstacles.spawn(w_geo, &"geode", 520.0, 0.0, "Mercury Geode")
	SimObstacles.rebuild_hash(w_geo)
	var g1: SimObstacle = w_geo.obstacles.items[g1_idx]
	var g2: SimObstacle = w_geo.obstacles.items[g2_idx]
	SimObstacles.damage_geode(w_geo, g1_idx, 10.0)
	ok = _check(is_equal_approx(g1.collapse_timer, 12.0), "Suite 4: first hit sets geode collapse_timer = 12.0") and ok
	var prev_cracked: int = w_geo.geodes_cracked_run
	SimObstacles.damage_geode(w_geo, g1_idx, 9999.0)
	ok = _check(w_geo.geodes_cracked_run == prev_cracked + 1 and g1.state == &"cracked", "Suite 4: breaking geode increments geodes_cracked_run") and ok
	for _i: int in 100:
		SimObstacles.step(w_geo, dt)
	ok = _check(g1.state == &"depleted", "Suite 4: cracked geode becomes depleted crater husk") and ok

	SimObstacles.damage_geode(w_geo, g2_idx, 10.0)
	w_geo.gems.clear()
	var cracked_before: int = w_geo.geodes_cracked_run
	for _i: int in 730:
		SimObstacles.step(w_geo, dt)
	var alive_gems: int = 0
	for g: int in w_geo.gems.cap:
		if w_geo.gems.alive[g] != 0:
			alive_gems += 1
	ok = _check(g2.state == &"depleted" and w_geo.geodes_cracked_run == cracked_before and alive_gems == 0, "Suite 4: expired geode drops 0 items and becomes depleted") and ok

	# 5. Surface Alchemy
	var w_alc: SimWorld = SimWorld.create(cat, "runner", [], [], 0x4545)
	w_alc.obstacles.clear()
	w_alc.zones.clear()
	var h1_idx: int = SimObstacles.spawn(w_alc, &"hazard", 600.0, 0.0, "Slag Fissure")
	SimObstacles.rebuild_hash(w_alc)
	ok = _check(not SimAlchemy.trigger_surface_reaction(w_alc, 600.0, 0.0, 30.0, false, "fire"), "Suite 4: Primary NEVER triggers surface reaction") and ok
	ok = _check(SimAlchemy.trigger_surface_reaction(w_alc, 600.0, 0.0, 30.0, true, "fire"), "Suite 4: Fire Secondary triggers Vitriol Flash") and ok
	var smoke_count: int = 0
	for z: int in w_alc.zones.cap:
		if w_alc.zones.alive[z] != 0 and w_alc.zones.kind[z] == ZonePool.ZONE_SMOKE_CLOUD:
			smoke_count += 1
	ok = _check(smoke_count == 1 and is_equal_approx(w_alc.obstacles.items[h1_idx].reaction_cooldown, 4.0), "Suite 4: Vitriol Flash spawns ZONE_SMOKE_CLOUD + sets 4.0s cooldown") and ok

	w_alc.obstacles.clear()
	w_alc.zones.clear()
	var h2_idx: int = SimObstacles.spawn(w_alc, &"hazard", 800.0, 0.0, "Brine Pool")
	var h3_idx: int = SimObstacles.spawn(w_alc, &"hazard", 810.0, 0.0, "Brine Pool")
	SimObstacles.rebuild_hash(w_alc)
	var react_before: int = w_alc.alchemy_reactions_run
	ok = _check(SimAlchemy.trigger_surface_reaction(w_alc, 805.0, 0.0, 40.0, true, "aether"), "Suite 4: Aether Secondary triggers Shatter Frost") and ok
	ok = _check(w_alc.alchemy_reactions_run == react_before + 1, "Suite 4: Shatter Frost never chains across overlapping hazards") and ok
	var h2: SimObstacle = w_alc.obstacles.items[h2_idx]
	var h3: SimObstacle = w_alc.obstacles.items[h3_idx]
	var frozen_obs_count: int = (1 if h2.sub_kind == "frozen" and is_equal_approx(h2.reaction_cooldown, 4.0) else 0) + (1 if h3.sub_kind == "frozen" and is_equal_approx(h3.reaction_cooldown, 4.0) else 0)
	var frozen_patch_count: int = 0
	for z: int in w_alc.zones.cap:
		if w_alc.zones.alive[z] != 0 and w_alc.zones.kind[z] == ZonePool.ZONE_FROZEN_PATCH:
			frozen_patch_count += 1
	ok = _check(frozen_obs_count == 1 and frozen_patch_count == 1, "Suite 4: Shatter Frost freezes exactly 1 hazard + spawns 1 ZONE_FROZEN_PATCH") and ok
	return ok


func _suite_05_teleporter_overheat_drops(cat: Catalog) -> bool:
	var ok: bool = true
	var dt: float = 1.0 / 60.0
	var w: SimWorld = SimWorld.create(cat, "runner", [], [], 0x5555)
	ok = _check(w.teleporter_state == &"ready" and not w.teleporter_discovered, "Suite 5: teleporter ready & undiscovered at spawn") and ok

	w.player.x = w.teleporter_x - 320.0
	w.player.y = w.teleporter_y
	w.step([], dt)
	ok = _check(w.teleporter_discovered, "Suite 5: teleporter discovered within <= 340px") and ok

	w.player.x = w.teleporter_x
	w.player.y = w.teleporter_y
	var act_in: InputFrame = InputFrame.empty()
	act_in.interact_pressed = true
	w.step([act_in], dt)
	ok = _check(w.teleporter_state == &"charging" and w.ritual_tier == 0 and w.teleporter_flawless_hold, "Suite 5: teleporter activated into charging") and ok

	var hold_in: InputFrame = InputFrame.empty()
	var saw_tier1: bool = false
	var saw_tier2: bool = false
	var fodder_spawned_for_rupture: bool = false
	var mite_idx: int = -1
	var spec_idx: int = -1
	var elite_idx: int = -1
	for _s: int in 3200:
		w.player.iframe_remain = 120.0
		w.player.x = w.teleporter_x
		w.player.y = w.teleporter_y
		if w.ritual_tier == 1:
			saw_tier1 = true
		if w.ritual_tier == 2:
			saw_tier2 = true
		if not fodder_spawned_for_rupture and w.teleporter_charge >= w.teleporter_hold - 0.05:
			fodder_spawned_for_rupture = true
			mite_idx = SimEnemies.spawn(w, cat.entity("ember-mite"), w.teleporter_x + 80.0, w.teleporter_y)
			spec_idx = SimEnemies.spawn(w, cat.entity("ember-spitter"), w.teleporter_x, w.teleporter_y + 90.0)
			elite_idx = SimEnemies.spawn(w, cat.entity("ember-chaser"), w.teleporter_x - 85.0, w.teleporter_y, true, "burn")
		w.step([hold_in], dt)
		if w.ritual_tier == 3:
			break
	ok = _check(saw_tier1 and saw_tier2 and w.ritual_tier == 3, "Suite 5: ritual tiers 1 -> 2 -> 3 reached") and ok
	ok = _check(w.hit_stop_remain >= 0.10, "Suite 5: rupture hit_stop_remain >= 0.10 (got %.3f)" % w.hit_stop_remain) and ok
	ok = _check(mite_idx >= 0 and w.enemies.vel_x[mite_idx] > 100.0, "Suite 5: rupture applies radial knockback to nearby fodder") and ok
	ok = _check(spec_idx >= 0 and w.enemies.vel_y[spec_idx] > 100.0, "Suite 5: rupture applies radial knockback to nearby specialist") and ok
	ok = _check(elite_idx >= 0 and w.enemies.vel_x[elite_idx] < -100.0, "Suite 5: rupture applies radial knockback to nearby elite") and ok
	ok = _check(w.boss_spawned and w.counts_boss == 1, "Suite 5: rupture spawns stage boss") and ok
	var boss_idx: int = w.boss.enemy_index
	ok = _check(boss_idx >= 0 and is_equal_approx(w.enemies.x[boss_idx], w.teleporter_x) and is_equal_approx(w.enemies.y[boss_idx], w.teleporter_y), "Suite 5: stage boss spawns at teleporter center") and ok
	ok = _check(w.boss.emerge_remain > 0.0, "Suite 5: stage boss starts with emerge_remain > 0.0") and ok
	var saw_emerge_fx: bool = false
	for fx_i: int in w.fx.count:
		if int(w.fx.kind[fx_i]) == FxIds.BOSS_EMERGE:
			saw_emerge_fx = true
			break
	ok = _check(saw_emerge_fx, "Suite 5: spawn_stage_boss emits FxIds.BOSS_EMERGE") and ok

	# Step past hitstop while verifying displacement + zero boss contact damage during emerge
	for _s2: int in 25:
		w.player.iframe_remain = 120.0
		w.player.x = w.teleporter_x
		w.player.y = w.teleporter_y
		w.step([hold_in], dt)
	var eff_tel_r: float = SimLoop.effective_teleporter_radius(w)
	var mite_dist: float = Vector2(w.enemies.x[mite_idx] - w.teleporter_x, w.enemies.y[mite_idx] - w.teleporter_y).length()
	var spec_dist: float = Vector2(w.enemies.x[spec_idx] - w.teleporter_x, w.enemies.y[spec_idx] - w.teleporter_y).length()
	var elite_dist: float = Vector2(w.enemies.x[elite_idx] - w.teleporter_x, w.enemies.y[elite_idx] - w.teleporter_y).length()
	ok = _check(mite_dist > eff_tel_r, "Suite 5: rupture shoves fodder outside circle (dist=%.1f > %.1f)" % [mite_dist, eff_tel_r]) and ok
	ok = _check(spec_dist > eff_tel_r, "Suite 5: rupture shoves specialist outside circle (dist=%.1f > %.1f)" % [spec_dist, eff_tel_r]) and ok
	ok = _check(elite_dist > eff_tel_r, "Suite 5: rupture shoves elite outside circle (dist=%.1f > %.1f)" % [elite_dist, eff_tel_r]) and ok
	ok = _check(w.boss.emerge_remain > 0.0 and is_equal_approx(w.enemies.x[boss_idx], w.teleporter_x) and is_equal_approx(w.enemies.y[boss_idx], w.teleporter_y), "Suite 5: boss stays stationary at circle center during emerge") and ok
	# Clear non-boss enemies so only emerging boss overlaps player with iframe=0
	for e: int in w.enemies.cap:
		if w.enemies.alive[e] != 0 and w.enemies.role[e] != EnemyPool.ROLE_BOSS:
			w.enemies.alive[e] = 0
			if w.enemies.role[e] == EnemyPool.ROLE_FODDER:
				w.counts_fodder = maxi(0, w.counts_fodder - 1)
			else:
				w.counts_elite = maxi(0, w.counts_elite - 1)
	w.projectiles.clear()
	w.obstacles.clear()
	SimObstacles.rebuild_hash(w)
	w.player.iframe_remain = 0.0
	w.player.parry_remain = 0.0
	w.player.dash_remain = 0.0
	w.player.x = w.enemies.x[boss_idx]
	w.player.y = w.enemies.y[boss_idx]
	var dmg_before_emerge: float = w.damage_taken
	for _s3: int in 10:
		w.player.x = w.enemies.x[boss_idx]
		w.player.y = w.enemies.y[boss_idx]
		w.step([hold_in], dt)
	ok = _check(is_equal_approx(w.damage_taken, dmg_before_emerge) and w.boss.emerge_remain > 0.0, "Suite 5: zero contact damage from emerging boss while emerge_remain > 0.0") and ok
	for _s4: int in 60:
		w.player.iframe_remain = 10.0
		w.step([hold_in], dt)
	ok = _check(is_equal_approx(w.boss.emerge_remain, 0.0), "Suite 5: boss emerge_remain finishes cleanly") and ok

	# Step outside teleporter during charging flips flawless hold to false
	var w_out: SimWorld = SimWorld.create(cat, "runner", [], [], 0x5556)
	w_out.player.x = w_out.teleporter_x
	w_out.player.y = w_out.teleporter_y
	w_out.step([act_in], dt)
	w_out.player.x = w_out.teleporter_x + w_out.teleporter_radius + 120.0
	w_out.step([hold_in], dt)
	ok = _check(not w_out.teleporter_flawless_hold, "Suite 5: leaving circle flips teleporter_flawless_hold to false") and ok

	# Crucible Overheat: Critical Vent & Backfire
	var w_oh: SimWorld = SimWorld.create(cat, "runner", [], [], 0x5557)
	w_oh.obstacles.clear()
	SimObstacles.rebuild_hash(w_oh)
	var fire_p: InputFrame = InputFrame.empty()
	fire_p.aim_x = 120.0
	fire_p.aim_y = 0.0
	fire_p.held[InputFrame.SLOT_PRIMARY] = true
	fire_p.pressed[InputFrame.SLOT_PRIMARY] = true
	var guard: int = 0
	while w_oh.player.heat < 0.82 and guard < 600:
		w_oh.step([fire_p], dt)
		guard += 1
	ok = _check(w_oh.player.heat >= 0.80 and w_oh.player.heat < 1.0, "Suite 5: built primary heat to sweet spot (%.3f)" % w_oh.player.heat) and ok

	var fire_sec: InputFrame = InputFrame.empty()
	fire_sec.aim_x = 120.0
	fire_sec.aim_y = 0.0
	fire_sec.pressed[InputFrame.SLOT_SECONDARY] = true
	fire_sec.held[InputFrame.SLOT_SECONDARY] = true
	w_oh.step([fire_sec], dt)
	ok = _check(is_equal_approx(w_oh.player.heat, 0.0) and w_oh.player.critical_vent_count == 1, "Suite 5: Critical Vent resets heat and increments critical_vent_count") and ok
	ok = _check(is_equal_approx(float(w_oh.player.skill_cd[InputFrame.SLOT_SECONDARY]), 3.0), "Suite 5: Critical Vent refunds 25%% Secondary CD (got %.2f)" % float(w_oh.player.skill_cd[InputFrame.SLOT_SECONDARY])) and ok

	w_oh.enemies.clear()
	w_oh.projectiles.clear()
	w_oh.zones.clear()
	w_oh.player.hp = w_oh.stats.max_hp
	w_oh.player.heat = 0.99
	w_oh.player.overheat_lockout_remain = 0.0
	w_oh.player.skill_cd[InputFrame.SLOT_PRIMARY] = 0.0
	var kb_mite: int = SimEnemies.spawn(w_oh, cat.entity("ember-mite"), w_oh.player.x, w_oh.player.y + 70.0)
	var kb_elite: int = SimEnemies.spawn(w_oh, cat.entity("ember-chaser"), w_oh.player.x + 70.0, w_oh.player.y, true, "burn")
	var kb_boss: int = SimEnemies.spawn(w_oh, cat.entity("cinder-heart"), w_oh.player.x - 70.0, w_oh.player.y)
	var hp_before_bf: float = w_oh.player.hp
	w_oh.step([fire_p], dt)
	ok = _check(w_oh.player.backfire_count == 1 and w_oh.player.overheat_lockout_remain > 0.0, "Suite 5: Backfire locks primary") and ok
	ok = _check(is_equal_approx(w_oh.player.hp, hp_before_bf), "Suite 5: Backfire leaves player HP untouched (before=%.2f after=%.2f)" % [hp_before_bf, w_oh.player.hp]) and ok
	ok = _check(kb_mite >= 0 and w_oh.enemies.alive[kb_mite] != 0 and w_oh.enemies.vel_y[kb_mite] > 50.0, "Suite 5: Backfire knocks back fodder within 95px (vel_y=%.1f)" % (w_oh.enemies.vel_y[kb_mite] if kb_mite >= 0 else 0.0)) and ok
	ok = _check(kb_elite >= 0 and w_oh.enemies.alive[kb_elite] != 0 and w_oh.enemies.vel_x[kb_elite] > 50.0, "Suite 5: Backfire knocks back elite within 95px (vel_x=%.1f)" % (w_oh.enemies.vel_x[kb_elite] if kb_elite >= 0 else 0.0)) and ok
	ok = _check(kb_boss >= 0 and is_equal_approx(w_oh.enemies.vel_x[kb_boss], 0.0) and is_equal_approx(w_oh.enemies.vel_y[kb_boss], 0.0), "Suite 5: Boss remains immune to Backfire knockback") and ok
	for _bf: int in 12:
		w_oh.player.iframe_remain = 10.0
		w_oh.step([InputFrame.empty()], dt)
	ok = _check(w_oh.enemies.y[kb_mite] > w_oh.player.y + 100.0 and w_oh.enemies.x[kb_elite] > w_oh.player.x + 100.0, "Suite 5: Backfire stun lets fodder & elite shove significantly outward") and ok

	w_oh.projectiles.clear()
	w_oh.player.skill_cd[InputFrame.SLOT_PRIMARY] = 0.0
	w_oh.player.skill_cd[InputFrame.SLOT_SECONDARY] = 0.0
	w_oh.step([fire_p], dt)
	ok = _check(is_equal_approx(float(w_oh.player.skill_cd[InputFrame.SLOT_PRIMARY]), 0.0), "Suite 5: Primary cannot fire during overheat lockout") and ok
	w_oh.step([fire_sec], dt)
	ok = _check(float(w_oh.player.skill_cd[InputFrame.SLOT_SECONDARY]) > 0.0, "Suite 5: Secondary STILL usable during overheat lockout") and ok

	# Randomized drops
	var w_drop: SimWorld = SimWorld.create(cat, "runner", [], [], 0x5558)
	w_drop.gems.clear()
	for _i: int in 12:
		SimPickups.spawn_enemy_drops(w_drop, 100.0, 0.0, 3.0, false, false, false)
	for _i: int in 5:
		SimPickups.spawn_enemy_drops(w_drop, 120.0, 0.0, 8.0, false, false, true)
	for _i: int in 5:
		SimPickups.spawn_enemy_drops(w_drop, 140.0, 0.0, 20.0, true, false, false)
	SimPickups.spawn_enemy_drops(w_drop, 160.0, 0.0, 80.0, false, true, false)
	var seen_kinds: Dictionary = {}
	for g: int in w_drop.gems.cap:
		if w_drop.gems.alive[g] != 0:
			seen_kinds[int(w_drop.gems.kind[g])] = true
	ok = _check(seen_kinds.has(GemPool.KIND_XP_SMALL) and seen_kinds.has(GemPool.KIND_XP_MEDIUM) and seen_kinds.has(GemPool.KIND_XP_CLUSTER) and seen_kinds.has(GemPool.KIND_ESSENCE), "Suite 5: randomized drops include all GemPool.KIND_* variants") and ok

	w_drop.gems.clear()
	w_drop.gems.spawn_typed(w_drop.player.x, w_drop.player.y, 4.0, GemPool.KIND_ESSENCE)
	var xp0: float = w_drop.xp
	var ess0: int = w_drop.run_essence
	SimPickups.step_gems(w_drop, dt)
	ok = _check(w_drop.run_essence > ess0 and is_equal_approx(w_drop.xp, xp0), "Suite 5: KIND_ESSENCE pickup updates run_essence without adding XP") and ok
	return ok


func _suite_06_enemies_elites_bosses(cat: Catalog) -> bool:
	var ok: bool = true
	var dt: float = 1.0 / 60.0

	# 1. Director scaling & boss pause
	var w_dir: SimWorld = SimWorld.create(cat, "runner", [], [], 0x6661)
	ok = _check(SimDirector.current_elite_cap(w_dir) == 1, "Suite 6: preActivationEliteCap == 1 before charge") and ok
	var f0: int = SimDirector.current_fodder_cap(w_dir)
	var s0: int = SimDirector.current_specialist_cap(w_dir)
	w_dir.run_time = 300.0
	w_dir.stage_index = 2
	w_dir.teleporter_state = &"charging"
	w_dir.ritual_tier = 1
	ok = _check(SimDirector.current_fodder_cap(w_dir) > f0, "Suite 6: fodder cap scales with coeff") and ok
	ok = _check(SimDirector.current_specialist_cap(w_dir) > s0, "Suite 6: specialist cap scales with coeff") and ok
	ok = _check(SimDirector.current_elite_cap(w_dir) > 1, "Suite 6: elite cap scales during charging") and ok
	SimEnemies.clear(w_dir)
	w_dir.boss_spawned = true
	w_dir.credits = 500.0
	w_dir.stage_time = 200.0
	SimDirector.step(w_dir, 2.0)
	ok = _check(w_dir.counts_fodder == 0 and w_dir.counts_elite == 0, "Suite 6: SimDirector stops during active boss") and ok

	# 2. Burn elite + 8 dynamic hazard cap separation
	var w_el: SimWorld = SimWorld.create(cat, "runner", [], [], 0x6662)
	w_el.obstacles.clear()
	SimEnemies.clear(w_el)
	for h: int in 8:
		SimObstacles.spawn(w_el, &"hazard", -600.0 - float(h) * 40.0, 0.0, "Acid", 10.0)
	SimObstacles.rebuild_hash(w_el)
	ok = _check(w_el.obstacles.count_dynamic_hazards() == 8, "Suite 6: seeded 8 dynamic hazards") and ok
	var burn_idx: int = SimEnemies.spawn(w_el, cat.entity("ember-mite"), 260.0, 0.0, true, "burn")
	ok = _check(burn_idx >= 0, "Suite 6: spawned burn elite") and ok
	for _s: int in 60:
		SimEnemiesStep.step(w_el, dt)
		SimObstacles.step(w_el, dt)
	ok = _check(w_el.player.burn_stacks == 0 and is_equal_approx(w_el.damage_taken, 0.0), "Suite 6: burn elite never damages via proximity without hit") and ok
	ok = _check(w_el.obstacles.count_type(&"burn_trail") > 0, "Suite 6: burn elite leaves burn_trail spots") and ok
	ok = _check(w_el.obstacles.count_dynamic_hazards() == 8, "Suite 6: burn_trail stays outside 8-puddle dynamic hazard cap") and ok
	SimEnemies.apply_burn_to_player(w_el, burn_idx)
	ok = _check(w_el.player.burn_stacks >= 1, "Suite 6: apply_burn_to_player applies burn on hit") and ok

	# 3. Noxious & Shielder elites
	SimEnemies.clear(w_el)
	w_el.player.slow_remain = 0.0
	var nox_idx: int = SimEnemies.spawn(w_el, cat.entity("ember-mite"), 200.0, 0.0, true, "noxious")
	SimEnemies.apply_noxious_contact(w_el, nox_idx)
	ok = _check(w_el.player.slow_remain > 0.0, "Suite 6: noxious contact slows player") and ok
	SimEnemies.start_death(w_el, nox_idx)
	ok = _check(w_el.enemies.corpse_remain[nox_idx] > 0.0, "Suite 6: noxious corpse lingers before pop") and ok
	for _s: int in 40:
		SimEnemiesStep.step(w_el, dt)
	ok = _check(w_el.enemies.alive[nox_idx] == 0, "Suite 6: noxious corpse pops after delay") and ok

	var sh_idx: int = SimEnemies.spawn(w_el, cat.entity("ember-chaser"), 200.0, 0.0, true, "shielder")
	var sh_hp0: float = w_el.enemies.hp[sh_idx]
	ok = _check(w_el.enemies.shield_hp[sh_idx] > 0.0, "Suite 6: shielder spawns with shield_hp") and ok
	SimEnemies.apply_damage(w_el, sh_idx, 5.0)
	ok = _check(is_equal_approx(w_el.enemies.hp[sh_idx], sh_hp0) and is_equal_approx(w_el.enemies.shield_delay_remain[sh_idx], 5.0), "Suite 6: shielder absorbs hit and sets 5.0s regen delay") and ok

	# 4. Chain lightning elite bounce to conduit / volatile
	w_el.obstacles.clear()
	SimEnemies.clear(w_el)
	w_el.player.x = 0.0
	w_el.player.y = 0.0
	w_el.player.iframe_remain = 0.0
	var cl_idx: int = SimEnemies.spawn(w_el, cat.entity("ember-spitter"), 140.0, 0.0, true, "chain_lightning")
	var cl_conduit: int = SimObstacles.spawn(w_el, &"conduit", 80.0, 40.0, "Resonance Conduit")
	var cl_vol: int = SimObstacles.spawn(w_el, &"volatile", 120.0, 40.0, "Brimstone Urn")
	SimObstacles.rebuild_hash(w_el)
	w_el.enemies.chain_cd[cl_idx] = 0.05
	var saw_windup: bool = false
	for _s: int in 60:
		SimEnemiesStep.step(w_el, dt)
		if w_el.enemies.chain_cd[cl_idx] < 0.0 and w_el.enemies.windup[cl_idx] > 0.0:
			saw_windup = true
	var c_obs: SimObstacle = w_el.obstacles.items[cl_conduit]
	var v_obs: SimObstacle = w_el.obstacles.items[cl_vol]
	ok = _check(saw_windup, "Suite 6: chain_lightning enters windup") and ok
	ok = _check(c_obs.charges >= 1 or v_obs.state == &"primed", "Suite 6: chain_lightning bounces to conduit (+1) / volatile") and ok

	# 5. Slag-hound charger + pillar stun, Aether-hexer sigil, Cleaver volatile detonation
	var w_sp: SimWorld = SimWorld.create(cat, "runner", [], [], 0x6663)
	w_sp.obstacles.clear()
	SimEnemies.clear(w_sp)
	w_sp.zones.clear()
	w_sp.player.x = 0.0
	w_sp.player.y = 0.0
	SimObstacles.spawn(w_sp, &"pillar", 100.0, 0.0, "Obsidian Kiln")
	SimObstacles.rebuild_hash(w_sp)
	var hound: int = SimEnemies.spawn(w_sp, cat.entity("slag-hound"), 210.0, 0.0)
	w_sp.enemies.attack_cd[hound] = 0.0
	var hound_max: float = w_sp.enemies.max_hp[hound]
	for _s: int in 90:
		w_sp.player.iframe_remain = 10.0
		SimEnemiesStep.step(w_sp, dt)
		if w_sp.enemies.ai_state[hound] == EnemyPool.AI_STATE_STUN:
			break
	ok = _check(w_sp.enemies.hp[hound] < hound_max and w_sp.enemies.ai_state[hound] == EnemyPool.AI_STATE_STUN and w_sp.enemies.root_remain[hound] >= 0.5, "Suite 6: slag-hound takes self-damage + 0.8s stun on pillar collision") and ok

	SimEnemies.clear(w_sp)
	w_sp.obstacles.clear()
	SimObstacles.rebuild_hash(w_sp)
	var hexer: int = SimEnemies.spawn(w_sp, cat.entity("aether-hexer"), 260.0, 0.0)
	w_sp.enemies.attack_cd[hexer] = 0.0
	for _s: int in 60:
		SimEnemiesStep.step(w_sp, dt)
	var has_hex_sigil: bool = false
	for z: int in w_sp.zones.cap:
		if w_sp.zones.alive[z] != 0 and w_sp.zones.kind[z] == ZonePool.ZONE_HEX_SIGIL:
			has_hex_sigil = true
			break
	ok = _check(has_hex_sigil, "Suite 6: aether-hexer spawns ZONE_HEX_SIGIL") and ok

	SimEnemies.clear(w_sp)
	w_sp.obstacles.clear()
	var vol_idx: int = SimObstacles.spawn(w_sp, &"volatile", 50.0, 0.0, "Brimstone Urn")
	SimObstacles.rebuild_hash(w_sp)
	w_sp.player.x = 55.0
	w_sp.player.y = 0.0
	var cleaver: int = SimEnemies.spawn(w_sp, cat.entity("ember-chaser"), 0.0, 0.0)
	w_sp.enemies.attack_cd[cleaver] = 0.0
	for _s: int in 55:
		w_sp.player.iframe_remain = 10.0
		SimEnemiesStep.step(w_sp, dt)
	ok = _check(w_sp.obstacles.items[vol_idx].state == &"detonated", "Suite 6: cleaver detonates volatile barrel") and ok

	SimEnemies.clear(w_sp)
	w_sp.obstacles.clear()
	SimObstacles.rebuild_hash(w_sp)
	w_sp.player.x = 0.0
	w_sp.player.y = 0.0
	var sniper: int = SimEnemies.spawn(w_sp, cat.entity("enemy-astral-sniper"), 320.0, 0.0)
	w_sp.enemies.attack_cd[sniper] = 0.0
	SimEnemiesStep.step(w_sp, dt)
	var lock_sx: float = w_sp.enemies.x[sniper]
	var lock_sy: float = w_sp.enemies.y[sniper]
	var lock_ax: float = w_sp.enemies.aim_x[sniper]
	var lock_ay: float = w_sp.enemies.aim_y[sniper]
	for _s: int in 30:
		w_sp.player.y += 6.0
		SimEnemiesStep.step(w_sp, dt)
	var sniper_locked: bool = (
		w_sp.enemies.windup[sniper] > 0.0
		and is_equal_approx(w_sp.enemies.x[sniper], lock_sx)
		and is_equal_approx(w_sp.enemies.y[sniper], lock_sy)
		and is_equal_approx(w_sp.enemies.aim_x[sniper], lock_ax)
		and is_equal_approx(w_sp.enemies.aim_y[sniper], lock_ay)
	)
	ok = _check(sniper_locked, "Suite 6: astral-sniper locks aim and holds position during windup") and ok

	# 6. Boss attacks: geyser, dash_slam, chain_anchor, single-hit ring_wave
	ok = _check(_test_boss_attack(cat, "cinder-heart", "geyser"), "Suite 6: cinder-heart executes geyser") and ok
	ok = _check(_test_boss_attack(cat, "viridian-alchemist", "dash_slam"), "Suite 6: viridian-alchemist executes dash_slam") and ok
	ok = _check(_test_voltaic_regent(cat), "Suite 6: voltaic-regent chain_anchor + single-hit ring_wave") and ok
	return ok


func _test_boss_attack(cat: Catalog, boss_id: String, atk_type: String) -> bool:
	var w: SimWorld = SimWorld.create(cat, "runner", [], [], 0x6700)
	w.obstacles.clear()
	SimEnemies.clear(w)
	SimObstacles.rebuild_hash(w)
	var def: Dictionary = cat.entity(boss_id)
	var b_idx: int = SimEnemies.spawn(w, def, 260.0, 0.0)
	var ai: Dictionary = DictUtil.d(def, "ai")
	SimBoss.init_state(w, b_idx, ai)
	w.boss_spawned = true
	var attacks: Array = DictUtil.a(ai, "attacks")
	for k: int in attacks.size():
		var atk: Dictionary = attacks[k]
		w.boss.cooldowns[k] = 0.0 if String(atk.get("type", "")) == atk_type else 999.0
	for _s: int in 140:
		w.player.iframe_remain = 10.0
		SimEnemiesStep.step(w, 1.0 / 60.0)
		SimBossHazards.step(w, 1.0 / 60.0)
		if int(w.boss.counts.get(atk_type, 0)) >= 1:
			return true
	return false


func _test_voltaic_regent(cat: Catalog) -> bool:
	var dt: float = 1.0 / 60.0
	var w: SimWorld = SimWorld.create(cat, "runner", [], [], 0x6701)
	w.obstacles.clear()
	SimEnemies.clear(w)
	SimObstacles.rebuild_hash(w)
	var def: Dictionary = cat.entity("voltaic-regent")
	var b_idx: int = SimEnemies.spawn(w, def, 260.0, 0.0)
	var ai: Dictionary = DictUtil.d(def, "ai")
	SimBoss.init_state(w, b_idx, ai)
	w.boss_spawned = true
	var attacks: Array = DictUtil.a(ai, "attacks")
	for k: int in attacks.size():
		var atk: Dictionary = attacks[k]
		w.boss.cooldowns[k] = 0.0 if String(atk.get("type", "")) == "chain_anchor" else 999.0
	for _s: int in 90:
		w.player.iframe_remain = 10.0
		SimEnemiesStep.step(w, dt)
		if int(w.boss.counts.get("chain_anchor", 0)) >= 1:
			break
	var spire_found: bool = false
	for e: int in w.enemies.cap:
		if w.enemies.alive[e] != 0 and w.enemies.def_id[e] == "voltaic-spire":
			spire_found = true
			break
	if int(w.boss.counts.get("chain_anchor", 0)) < 1 or not spire_found:
		return false

	# Now trigger ring_wave and verify single-hit HAZ_RING
	w.boss_hazards.clear()
	w.projectiles.clear()
	for k: int in attacks.size():
		var atk: Dictionary = attacks[k]
		w.boss.cooldowns[k] = 0.0 if String(atk.get("type", "")) == "ring_wave" else 999.0
	for _s: int in 90:
		w.player.iframe_remain = 10.0
		SimEnemiesStep.step(w, dt)
		if int(w.boss.counts.get("ring_wave", 0)) >= 1:
			break
	w.projectiles.clear()
	var ring_slot: int = -1
	for h: int in w.boss_hazards.cap:
		if w.boss_hazards.alive[h] != 0 and w.boss_hazards.kind[h] == BossHazardPool.HAZ_RING:
			ring_slot = h
			break
	if ring_slot < 0:
		return false
	w.player.iframe_remain = 0.0
	w.player.parry_remain = 0.0
	w.player.dash_remain = 0.0
	var dmg0: float = w.damage_taken
	w.player.x = w.boss_hazards.x[ring_slot] + w.boss_hazards.radius[ring_slot]
	w.player.y = w.boss_hazards.y[ring_slot]
	SimBossHazards.step(w, dt)
	var dmg1: float = w.damage_taken
	if dmg1 <= dmg0 or w.boss_hazards.state[ring_slot] != 1:
		return false
	w.player.iframe_remain = 0.0
	w.player.x = w.boss_hazards.x[ring_slot] + w.boss_hazards.radius[ring_slot]
	w.player.y = w.boss_hazards.y[ring_slot]
	SimBossHazards.step(w, dt)
	return is_equal_approx(w.damage_taken, dmg1)


func _suite_07_vessels_draft_portals(cat: Catalog) -> bool:
	var ok: bool = true
	var dt: float = 1.0 / 60.0
	var survivors: Array[String] = ["runner", "penitent", "flagellant", "astromancer"]
	for sid: String in survivors:
		for variant: String in ["A", "B"]:
			var cfg: Dictionary = {"loadout": {"primary": variant, "secondary": variant, "utility": variant, "special": variant}}
			var w: SimWorld = SimWorld.create(cat, sid, [], [], 0x7001, "", cfg)
			w.obstacles.clear()
			SimObstacles.rebuild_hash(w)
			var surv_def: Dictionary = cat.survivor(sid)
			var expected_map: Dictionary = surv_def.get("altSkills" if variant == "B" else "skills", {})
			for slot: StringName in InputFrame.SLOTS:
				var expected_id: String = String(expected_map.get(String(slot), ""))
				ok = _check(SimSkills.slot_skill_id(w, slot) == expected_id, "Suite 7: %s/%s %s == %s" % [sid, variant, String(slot), expected_id]) and ok
				w.player.skill_cd = InputFrame.empty_cds()
				w.player.heat = 0.0
				w.player.overheat_lockout_remain = 0.0
				w.player.x = 0.0
				w.player.y = 0.0
				SimEnemies.clear(w)
				var target_e: int = SimEnemies.spawn(w, cat.entity("ember-chaser"), 70.0, 0.0)
				w.enemies.hp[target_e] = 500.0
				w.enemies.max_hp[target_e] = 500.0
				var inp: InputFrame = InputFrame.empty()
				inp.aim_x = 70.0
				inp.aim_y = 0.0
				inp.held[slot] = true
				inp.pressed[slot] = true
				w.step([inp], dt)
				ok = _check(float(w.player.skill_cd[slot]) > 0.0, "Suite 7: %s/%s cast %s triggered CD" % [sid, variant, expected_id]) and ok

	# Specific mechanics verification across A/B loadouts
	# Runner B: parry reflect + prism lance
	var w_run_b: SimWorld = SimWorld.create(cat, "runner", [], [], 0x7002, "", {"loadout": {"primary": "B", "secondary": "B", "utility": "B", "special": "B"}})
	w_run_b.obstacles.clear()
	SimObstacles.rebuild_hash(w_run_b)
	var parry_in: InputFrame = InputFrame.empty()
	parry_in.aim_x = 100.0
	parry_in.aim_y = 0.0
	parry_in.pressed[InputFrame.SLOT_UTILITY] = true
	w_run_b.step([parry_in], dt)
	ok = _check(w_run_b.player.parry_remain > 0.0, "Suite 7: runner B parry_remain active") and ok
	w_run_b.projectiles.spawn(0.0, 0.0, -1.0, 0.0, 100.0, 1.0, 6.0, 15.0, ProjectilePool.TEAM_ENEMY)
	w_run_b.step([], dt)
	var parry_shards: int = 0
	for p: int in w_run_b.projectiles.alive.size():
		if w_run_b.projectiles.alive[p] != 0 and w_run_b.projectiles.skill_tag[p] == "parry":
			parry_shards += 1
	ok = _check(w_run_b.player.parry_triggered and parry_shards == 3, "Suite 7: Quicksilver Parry reflects 3 shards") and ok

	# Flagellant A: harpoon pull + calcinatio-slam overheat vent
	var w_flag_a: SimWorld = SimWorld.create(cat, "flagellant", [], [], 0x7003, "", {"loadout": {"primary": "A", "secondary": "A", "utility": "A", "special": "A"}})
	w_flag_a.obstacles.clear()
	SimObstacles.rebuild_hash(w_flag_a)
	var f_e: int = SimEnemies.spawn(w_flag_a, cat.entity("ember-chaser"), 120.0, 0.0)
	var h_in: InputFrame = InputFrame.empty()
	h_in.aim_x = 120.0
	h_in.aim_y = 0.0
	h_in.pressed[InputFrame.SLOT_SECONDARY] = true
	for _i: int in 15:
		w_flag_a.step([h_in if _i == 0 else InputFrame.empty()], dt)
	ok = _check(w_flag_a.enemies.x[f_e] < 100.0 and w_flag_a.enemies.ai_state[f_e] == EnemyPool.AI_STATE_STUN, "Suite 7: Slag Harpoon pulls & stuns enemy") and ok
	w_flag_a.player.heat = 0.9
	var slam_in: InputFrame = InputFrame.empty()
	slam_in.aim_x = 120.0
	slam_in.aim_y = 0.0
	slam_in.pressed[InputFrame.SLOT_SPECIAL] = true
	w_flag_a.step([slam_in], dt)
	ok = _check(is_equal_approx(w_flag_a.player.heat, 0.0) and w_flag_a.player.x > 50.0, "Suite 7: Calcinatio Slam leaps & vents overheat") and ok

	# Flagellant B: iron-bulwark
	var w_flag_b: SimWorld = SimWorld.create(cat, "flagellant", [], [], 0x7004, "", {"loadout": {"primary": "B", "secondary": "B", "utility": "B", "special": "B"}})
	var bul_in: InputFrame = InputFrame.empty()
	bul_in.pressed[InputFrame.SLOT_UTILITY] = true
	w_flag_b.step([bul_in], dt)
	ok = _check(w_flag_b.player.bulwark_remain > 0.0, "Suite 7: Iron Bulwark active") and ok
	w_flag_b.damage_player(40.0)
	ok = _check(w_flag_b.player.bulwark_stored_damage > 20.0, "Suite 7: Iron Bulwark stores mitigated damage") and ok

	# Penitent B: censure-bell
	var w_pen_b: SimWorld = SimWorld.create(cat, "penitent", [], [], 0x7005, "", {"loadout": {"primary": "B", "secondary": "B", "utility": "B", "special": "B"}})
	w_pen_b.projectiles.spawn(40.0, 0.0, -1.0, 0.0, 50.0, 2.0, 6.0, 10.0, ProjectilePool.TEAM_ENEMY)
	var bell_in: InputFrame = InputFrame.empty()
	bell_in.pressed[InputFrame.SLOT_UTILITY] = true
	w_pen_b.step([bell_in], dt)
	var e_projs_left: int = 0
	for p: int in w_pen_b.projectiles.alive.size():
		if w_pen_b.projectiles.alive[p] != 0 and w_pen_b.projectiles.team[p] == ProjectilePool.TEAM_ENEMY:
			e_projs_left += 1
	ok = _check(e_projs_left == 0 and w_pen_b.player.bell_armor_remain > 0.0, "Suite 7: Censure Bell destroys enemy bolts & grants armor") and ok

	# Astromancer A: prism beacon splitting primary + solar-beam; Astromancer B: celestial-swap
	var w_ast_a: SimWorld = SimWorld.create(cat, "astromancer", [], [], 0x7006, "", {"loadout": {"primary": "A", "secondary": "A", "utility": "A", "special": "A"}})
	w_ast_a.obstacles.clear()
	SimObstacles.rebuild_hash(w_ast_a)
	var prism_in: InputFrame = InputFrame.empty()
	prism_in.aim_x = 80.0
	prism_in.aim_y = 0.0
	prism_in.pressed[InputFrame.SLOT_SECONDARY] = true
	w_ast_a.step([prism_in], dt)
	var p_fire: InputFrame = InputFrame.empty()
	p_fire.aim_x = 120.0
	p_fire.aim_y = 0.0
	p_fire.held[InputFrame.SLOT_PRIMARY] = true
	p_fire.pressed[InputFrame.SLOT_PRIMARY] = true
	var max_p_alive: int = 0
	for _i: int in 15:
		w_ast_a.step([p_fire if _i == 0 else InputFrame.empty()], dt)
		var c: int = 0
		for p: int in w_ast_a.projectiles.alive.size():
			if w_ast_a.projectiles.alive[p] != 0:
				c += 1
		max_p_alive = maxi(max_p_alive, c)
	ok = _check(max_p_alive >= 3, "Suite 7: Prism Refraction splits primary into >= 3 rays (max=%d)" % max_p_alive) and ok

	var beam_in: InputFrame = InputFrame.empty()
	beam_in.aim_x = 120.0
	beam_in.aim_y = 0.0
	beam_in.pressed[InputFrame.SLOT_SPECIAL] = true
	w_ast_a.step([beam_in], dt)
	var has_beam: bool = false
	for z: int in w_ast_a.zones.cap:
		if w_ast_a.zones.alive[z] != 0 and w_ast_a.zones.kind[z] == ZonePool.ZONE_SOLAR_BEAM:
			has_beam = true
	ok = _check(has_beam, "Suite 7: Solar Convergence spawns ZONE_SOLAR_BEAM") and ok

	var w_ast_b: SimWorld = SimWorld.create(cat, "astromancer", [], [], 0x7007, "", {"loadout": {"primary": "B", "secondary": "B", "utility": "B", "special": "B"}})
	w_ast_b.obstacles.clear()
	SimObstacles.rebuild_hash(w_ast_b)
	var swap_mite: int = SimEnemies.spawn(w_ast_b, cat.entity("ember-mite"), 180.0, 0.0)
	var swap_in: InputFrame = InputFrame.empty()
	swap_in.aim_x = 180.0
	swap_in.aim_y = 0.0
	swap_in.pressed[InputFrame.SLOT_UTILITY] = true
	w_ast_b.step([swap_in], dt)
	ok = _check(w_ast_b.player.x > 100.0 and w_ast_b.enemies.x[swap_mite] < 20.0, "Suite 7: Celestial Swap trades position with fodder") and ok

	# Draft tools: reroll / banish / lock
	var w_draft: SimWorld = SimWorld.create(cat, "runner", [], [], 0x7008, "", {
		"crucible_upgrades": {"divination-reroll": 2, "exorcism-banish": 1, "fixation-lock": 1}
	})
	SimLevel.grant_xp(w_draft, w_draft.xp_need)
	ok = _check(w_draft.phase == &"levelup" and w_draft.offer.size() == 3, "Suite 7: levelup opens 3-card draft") and ok
	var locked_id: String = String(w_draft.offer[0].get("id", ""))
	ok = _check(SimLevel.toggle_lock_choice(w_draft, 0) and w_draft.locked_item_id == locked_id and w_draft.locks_left == 0, "Suite 7: toggle_lock_choice locks card") and ok
	ok = _check(SimLevel.reroll_choices(w_draft) and w_draft.rerolls_left == 1 and String(w_draft.offer[0].get("id", "")) == locked_id, "Suite 7: reroll keeps locked card") and ok
	var ban_id: String = String(w_draft.offer[1].get("id", ""))
	ok = _check(SimLevel.banish_choice(w_draft, 1) and w_draft.banishes_left == 0 and w_draft.banished_items.has(ban_id), "Suite 7: banish_choice bans card") and ok
	ok = _check(String(w_draft.offer[1].get("id", "")) != ban_id, "Suite 7: banished card replaced immediately") and ok
	for _r: int in 8:
		for c_dict: Dictionary in SimLevel.roll_choices(w_draft):
			if String(c_dict.get("id", "")) == ban_id:
				ok = _check(false, "Suite 7: banished card %s reappeared in roll_choices" % ban_id) and ok

	# Branching & Portals
	var w_port: SimWorld = SimWorld.create(cat, "runner", [], [], 0x7009)
	w_port.stage_obelisks_total = 1
	w_port.stage_obelisks_completed = 1
	w_port.teleporter_flawless_hold = true
	w_port.boss_defeated = true
	SimLoop.open_stage_portals(w_port)
	var branch_p: Dictionary = _find_portal(w_port.portals, "branch")
	var secret_p: Dictionary = _find_portal(w_port.portals, "secret")
	ok = _check(not branch_p.is_empty() and String(branch_p.get("target_stage_id", "")) == "putrid-conservatory", "Suite 7: completed obelisks route Stage 1 -> putrid-conservatory") and ok
	ok = _check(not secret_p.is_empty() and String(secret_p.get("target_stage_id", "")) == "aether-vault", "Suite 7: flawless hold spawns aether-vault secret portal") and ok

	SimLoop._activate_portal(w_port, secret_p)
	ok = _check(w_port.stage_id == "aether-vault", "Suite 7: secret portal enters aether-vault") and ok
	w_port.boss_defeated = true
	SimLoop.open_stage_portals(w_port)
	var has_cat: bool = false
	for inst: ItemInstance in w_port.inventory:
		if inst.id == "philosophers-catalyst":
			has_cat = true
	ok = _check(has_cat, "Suite 7: aether-vault grants philosophers-catalyst") and ok

	SimLevel.grant_specific_item(w_port, "lunar-tithe")
	SimLoop.begin_stage(w_port, 3)
	w_port.boss_defeated = true
	SimLoop.open_stage_portals(w_port)
	var silver_p: Dictionary = _find_portal(w_port.portals, "silver")
	var gold_p: Dictionary = _find_portal(w_port.portals, "gold")
	var crimson_p: Dictionary = _find_portal(w_port.portals, "crimson")
	ok = _check(not silver_p.is_empty() and not gold_p.is_empty() and not crimson_p.is_empty(), "Suite 7: Stage 4 spawns Silver + Gold + Crimson portals") and ok

	var w_gold: SimWorld = SimWorld.create(cat, "runner", [], [], 0x700A)
	SimLoop.begin_stage(w_gold, 3)
	w_gold.boss_defeated = true
	SimLoop.open_stage_portals(w_gold)
	SimLoop._activate_portal(w_gold, _find_portal(w_gold.portals, "gold"))
	ok = _check(w_gold.cycle_index == 1 and w_gold.stage_id == "cinder-yard", "Suite 7: Gold portal starts loop cycle_index == 1") and ok

	SimLoop._activate_portal(w_port, crimson_p)
	ok = _check(w_port.stage_id == "prima-materia-core", "Suite 7: Crimson portal enters prima-materia-core") and ok
	w_port.boss_defeated = true
	SimLoop.open_stage_portals(w_port)
	var true_p: Dictionary = _find_portal(w_port.portals, "true-ending")
	ok = _check(not true_p.is_empty(), "Suite 7: prima-materia-core spawns true-ending portal") and ok
	SimLoop._activate_portal(w_port, true_p)
	ok = _check(w_port.true_victory and w_port.won and w_port.phase == &"victory", "Suite 7: true-ending portal awards true_victory") and ok

	var w_demo: SimWorld = SimWorld.create(cat, "runner", [], [], 0x700B, "", {"demo_mode": true})
	SimLoop.begin_stage(w_demo, 1)
	w_demo.boss_defeated = true
	SimLoop.open_stage_portals(w_demo)
	var demo_p: Dictionary = _find_portal(w_demo.portals, "demo-seal")
	ok = _check(not demo_p.is_empty(), "Suite 7: demo_mode spawns demo-seal portal on Stage 2") and ok
	SimLoop._activate_portal(w_demo, demo_p)
	ok = _check(w_demo.demo_completed and w_demo.won, "Suite 7: demo-seal portal sets demo_completed = true") and ok
	return ok


func _find_portal(portals: Array[Dictionary], kind: String) -> Dictionary:
	for p: Dictionary in portals:
		if String(p.get("kind", "")) == kind:
			return p
	return {}


func _suite_08_persistence(cat: Catalog) -> bool:
	var ok: bool = true
	var rec_existed: bool = FileAccess.file_exists(ArchiveRecords.PATH)
	var rec_backup: PackedByteArray = FileAccess.get_file_as_bytes(ArchiveRecords.PATH) if rec_existed else PackedByteArray()
	var set_existed: bool = FileAccess.file_exists(GameSettings.PATH)
	var set_backup: PackedByteArray = FileAccess.get_file_as_bytes(GameSettings.PATH) if set_existed else PackedByteArray()

	var interact_was_in_map: bool = InputMap.has_action("interact")
	var saved_actions: Dictionary = {}
	var actions_to_save: Array[String] = []
	for act: String in GameSettings.REBINDABLE_ACTIONS:
		actions_to_save.append(act)
	actions_to_save.append("interact")
	for act: String in actions_to_save:
		if InputMap.has_action(act):
			var evs: Array[InputEvent] = []
			for ev: InputEvent in InputMap.action_get_events(act):
				if ev != null:
					evs.append(ev.duplicate() as InputEvent)
			saved_actions[act] = evs

	# Crucible upgrades + 100% refund math + selectedLoadouts + ascensionTier
	var rec: ArchiveRecords = ArchiveRecords.new()
	rec.data = ArchiveRecords._empty()
	rec.grant_essence(250)
	ok = _check(rec.spend_essence(40), "Suite 8: spend 40 essence") and ok
	rec.set_upgrade_level("divination-reroll", 1)
	ok = _check(rec.spend_essence(75), "Suite 8: spend 75 essence") and ok
	rec.set_upgrade_level("divination-reroll", 2)
	ok = _check(rec.spend_essence(60), "Suite 8: spend 60 essence") and ok
	rec.set_upgrade_level("ascension-seals", 1)
	rec.set_ascension_tier(1)
	rec.set_slot_variant("runner", "primary", "B")
	rec.set_slot_variant("astromancer", "special", "B")

	var loaded_rec: ArchiveRecords = ArchiveRecords.load_or_default()
	ok = _check(loaded_rec.essence_balance() == 75, "Suite 8: reloaded essence == 75 (got %d)" % loaded_rec.essence_balance()) and ok
	ok = _check(loaded_rec.upgrade_level("divination-reroll") == 2, "Suite 8: reloaded upgrade level == 2") and ok
	ok = _check(loaded_rec.ascension_tier() == 1, "Suite 8: reloaded ascensionTier == 1") and ok
	ok = _check(String(loaded_rec.loadout_for("runner").get("primary", "A")) == "B", "Suite 8: reloaded selectedLoadouts runner.primary == B") and ok
	ok = _check(String(loaded_rec.loadout_for("astromancer").get("special", "A")) == "B", "Suite 8: reloaded selectedLoadouts astromancer.special == B") and ok

	var modal: CrucibleModal = CrucibleModal.new()
	var refund: int = modal._total_spent_essence(loaded_rec, cat)
	modal.free()
	ok = _check(refund == 175, "Suite 8: 100%% Crucible refund math == 175 (got %d)" % refund) and ok
	loaded_rec.grant_essence(refund)
	for upg: Dictionary in cat.crucible_upgrades:
		loaded_rec.set_upgrade_level(String(upg.get("id", "")), 0)
	loaded_rec.set_ascension_tier(0)
	ok = _check(loaded_rec.essence_balance() == 250 and loaded_rec.ascension_tier() == 0, "Suite 8: post-refund essence == 250 and ascension == 0") and ok

	# GameSettings keybind serialization including "interact"
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var ev_e: InputEventKey = InputEventKey.new()
		ev_e.device = GameSettings.ALL_DEVICES
		ev_e.physical_keycode = KEY_E
		InputMap.action_add_event("interact", ev_e)

	var settings: GameSettings = GameSettings.new()
	settings.input_rebinds["interact"] = [{"type": "key", "keycode": int(KEY_F), "physical_keycode": int(KEY_F)}]
	settings.input_rebinds["fire_secondary"] = [{"type": "key", "keycode": int(KEY_R), "physical_keycode": int(KEY_R)}]
	settings.save()
	var loaded_set: GameSettings = GameSettings.load_or_default()
	ok = _check(loaded_set.input_rebinds.has("interact"), "Suite 8: GameSettings preserves interact keybind") and ok
	var int_evs: Array[InputEvent] = InputMap.action_get_events("interact")
	var bound_f: bool = false
	for ev: InputEvent in int_evs:
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_F:
			bound_f = true
	ok = _check(bound_f, "Suite 8: GameSettings applies rebound interact key (KEY_F)") and ok
	ok = _check(loaded_set.input_rebinds.has("fire_secondary"), "Suite 8: GameSettings preserves fire_secondary keybind") and ok

	# Restore user files and InputMap cleanly
	_restore_user_file(ArchiveRecords.PATH, rec_existed, rec_backup)
	_restore_user_file(GameSettings.PATH, set_existed, set_backup)
	for act: String in actions_to_save:
		if act == "interact" and not interact_was_in_map:
			if InputMap.has_action("interact"):
				InputMap.erase_action("interact")
			continue
		if InputMap.has_action(act) and saved_actions.has(act):
			InputMap.action_erase_events(act)
			var restore_evs: Array = saved_actions[act]
			for ev_v: Variant in restore_evs:
				if ev_v is InputEvent:
					InputMap.action_add_event(act, ev_v as InputEvent)
	return ok


func _restore_user_file(user_path: String, existed: bool, bytes: PackedByteArray) -> void:
	var abs_p: String = ProjectSettings.globalize_path(user_path)
	if existed:
		var f: FileAccess = FileAccess.open(user_path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(bytes)
			f.close()
	elif FileAccess.file_exists(user_path):
		DirAccess.remove_absolute(abs_p)


func _suite_09_shaders_and_assets() -> bool:
	var ok: bool = true

	# 1. Check all shaders in res://shaders/ (10 .gdshader + 1 .gdshaderinc = 11) and res://assets/shaders/
	var shader_dirs: Array[String] = ["res://shaders", "res://assets/shaders"]
	var total_shaders_dir_files: int = 0
	for sdir_path: String in shader_dirs:
		var sdir: DirAccess = DirAccess.open(sdir_path)
		if not _check(sdir != null, "Suite 9: open %s" % sdir_path):
			ok = false
			continue
		sdir.list_dir_begin()
		var sname: String = sdir.get_next()
		while sname != "":
			if not sdir.current_is_dir():
				if sdir_path == "res://shaders" and (sname.ends_with(".gdshader") or sname.ends_with(".gdshaderinc")):
					total_shaders_dir_files += 1
				if sname.ends_with(".gdshader"):
					var full_s: String = "%s/%s" % [sdir_path, sname]
					var sh: Resource = ResourceLoader.load(full_s)
					ok = _check(sh is Shader and (sh as Shader).get_code() != "", "Suite 9: shader loads non-empty: %s" % full_s) and ok
					if sh is Shader:
						var code: String = (sh as Shader).get_code()
						if code.contains("#include "):
							var rx_inc: RegEx = RegEx.new()
							rx_inc.compile("#include\\s+\"([^\"]+)\"")
							var m: RegExMatch = rx_inc.search(code)
							if m != null:
								var inc_rel: String = m.get_string(1)
								var inc_path: String = inc_rel if inc_rel.begins_with("res://") else "%s/%s" % [sdir_path, inc_rel]
								ok = _check(FileAccess.file_exists(inc_path), "Suite 9: shader include exists: %s" % inc_path) and ok
			sname = sdir.get_next()
		sdir.list_dir_end()
	ok = _check(total_shaders_dir_files == 11, "Suite 9: res://shaders contains 11 shader files (10 .gdshader + 1 .gdshaderinc, got %d)" % total_shaders_dir_files) and ok

	# 2. Check generated PNGs exist with exact required dimensions
	var expected_dims: Dictionary = {
		"resurrect-64-32x.png": Vector2i(1024, 32),
		"players/vessel-flagellant.png": Vector2i(192, 32),
		"players/vessel-astromancer.png": Vector2i(192, 32),
		"enemies/slag-hound.png": Vector2i(192, 32),
		"enemies/aether-hexer.png": Vector2i(192, 32),
		"enemies/voltaic-regent.png": Vector2i(288, 48),
		"enemies/voltaic-spire.png": Vector2i(24, 32),
		"env/arena-rim-curved.png": Vector2i(64, 32),
		"env/env-conduit-base.png": Vector2i(32, 48),
		"env/env-conduit-mask.png": Vector2i(32, 48),
		"env/env-vent-grate.png": Vector2i(32, 32),
		"env/mercury-geode.png": Vector2i(96, 32),
		"env/obelisk-blood.png": Vector2i(32, 48),
		"env/obelisk-essence.png": Vector2i(32, 48),
		"env/obelisk-mask.png": Vector2i(32, 48),
		"env/obelisk-reliquary.png": Vector2i(32, 48),
		"pickups/essence-crystal.png": Vector2i(16, 16),
		"pickups/xp-cluster-gold.png": Vector2i(20, 20),
		"pickups/xp-drop-medium.png": Vector2i(16, 16),
		"pickups/xp-drop-small.png": Vector2i(12, 12),
	}

	# Load resurrect-64.pal + #000000
	var pal_abs: String = ProjectSettings.globalize_path("res://").path_join("../../tools/pixelorama/resurrect-64.pal")
	var pal_f: FileAccess = FileAccess.open(pal_abs, FileAccess.READ)
	if not _check(pal_f != null, "Suite 9: open resurrect-64.pal at %s" % pal_abs):
		return false
	var pal_lines: PackedStringArray = pal_f.get_as_text().split("\n")
	var allowed_rgb: Dictionary = {0: true}
	for li: int in range(3, pal_lines.size()):
		var parts: PackedStringArray = pal_lines[li].strip_edges().split(" ", false)
		if parts.size() == 3:
			var key: int = int(parts[0]) | (int(parts[1]) << 8) | (int(parts[2]) << 16)
			allowed_rgb[key] = true
	ok = _check(allowed_rgb.size() == 65, "Suite 9: resurrect-64 + #000000 has 65 colors (got %d)" % allowed_rgb.size()) and ok

	for rel_v: Variant in expected_dims.keys():
		var rel: String = String(rel_v)
		var want: Vector2i = expected_dims[rel_v]
		var res_p: String = "res://assets/sprites/generated/%s" % rel
		var abs_p: String = ProjectSettings.globalize_path(res_p)
		if not _check(FileAccess.file_exists(res_p), "Suite 9: generated PNG exists: %s" % rel):
			ok = false
			continue
		var img: Image = Image.load_from_file(abs_p)
		if not _check(img != null and not img.is_empty(), "Suite 9: load PNG %s" % rel):
			ok = false
			continue
		ok = _check(img.get_width() == want.x and img.get_height() == want.y, "Suite 9: %s dims %dx%d == %dx%d" % [rel, img.get_width(), img.get_height(), want.x, want.y]) and ok
		var off_count: int = 0
		for y: int in img.get_height():
			for x: int in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a8 == 0:
					continue
				var pk: int = c.r8 | (c.g8 << 8) | (c.b8 << 16)
				if not allowed_rgb.has(pk):
					off_count += 1
		ok = _check(off_count == 0, "Suite 9: %s all pixels in resurrect-64 + #000000 (off=%d)" % [rel, off_count]) and ok

	# 3. Check flagellant.json & astromancer.json anims
	for ent_id: String in ["flagellant", "astromancer"]:
		var jpath: String = "res://assets/sprites/entities/%s.json" % ent_id
		var jf: FileAccess = FileAccess.open(jpath, FileAccess.READ)
		if not _check(jf != null, "Suite 9: open %s" % jpath):
			ok = false
			continue
		var parsed: Variant = JSON.parse_string(jf.get_as_text())
		ok = _check(typeof(parsed) == TYPE_DICTIONARY, "Suite 9: %s valid JSON" % ent_id) and ok
		if typeof(parsed) == TYPE_DICTIONARY:
			var jd: Dictionary = parsed
			var anims: Dictionary = DictUtil.d(jd, "anims")
			ok = _check(int(jd.get("frameWidth", 0)) == 32 and int(jd.get("frameHeight", 0)) == 32, "Suite 9: %s frame size 32x32" % ent_id) and ok
			ok = _check(anims.has("walk") and anims.has("idle") and anims.has("attack"), "Suite 9: %s has walk/idle/attack anims" % ent_id) and ok
	return ok


func _suite_10_anti_idle(cat: Catalog) -> bool:
	var ok: bool = true
	var dt: float = 1.0 / 60.0
	for sid: String in ["runner", "penitent", "flagellant", "astromancer"]:
		for variant: String in ["A", "B"]:
			var w: SimWorld = SimWorld.create(cat, sid, [], [], 0xABCD, "", {"loadout": {"primary": variant, "secondary": variant, "utility": variant, "special": variant}})
			w.obstacles.clear()
			SimObstacles.rebuild_hash(w)
			SimEnemies.spawn(w, cat.entity("ember-mite"), 90.0, 0.0)
			var idle_in: InputFrame = InputFrame.empty()
			idle_in.aim_x = 90.0
			idle_in.aim_y = 0.0
			idle_in.held[InputFrame.SLOT_PRIMARY] = false
			idle_in.pressed[InputFrame.SLOT_PRIMARY] = false
			for _t: int in 60:
				w.step([idle_in], dt)
			var any_player_proj: bool = false
			for p: int in w.projectiles.alive.size():
				if w.projectiles.alive[p] != 0 and w.projectiles.team[p] == ProjectilePool.TEAM_PLAYER:
					any_player_proj = true
					break
			ok = _check(not any_player_proj and is_equal_approx(w.player.heat, 0.0) and is_equal_approx(w.damage_dealt, 0.0), "Suite 10: %s/%s Primary never auto-fires over 60 idle ticks" % [sid, variant]) and ok

	ok = _check(not Catalog.IMPLEMENTED_EFFECTS.has("orbit-orb"), "Suite 10: orbit-orb absent from Catalog.IMPLEMENTED_EFFECTS") and ok
	var sf: FileAccess = FileAccess.open("res://data/catalog/skills.json", FileAccess.READ)
	ok = _check(sf != null and not sf.get_as_text().contains("orbit-orb"), "Suite 10: orbit-orb absent from skills.json") and ok

	var av: FileAccess = FileAccess.open("res://src/view/arena_view.gd", FileAccess.READ)
	if _check(av != null, "Suite 10: read arena_view.gd"):
		var av_txt: String = av.get_as_text()
		ok = _check(not av_txt.contains("complete_working"), "Suite 10: arena_view.gd does not call complete_working") and ok
		var rx_cheat: RegEx = RegEx.new()
		rx_cheat.compile("is_action_just_pressed\\(\\s*\"confirm\"\\s*\\)")
		ok = _check(rx_cheat.search(av_txt) == null, "Suite 10: arena_view.gd has no confirm -> complete_working shortcut") and ok
	return ok


func _suite_11_sfx_range_fade() -> bool:
	var ok: bool = true
	var audio_script: GDScript = load("res://src/audio/game_audio.gd") as GDScript
	if not _check(audio_script != null, "Suite 11: load game_audio.gd"):
		return false
	var audio: Node = audio_script.new()
	ok = _check(is_equal_approx(audio._distance_gain(FxIds.HIT, 0.0), 1.0), "Suite 11: distance 0.0 -> gain 1.0") and ok
	ok = _check(is_equal_approx(audio._distance_gain(FxIds.HIT, 160.0), 1.0), "Suite 11: distance 160.0 -> gain 1.0") and ok
	ok = _check(is_equal_approx(audio._distance_gain(FxIds.HIT, 340.0), 0.25), "Suite 11: distance 340.0 (midpoint) -> gain 0.25") and ok
	ok = _check(is_equal_approx(audio._distance_gain(FxIds.HIT, 520.0), 0.0), "Suite 11: distance 520.0 -> gain 0.0") and ok
	ok = _check(is_equal_approx(audio._distance_gain(FxIds.DEATH, 900.0), 0.0), "Suite 11: distance 900.0 -> gain 0.0") and ok
	ok = _check(is_equal_approx(audio._distance_gain(FxIds.BOSS_EMERGE, 900.0), 1.0), "Suite 11: BOSS_EMERGE bypasses range fade") and ok
	ok = _check(is_equal_approx(audio._distance_gain(FxIds.HURT, 900.0), 1.0), "Suite 11: HURT bypasses range fade") and ok
	ok = _check(is_equal_approx(audio._distance_gain(FxIds.DASH, 900.0), 1.0), "Suite 11: DASH bypasses range fade") and ok
	audio.free()
	return ok
