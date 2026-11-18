class_name InputFrame
extends RefCounted

const SLOT_PRIMARY: StringName = &"primary"
const SLOT_SECONDARY: StringName = &"secondary"
const SLOT_UTILITY: StringName = &"utility"
const SLOT_SPECIAL: StringName = &"special"
const SLOTS: Array[StringName] = [&"primary", &"secondary", &"utility", &"special"]

var player_id: int = 0
var move_x: float = 0.0
var move_y: float = 0.0
var aim_x: float = 0.0
var aim_y: float = 0.0
var held: Dictionary = empty_slots()
var pressed: Dictionary = empty_slots()
var interact_held: bool = false
var interact_pressed: bool = false


static func empty_slots() -> Dictionary:
	return {
		SLOT_PRIMARY: false,
		SLOT_SECONDARY: false,
		SLOT_UTILITY: false,
		SLOT_SPECIAL: false,
	}


static func empty_cds() -> Dictionary:
	return {
		SLOT_PRIMARY: 0.0,
		SLOT_SECONDARY: 0.0,
		SLOT_UTILITY: 0.0,
		SLOT_SPECIAL: 0.0,
	}


static func empty() -> InputFrame:
	return InputFrame.new()
