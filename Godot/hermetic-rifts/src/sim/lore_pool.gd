class_name LorePool
extends RefCounted

var cap: int = GemPool.MAX_LORE_DROPS
var alive: PackedByteArray = PackedByteArray()
var x: PackedFloat32Array = PackedFloat32Array()
var y: PackedFloat32Array = PackedFloat32Array()
var entity_id: PackedStringArray = PackedStringArray()


static func create(pool_cap: int = GemPool.MAX_LORE_DROPS) -> LorePool:
	var pool := LorePool.new()
	pool.cap = pool_cap
	pool.alive.resize(pool_cap)
	pool.x.resize(pool_cap)
	pool.y.resize(pool_cap)
	pool.entity_id.resize(pool_cap)
	return pool


func has_active(id: String) -> bool:
	for i: int in cap:
		if alive[i] != 0 and entity_id[i] == id:
			return true
	return false


func spawn_drop(px: float, py: float, id: String) -> bool:
	if has_active(id):
		return false
	for i: int in cap:
		if alive[i] != 0:
			continue
		alive[i] = 1
		x[i] = px
		y[i] = py
		entity_id[i] = id
		return true
	return false


func clear() -> void:
	for i: int in cap:
		alive[i] = 0
		entity_id[i] = ""
