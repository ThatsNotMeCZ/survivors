class_name DecoyState
extends RefCounted

var active: bool = false
var x: float = 0.0
var y: float = 0.0
var remain: float = 0.0


func spawn(px: float, py: float, duration: float) -> void:
	if duration <= 0.0:
		return
	active = true
	x = px
	y = py
	remain = duration


func reset() -> void:
	active = false
	remain = 0.0
	x = 0.0
	y = 0.0
