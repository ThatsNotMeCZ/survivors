class_name GemPool
extends RefCounted

const MAX_LORE_DROPS: int = 8

var cap: int = 0
var alive: PackedByteArray = PackedByteArray()
var x: PackedFloat32Array = PackedFloat32Array()
var y: PackedFloat32Array = PackedFloat32Array()
var xp: PackedFloat32Array = PackedFloat32Array()


static func create(pool_cap: int) -> GemPool:
	var pool := GemPool.new()
	pool.cap = pool_cap
	pool.alive.resize(pool_cap)
	pool.x.resize(pool_cap)
	pool.y.resize(pool_cap)
	pool.xp.resize(pool_cap)
	return pool


func spawn_gem(px: float, py: float, value: float) -> bool:
	for i: int in cap:
		if alive[i] != 0:
			continue
		alive[i] = 1
		x[i] = px
		y[i] = py
		xp[i] = value
		return true
	return false


func clear() -> void:
	for i: int in cap:
		alive[i] = 0
