class_name GameSettings
extends RefCounted

const PATH: String = "user://settings.v1.json"
const ALL_DEVICES: int = -1
const REBINDABLE_ACTIONS: Array[String] = [
	"move_left",
	"move_right",
	"move_up",
	"move_down",
	"fire_primary",
	"fire_secondary",
	"utility",
	"special",
	"pause",
	"confirm",
	"back",
]

static var _default_input_map: Dictionary = {}

var master_volume: float = 0.7
var sfx_volume: float = 0.8
var music_volume: float = 0.6
var muted: bool = false
var screenshake: bool = true
var reduce_vfx: bool = false
var survivor_id: String = "runner"
var daily_rite: bool = false
var demo_mode: bool = false
var window_mode: String = "windowed"
var screen_index: int = 0
var resolution_w: int = 1920
var resolution_h: int = 1080
var vsync: String = "on"
var max_fps: int = 0
var input_rebinds: Dictionary = {}


func _init() -> void:
	_capture_defaults_once()


static func load_or_default() -> GameSettings:
	_capture_defaults_once()
	var s: GameSettings = GameSettings.new()
	if not FileAccess.file_exists(PATH):
		return s
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return s
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return s
	var data: Dictionary = parsed
	s.master_volume = clampf(float(data.get("masterVolume", 0.7)), 0.0, 1.0)
	s.sfx_volume = clampf(float(data.get("sfxVolume", 0.8)), 0.0, 1.0)
	s.music_volume = clampf(float(data.get("musicVolume", 0.6)), 0.0, 1.0)
	s.muted = bool(data.get("muted", false))
	s.screenshake = bool(data.get("screenshake", true))
	s.reduce_vfx = bool(data.get("reduceVfx", false))
	s.survivor_id = String(data.get("survivorId", "runner"))
	s.daily_rite = bool(data.get("dailyRite", false))
	s.demo_mode = bool(data.get("demoMode", false))
	s.window_mode = String(data.get("windowMode", "windowed"))
	s.screen_index = int(data.get("screenIndex", 0))
	s.resolution_w = int(data.get("resolutionW", 1920))
	s.resolution_h = int(data.get("resolutionH", 1080))
	s.vsync = String(data.get("vsync", "on"))
	s.max_fps = int(data.get("maxFps", 0))
	s.input_rebinds = _sanitize_input_rebinds(data.get("inputRebinds", {}))
	s.apply_input_rebinds()
	return s


func save() -> void:
	var data: Dictionary = {
		"masterVolume": master_volume,
		"sfxVolume": sfx_volume,
		"musicVolume": music_volume,
		"muted": muted,
		"screenshake": screenshake,
		"reduceVfx": reduce_vfx,
		"survivorId": survivor_id,
		"dailyRite": daily_rite,
		"demoMode": demo_mode,
		"windowMode": window_mode,
		"screenIndex": screen_index,
		"resolutionW": resolution_w,
		"resolutionH": resolution_h,
		"vsync": vsync,
		"maxFps": max_fps,
		"inputRebinds": input_rebinds,
	}
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))


func apply_input_rebinds() -> void:
	_capture_defaults_once()
	var handled: Dictionary = {}
	for action: String in REBINDABLE_ACTIONS:
		handled[action] = true
		_apply_action_rebind(action)
	for extra_v: Variant in input_rebinds.keys():
		var action: String = String(extra_v)
		if handled.has(action):
			continue
		if InputMap.has_action(action) and not _default_input_map.has(action):
			_default_input_map[action] = _duplicate_action_events(action)
		_apply_action_rebind(action)


func capture_input_rebinds_from_input_map() -> void:
	_capture_defaults_once()
	var captured: Dictionary = {}
	for action: String in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var list: Array[Dictionary] = []
		for ev: InputEvent in InputMap.action_get_events(action):
			var desc: Dictionary = _event_to_descriptor(ev)
			if not desc.is_empty():
				list.append(desc)
		captured[action] = list
	input_rebinds = captured


func reset_input_rebinds_to_default() -> void:
	_capture_defaults_once()
	var extra_actions: Array[String] = []
	for k: Variant in input_rebinds.keys():
		var action: String = String(k)
		if not REBINDABLE_ACTIONS.has(action):
			extra_actions.append(action)
	input_rebinds = {}
	for action: String in REBINDABLE_ACTIONS:
		_restore_action_default(action)
	for action: String in extra_actions:
		_restore_action_default(action)


func _apply_action_rebind(action: String) -> void:
	if not InputMap.has_action(action):
		return
	if not input_rebinds.has(action):
		_restore_action_default(action)
		return
	var raw_list_v: Variant = input_rebinds.get(action, null)
	if typeof(raw_list_v) != TYPE_ARRAY:
		_restore_action_default(action)
		return
	var raw_list: Array = raw_list_v
	var events: Array[InputEvent] = []
	var had_invalid: bool = false
	for item_v: Variant in raw_list:
		if typeof(item_v) != TYPE_DICTIONARY:
			had_invalid = true
			continue
		var ev: InputEvent = _descriptor_to_event(item_v as Dictionary)
		if ev != null:
			events.append(ev)
		else:
			had_invalid = true
	if events.is_empty() and (not raw_list.is_empty() or had_invalid):
		_restore_action_default(action)
		return
	InputMap.action_erase_events(action)
	for ev: InputEvent in events:
		InputMap.action_add_event(action, ev)


static func _capture_defaults_once() -> void:
	if not _default_input_map.is_empty():
		return
	for action: String in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		_default_input_map[action] = _duplicate_action_events(action)


static func _duplicate_action_events(action: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev != null:
			out.append(ev.duplicate() as InputEvent)
	return out


static func _restore_action_default(action: String) -> void:
	if not InputMap.has_action(action):
		return
	if not _default_input_map.has(action):
		return
	InputMap.action_erase_events(action)
	var stored_v: Variant = _default_input_map.get(action, [])
	if typeof(stored_v) != TYPE_ARRAY:
		return
	for ev_v: Variant in stored_v:
		if ev_v is InputEvent:
			InputMap.action_add_event(action, (ev_v as InputEvent).duplicate() as InputEvent)


static func _sanitize_input_rebinds(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var raw_dict: Dictionary = raw
	var out: Dictionary = {}
	for k: Variant in raw_dict.keys():
		var action: String = String(k)
		if action == "" or (not REBINDABLE_ACTIONS.has(action) and not InputMap.has_action(action)):
			continue
		var list_v: Variant = raw_dict[k]
		if typeof(list_v) != TYPE_ARRAY:
			continue
		var raw_list: Array = list_v
		var clean_list: Array[Dictionary] = []
		for item_v: Variant in raw_list:
			if typeof(item_v) != TYPE_DICTIONARY:
				continue
			var norm: Dictionary = _normalize_descriptor(item_v as Dictionary)
			if norm.is_empty():
				continue
			if _descriptor_to_event(norm) == null:
				continue
			clean_list.append(norm)
		if clean_list.is_empty() and not raw_list.is_empty():
			continue
		out[action] = clean_list
	return out


static func _normalize_descriptor(raw_desc: Dictionary) -> Dictionary:
	var t: String = String(raw_desc.get("type", ""))
	match t:
		"key":
			return {
				"type": "key",
				"keycode": int(raw_desc.get("keycode", 0)),
				"physical_keycode": int(raw_desc.get("physical_keycode", 0)),
			}
		"mouse":
			return {
				"type": "mouse",
				"button_index": int(raw_desc.get("button_index", 0)),
			}
		"joy_button":
			return {
				"type": "joy_button",
				"button_index": int(raw_desc.get("button_index", -1)),
			}
		"joy_axis":
			return {
				"type": "joy_axis",
				"axis": int(raw_desc.get("axis", -1)),
				"axis_value": float(raw_desc.get("axis_value", 0.0)),
			}
		_:
			return {}


static func _event_to_descriptor(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k: InputEventKey = ev as InputEventKey
		return {
			"type": "key",
			"keycode": int(k.keycode),
			"physical_keycode": int(k.physical_keycode),
		}
	if ev is InputEventMouseButton:
		var m: InputEventMouseButton = ev as InputEventMouseButton
		return {
			"type": "mouse",
			"button_index": int(m.button_index),
		}
	if ev is InputEventJoypadButton:
		var jb: InputEventJoypadButton = ev as InputEventJoypadButton
		return {
			"type": "joy_button",
			"button_index": int(jb.button_index),
		}
	if ev is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = ev as InputEventJoypadMotion
		return {
			"type": "joy_axis",
			"axis": int(jm.axis),
			"axis_value": float(jm.axis_value),
		}
	return {}


static func _descriptor_to_event(desc: Dictionary) -> InputEvent:
	var t: String = String(desc.get("type", ""))
	match t:
		"key":
			var kc: int = int(desc.get("keycode", 0))
			var pkc: int = int(desc.get("physical_keycode", 0))
			if kc == 0 and pkc == 0:
				return null
			var k: InputEventKey = InputEventKey.new()
			k.device = ALL_DEVICES
			k.keycode = kc as Key
			k.physical_keycode = pkc as Key
			return k
		"mouse":
			var btn: int = int(desc.get("button_index", 0))
			if btn <= 0:
				return null
			var m: InputEventMouseButton = InputEventMouseButton.new()
			m.device = ALL_DEVICES
			m.button_index = btn as MouseButton
			return m
		"joy_button":
			var jbtn: int = int(desc.get("button_index", -1))
			if jbtn < 0:
				return null
			var jb: InputEventJoypadButton = InputEventJoypadButton.new()
			jb.device = ALL_DEVICES
			jb.button_index = jbtn as JoyButton
			return jb
		"joy_axis":
			var ax: int = int(desc.get("axis", -1))
			var av: float = float(desc.get("axis_value", 0.0))
			if ax < 0 or is_zero_approx(av):
				return null
			var jm: InputEventJoypadMotion = InputEventJoypadMotion.new()
			jm.device = ALL_DEVICES
			jm.axis = ax as JoyAxis
			jm.axis_value = clampf(av, -1.0, 1.0)
			return jm
		_:
			return null
