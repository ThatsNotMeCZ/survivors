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
var offer_rng: SimRng
var combat_rng: RandomNumberGenerator


static func create(
	cat: Catalog,
	survivor_id: String = "",
	unlocked: Array[String] = [],
	collected: Array[String] = [],
	p_run_seed: int = -1,
	p_daily_date: String = "",
) -> SimWorld:
	var world := SimWorld.new()
	world.catalog = cat
	var sid: String = survivor_id if survivor_id != "" else String(cat.world.get("defaultSurvivor", "runner"))
	world.survivor = cat.survivor(sid)
	world.inventory.clear()
	for item_id: Variant in world.survivor.get("startingItems", []):
		world.inventory.append(ItemInstance.make(String(item_id), 1))
	world.stats = SimStats.resolve(world.survivor.get("stats", {}), world.inventory, cat)
	var loop: Dictionary = cat.loop
	var enemy_cap: int = int(loop.get("maxFodder", 24)) + int(loop.get("maxElites", 6)) + 1
	world.player = PlayerState.new()
	world.player.def_id = String(world.survivor.get("id", sid))
	world.player.x = float(cat.world.get("width", 2560.0)) * 0.5
	world.player.y = float(cat.world.get("height", 2560.0)) * 0.5
	world.player.radius = world.stats.radius
	world.player.hp = world.stats.max_hp
	world.player.max_hp = world.stats.max_hp
	world.player.speed = world.stats.speed
	world.player.skill_cd = InputFrame.empty_cds()
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
	world.combat_rng = RandomNumberGenerator.new()
	world.combat_rng.randomize()
	world.aim_x = world.player.x + 1.0
	world.aim_y = world.player.y
	world.projectiles = ProjectilePool.create(int(cat.world.get("maxProjectiles", 128)))
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
	return world


func randf() -> float:
	return combat_rng.randf()


func randi_range(lo: int, hi: int) -> int:
	return combat_rng.randi_range(lo, hi)


func step(frames: Array[InputFrame], dt: float) -> void:
	if phase != &"play":
		return
	var input: InputFrame = frames[0] if not frames.is_empty() else InputFrame.empty()
	var prev_taken: float = damage_taken
	fx.clear()
	aim_x = input.aim_x
	aim_y = input.aim_y
	run_time += dt
	stage_time += dt
	SimSkills.tick_cooldowns(self, dt)
	player.iframe_remain = maxf(0.0, player.iframe_remain - dt)
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
	SimPickups.step_gems(self, dt)
	SimPickups.step_lores(self, dt)
	SimLoop.step(self, dt)
	if stats.hp_regen > 0.0 and player.hp > 0.0:
		heal_player(stats.hp_regen * dt)
	if damage_taken > prev_taken and player.hurt_cooldown <= 0.0:
		player.hurt_remain = 0.14
		player.hurt_cooldown = 0.22
	player.hurt_cooldown = maxf(0.0, player.hurt_cooldown - dt)
	player.hurt_remain = maxf(0.0, player.hurt_remain - dt)


func damage_player(raw: float, is_hazard: bool = false) -> void:
	if raw <= 0.0 or player.iframe_remain > 0.0 or player.hp <= 0.0:
		return
	var final_damage: float = raw * (1.0 - stats.armor)
	if is_hazard:
		final_damage *= 1.0 - stats.hazard_resist
	final_damage = maxf(0.0, final_damage)
	var osp: float = player.max_hp * ONE_SHOT_PROTECTION_THRESHOLD
	if player.hp >= osp and player.hp - final_damage < 1.0:
		final_damage = maxf(0.0, player.hp - 1.0)
		player.iframe_remain = maxf(player.iframe_remain, ONE_SHOT_PROTECTION_IFRAME)
	player.hp -= final_damage
	damage_taken += final_damage


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
		var speed: float = stats.speed * SimObstacles.player_speed_mul(self)
		player.x += mx * speed * dt
		player.y += my * speed * dt
	var pad_x: float = float(bounds.get("borderInsetX", 0.0)) + player.radius
	var pad_y: float = float(bounds.get("borderInsetY", 0.0)) + player.radius
	player.x = clampf(player.x, pad_x, float(bounds.get("width", 2560.0)) - pad_x)
	player.y = clampf(player.y, pad_y, float(bounds.get("height", 2560.0)) - pad_y)


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
			SimObstacles.hit_aoe(self, px, py, radius, dmg)
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
			var any: bool = false
			for k: int in n:
				var idx: int = grid.hits[k]
				if not _can_hit(i, idx):
					continue
				_apply_player_hit(i, idx, false)
				any = true
			if any:
				pass
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
	if tether_anchor:
		enemies.root_remain[enemy] = maxf(enemies.root_remain[enemy], projectiles.root_duration[proj])
		enemies.root_duration[enemy] = maxf(enemies.root_duration[enemy], projectiles.root_duration[proj])
		enemies.tether_dps[enemy] = projectiles.tether_dps[proj]
		fx.emit(FxIds.TETHER_LATCH, enemies.x[enemy], enemies.y[enemy], 0xFF4422 if is_crit else 0xF79617, enemies.radius[enemy])
		if dmg > 0.0:
			SimEnemies.apply_damage(self, enemy, dmg)
		if is_crit:
			trigger_on_crit()
		return
	fx.emit(FxIds.HIT, projectiles.x[proj], projectiles.y[proj], 0xFF4422 if is_crit else 0xFFF4C8)
	SimEnemies.apply_damage(self, enemy, dmg)
	if is_crit:
		trigger_on_crit()


func _hit_player() -> void:
	if player.iframe_remain > 0.0:
		return
	for i: int in projectiles.alive.size():
		if projectiles.alive[i] == 0 or projectiles.team[i] != ProjectilePool.TEAM_ENEMY:
			continue
		if not SimCollision.aabb_overlap(projectiles.x[i], projectiles.y[i], projectiles.radius[i], player.x, player.y, player.radius):
			continue
		fx.emit(FxIds.HURT, projectiles.x[i], projectiles.y[i], 0xFF7A3A)
		damage_player(projectiles.damage[i])
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
		if not SimCollision.aabb_overlap(player.x, player.y, player.radius, enemies.x[idx], enemies.y[idx], enemies.radius[idx]):
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
