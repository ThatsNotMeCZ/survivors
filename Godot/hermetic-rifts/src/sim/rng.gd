class_name SimRng
extends RefCounted

var _a: int = 0


func _init(p_seed: int = 0) -> void:
	_a = _i32(p_seed)


func next() -> float:
	_a = _i32(_a + 0x6D2B79F5)
	var t: int = _imul32(_a ^ _usr(_a, 15), 1 | _a)
	t = _i32(t + _imul32(t ^ _usr(t, 7), 61 | t)) ^ t
	return float(_usr(t ^ _usr(t, 14), 0)) / 4294967296.0


static func hash_string(text: String) -> int:
	var h: int = 2166136261
	for i: int in text.length():
		h ^= text.unicode_at(i)
		h = _imul32(h, 16777619)
	return h & 0xFFFFFFFF


static func utc_ymd() -> String:
	return Time.get_datetime_string_from_system(true).substr(0, 10)


static func daily_seed(date: String = "") -> int:
	var day: String = date if date != "" else utc_ymd()
	return hash_string("daily:%s" % day)


static func random_run_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi() & 0xFFFFFFFF


static func format_seed_tag(seed_value: int) -> String:
	var hex: String = ("%x" % (seed_value & 0xFFFFFFFF)).to_upper()
	while hex.length() < 4:
		hex = "0" + hex
	return "#" + hex.substr(hex.length() - 4, 4)


static func cycle_numeral(cycle_index: int) -> String:
	var values: Array[Array] = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
	var rest: int = maxi(1, int(floor(float(cycle_index))) + 1)
	var out: String = ""
	for pair: Array in values:
		var value: int = int(pair[0])
		var glyph: String = String(pair[1])
		while rest >= value:
			out += glyph
			rest -= value
	return out


static func _i32(n: int) -> int:
	var u: int = n & 0xFFFFFFFF
	if u >= 0x80000000:
		return u - 0x100000000
	return u


static func _usr(n: int, bits: int) -> int:
	return (n & 0xFFFFFFFF) >> bits


static func _imul32(a: int, b: int) -> int:
	return _i32((a & 0xFFFFFFFF) * (b & 0xFFFFFFFF))
