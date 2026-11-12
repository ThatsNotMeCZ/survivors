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
