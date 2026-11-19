class_name PlayerState
extends RefCounted

var def_id: String = ""
var x: float = 0.0
var y: float = 0.0
var vx: float = 0.0
var vy: float = 0.0
var radius: float = 14.0
var hp: float = 100.0
var max_hp: float = 100.0
var speed: float = 280.0
var skill_cd: Dictionary = InputFrame.empty_cds()
var dash_remain: float = 0.0
var dash_vx: float = 0.0
var dash_vy: float = 0.0
var iframe_remain: float = 0.0
var slow_remain: float = 0.0
var slow_mul: float = 1.0
var root_remain: float = 0.0
var hurt_remain: float = 0.0
var hurt_cooldown: float = 0.0

# Overheat state
var heat: float = 0.0
var heat_decay_delay_remain: float = 0.0
var overheat_lockout_remain: float = 0.0
var heat_gain_mul: float = 1.0
var heat_decay_mul: float = 1.0
var critical_vent_count: int = 0
var backfire_count: int = 0

# Defensive / Affix / Buff state
var parry_remain: float = 0.0
var parry_shard_count: int = 3
var parry_shard_damage: float = 20.0
var parry_cooldown_refund: float = 1.8
var parry_triggered: bool = false

var bulwark_remain: float = 0.0
var bulwark_dr: float = 0.0
var bulwark_knockback_immune: bool = false
var bulwark_stored_damage: float = 0.0
var bulwark_counter_damage: float = 32.0
var bulwark_counter_range: float = 140.0
var bulwark_counter_arc_deg: float = 90.0

var burn_stacks: int = 0
var burn_remain: float = 0.0
var burn_dps: float = 0.0

var bell_armor_remain: float = 0.0


func reset_stage_states() -> void:
	vx = 0.0
	vy = 0.0
	dash_remain = 0.0
	dash_vx = 0.0
	dash_vy = 0.0
	iframe_remain = 0.0
	slow_remain = 0.0
	slow_mul = 1.0
	root_remain = 0.0
	hurt_remain = 0.0
	hurt_cooldown = 0.0
	heat = 0.0
	heat_decay_delay_remain = 0.0
	overheat_lockout_remain = 0.0
	parry_remain = 0.0
	parry_shard_count = 3
	parry_shard_damage = 20.0
	parry_cooldown_refund = 1.8
	parry_triggered = false
	bulwark_remain = 0.0
	bulwark_dr = 0.0
	bulwark_knockback_immune = false
	bulwark_stored_damage = 0.0
	bulwark_counter_damage = 32.0
	bulwark_counter_range = 140.0
	bulwark_counter_arc_deg = 90.0
	burn_stacks = 0
	burn_remain = 0.0
	burn_dps = 0.0
	bell_armor_remain = 0.0


func tick_heat(dt: float, overheat_cfg: Dictionary) -> void:
	overheat_lockout_remain = maxf(0.0, overheat_lockout_remain - dt)
	heat_decay_delay_remain = maxf(0.0, heat_decay_delay_remain - dt)
	if heat_decay_delay_remain <= 0.0 and heat > 0.0:
		var rate: float = float(overheat_cfg.get("decayRatePerSec", 0.42)) * heat_decay_mul
		heat = maxf(0.0, heat - rate * dt)


func add_primary_heat(amount: float, world: SimWorld) -> bool:
	var cfg: Dictionary = DictUtil.d(world.catalog.loop, "overheat")
	if not bool(cfg.get("enabled", true)) or amount <= 0.0:
		return false
	heat += amount * heat_gain_mul
	heat_decay_delay_remain = float(cfg.get("decayDelay", 0.65))
	if heat >= 1.0:
		heat = 0.0
		heat_decay_delay_remain = 0.0
		overheat_lockout_remain = float(cfg.get("backfireLockDuration", 1.2))
		backfire_count += 1
		var kb_radius: float = float(cfg.get("backfireKnockbackRadius", 95.0))
		var imp: float = float(cfg.get("backfireKnockbackImpulse", 450.0))
		world.fx.emit(FxIds.OVERHEAT_BACKFIRE, x, y, 0xFF5522, kb_radius)
		SimEnemies.knockback_radial(world, x, y, kb_radius, imp, 0.32)
		return true
	return false


func try_critical_vent(overheat_cfg: Dictionary, world_fx: FxPool, px: float, py: float) -> bool:
	if not bool(overheat_cfg.get("enabled", true)):
		return false
	var lo: float = float(overheat_cfg.get("sweetSpotMin", 0.80))
	var hi: float = float(overheat_cfg.get("sweetSpotMax", 0.99))
	if overheat_lockout_remain <= 0.0 and heat >= lo and heat < 1.0 and (hi >= 0.99 or heat <= hi):
		heat = 0.0
		heat_decay_delay_remain = 0.0
		critical_vent_count += 1
		if world_fx != null:
			world_fx.emit(FxIds.CRITICAL_VENT, px, py, 0xFFE070, 90.0)
		return true
	return false
