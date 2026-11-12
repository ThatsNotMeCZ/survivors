class_name ZonePool
extends RefCounted

const ZONE_LINE: int = 0
const ZONE_STRIKE: int = 1

var cap: int = 8
var alive: PackedByteArray = PackedByteArray()
var kind: PackedByteArray = PackedByteArray()
var x: PackedFloat32Array = PackedFloat32Array()
var y: PackedFloat32Array = PackedFloat32Array()
var dir_x: PackedFloat32Array = PackedFloat32Array()
var dir_y: PackedFloat32Array = PackedFloat32Array()
var length: PackedFloat32Array = PackedFloat32Array()
var width: PackedFloat32Array = PackedFloat32Array()
var radius: PackedFloat32Array = PackedFloat32Array()
var remain: PackedFloat32Array = PackedFloat32Array()
var duration: PackedFloat32Array = PackedFloat32Array()
var damage: PackedFloat32Array = PackedFloat32Array()
var slow_mul: PackedFloat32Array = PackedFloat32Array()
var fodder_only: PackedByteArray = PackedByteArray()


static func create(pool_cap: int = 8) -> ZonePool:
	var pool := ZonePool.new()
	pool.cap = pool_cap
	pool.alive.resize(pool_cap)
	pool.kind.resize(pool_cap)
	pool.x.resize(pool_cap)
	pool.y.resize(pool_cap)
	pool.dir_x.resize(pool_cap)
	pool.dir_y.resize(pool_cap)
	pool.length.resize(pool_cap)
	pool.width.resize(pool_cap)
	pool.radius.resize(pool_cap)
	pool.remain.resize(pool_cap)
	pool.duration.resize(pool_cap)
	pool.damage.resize(pool_cap)
	pool.slow_mul.resize(pool_cap)
	pool.fodder_only.resize(pool_cap)
	return pool


func spawn_slow_line(
	px: float,
	py: float,
	dx: float,
	dy: float,
	line_len: float,
	line_width: float,
	dur: float,
	slow: float,
	dmg: float,
	fodder: bool,
) -> bool:
	var slot: int = _free()
	if slot < 0:
		return false
	alive[slot] = 1
	kind[slot] = ZONE_LINE
	x[slot] = px
	y[slot] = py
	dir_x[slot] = dx
	dir_y[slot] = dy
	length[slot] = line_len
	width[slot] = line_width
	radius[slot] = 0.0
	remain[slot] = dur
	duration[slot] = dur
	damage[slot] = dmg
	slow_mul[slot] = slow
	fodder_only[slot] = 1 if fodder else 0
	return true


func spawn_delayed_strike(px: float, py: float, rad: float, delay: float, dmg: float) -> bool:
	var slot: int = _free()
	if slot < 0:
		return false
	alive[slot] = 1
	kind[slot] = ZONE_STRIKE
	x[slot] = px
	y[slot] = py
	dir_x[slot] = 0.0
	dir_y[slot] = 0.0
	length[slot] = 0.0
	width[slot] = 0.0
	radius[slot] = rad
	remain[slot] = delay
	duration[slot] = delay
	damage[slot] = dmg
	slow_mul[slot] = 1.0
	fodder_only[slot] = 0
	return true


func clear() -> void:
	for i: int in cap:
		alive[i] = 0


func _free() -> int:
	for i: int in cap:
		if alive[i] == 0:
			return i
	return -1
