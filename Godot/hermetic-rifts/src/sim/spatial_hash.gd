class_name SpatialHash
extends RefCounted

var cell: float = 128.0
var buckets: Dictionary = {}
var pool: Array[Array] = []
var pool_used: int = 0
var hits: PackedInt32Array = PackedInt32Array()


static func create(cell_size: float, scratch_cap: int = 64) -> SpatialHash:
	var grid := SpatialHash.new()
	grid.cell = cell_size
	grid.hits.resize(maxi(scratch_cap, 8))
	return grid


func clear() -> void:
	buckets.clear()
	pool_used = 0


func insert(x: float, y: float, index: int) -> void:
	var cx: int = int(floor(x / cell))
	var cy: int = int(floor(y / cell))
	var key: int = cell_key(cx, cy)
	var bucket: Array
	if buckets.has(key):
		bucket = buckets[key]
	else:
		if pool_used < pool.size():
			bucket = pool[pool_used]
			bucket.clear()
		else:
			bucket = []
			pool.append(bucket)
		pool_used += 1
		buckets[key] = bucket
	bucket.append(index)


func query(x: float, y: float, radius: float) -> int:
	var min_cx: int = int(floor((x - radius) / cell))
	var max_cx: int = int(floor((x + radius) / cell))
	var min_cy: int = int(floor((y - radius) / cell))
	var max_cy: int = int(floor((y + radius) / cell))
	var n: int = 0
	for cy: int in range(min_cy, max_cy + 1):
		for cx: int in range(min_cx, max_cx + 1):
			var key: int = cell_key(cx, cy)
			if not buckets.has(key):
				continue
			var bucket: Array = buckets[key]
			for i: int in bucket.size():
				if n >= hits.size():
					hits.resize(n + 32)
				hits[n] = int(bucket[i])
				n += 1
	return n


static func cell_key(cx: int, cy: int) -> int:
	return ((cx + 4096) & 8191) | (((cy + 4096) & 8191) << 13)
