class_name BossHazardPool
extends RefCounted

const HAZ_METEOR: int = 0
const HAZ_POOL: int = 1
const HAZ_PRISON: int = 2
const HAZ_CONE: int = 3
const HAZ_PULSE: int = 4
const HAZ_RING: int = 5
const HAZ_SPIRE_TETHER: int = 6

const STYLE_LAVA: int = 0
const STYLE_FROST: int = 1
const STYLE_AETHER: int = 2
const CAP_DEFAULT: int = 32

var cap: int = CAP_DEFAULT
var alive: PackedByteArray = PackedByteArray()
var kind: PackedByteArray = PackedByteArray()
var style: PackedByteArray = PackedByteArray()
var state: PackedByteArray = PackedByteArray()
var x: PackedFloat32Array = PackedFloat32Array()
var y: PackedFloat32Array = PackedFloat32Array()
var dir_x: PackedFloat32Array = PackedFloat32Array()
var dir_y: PackedFloat32Array = PackedFloat32Array()
var radius: PackedFloat32Array = PackedFloat32Array()
var angle: PackedFloat32Array = PackedFloat32Array()
var elapsed: PackedFloat32Array = PackedFloat32Array()
var duration: PackedFloat32Array = PackedFloat32Array()
var damage: PackedFloat32Array = PackedFloat32Array()
var slow_mul: PackedFloat32Array = PackedFloat32Array()
var slow_duration: PackedFloat32Array = PackedFloat32Array()
var root_duration: PackedFloat32Array = PackedFloat32Array()
var pool_duration: PackedFloat32Array = PackedFloat32Array()
var pool_radius: PackedFloat32Array = PackedFloat32Array()
var pool_dps: PackedFloat32Array = PackedFloat32Array()
var pool_slow: PackedFloat32Array = PackedFloat32Array()


static func create(pool_cap: int = CAP_DEFAULT) -> BossHazardPool:
	var pool: BossHazardPool = BossHazardPool.new()
	pool.cap = pool_cap
	pool.alive.resize(pool_cap)
	pool.kind.resize(pool_cap)
	pool.style.resize(pool_cap)
	pool.state.resize(pool_cap)
	pool.x.resize(pool_cap)
	pool.y.resize(pool_cap)
	pool.dir_x.resize(pool_cap)
	pool.dir_y.resize(pool_cap)
	pool.radius.resize(pool_cap)
	pool.angle.resize(pool_cap)
	pool.elapsed.resize(pool_cap)
	pool.duration.resize(pool_cap)
	pool.damage.resize(pool_cap)
	pool.slow_mul.resize(pool_cap)
	pool.slow_duration.resize(pool_cap)
	pool.root_duration.resize(pool_cap)
	pool.pool_duration.resize(pool_cap)
	pool.pool_radius.resize(pool_cap)
	pool.pool_dps.resize(pool_cap)
	pool.pool_slow.resize(pool_cap)
	return pool


func clear() -> void:
	for i: int in cap:
		alive[i] = 0


func alloc() -> int:
	for i: int in cap:
		if alive[i] == 0:
			return i
	return -1


func spawn_meteor(
	px: float,
	py: float,
	rad: float,
	delay: float,
	dmg: float,
	fx_style: int,
	p_dur: float = 0.0,
	p_rad: float = 0.0,
	p_dps: float = 0.0,
	p_slow: float = 1.0,
) -> int:
	var s: int = alloc()
	if s < 0:
		return -1
	alive[s] = 1
	kind[s] = HAZ_METEOR
	style[s] = fx_style
	state[s] = 0
	x[s] = px
	y[s] = py
	dir_x[s] = 1.0
	dir_y[s] = 0.0
	radius[s] = rad
	angle[s] = 0.0
	elapsed[s] = 0.0
	duration[s] = delay
	damage[s] = dmg
	slow_mul[s] = 1.0
	slow_duration[s] = 0.0
	root_duration[s] = 0.0
	pool_duration[s] = p_dur
	pool_radius[s] = p_rad if p_rad > 0.0 else rad
	pool_dps[s] = p_dps
	pool_slow[s] = p_slow
	return s


func spawn_pool(px: float, py: float, rad: float, dur: float, dps: float, slow: float, fx_style: int) -> int:
	var s: int = alloc()
	if s < 0:
		return -1
	alive[s] = 1
	kind[s] = HAZ_POOL
	style[s] = fx_style
	state[s] = 0
	x[s] = px
	y[s] = py
	dir_x[s] = 1.0
	dir_y[s] = 0.0
	radius[s] = rad
	angle[s] = 0.0
	elapsed[s] = 0.0
	duration[s] = dur
	damage[s] = dps
	slow_mul[s] = slow
	slow_duration[s] = 0.25
	root_duration[s] = 0.0
	pool_duration[s] = 0.0
	pool_radius[s] = 0.0
	pool_dps[s] = 0.0
	pool_slow[s] = 1.0
	return s


func spawn_prison(px: float, py: float, rad: float, delay: float, dmg: float, root_dur: float) -> int:
	var s: int = alloc()
	if s < 0:
		return -1
	alive[s] = 1
	kind[s] = HAZ_PRISON
	style[s] = STYLE_FROST
	state[s] = 0
	x[s] = px
	y[s] = py
	dir_x[s] = 1.0
	dir_y[s] = 0.0
	radius[s] = rad
	angle[s] = 0.0
	elapsed[s] = 0.0
	duration[s] = delay
	damage[s] = dmg
	slow_mul[s] = 1.0
	slow_duration[s] = 0.0
	root_duration[s] = root_dur
	pool_duration[s] = 0.0
	pool_radius[s] = 0.0
	pool_dps[s] = 0.0
	pool_slow[s] = 1.0
	return s


func spawn_cone(
	px: float,
	py: float,
	dx: float,
	dy: float,
	range_v: float,
	angle_rad: float,
	windup: float,
	lingering: float,
	dmg: float,
	slow: float,
	slow_dur: float,
) -> int:
	var s: int = alloc()
	if s < 0:
		return -1
	alive[s] = 1
	kind[s] = HAZ_CONE
	style[s] = STYLE_FROST
	state[s] = 0
	x[s] = px
	y[s] = py
	dir_x[s] = dx
	dir_y[s] = dy
	radius[s] = range_v
	angle[s] = angle_rad
	elapsed[s] = 0.0
	duration[s] = windup
	damage[s] = dmg
	slow_mul[s] = slow
	slow_duration[s] = slow_dur
	root_duration[s] = 0.0
	pool_duration[s] = lingering
	pool_radius[s] = 0.0
	pool_dps[s] = 0.0
	pool_slow[s] = 1.0
	return s


func spawn_pulse(px: float, py: float, rad: float, windup: float, dmg: float, slow: float, slow_dur: float) -> int:
	var s: int = alloc()
	if s < 0:
		return -1
	alive[s] = 1
	kind[s] = HAZ_PULSE
	style[s] = STYLE_AETHER
	state[s] = 0
	x[s] = px
	y[s] = py
	dir_x[s] = 1.0
	dir_y[s] = 0.0
	radius[s] = rad
	angle[s] = 0.0
	elapsed[s] = 0.0
	duration[s] = windup
	damage[s] = dmg
	slow_mul[s] = slow
	slow_duration[s] = slow_dur
	root_duration[s] = 0.0
	pool_duration[s] = 0.45
	pool_radius[s] = 0.0
	pool_dps[s] = 0.0
	pool_slow[s] = 1.0
	return s


func spawn_ring(
	px: float,
	py: float,
	start_rad: float,
	max_rad: float,
	thickness: float,
	expand_speed: float,
	dmg: float,
	fx_style: int = STYLE_AETHER,
) -> int:
	var s: int = alloc()
	if s < 0:
		return -1
	var spd: float = maxf(1.0, expand_speed)
	alive[s] = 1
	kind[s] = HAZ_RING
	style[s] = fx_style
	state[s] = 0
	x[s] = px
	y[s] = py
	dir_x[s] = 1.0
	dir_y[s] = 0.0
	radius[s] = start_rad
	angle[s] = thickness
	elapsed[s] = 0.0
	duration[s] = maxf(0.1, (max_rad - start_rad) / spd)
	damage[s] = dmg
	slow_mul[s] = 1.0
	slow_duration[s] = 0.0
	root_duration[s] = 0.0
	pool_duration[s] = 0.0
	pool_radius[s] = max_rad
	pool_dps[s] = spd
	pool_slow[s] = 1.0
	return s


static func point_in_cone(
	px: float,
	py: float,
	pr: float,
	ox: float,
	oy: float,
	aim_dx: float,
	aim_dy: float,
	range_v: float,
	full_angle: float,
) -> bool:
	var dx: float = px - ox
	var dy: float = py - oy
	var dist: float = sqrt(dx * dx + dy * dy)
	if dist > range_v + pr:
		return false
	if dist <= pr + 12.0:
		return true
	var cos_half: float = cos(full_angle * 0.5)
	var dot: float = (dx * aim_dx + dy * aim_dy) / dist
	return dot >= cos_half
