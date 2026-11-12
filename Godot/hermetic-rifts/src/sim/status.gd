class_name SimStatus
extends RefCounted


static func apply_root(state: PlayerState, duration: float) -> void:
	if duration <= 0.0:
		return
	state.root_remain = maxf(state.root_remain, duration)


static func tick_root(state: PlayerState, dt: float) -> void:
	if state.root_remain > 0.0:
		state.root_remain = maxf(0.0, state.root_remain - dt)


static func apply_slow(state: PlayerState, mul: float, duration: float) -> void:
	if duration <= 0.0 or mul >= 1.0:
		return
	if state.slow_remain <= 0.0 or mul <= state.slow_mul:
		state.slow_mul = mul
		state.slow_remain = maxf(state.slow_remain, duration)


static func tick_slow(state: PlayerState, dt: float) -> void:
	if state.slow_remain <= 0.0:
		state.slow_mul = 1.0
		return
	state.slow_remain = maxf(0.0, state.slow_remain - dt)
	if state.slow_remain <= 0.0:
		state.slow_mul = 1.0
