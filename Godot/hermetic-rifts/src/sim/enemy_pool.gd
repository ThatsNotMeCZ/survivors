class_name EnemyPool
extends RefCounted

const ROLE_FODDER: int = 0
const ROLE_ELITE: int = 1
const ROLE_BOSS: int = 2

const AI_STATE_DEFAULT: int = 0
const AI_STATE_WINDUP: int = 1
const AI_STATE_ACTIVE: int = 2
const AI_STATE_STUN: int = 3

const CHASE_ATTACK_DURATION: float = 0.35
const CHASE_ATTACK_COOLDOWN: float = 0.8
const CHASE_ATTACK_RANGE_PAD: float = 6.0
const CHASE_CONTACT_RANGE_PAD: float = 10.0
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

var affix: PackedStringArray = PackedStringArray()
var ai_state: PackedByteArray = PackedByteArray()
var state_timer: PackedFloat32Array = PackedFloat32Array()
var vel_x: PackedFloat32Array = PackedFloat32Array()
var vel_y: PackedFloat32Array = PackedFloat32Array()
var chain_cd: PackedFloat32Array = PackedFloat32Array()
var trail_cd: PackedFloat32Array = PackedFloat32Array()
var burn_remain: PackedFloat32Array = PackedFloat32Array()
var burn_dps: PackedFloat32Array = PackedFloat32Array()
var source_obstacle_id: PackedInt32Array = PackedInt32Array()
var is_specialist: PackedByteArray = PackedByteArray()


static func create(pool_cap: int) -> EnemyPool:
	var pool: EnemyPool = EnemyPool.new()
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
	pool.affix.resize(pool_cap)
	pool.ai_state.resize(pool_cap)
	pool.state_timer.resize(pool_cap)
	pool.vel_x.resize(pool_cap)
	pool.vel_y.resize(pool_cap)
	pool.chain_cd.resize(pool_cap)
	pool.trail_cd.resize(pool_cap)
	pool.burn_remain.resize(pool_cap)
	pool.burn_dps.resize(pool_cap)
	pool.source_obstacle_id.resize(pool_cap)
	pool.is_specialist.resize(pool_cap)
	pool.clear()
	return pool


func clear() -> void:
	for i: int in cap:
		alive[i] = 0
		role[i] = ROLE_FODDER
		facing[i] = 1
		slow_remain[i] = 0.0
		slow_mul[i] = 1.0
		shielder[i] = 0
		noxious[i] = 0
		corpse_remain[i] = 0.0
		root_remain[i] = 0.0
		root_duration[i] = 0.0
		tether_dps[i] = 0.0
		attack_remain[i] = 0.0
		attack_cd[i] = 0.0
		windup[i] = 0.0
		shield_hp[i] = 0.0
		shield_delay_remain[i] = 0.0
		hurt_remain[i] = 0.0
		def_id[i] = ""
		anim_name[i] = ""
		affix[i] = ""
		ai_state[i] = AI_STATE_DEFAULT
		state_timer[i] = 0.0
		vel_x[i] = 0.0
		vel_y[i] = 0.0
		chain_cd[i] = 0.0
		trail_cd[i] = 0.0
		burn_remain[i] = 0.0
		burn_dps[i] = 0.0
		source_obstacle_id[i] = -1
		is_specialist[i] = 0


func apply_slow(index: int, mul: float, duration: float) -> void:
	if index < 0 or index >= cap or alive[index] == 0:
		return
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


func apply_knockback(index: int, vx: float, vy: float) -> void:
	if index < 0 or index >= cap or alive[index] == 0:
		return
	vel_x[index] += vx
	vel_y[index] += vy


func apply_stun(index: int, dur: float) -> void:
	if index < 0 or index >= cap or alive[index] == 0 or dur <= 0.0:
		return
	root_remain[index] = maxf(root_remain[index], dur)
	if role[index] != ROLE_BOSS:
		ai_state[index] = AI_STATE_STUN
		state_timer[index] = maxf(state_timer[index], dur)
		windup[index] = 0.0


func apply_burn(index: int, dps: float, dur: float) -> void:
	if index < 0 or index >= cap or alive[index] == 0 or dur <= 0.0 or dps <= 0.0:
		return
	burn_dps[index] = maxf(burn_dps[index], dps)
	burn_remain[index] = maxf(burn_remain[index], dur)
