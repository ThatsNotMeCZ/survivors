class_name DeviceMap
extends RefCounted

static var _prev_interact_key: bool = false


static func read_frame(player_id: int, aim_world: Vector2) -> InputFrame:
	var frame := InputFrame.empty()
	frame.player_id = player_id
	var move: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	frame.move_x = move.x
	frame.move_y = move.y
	frame.aim_x = aim_world.x
	frame.aim_y = aim_world.y
	frame.held[InputFrame.SLOT_PRIMARY] = Input.is_action_pressed("fire_primary")
	frame.held[InputFrame.SLOT_SECONDARY] = Input.is_action_pressed("fire_secondary")
	frame.held[InputFrame.SLOT_UTILITY] = Input.is_action_pressed("utility")
	frame.held[InputFrame.SLOT_SPECIAL] = Input.is_action_pressed("special")
	frame.pressed[InputFrame.SLOT_PRIMARY] = Input.is_action_just_pressed("fire_primary")
	frame.pressed[InputFrame.SLOT_SECONDARY] = Input.is_action_just_pressed("fire_secondary")
	frame.pressed[InputFrame.SLOT_UTILITY] = Input.is_action_just_pressed("utility")
	frame.pressed[InputFrame.SLOT_SPECIAL] = Input.is_action_just_pressed("special")
	if InputMap.has_action("interact"):
		frame.interact_held = Input.is_action_pressed("interact")
		frame.interact_pressed = Input.is_action_just_pressed("interact")
		_prev_interact_key = frame.interact_held
	else:
		var e_held: bool = Input.is_key_pressed(KEY_E)
		frame.interact_held = e_held
		frame.interact_pressed = e_held and not _prev_interact_key
		_prev_interact_key = e_held
	return frame
