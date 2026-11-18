class_name ResolvedStats
extends RefCounted

var speed: float = 0.0
var max_hp: float = 0.0
var radius: float = 14.0
var damage_mul: float = 1.0
var cooldown_mul: float = 1.0
var crit_chance: float = 0.05
var crit_mul: float = 2.0
var armor: float = 0.0
var hazard_resist: float = 0.0
var hp_regen: float = 0.0
var pickup_radius_mul: float = 1.0
var xp_mul: float = 1.0
var aoe_radius_mul: float = 1.0
var proj_speed_mul: float = 1.0
var control_duration_mul: float = 1.0
var elite_damage_mul: float = 1.0


func effective_armor(armor_debuff: float = 0.0, bell_armor_bonus: float = 0.0) -> float:
	return clampf(armor + armor_debuff + bell_armor_bonus, -0.5, 0.85)
