class_name PlayerState
extends RefCounted

var def_id: String = ""
var x: float = 0.0
var y: float = 0.0
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
