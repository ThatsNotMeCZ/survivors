class_name ZonePool
extends RefCounted

const ZONE_LINE: int = 0
const ZONE_STRIKE: int = 1
const ZONE_PRISM: int = 2
const ZONE_SOLAR_BEAM: int = 3
const ZONE_CENSURE_BELL: int = 4
const ZONE_SWAP_ANCHOR: int = 5
const ZONE_SMOKE_CLOUD: int = 6
const ZONE_FROZEN_PATCH: int = 7
const ZONE_HEX_SIGIL: int = 8

var cap: int = 24
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
var element: PackedStringArray = PackedStringArray()
var tick_accum: PackedFloat32Array = PackedFloat32Array()
var extra_a: PackedFloat32Array = PackedFloat32Array()
var extra_b: PackedFloat32Array = PackedFloat32Array()
var flag_bits: PackedInt32Array = PackedInt32Array()


static func create(pool_cap: int = 24) -> ZonePool:
	var pool: ZonePool = ZonePool.new()
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
	pool.element.resize(pool_cap)
	pool.tick_accum.resize(pool_cap)
	pool.extra_a.resize(pool_cap)
	pool.extra_b.resize(pool_cap)
	pool.flag_bits.resize(pool_cap)
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
	elem: String = "",
	is_sec_or_spec: bool = false,
) -> bool:
	var slot: int = _free()
	if slot < 0:
		return false
	_init_slot(slot, ZONE_LINE, px, py, dx, dy, line_len, line_width, 0.0, dur, dmg, slow, fodder, elem, 0.0, 0.0, 1 if is_sec_or_spec else 0)
	return true


func spawn_delayed_strike(
	px: float,
	py: float,
	rad: float,
	delay: float,
	dmg: float,
	is_sec_or_spec: bool = false,
	elem: String = "",
) -> bool:
	var slot: int = _free()
	if slot < 0:
		return false
	_init_slot(slot, ZONE_STRIKE, px, py, 0.0, 0.0, 0.0, 0.0, rad, delay, dmg, 1.0, false, elem, 0.0, 0.0, 1 if is_sec_or_spec else 0)
	return true


func spawn_prism(
	px: float,
	py: float,
	rad: float,
	dur: float,
	split_count: int = 3,
	split_spread_deg: float = 18.0,
	split_damage: float = 0.0,
	elem: String = "aether",
) -> bool:
	var slot: int = _free()
	if slot < 0:
		return false
	_init_slot(slot, ZONE_PRISM, px, py, 0.0, 0.0, 0.0, 0.0, rad, dur, split_damage, 1.0, false, elem, float(split_count), split_spread_deg, 0)
	return true


func spawn_solar_beam(
	px: float,
	py: float,
	dx: float,
	dy: float,
	beam_len: float,
	beam_width: float,
	dur: float,
	dps: float,
	tick_interval: float = 0.16,
	elem: String = "aether",
) -> bool:
	var slot: int = _free()
	if slot < 0:
		return false
	_init_slot(slot, ZONE_SOLAR_BEAM, px, py, dx, dy, beam_len, beam_width, 0.0, dur, dps, 1.0, false, elem, tick_interval, 0.0, 1)
	return true


func spawn_censure_bell(px: float, py: float, rad: float, dur: float = 0.45, elem: String = "aether") -> bool:
	var slot: int = _free()
	if slot < 0:
		return false
	_init_slot(slot, ZONE_CENSURE_BELL, px, py, 0.0, 0.0, 0.0, 0.0, rad, dur, 0.0, 1.0, false, elem, 0.0, 0.0, 0)
	return true


func spawn_swap_anchor(px: float, py: float, rad: float, dur: float = 0.45, elem: String = "aether") -> bool:
	var slot: int = _free()
	if slot < 0:
		return false
	_init_slot(slot, ZONE_SWAP_ANCHOR, px, py, 0.0, 0.0, 0.0, 0.0, rad, dur, 0.0, 1.0, false, elem, 0.0, 0.0, 0)
	return true


func spawn_smoke_cloud(px: float, py: float, rad: float, dur: float, proj_slow_mul: float) -> bool:
	var slot: int = _free()
	if slot < 0:
		return false
	_init_slot(slot, ZONE_SMOKE_CLOUD, px, py, 0.0, 0.0, 0.0, 0.0, rad, dur, 0.0, proj_slow_mul, false, "", 0.0, 0.0, 0)
	return true


func spawn_frozen_patch(px: float, py: float, rad: float, dur: float, dmg: float, freeze_dur: float) -> bool:
	var slot: int = _free()
	if slot < 0:
		return false
	_init_slot(slot, ZONE_FROZEN_PATCH, px, py, 0.0, 0.0, 0.0, 0.0, rad, dur, dmg, 1.2, false, "cold", freeze_dur, 0.0, 0)
	return true


func spawn_hex_sigil(px: float, py: float, rad: float, delay: float, dmg: float, slow: float, slow_dur: float) -> bool:
	var slot: int = _free()
	if slot < 0:
		return false
	_init_slot(slot, ZONE_HEX_SIGIL, px, py, 0.0, 0.0, 0.0, 0.0, rad, delay, dmg, slow, false, "aether", slow_dur, 0.0, 0)
	return true


func clear() -> void:
	for i: int in cap:
		alive[i] = 0
		element[i] = ""
		tick_accum[i] = 0.0
		extra_a[i] = 0.0
		extra_b[i] = 0.0
		flag_bits[i] = 0


func _init_slot(
	slot: int,
	z_kind: int,
	px: float,
	py: float,
	dx: float,
	dy: float,
	z_len: float,
	z_width: float,
	rad: float,
	dur: float,
	dmg: float,
	slow: float,
	fodder: bool,
	elem: String,
	ex_a: float,
	ex_b: float,
	fbits: int,
) -> void:
	alive[slot] = 1
	kind[slot] = z_kind
	x[slot] = px
	y[slot] = py
	dir_x[slot] = dx
	dir_y[slot] = dy
	length[slot] = z_len
	width[slot] = z_width
	radius[slot] = rad
	remain[slot] = dur
	duration[slot] = dur
	damage[slot] = dmg
	slow_mul[slot] = slow
	fodder_only[slot] = 1 if fodder else 0
	element[slot] = elem
	tick_accum[slot] = 0.0
	extra_a[slot] = ex_a
	extra_b[slot] = ex_b
	flag_bits[slot] = fbits


func _free() -> int:
	for i: int in cap:
		if alive[i] == 0:
			return i
	return -1
