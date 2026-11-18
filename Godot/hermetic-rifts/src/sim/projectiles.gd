class_name ProjectilePool
extends RefCounted

const TEAM_PLAYER: int = 0
const TEAM_ENEMY: int = 1
const FLAG_PIERCE: int = 1
const FLAG_FLYOVER: int = 2
const FLAG_TETHER: int = 4
const FLAG_IMPACT: int = 8
const FLAG_PRIMARY: int = 16
const FLAG_SECONDARY_OR_SPECIAL: int = 32
const FLAG_SPLIT: int = 64
const FLAG_PULL_HARPOON: int = 128

var alive: PackedByteArray = PackedByteArray()
var team: PackedByteArray = PackedByteArray()
var flags: PackedByteArray = PackedByteArray()
var x: PackedFloat32Array = PackedFloat32Array()
var y: PackedFloat32Array = PackedFloat32Array()
var vx: PackedFloat32Array = PackedFloat32Array()
var vy: PackedFloat32Array = PackedFloat32Array()
var life: PackedFloat32Array = PackedFloat32Array()
var radius: PackedFloat32Array = PackedFloat32Array()
var damage: PackedFloat32Array = PackedFloat32Array()
var dest_x: PackedFloat32Array = PackedFloat32Array()
var dest_y: PackedFloat32Array = PackedFloat32Array()
var impact_radius: PackedFloat32Array = PackedFloat32Array()
var root_duration: PackedFloat32Array = PackedFloat32Array()
var tether_dps: PackedFloat32Array = PackedFloat32Array()
var element: PackedStringArray = PackedStringArray()
var skill_tag: PackedStringArray = PackedStringArray()
var extra_float: PackedFloat32Array = PackedFloat32Array()
var extra_float2: PackedFloat32Array = PackedFloat32Array()
var extra_int: PackedInt32Array = PackedInt32Array()
var pierce_hit0: PackedInt32Array = PackedInt32Array()
var pierce_hit1: PackedInt32Array = PackedInt32Array()
var pierce_hit2: PackedInt32Array = PackedInt32Array()
var pierce_hit3: PackedInt32Array = PackedInt32Array()
var last_spawned: int = -1


static func create(size: int) -> ProjectilePool:
	var pool: ProjectilePool = ProjectilePool.new()
	pool.alive.resize(size)
	pool.team.resize(size)
	pool.flags.resize(size)
	pool.x.resize(size)
	pool.y.resize(size)
	pool.vx.resize(size)
	pool.vy.resize(size)
	pool.life.resize(size)
	pool.radius.resize(size)
	pool.damage.resize(size)
	pool.dest_x.resize(size)
	pool.dest_y.resize(size)
	pool.impact_radius.resize(size)
	pool.root_duration.resize(size)
	pool.tether_dps.resize(size)
	pool.element.resize(size)
	pool.skill_tag.resize(size)
	pool.extra_float.resize(size)
	pool.extra_float2.resize(size)
	pool.extra_int.resize(size)
	pool.pierce_hit0.resize(size)
	pool.pierce_hit1.resize(size)
	pool.pierce_hit2.resize(size)
	pool.pierce_hit3.resize(size)
	pool.last_spawned = -1
	return pool


func spawn(
	px: float,
	py: float,
	dir_x: float,
	dir_y: float,
	speed: float,
	lifetime: float,
	rad: float,
	dmg: float,
	proj_team: int,
	proj_flags: int = 0,
	destx: float = 0.0,
	desty: float = 0.0,
	impact_r: float = 0.0,
	root_dur: float = 0.0,
	tether: float = 0.0,
	has_dest: bool = false,
	p_element: String = "",
	p_skill_tag: String = "",
	p_extra: float = 0.0,
) -> bool:
	for i: int in alive.size():
		if alive[i] != 0:
			continue
		alive[i] = 1
		team[i] = proj_team
		flags[i] = proj_flags
		x[i] = px
		y[i] = py
		vx[i] = dir_x * speed
		vy[i] = dir_y * speed
		life[i] = lifetime
		radius[i] = rad
		damage[i] = dmg
		dest_x[i] = destx if has_dest else px
		dest_y[i] = desty if has_dest else py
		impact_radius[i] = impact_r
		root_duration[i] = root_dur
		tether_dps[i] = tether
		element[i] = p_element
		skill_tag[i] = p_skill_tag
		extra_float[i] = p_extra
		extra_float2[i] = 0.0
		extra_int[i] = 0
		pierce_hit0[i] = 0
		pierce_hit1[i] = 0
		pierce_hit2[i] = 0
		pierce_hit3[i] = 0
		last_spawned = i
		return true
	last_spawned = -1
	return false


func step(dt: float) -> void:
	for i: int in alive.size():
		if alive[i] == 0:
			continue
		x[i] += vx[i] * dt
		y[i] += vy[i] * dt
		life[i] -= dt
		if life[i] > 0.0:
			continue
		if (flags[i] & FLAG_IMPACT) != 0:
			continue
		alive[i] = 0


func has_hit(index: int, enemy_index: int) -> bool:
	if enemy_index < 0 or enemy_index >= 128:
		return false
	var bit: int = 1 << (enemy_index & 31)
	if enemy_index < 32:
		return (pierce_hit0[index] & bit) != 0
	if enemy_index < 64:
		return (pierce_hit1[index] & bit) != 0
	if enemy_index < 96:
		return (pierce_hit2[index] & bit) != 0
	return (pierce_hit3[index] & bit) != 0


func mark_hit(index: int, enemy_index: int) -> void:
	if enemy_index < 0 or enemy_index >= 128:
		return
	var bit: int = 1 << (enemy_index & 31)
	if enemy_index < 32:
		pierce_hit0[index] |= bit
	elif enemy_index < 64:
		pierce_hit1[index] |= bit
	elif enemy_index < 96:
		pierce_hit2[index] |= bit
	else:
		pierce_hit3[index] |= bit


func kill_at(index: int) -> void:
	alive[index] = 0


func clear() -> void:
	last_spawned = -1
	for i: int in alive.size():
		alive[i] = 0
