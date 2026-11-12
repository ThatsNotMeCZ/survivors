class_name DeviceMap
extends RefCounted


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
	return frame
