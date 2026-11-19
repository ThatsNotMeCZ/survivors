class_name SimSeparation
extends RefCounted

const ITERATIONS: int = 2
const PLAYER_SHARE: float = 0.35
const ENEMY_SHARE: float = 0.65


static func resolve(world: SimWorld) -> void:
	for _iter: int in ITERATIONS:
		_rehash(world)
		_enemy_pairs(world)
		if world.player.dash_remain <= 0.0:
			_player_enemies(world)
		SimObstacles.resolve_bodies(world)
		_clamp_actors(world)


static func _rehash(world: SimWorld) -> void:
	world.grid.clear()
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0:
			continue
		world.grid.insert(world.enemies.x[i], world.enemies.y[i], i)


static func _enemy_pairs(world: SimWorld) -> void:
	var enemies: EnemyPool = world.enemies
	for i: int in enemies.cap:
		if enemies.alive[i] == 0:
			continue
		var n: int = world.grid.query(enemies.x[i], enemies.y[i], enemies.radius[i] + 48.0)
		for k: int in n:
			var j: int = world.grid.hits[k]
			if j <= i or enemies.alive[j] == 0:
				continue
			if enemies.corpse_remain[i] > 0.0 or enemies.corpse_remain[j] > 0.0:
				continue
			if not SimCollision.aabb_overlap(enemies.x[i], enemies.y[i], enemies.radius[i], enemies.x[j], enemies.y[j], enemies.radius[j]):
				continue
			var share_i: float = 0.5
			var share_j: float = 0.5
			var boss_i: bool = enemies.role[i] == EnemyPool.ROLE_BOSS
			var boss_j: bool = enemies.role[j] == EnemyPool.ROLE_BOSS
			if boss_i and not boss_j:
				share_i = 0.0
				share_j = 1.0
			elif boss_j and not boss_i:
				share_i = 1.0
				share_j = 0.0
			var split: Vector4 = _separate(
				enemies.x[i], enemies.y[i], enemies.radius[i],
				enemies.x[j], enemies.y[j], enemies.radius[j],
				share_i, share_j,
			)
			enemies.x[i] = split.x
			enemies.y[i] = split.y
			enemies.x[j] = split.z
			enemies.y[j] = split.w


static func _player_enemies(world: SimWorld) -> void:
	var n: int = world.grid.query(world.player.x, world.player.y, world.player.radius + 48.0)
	for k: int in n:
		var i: int = world.grid.hits[k]
		if world.enemies.alive[i] == 0 or world.enemies.corpse_remain[i] > 0.0:
			continue
		if SimEnemies.is_chase(world, i):
			_hold_melee(world, i)
			continue
		if not SimCollision.aabb_overlap(world.player.x, world.player.y, world.player.radius, world.enemies.x[i], world.enemies.y[i], world.enemies.radius[i]):
			continue
		var p_share: float = 1.0 if (world.enemies.role[i] == EnemyPool.ROLE_BOSS and world.boss.emerge_remain > 0.0) else PLAYER_SHARE
		var e_share: float = 1.0 - p_share
		var split: Vector4 = _separate(
			world.player.x, world.player.y, world.player.radius,
			world.enemies.x[i], world.enemies.y[i], world.enemies.radius[i],
			p_share, e_share,
		)
		world.player.x = split.x
		world.player.y = split.y
		world.enemies.x[i] = split.z
		world.enemies.y[i] = split.w


static func _hold_melee(world: SimWorld, index: int) -> void:
	var enemies: EnemyPool = world.enemies
	if enemies.root_remain[index] > 0.0:
		return
	var hold: float = SimEnemies.chase_attack_range(enemies.radius[index], world.player.radius)
	var dx: float = world.player.x - enemies.x[index]
	var dy: float = world.player.y - enemies.y[index]
	var dist: float = sqrt(dx * dx + dy * dy)
	if dist >= hold:
		return
	if dist <= 0.001:
		enemies.x[index] = world.player.x - hold
		return
	var nx: float = dx / dist
	var ny: float = dy / dist
	enemies.x[index] = world.player.x - nx * hold
	enemies.y[index] = world.player.y - ny * hold


static func _clamp_actors(world: SimWorld) -> void:
	if world.arena_shape == "circle":
		var p_max: float = maxf(0.0, world.arena_radius - world.player.radius)
		var clamped_p: Vector2 = SimCollision.clamp_to_circle(world.player.x, world.player.y, p_max)
		world.player.x = clamped_p.x
		world.player.y = clamped_p.y
		for i: int in world.enemies.cap:
			if world.enemies.alive[i] == 0:
				continue
			var e_max: float = maxf(0.0, world.arena_radius - world.enemies.radius[i] - 4.0)
			var clamped_e: Vector2 = SimCollision.clamp_to_circle(world.enemies.x[i], world.enemies.y[i], e_max)
			world.enemies.x[i] = clamped_e.x
			world.enemies.y[i] = clamped_e.y
		return
	var bounds: Dictionary = world.catalog.world
	var inset_x: float = float(bounds.get("borderInsetX", 0.0))
	var inset_y: float = float(bounds.get("borderInsetY", 0.0))
	var width: float = float(bounds.get("width", 6000.0))
	var height: float = float(bounds.get("height", 6000.0))
	var ppx: float = inset_x + world.player.radius
	var ppy: float = inset_y + world.player.radius
	world.player.x = clampf(world.player.x, ppx, width - ppx)
	world.player.y = clampf(world.player.y, ppy, height - ppy)
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0:
			continue
		var pad_x: float = inset_x + world.enemies.radius[i] + 8.0
		var pad_y: float = inset_y + world.enemies.radius[i] + 8.0
		world.enemies.x[i] = clampf(world.enemies.x[i], pad_x, width - pad_x)
		world.enemies.y[i] = clampf(world.enemies.y[i], pad_y, height - pad_y)


static func _separate(
	ax: float, ay: float, ar: float,
	bx: float, by: float, br: float,
	weight_a: float, weight_b: float,
) -> Vector4:
	var overlap_x: float = ar + br - absf(ax - bx)
	var overlap_y: float = ar + br - absf(ay - by)
	if overlap_x <= 0.0 or overlap_y <= 0.0:
		return Vector4(ax, ay, bx, by)
	if overlap_x < overlap_y:
		var sign_x: float = 1.0 if ax >= bx else -1.0
		return Vector4(ax + overlap_x * weight_a * sign_x, ay, bx - overlap_x * weight_b * sign_x, by)
	var sign_y: float = 1.0 if ay >= by else -1.0
	return Vector4(ax, ay + overlap_y * weight_a * sign_y, bx, by - overlap_y * weight_b * sign_y)
