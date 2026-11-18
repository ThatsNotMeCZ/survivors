class_name SimObstacle
extends RefCounted

var id: int = 0
var type: StringName = &"pillar"
var x: float = 0.0
var y: float = 0.0
var radius: float = 0.0
var hp: float = 0.0
var max_hp: float = 0.0
var state: StringName = &"detonated"
var timer: float = 0.0
var biome_variant: String = ""
var sub_kind: String = ""
var charges: int = 0
var cycle_timer: float = 0.0
var trial_timer: float = 0.0
var collapse_timer: float = -1.0
var reaction_cooldown: float = 0.0
var progress: float = 0.0
var trial_remaining: int = 0
var hit_proj_ids: Array[int] = []
var erupt_hit_player: bool = false
var erupt_hit_enemies: Array[int] = []


func reset() -> void:
	type = &"pillar"
	x = 0.0
	y = 0.0
	radius = 0.0
	hp = 0.0
	max_hp = 0.0
	state = &"detonated"
	timer = 0.0
	biome_variant = ""
	sub_kind = ""
	charges = 0
	cycle_timer = 0.0
	trial_timer = 0.0
	collapse_timer = -1.0
	reaction_cooldown = 0.0
	progress = 0.0
	trial_remaining = 0
	hit_proj_ids.clear()
	erupt_hit_player = false
	erupt_hit_enemies.clear()
