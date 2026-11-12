class_name FxPool
extends RefCounted

var cap: int = FxIds.CAP
var count: int = 0
var kind: PackedByteArray = PackedByteArray()
var x: PackedFloat32Array = PackedFloat32Array()
var y: PackedFloat32Array = PackedFloat32Array()
var tint: PackedInt32Array = PackedInt32Array()
var radius: PackedFloat32Array = PackedFloat32Array()


static func create(pool_cap: int = FxIds.CAP) -> FxPool:
	var pool := FxPool.new()
	pool.cap = pool_cap
	pool.kind.resize(pool_cap)
	pool.x.resize(pool_cap)
	pool.y.resize(pool_cap)
	pool.tint.resize(pool_cap)
	pool.radius.resize(pool_cap)
	return pool


func emit(fx_kind: int, px: float, py: float, fx_tint: int, fx_radius: float = 0.0) -> void:
	if count >= cap:
		return
	var i: int = count
	kind[i] = fx_kind
	x[i] = px
	y[i] = py
	tint[i] = fx_tint
	radius[i] = fx_radius
	count += 1


func clear() -> void:
	count = 0
