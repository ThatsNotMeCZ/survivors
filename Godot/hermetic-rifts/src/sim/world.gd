class_name SimWorld
extends RefCounted

const ONE_SHOT_PROTECTION_THRESHOLD: float = 0.9
const ONE_SHOT_PROTECTION_IFRAME: float = 0.25

var catalog: Catalog
var survivor: Dictionary = {}
var stats: ResolvedStats
var player: PlayerState
var inventory: Array[ItemInstance] = []
var aim_x: float = 0.0
var aim_y: float = 0.0
var projectiles: ProjectilePool
var enemies: EnemyPool
var gems: GemPool
var lores: LorePool
var collected_lores: Dictionary = {}
var newly_collected_lores: Array[String] = []
var unlocked_items: Dictionary = {}
var obstacles: ObstaclePool
var grid: SpatialHash
var scratch: PackedInt32Array = PackedInt32Array()
var run_time: float = 0.0
var stage_time: float = 0.0
var stage_index: int = 0
var stage_gen: int = 0
var coefficient: float = 1.0
var credits: float = 0.0
var last_fodder_at: float = -99.0
var last_elite_at: float = -99.0
var counts_fodder: int = 0
var counts_elite: int = 0
var counts_boss: int = 0
var xp: float = 0.0
var xp_need: float = 32.0
var level: int = 1
var pending_levels: int = 0
var phase: StringName = &"play"
var offer: Array[Dictionary] = []
var won: bool = false
var boss_spawned: bool = false
var boss_defeated: bool = false
var teleporter_state: StringName = &"hidden"
var teleporter_x: float = 0.0
var teleporter_y: float = 0.0
var teleporter_radius: float = 160.0
var teleporter_charge: float = 0.0
var teleporter_hold: float = 20.0
var portal_open: bool = false
var portal_x: float = 0.0
var portal_y: float = 0.0
var portal_hold: float = 0.0
var focus_kind: StringName = &"none"
var focus_hp: float = 0.0
var focus_max_hp: float = 0.0
var focus_id: String = ""
var fx: FxPool
var zones: ZonePool
var boss: BossState
var boss_hazards: BossHazardPool
var decoy: DecoyState
var bosses_defeated: int = 0
var last_sniper_at: float = -99.0
var kills_fodder: int = 0
var kills_elite: int = 0
var kills_boss: int = 0
var kills_total: int = 0
var kills_by_entity: Dictionary = {}
var encounters_by_entity: Dictionary = {}
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var healing_done: float = 0.0
var gems_collected: int = 0
var stages_cleared: int = 0
var cycle_index: int = 0
var run_seed: int = 0
var daily_date: String = ""
var arena_shape: String = "circle"
var arena_radius: float = 1500.0
var arena_rim_thickness: float = 24.0
var stage_id: String = "cinder-yard"
var return_stage_index: int = 1
var demo_mode: bool = false
var demo_completed: bool = false
var ascension_tier: int = 0
var loadout: Dictionary = {"primary": "A", "secondary": "A", "utility": "A", "special": "A"}
var rerolls_left: int = 0
var banishes_left: int = 0
var locks_left: int = 0
var banished_items: Dictionary = {}
var locked_item_id: String = ""
var pending_bonus_drafts: int = 0
var is_bonus_draft: bool = false
var run_essence: int = 0
var run_essence_collected: int = 0:
	get:
		return run_essence
	set(val):
		run_essence_collected = val
var essence_gain_mul: float = 1.0
var teleporter_discovered: bool = false
var teleporter_flawless_hold: bool = true
var ritual_tier: int = 0
var hit_stop_remain: float = 0.0
var stage_obelisks_total: int = 0
var stage_obelisks_completed: int = 0
var obelisks_completed: int = 0
var obelisk_armor_debuff: float = 0.0
var geodes_cracked_run: int = 0
var alchemy_reactions_run: int = 0
var low_hp_boss_kills_run: int = 0
var low_hp_boss_kills: int = 0:
	get:
		return maxi(low_hp_boss_kills, low_hp_boss_kills_run)
	set(val):
		low_hp_boss_kills = val
		low_hp_boss_kills_run = maxi(low_hp_boss_kills_run, val)
var portals: Array[Dictionary] = []
var stage_rng: SimRng
var interact_held: bool = false
var interact_pressed: bool = false
var exited_via_victory_portal: bool = false
var true_victory: bool = false
var visited_stage_ids: Array[String] = []
var cleared_stage_ids: Array[String] = []
var crucible_upgrades: Dictionary = {}
var tonic_buffer_hp: float = 0.0
var overheat_decay_mul: float = 1.0
var overheat_gain_mul: float = 1.0
var _prev_stage_obelisks: int = 0
var offer_rng: SimRng
var combat_rng: RandomNumberGenerator


static func create(
	cat: Catalog,
	survivor_id: String = "",
	unlocked: Array[String] = [],
	collected: Array[String] = [],
	p_run_seed: int = -1,
	p_daily_date: String = "",
	run_config: Dictionary = {},
) -> SimWorld:
	var world: SimWorld = SimWorld.new()
	world.catalog = cat
	world.arena_shape = String(cat.world.get("arenaShape", "circle"))
	world.arena_radius = float(cat.world.get("arenaRadius", 1500.0))
	world.arena_rim_thickness = float(cat.world.get("arenaRimThickness", 24.0))
	world.demo_mode = bool(run_config.get("demo_mode", run_config.get("demoMode", false)))
	world.ascension_tier = maxi(0, int(run_config.get("ascension_tier", run_config.get("ascensionTier", 0))))
	var raw_loadout: Variant = run_config.get("loadout", {})
	if typeof(raw_loadout) == TYPE_DICTIONARY:
		var ldict: Dictionary = raw_loadout
		for slot: String in Catalog.SLOTS:
			world.loadout[slot] = "B" if String(ldict.get(slot, "A")) == "B" else "A"
	var raw_upgrades: Variant = run_config.get("crucible_upgrades", run_config.get("crucibleUpgrades", {}))
	var upgrades: Dictionary = raw_upgrades if typeof(raw_upgrades) == TYPE_DICTIONARY else {}
	world.crucible_upgrades = upgrades.duplicate()
	var reroll_lvl: int = maxi(0, int(upgrades.get("divination-reroll", 0)))
	var banish_lvl: int = maxi(0, int(upgrades.get("exorcism-banish", 0)))
	var lock_lvl: int = maxi(0, int(upgrades.get("fixation-lock", 0)))
	var attunement_lvl: int = maxi(0, int(upgrades.get("distillation-attunement", 0)))
	var tonic_lvl: int = maxi(0, int(upgrades.get("tonic-buffer", 0)))
	var bellows_lvl: int = maxi(0, int(upgrades.get("bellows-valve", 0)))
	world.rerolls_left = reroll_lvl * int(_upgrade_val(cat, "divination-reroll", "perLevel", 1.0))
	world.banishes_left = banish_lvl * int(_upgrade_val(cat, "exorcism-banish", "perLevel", 1.0))
	world.locks_left = lock_lvl * int(_upgrade_val(cat, "fixation-lock", "perLevel", 1.0))
	var att_per: float = _upgrade_val(cat, "distillation-attunement", "perLevel", 0.05)
	var asc_per: float = _upgrade_val(cat, "ascension-seals", "essenceBonusPerTier", 0.15)
	world.essence_gain_mul = 1.0 + float(attunement_lvl) * att_per + float(world.ascension_tier) * asc_per
	world.tonic_buffer_hp = float(tonic_lvl) * _upgrade_val(cat, "tonic-buffer", "perLevel", 15.0)
	world.overheat_decay_mul = 1.0 + float(bellows_lvl) * _upgrade_val(cat, "bellows-valve", "decayPerLevel", 0.12)
	world.overheat_gain_mul = maxf(0.25, 1.0 - float(bellows_lvl) * _upgrade_val(cat, "bellows-valve", "heatGainReductionPerLevel", 0.08))
	var sid: String = survivor_id if survivor_id != "" else String(cat.world.get("defaultSurvivor", "runner"))
	world.survivor = cat.survivor(sid)
	world.inventory.clear()
	for item_id: Variant in world.survivor.get("startingItems", []):
		world.inventory.append(ItemInstance.make(String(item_id), 1))
	world.stats = SimStats.resolve(world.survivor.get("stats", {}), world.inventory, cat, world.tonic_buffer_hp)
	var loop: Dictionary = cat.loop
	var enemy_cap: int = int(loop.get("maxFodder", 42)) + int(loop.get("maxElites", 12)) + int(loop.get("maxSpecialists", 9)) + 8
	world.player = PlayerState.new()
	world.player.def_id = String(world.survivor.get("id", sid))
	if world.arena_shape == "circle":
		world.player.x = 0.0
		world.player.y = 0.0
	else:
		world.player.x = float(cat.world.get("width", 2560.0)) * 0.5
		world.player.y = float(cat.world.get("height", 2560.0)) * 0.5
	world.player.radius = world.stats.radius
	world.player.hp = world.stats.max_hp
	world.player.max_hp = world.stats.max_hp
	world.player.speed = world.stats.speed
	world.player.skill_cd = InputFrame.empty_cds()
	_sync_player_bellows(world.player, bellows_lvl, world.overheat_decay_mul, world.overheat_gain_mul)
	if unlocked.is_empty():
		for item_def: Dictionary in cat.items:
			world.unlocked_items[String(item_def.get("id", ""))] = true
	else:
		for id: String in unlocked:
			world.unlocked_items[id] = true
	for id: String in collected:
		world.collected_lores[id] = true
	world.run_seed = p_run_seed if p_run_seed >= 0 else SimRng.random_run_seed()
	world.daily_date = p_daily_date
	world.offer_rng = SimRng.new(world.run_seed ^ 0x51ED)
	world.stage_rng = SimRng.new(world.run_seed ^ 0x57A6)
	world.combat_rng = RandomNumberGenerator.new()
	world.combat_rng.randomize()
	world.aim_x = world.player.x + 1.0
	world.aim_y = world.player.y
	world.projectiles = ProjectilePool.create(int(cat.world.get("maxProjectiles", 160)))
	world.enemies = EnemyPool.create(enemy_cap)
	world.gems = GemPool.create(int(loop.get("maxGems", 999)))
	world.lores = LorePool.create(GemPool.MAX_LORE_DROPS)
	world.obstacles = ObstaclePool.create(
		ObstaclePool.obstacle_cap(cat.obstacles.get("counts", {}), int(cat.obstacles.get("dynamicHazards", 8))),
		float(loop.get("hashCell", 128.0)),
	)
	world.grid = SpatialHash.create(float(loop.get("hashCell", 128.0)), enemy_cap)
	world.scratch.resize(enemy_cap)
	world.xp_need = SimLevel.xp_for_level(float(loop.get("xpBase", 32.0)), float(loop.get("xpGrowth", 1.3)), 1)
	var stages: Array = DictUtil.a(loop, "stages")
	if not stages.is_empty():
		world.teleporter_radius = float(stages[0].get("teleporterRadius", 160.0))
		world.teleporter_hold = float(stages[0].get("teleporterHold", 20.0))
	world.fx = FxPool.create()
	world.zones = ZonePool.create()
	world.boss = BossState.new()
	world.boss_hazards = BossHazardPool.create()
	world.decoy = DecoyState.new()
	SimLoop.begin_stage(world, 0)
	if world.arena_shape == "circle":
		world.player.x = 0.0
		world.player.y = 0.0
		world.aim_x = 1.0
		world.aim_y = 0.0
	return world


static func _upgrade_val(cat: Catalog, id: String, key: String, fallback: float) -> float:
	if cat == null or not cat.has_upgrade(id):
		return fallback
	var eff: Dictionary = DictUtil.d(cat.upgrade(id), "effect")
	return float(eff.get(key, fallback))


static func _sync_player_bellows(p: PlayerState, _lvl: int, decay_mul: float, gain_mul: float) -> void:
	p.heat_decay_mul = decay_mul
	p.heat_gain_mul = gain_mul


func randf() -> float:
	return combat_rng.randf()


func randi_range(lo: int, hi: int) -> int:
	return combat_rng.randi_range(lo, hi)


func step(frames: Array[InputFrame], dt: float) -> void:
	if phase != &"play":
		return
	var input: InputFrame = frames[0] if not frames.is_empty() else InputFrame.empty()
	fx.clear()
	aim_x = input.aim_x
	aim_y = input.aim_y
	interact_held = input.interact_held
	interact_pressed = input.interact_pressed
	if hit_stop_remain > 0.0:
		hit_stop_remain = maxf(0.0, hit_stop_remain - dt)
		return
	var prev_taken: float = damage_taken
	run_time += dt
	stage_time += dt
	SimSkills.tick_cooldowns(self, dt)
	player.iframe_remain = maxf(0.0, player.iframe_remain - dt)
	player.tick_heat(dt, catalog.loop.get("overheat", {}))
	if player.parry_remain > 0.0:
		player.parry_remain = maxf(0.0, player.parry_remain - dt)
		if player.parry_remain <= 0.0:
			player.parry_triggered = false
	if player.bell_armor_remain > 0.0:
		player.bell_armor_remain = maxf(0.0, player.bell_armor_remain - dt)
	if player.bulwark_remain > 0.0:
		player.bulwark_remain = maxf(0.0, player.bulwark_remain - dt)
		if player.bulwark_remain <= 0.0:
			_trigger_bulwark_counter()
	if player.burn_remain > 0.0:
		player.burn_remain = maxf(0.0, player.burn_remain - dt)
		var burn_cfg: Dictionary = catalog.loop.get("burn", {})
		var stacks: int = maxi(1, player.burn_stacks)
		var burn_dps: float = player.burn_dps if player.burn_dps > 0.0 else float(burn_cfg.get("dpsCoeff", 4.5)) * coefficient * float(stacks)
		_apply_dot_damage(burn_dps * dt)
		if player.burn_remain <= 0.0:
			player.burn_stacks = 0
			player.burn_dps = 0.0
	SimSkills.try_skills(self, input)
	_move_player(input, dt)
	projectiles.step(dt)
	_detonate_impacts()
	SimDirector.step(self, dt)
	SimEnemiesStep.step(self, dt)
	_rebuild_hash()
	SimSeparation.resolve(self)
	_rebuild_hash()
	SimObstacles.hit_projectiles(self)
	_hit_enemies()
	_hit_player()
	_contact_damage(dt)
	SimZones.step(self, dt)
	SimBossHazards.step(self, dt)
	SimObstacles.step(self, dt)
	_sync_run_counters()
	SimPickups.step_gems(self, dt)
	SimPickups.step_lores(self, dt)
	SimLoop.step(self, dt)
	_sync_run_counters()
	SimLevel.open_bonus_draft_if_ready(self)
	if stats.hp_regen > 0.0 and player.hp > 0.0:
		heal_player(stats.hp_regen * dt)
	if damage_taken > prev_taken and teleporter_state == &"charging":
		teleporter_flawless_hold = false
	if damage_taken > prev_taken and player.hurt_cooldown <= 0.0:
		player.hurt_remain = 0.14
		player.hurt_cooldown = 0.22
	player.hurt_cooldown = maxf(0.0, player.hurt_cooldown - dt)
	player.hurt_remain = maxf(0.0, player.hurt_remain - dt)


func _sync_run_counters() -> void:
	if stage_obelisks_completed > _prev_stage_obelisks:
		obelisks_completed += stage_obelisks_completed - _prev_stage_obelisks
	_prev_stage_obelisks = stage_obelisks_completed
	run_essence_collected = run_essence
	var max_low_hp: int = maxi(low_hp_boss_kills, low_hp_boss_kills_run)
	low_hp_boss_kills = max_low_hp
	low_hp_boss_kills_run = max_low_hp


func damage_player(raw: float, is_hazard: bool = false) -> void:
	if raw <= 0.0 or player.hp <= 0.0:
		return
	if player.parry_remain > 0.0:
		_trigger_parry_reflect()
		return
	if player.iframe_remain > 0.0:
		return
	var bell_bonus: float = 0.25 if player.bell_armor_remain > 0.0 else 0.0
	var eff_armor: float = clampf(stats.armor - absf(obelisk_armor_debuff) + bell_bonus, -0.5, 0.85)
	var final_damage: float = raw * (1.0 - eff_armor)
	if is_hazard:
		final_damage *= 1.0 - stats.hazard_resist
	if player.bulwark_remain > 0.0 and player.bulwark_dr > 0.0:
		var mitigated: float = final_damage * clampf(player.bulwark_dr, 0.0, 0.95)
		player.bulwark_stored_damage += mitigated
		final_damage -= mitigated
	_commit_player_damage(final_damage)


func _apply_dot_damage(raw: float) -> void:
	if raw <= 0.0 or player.hp <= 0.0:
		return
	var bell_bonus: float = 0.25 if player.bell_armor_remain > 0.0 else 0.0
	var eff_armor: float = clampf(stats.armor - absf(obelisk_armor_debuff) + bell_bonus, -0.5, 0.85)
	var final_damage: float = raw * (1.0 - eff_armor) * (1.0 - stats.hazard_resist)
	if player.bulwark_remain > 0.0 and player.bulwark_dr > 0.0:
		final_damage *= 1.0 - clampf(player.bulwark_dr, 0.0, 0.95)
	_commit_player_damage(final_damage)


func _commit_player_damage(raw_final: float) -> void:
	var final_damage: float = maxf(0.0, raw_final)
	var osp: float = player.max_hp * ONE_SHOT_PROTECTION_THRESHOLD
	if player.hp >= osp and player.hp - final_damage < 1.0:
		final_damage = maxf(0.0, player.hp - 1.0)
		player.iframe_remain = maxf(player.iframe_remain, ONE_SHOT_PROTECTION_IFRAME)
	player.hp -= final_damage
	damage_taken += final_damage


func _trigger_parry_reflect() -> void:
	if player.parry_triggered:
		return
	player.parry_triggered = true
	player.skill_cd[InputFrame.SLOT_UTILITY] = maxf(0.0, float(player.skill_cd[InputFrame.SLOT_UTILITY]) - player.parry_cooldown_refund)
	var dx: float = aim_x - player.x
	var dy: float = aim_y - player.y
	var dist: float = sqrt(dx * dx + dy * dy)
	var base_ang: float = atan2(dy, dx) if dist > 0.001 else 0.0
	var count: int = maxi(1, player.parry_shard_count)
	var spread_rad: float = deg_to_rad(24.0)
	var shard_dmg: float = player.parry_shard_damage * stats.damage_mul
	var speed: float = 1050.0 * stats.proj_speed_mul
	var muzzle: float = player.radius + 8.0
	for k: int in count:
		var frac: float = 0.0 if count == 1 else float(k) / float(count - 1) - 0.5
		var ang: float = base_ang + frac * spread_rad
		var nx: float = cos(ang)
		var ny: float = sin(ang)
		projectiles.spawn(
			player.x + nx * muzzle,
			player.y + ny * muzzle,
			nx,
			ny,
			speed,
			0.7,
			6.0,
			shard_dmg,
			ProjectilePool.TEAM_PLAYER,
			ProjectilePool.FLAG_PIERCE | ProjectilePool.FLAG_SPLIT,
			0.0,
			0.0,
			0.0,
			0.0,
			0.0,
			false,
			"aether",
			"parry",
		)
	fx.emit(FxIds.PARRY_REFLECT, player.x, player.y, 0xDFF6FF, player.radius + 24.0)


func _trigger_bulwark_counter() -> void:
	var c_dmg_base: float = player.bulwark_counter_damage * stats.damage_mul + player.bulwark_stored_damage
	var c_range: float = player.bulwark_counter_range * stats.aoe_radius_mul
	var c_arc_deg: float = player.bulwark_counter_arc_deg
	player.bulwark_dr = 0.0
	player.bulwark_knockback_immune = false
	player.bulwark_stored_damage = 0.0
	player.bulwark_counter_damage = 0.0
	if c_dmg_base <= 0.0 or c_range <= 0.0:
		return
	var dx: float = aim_x - player.x
	var dy: float = aim_y - player.y
	var dlen: float = sqrt(dx * dx + dy * dy)
	var ux: float = dx / dlen if dlen > 0.001 else 1.0
	var uy: float = dy / dlen if dlen > 0.001 else 0.0
	var cos_half: float = cos(deg_to_rad(c_arc_deg * 0.5))
	fx.emit(FxIds.CRUCIBLE_IMPACT, player.x + ux * (c_range * 0.45), player.y + uy * (c_range * 0.45), 0xFF8844, c_range * 0.55)
	var any_crit: bool = false
	for e: int in enemies.cap:
		if enemies.alive[e] == 0 or enemies.corpse_remain[e] > 0.0:
			continue
		var ex: float = enemies.x[e] - player.x
		var ey: float = enemies.y[e] - player.y
		var ed: float = sqrt(ex * ex + ey * ey)
		if ed > c_range + enemies.radius[e]:
			continue
		if ed > player.radius + enemies.radius[e] + 8.0 and ed > 0.001:
			var dot: float = (ex / ed) * ux + (ey / ed) * uy
			if dot < cos_half:
				continue
		var is_crit: bool = randf() < stats.crit_chance
		var dmg: float = c_dmg_base * (stats.crit_mul if is_crit else 1.0)
		SimEnemies.apply_damage(self, e, dmg)
		fx.emit(FxIds.HIT, enemies.x[e], enemies.y[e], 0xFF4422 if is_crit else 0xFFC070)
		if is_crit:
			any_crit = true
		if enemies.alive[e] != 0 and enemies.role[e] != EnemyPool.ROLE_BOSS and ed > 0.001:
			enemies.apply_knockback(e, (ex / ed) * 220.0, (ey / ed) * 220.0)
	if any_crit:
		trigger_on_crit()
	SimObstacles.hit_aoe(self, player.x + ux * (c_range * 0.45), player.y + uy * (c_range * 0.45), c_range * 0.65, c_dmg_base, false, "fire")


func heal_player(amount: float) -> void:
	if amount <= 0.0 or player.hp <= 0.0:
		return
	var prev: float = player.hp
	player.hp = minf(player.max_hp, player.hp + amount)
	healing_done += maxf(0.0, player.hp - prev)


func trigger_on_crit() -> void:
	var refund: float = SimStats.on_crit_cooldown_refund(inventory, catalog)
	if refund <= 0.0:
		return
	for slot: StringName in InputFrame.SLOTS:
		if float(player.skill_cd[slot]) > 0.0:
			player.skill_cd[slot] = maxf(0.0, float(player.skill_cd[slot]) - refund)


func _move_player(input: InputFrame, dt: float) -> void:
	var old_x: float = player.x
	var old_y: float = player.y
	var bounds: Dictionary = catalog.world
	if player.dash_remain > 0.0:
		player.root_remain = 0.0
		player.dash_remain = maxf(0.0, player.dash_remain - dt)
		player.x += player.dash_vx * dt
		player.y += player.dash_vy * dt
	elif player.root_remain <= 0.0:
		var mx: float = input.move_x
		var my: float = input.move_y
		var mag: float = sqrt(mx * mx + my * my)
		if mag > 1.0:
			mx /= mag
			my /= mag
		var speed: float = stats.speed * SimObstacles.player_speed_mul(self) * SimZones.player_speed_bonus(self)
		player.x += mx * speed * dt
		player.y += my * speed * dt
	if arena_shape == "circle":
		var max_r: float = maxf(1.0, arena_radius - arena_rim_thickness - player.radius)
		var clamped: Vector2 = SimCollision.clamp_to_circle(player.x, player.y, max_r)
		player.x = clamped.x
		player.y = clamped.y
	else:
		var pad_x: float = float(bounds.get("borderInsetX", 0.0)) + player.radius
		var pad_y: float = float(bounds.get("borderInsetY", 0.0)) + player.radius
		player.x = clampf(player.x, pad_x, float(bounds.get("width", 2560.0)) - pad_x)
		player.y = clampf(player.y, pad_y, float(bounds.get("height", 2560.0)) - pad_y)
	if dt > 0.0001:
		player.vx = (player.x - old_x) / dt
		player.vy = (player.y - old_y) / dt
	else:
		player.vx = 0.0
		player.vy = 0.0


func _rebuild_hash() -> void:
	grid.clear()
	for i: int in enemies.cap:
		if enemies.alive[i] == 0:
			continue
		grid.insert(enemies.x[i], enemies.y[i], i)


func _detonate_impacts() -> void:
	for i: int in projectiles.alive.size():
		if projectiles.alive[i] == 0:
			continue
		if (projectiles.flags[i] & ProjectilePool.FLAG_IMPACT) == 0:
			continue
		var dx: float = projectiles.dest_x[i] - projectiles.x[i]
		var dy: float = projectiles.dest_y[i] - projectiles.y[i]
		if projectiles.life[i] > 0.0 and dx * dx + dy * dy > 64.0:
			continue
		var px: float = projectiles.x[i]
		var py: float = projectiles.y[i]
		var radius: float = projectiles.impact_radius[i]
		var is_crit: bool = randf() < stats.crit_chance
		var dmg: float = projectiles.damage[i] * (stats.crit_mul if is_crit else 1.0)
		fx.emit(FxIds.CENSER_IMPACT, px, py, 0xFF4422 if is_crit else 0xFFAA55, radius)
		var hit_any: bool = false
		for e: int in enemies.cap:
			if enemies.alive[e] == 0 or enemies.corpse_remain[e] > 0.0:
				continue
			if not SimCollision.circles_overlap(px, py, radius, enemies.x[e], enemies.y[e], enemies.radius[e]):
				continue
			SimEnemies.apply_damage(self, e, dmg)
			hit_any = true
		if is_crit and hit_any and projectiles.team[i] == ProjectilePool.TEAM_PLAYER:
			trigger_on_crit()
		if projectiles.team[i] == ProjectilePool.TEAM_PLAYER:
			var is_sec_spec: bool = (projectiles.flags[i] & ProjectilePool.FLAG_SECONDARY_OR_SPECIAL) != 0
			var elem: String = projectiles.element[i]
			SimObstacles.hit_aoe(self, px, py, radius, dmg, is_sec_spec, elem)
			SimAlchemy.trigger_surface_reaction(self, px, py, radius, is_sec_spec, elem)
		projectiles.kill_at(i)


func _hit_enemies() -> void:
	for i: int in projectiles.alive.size():
		if projectiles.alive[i] == 0 or projectiles.team[i] != ProjectilePool.TEAM_PLAYER:
			continue
		if (projectiles.flags[i] & ProjectilePool.FLAG_FLYOVER) != 0:
			continue
		var pierce: bool = (projectiles.flags[i] & ProjectilePool.FLAG_PIERCE) != 0
		var tether: bool = (projectiles.flags[i] & ProjectilePool.FLAG_TETHER) != 0
		var n: int = grid.query(projectiles.x[i], projectiles.y[i], projectiles.radius[i] + 48.0)
		if tether:
			_hit_tether(i, n)
			continue
		if pierce:
			for k: int in n:
				var idx: int = grid.hits[k]
				if not _can_hit(i, idx):
					continue
				_apply_player_hit(i, idx, false)
			continue
		var nearest: int = -1
		var best: float = INF
		for k: int in n:
			var idx: int = grid.hits[k]
			if not _can_hit(i, idx):
				continue
			var ddx: float = enemies.x[idx] - projectiles.x[i]
			var ddy: float = enemies.y[idx] - projectiles.y[i]
			var dist: float = ddx * ddx + ddy * ddy
			if dist < best:
				best = dist
				nearest = idx
		if nearest < 0:
			continue
		_apply_player_hit(i, nearest, false)
		projectiles.kill_at(i)


func _hit_tether(proj: int, n: int) -> void:
	var nearest_anchor: int = -1
	var best: float = INF
	var fodder_hits: Array[int] = []
	for k: int in n:
		var idx: int = grid.hits[k]
		if not _can_hit(proj, idx):
			continue
		var ddx: float = enemies.x[idx] - projectiles.x[proj]
		var ddy: float = enemies.y[idx] - projectiles.y[proj]
		var dist: float = ddx * ddx + ddy * ddy
		if enemies.role[idx] == EnemyPool.ROLE_ELITE or enemies.role[idx] == EnemyPool.ROLE_BOSS:
			if dist < best:
				best = dist
				nearest_anchor = idx
		else:
			fodder_hits.append(idx)
	for f: int in fodder_hits:
		_apply_player_hit(proj, f, false)
	if nearest_anchor >= 0:
		_apply_player_hit(proj, nearest_anchor, true)
		projectiles.kill_at(proj)


func _can_hit(proj: int, idx: int) -> bool:
	if enemies.alive[idx] == 0 or enemies.corpse_remain[idx] > 0.0:
		return false
	if not SimCollision.aabb_overlap(projectiles.x[proj], projectiles.y[proj], projectiles.radius[proj], enemies.x[idx], enemies.y[idx], enemies.radius[idx]):
		return false
	if projectiles.has_hit(proj, idx):
		return false
	return true


func _apply_player_hit(proj: int, enemy: int, tether_anchor: bool) -> void:
	projectiles.mark_hit(proj, enemy)
	var is_crit: bool = randf() < stats.crit_chance
	var dmg: float = projectiles.damage[proj] * (stats.crit_mul if is_crit else 1.0)
	var is_sec_spec: bool = (projectiles.flags[proj] & ProjectilePool.FLAG_SECONDARY_OR_SPECIAL) != 0
	var elem: String = projectiles.element[proj]
	if tether_anchor:
		enemies.root_remain[enemy] = maxf(enemies.root_remain[enemy], projectiles.root_duration[proj])
		enemies.root_duration[enemy] = maxf(enemies.root_duration[enemy], projectiles.root_duration[proj])
		enemies.tether_dps[enemy] = projectiles.tether_dps[proj]
		fx.emit(FxIds.TETHER_LATCH, enemies.x[enemy], enemies.y[enemy], 0xFF4422 if is_crit else 0xF79617, enemies.radius[enemy])
		if dmg > 0.0:
			SimEnemies.apply_damage(self, enemy, dmg)
		if is_crit:
			trigger_on_crit()
		SimObstacles.hit_aoe(self, projectiles.x[proj], projectiles.y[proj], projectiles.radius[proj], dmg, is_sec_spec, elem)
		SimAlchemy.trigger_surface_reaction(self, projectiles.x[proj], projectiles.y[proj], projectiles.radius[proj], is_sec_spec, elem)
		return
	fx.emit(FxIds.HIT, projectiles.x[proj], projectiles.y[proj], 0xFF4422 if is_crit else 0xFFF4C8)
	SimEnemies.apply_damage(self, enemy, dmg)
	if projectiles.skill_tag[proj] == "harpoon" or (projectiles.flags[proj] & ProjectilePool.FLAG_PULL_HARPOON) != 0:
		if enemies.alive[enemy] != 0 and enemies.corpse_remain[enemy] <= 0.0 and enemies.role[enemy] != EnemyPool.ROLE_BOSS:
			var dx: float = player.x - enemies.x[enemy]
			var dy: float = player.y - enemies.y[enemy]
			var dist: float = sqrt(dx * dx + dy * dy)
			var pull_dist: float = projectiles.extra_float[proj] if projectiles.extra_float[proj] > 0.0 else 180.0
			var stop_dist: float = player.radius + enemies.radius[enemy] + 10.0
			var move_d: float = minf(pull_dist, maxf(0.0, dist - stop_dist))
			if dist > 0.001 and move_d > 0.0:
				enemies.x[enemy] += (dx / dist) * move_d
				enemies.y[enemy] += (dy / dist) * move_d
			var stun_dur: float = projectiles.extra_float2[proj] if projectiles.extra_float2[proj] > 0.0 else (0.4 * stats.control_duration_mul)
			enemies.apply_stun(enemy, stun_dur)
	if projectiles.skill_tag[proj] == "prism" and (projectiles.flags[proj] & ProjectilePool.FLAG_SPLIT) == 0:
		_split_prism_projectile(proj, enemy)
	if is_crit:
		trigger_on_crit()
	SimObstacles.hit_aoe(self, projectiles.x[proj], projectiles.y[proj], projectiles.radius[proj], dmg, is_sec_spec, elem)
	SimAlchemy.trigger_surface_reaction(self, projectiles.x[proj], projectiles.y[proj], projectiles.radius[proj], is_sec_spec, elem)


func _split_prism_projectile(proj: int, hit_enemy: int) -> void:
	var pvx: float = projectiles.vx[proj]
	var pvy: float = projectiles.vy[proj]
	var p_speed: float = sqrt(pvx * pvx + pvy * pvy)
	if p_speed <= 0.001:
		return
	var base_ang: float = atan2(pvy, pvx)
	var count: int = maxi(2, projectiles.extra_int[proj] if projectiles.extra_int[proj] > 0 else 3)
	var spread_deg: float = projectiles.extra_float2[proj] if projectiles.extra_float2[proj] > 0.0 else 36.0
	var spread_rad: float = deg_to_rad(spread_deg)
	var split_dmg: float = projectiles.extra_float[proj] if projectiles.extra_float[proj] > 0.0 else projectiles.damage[proj] * 0.55
	var shard_flags: int = ProjectilePool.FLAG_PIERCE | ProjectilePool.FLAG_SPLIT | (projectiles.flags[proj] & ProjectilePool.FLAG_SECONDARY_OR_SPECIAL)
	var shard_life: float = maxf(0.3, projectiles.life[proj])
	var shard_rad: float = maxf(4.0, projectiles.radius[proj] - 1.0)
	var px: float = projectiles.x[proj]
	var py: float = projectiles.y[proj]
	var elem: String = projectiles.element[proj]
	for k: int in count:
		var frac: float = 0.0 if count == 1 else float(k) / float(count - 1) - 0.5
		var ang: float = base_ang + frac * spread_rad
		if projectiles.spawn(
			px,
			py,
			cos(ang),
			sin(ang),
			p_speed,
			shard_life,
			shard_rad,
			split_dmg,
			ProjectilePool.TEAM_PLAYER,
			shard_flags,
			0.0,
			0.0,
			0.0,
			0.0,
			0.0,
			false,
			elem,
			"prism_shard",
		):
			if projectiles.last_spawned >= 0:
				projectiles.mark_hit(projectiles.last_spawned, hit_enemy)
	fx.emit(FxIds.PARRY_REFLECT, px, py, 0xA884F3, 24.0)


func _hit_player() -> void:
	var can_parry: bool = player.parry_remain > 0.0
	if player.iframe_remain > 0.0 and not can_parry:
		return
	for i: int in projectiles.alive.size():
		if projectiles.alive[i] == 0 or projectiles.team[i] != ProjectilePool.TEAM_ENEMY:
			continue
		if not SimCollision.aabb_overlap(projectiles.x[i], projectiles.y[i], projectiles.radius[i], player.x, player.y, player.radius):
			continue
		if can_parry:
			projectiles.kill_at(i)
			_trigger_parry_reflect()
			continue
		if player.iframe_remain > 0.0:
			continue
		var is_burn: bool = projectiles.element[i] == "burn"
		fx.emit(FxIds.HURT, projectiles.x[i], projectiles.y[i], 0xFF7A3A)
		damage_player(projectiles.damage[i])
		if is_burn:
			SimEnemies.apply_burn_stack(self)
		projectiles.kill_at(i)


func _contact_damage(dt: float) -> void:
	if player.iframe_remain > 0.0:
		return
	var cap: int = int(catalog.loop.get("fodderContactCap", 3))
	var fodder_hits: int = 0
	var n: int = grid.query(player.x, player.y, player.radius + 48.0)
	for k: int in n:
		var idx: int = grid.hits[k]
		if enemies.alive[idx] == 0:
			continue
		var touching: bool = SimCollision.aabb_overlap(player.x, player.y, player.radius, enemies.x[idx], enemies.y[idx], enemies.radius[idx])
		if SimEnemies.is_chase(self, idx):
			var cdx: float = player.x - enemies.x[idx]
			var cdy: float = player.y - enemies.y[idx]
			var reach: float = SimEnemies.chase_contact_range(enemies.radius[idx], player.radius)
			touching = cdx * cdx + cdy * cdy <= reach * reach
		if not touching:
			continue
		if enemies.corpse_remain[idx] > 0.0:
			continue
		if enemies.attack_remain[idx] <= 0.0 and enemies.attack_cd[idx] <= 0.0:
			enemies.attack_remain[idx] = EnemyPool.CHASE_ATTACK_DURATION
			enemies.attack_cd[idx] = EnemyPool.CHASE_ATTACK_COOLDOWN
		if enemies.role[idx] == EnemyPool.ROLE_FODDER:
			if fodder_hits >= cap:
				continue
			fodder_hits += 1
		damage_player(enemies.contact_dps[idx] * dt)
		SimEnemies.apply_noxious_contact(self, idx)
		if enemies.affix[idx] == "burn":
			SimEnemies.apply_burn_to_player(self, idx)
