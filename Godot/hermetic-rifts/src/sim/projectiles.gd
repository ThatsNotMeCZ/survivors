class_name ProjectilePool
extends RefCounted

const TEAM_PLAYER: int = 0
const TEAM_ENEMY: int = 1
const FLAG_PIERCE: int = 1
const FLAG_FLYOVER: int = 2
const FLAG_TETHER: int = 4
const FLAG_IMPACT: int = 8

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
var pierce_hit0: PackedInt32Array = PackedInt32Array()
var pierce_hit1: PackedInt32Array = PackedInt32Array()


static func create(size: int) -> ProjectilePool:
	var pool := ProjectilePool.new()
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
	pool.pierce_hit0.resize(size)
	pool.pierce_hit1.resize(size)
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
		pierce_hit0[i] = 0
		pierce_hit1[i] = 0
		return true
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
	var bit: int = 1 << (enemy_index & 31)
	if enemy_index < 32:
		return (pierce_hit0[index] & bit) != 0
	return (pierce_hit1[index] & bit) != 0


func mark_hit(index: int, enemy_index: int) -> void:
	var bit: int = 1 << (enemy_index & 31)
	if enemy_index < 32:
		pierce_hit0[index] |= bit
	else:
		pierce_hit1[index] |= bit


func kill_at(index: int) -> void:
	alive[index] = 0


func clear() -> void:
	for i: int in alive.size():
		alive[i] = 0
