class_name GemPool
extends RefCounted

const MAX_LORE_DROPS: int = 8
const KIND_XP_SMALL: int = 0
const KIND_XP_MEDIUM: int = 1
const KIND_XP_CLUSTER: int = 2
const KIND_ESSENCE: int = 3

var cap: int = 0
var alive: PackedByteArray = PackedByteArray()
var kind: PackedByteArray = PackedByteArray()
var x: PackedFloat32Array = PackedFloat32Array()
var y: PackedFloat32Array = PackedFloat32Array()
var xp: PackedFloat32Array = PackedFloat32Array()


static func create(pool_cap: int) -> GemPool:
	var pool := GemPool.new()
	pool.cap = pool_cap
	pool.alive.resize(pool_cap)
	pool.kind.resize(pool_cap)
	pool.x.resize(pool_cap)
	pool.y.resize(pool_cap)
	pool.xp.resize(pool_cap)
	return pool


func spawn_typed(px: float, py: float, value: float, drop_kind: int) -> bool:
	for i: int in cap:
		if alive[i] != 0:
			continue
		alive[i] = 1
		kind[i] = clampi(drop_kind, 0, 255)
		x[i] = px
		y[i] = py
		xp[i] = value
		return true
	return false


func spawn_gem(px: float, py: float, value: float) -> bool:
	var drop_kind: int = KIND_XP_SMALL
	if value >= 12.0:
		drop_kind = KIND_XP_CLUSTER
	elif value >= 6.0:
		drop_kind = KIND_XP_MEDIUM
	return spawn_typed(px, py, value, drop_kind)


func clear() -> void:
	for i: int in cap:
		alive[i] = 0
		kind[i] = KIND_XP_SMALL
