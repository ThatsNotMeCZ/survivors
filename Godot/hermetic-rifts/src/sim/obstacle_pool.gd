class_name ObstaclePool
extends RefCounted

var cap: int = 0
var alive: PackedByteArray = PackedByteArray()
var items: Array[SimObstacle] = []
var grid: SpatialHash
var scratch: PackedInt32Array = PackedInt32Array()
var next_id: int = 1


static func obstacle_cap(counts: Dictionary, dynamic_hazards: int = 0) -> int:
	return int(counts.get("pillar", 0)) + int(counts.get("hazard", 0)) + int(counts.get("volatile", 0)) + dynamic_hazards


static func create(pool_cap: int, cell: float) -> ObstaclePool:
	var pool := ObstaclePool.new()
	pool.cap = pool_cap
	pool.alive.resize(pool_cap)
	pool.scratch.resize(maxi(pool_cap, 8))
	pool.grid = SpatialHash.create(cell, pool_cap)
	for _i: int in pool_cap:
		pool.items.append(SimObstacle.new())
	return pool


func clear() -> void:
	for i: int in cap:
		alive[i] = 0
	grid.clear()


func count_type(kind: StringName = &"") -> int:
	var n: int = 0
	for i: int in cap:
		if alive[i] == 0:
			continue
		if kind != &"" and items[i].type != kind:
			continue
		n += 1
	return n
