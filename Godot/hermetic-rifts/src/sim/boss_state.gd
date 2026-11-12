class_name BossState
extends RefCounted

const MAX_ATTACKS: int = 8

var enemy_index: int = -1
var cooldowns: Array[float] = []
var active_attack: int = -1
var phase: StringName = &"none"
var elapsed: float = 0.0
var duration: float = 0.0
var aim_x: float = 0.0
var aim_y: float = 0.0
var laser_end_x: float = 0.0
var laser_end_y: float = 0.0
var trail_timer: float = 0.0
var enraged: bool = false
var counts: Dictionary = {
	"bolt": 0,
	"fan": 0,
	"meteor": 0,
	"cone": 0,
	"prison": 0,
	"pulse": 0,
	"laser": 0,
	"summon": 0,
}


func _init() -> void:
	cooldowns.resize(MAX_ATTACKS)
	for i: int in MAX_ATTACKS:
		cooldowns[i] = 0.0


func reset() -> void:
	enemy_index = -1
	cooldowns.resize(MAX_ATTACKS)
	for i: int in MAX_ATTACKS:
		cooldowns[i] = 0.0
	active_attack = -1
	phase = &"none"
	elapsed = 0.0
	duration = 0.0
	aim_x = 0.0
	aim_y = 0.0
	laser_end_x = 0.0
	laser_end_y = 0.0
	trail_timer = 0.0
	enraged = false
