class_name EnemyPool
extends RefCounted

const ROLE_FODDER: int = 0
const ROLE_ELITE: int = 1
const ROLE_BOSS: int = 2
const CHASE_ATTACK_DURATION: float = 0.35
const CHASE_ATTACK_COOLDOWN: float = 0.8
const CHASE_ATTACK_RANGE_PAD: float = 6.0
const PILLAR_COVER_EXTRA_RADIUS: float = 8.0

var cap: int = 0
var alive: PackedByteArray = PackedByteArray()
var role: PackedByteArray = PackedByteArray()
var x: PackedFloat32Array = PackedFloat32Array()
var y: PackedFloat32Array = PackedFloat32Array()
var facing: PackedByteArray = PackedByteArray()
var radius: PackedFloat32Array = PackedFloat32Array()
var hp: PackedFloat32Array = PackedFloat32Array()
var max_hp: PackedFloat32Array = PackedFloat32Array()
var speed: PackedFloat32Array = PackedFloat32Array()
var contact_dps: PackedFloat32Array = PackedFloat32Array()
var xp: PackedFloat32Array = PackedFloat32Array()
var credits: PackedFloat32Array = PackedFloat32Array()
var attack_cd: PackedFloat32Array = PackedFloat32Array()
var windup: PackedFloat32Array = PackedFloat32Array()
var aim_x: PackedFloat32Array = PackedFloat32Array()
var aim_y: PackedFloat32Array = PackedFloat32Array()
var slow_remain: PackedFloat32Array = PackedFloat32Array()
var slow_mul: PackedFloat32Array = PackedFloat32Array()
var shielder: PackedByteArray = PackedByteArray()
var noxious: PackedByteArray = PackedByteArray()
var corpse_remain: PackedFloat32Array = PackedFloat32Array()
var root_remain: PackedFloat32Array = PackedFloat32Array()
var root_duration: PackedFloat32Array = PackedFloat32Array()
var tether_dps: PackedFloat32Array = PackedFloat32Array()
var attack_remain: PackedFloat32Array = PackedFloat32Array()
var shield_hp: PackedFloat32Array = PackedFloat32Array()
var shield_delay_remain: PackedFloat32Array = PackedFloat32Array()
var hurt_remain: PackedFloat32Array = PackedFloat32Array()
var def_id: PackedStringArray = PackedStringArray()
var anim_name: PackedStringArray = PackedStringArray()


static func create(pool_cap: int) -> EnemyPool:
	var pool := EnemyPool.new()
	pool.cap = pool_cap
	pool.alive.resize(pool_cap)
	pool.role.resize(pool_cap)
	pool.x.resize(pool_cap)
	pool.y.resize(pool_cap)
	pool.facing.resize(pool_cap)
	pool.radius.resize(pool_cap)
	pool.hp.resize(pool_cap)
	pool.max_hp.resize(pool_cap)
	pool.speed.resize(pool_cap)
	pool.contact_dps.resize(pool_cap)
	pool.xp.resize(pool_cap)
	pool.credits.resize(pool_cap)
	pool.attack_cd.resize(pool_cap)
	pool.windup.resize(pool_cap)
	pool.aim_x.resize(pool_cap)
	pool.aim_y.resize(pool_cap)
	pool.slow_remain.resize(pool_cap)
	pool.slow_mul.resize(pool_cap)
	pool.shielder.resize(pool_cap)
	pool.noxious.resize(pool_cap)
	pool.corpse_remain.resize(pool_cap)
	pool.root_remain.resize(pool_cap)
	pool.root_duration.resize(pool_cap)
	pool.tether_dps.resize(pool_cap)
	pool.attack_remain.resize(pool_cap)
	pool.shield_hp.resize(pool_cap)
	pool.shield_delay_remain.resize(pool_cap)
	pool.hurt_remain.resize(pool_cap)
	pool.def_id.resize(pool_cap)
	pool.anim_name.resize(pool_cap)
	for i: int in pool_cap:
		pool.facing[i] = 1
		pool.slow_mul[i] = 1.0
	return pool


func apply_slow(index: int, mul: float, duration: float) -> void:
	if duration <= 0.0 or mul >= 1.0:
		return
	if slow_remain[index] <= 0.0 or mul <= slow_mul[index]:
		slow_mul[index] = mul
		slow_remain[index] = maxf(slow_remain[index], duration)


func tick_slow(index: int, dt: float) -> void:
	if slow_remain[index] <= 0.0:
		slow_mul[index] = 1.0
		return
	slow_remain[index] = maxf(0.0, slow_remain[index] - dt)
	if slow_remain[index] <= 0.0:
		slow_mul[index] = 1.0
