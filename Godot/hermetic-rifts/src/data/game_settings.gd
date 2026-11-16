class_name GameSettings
extends RefCounted

const PATH: String = "user://settings.v1.json"

var master_volume: float = 0.7
var sfx_volume: float = 0.8
var music_volume: float = 0.6
var muted: bool = false
var screenshake: bool = true
var reduce_vfx: bool = false
var survivor_id: String = "runner"
var daily_rite: bool = false
var window_mode: String = "windowed"
var screen_index: int = 0
var resolution_w: int = 1920
var resolution_h: int = 1080
var vsync: String = "on"
var max_fps: int = 0


static func load_or_default() -> GameSettings:
	var s := GameSettings.new()
	if not FileAccess.file_exists(PATH):
		return s
	var file := FileAccess.open(PATH, FileAccess.READ)
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
	s.window_mode = String(data.get("windowMode", "windowed"))
	s.screen_index = int(data.get("screenIndex", 0))
	s.resolution_w = int(data.get("resolutionW", 1920))
	s.resolution_h = int(data.get("resolutionH", 1080))
	s.vsync = String(data.get("vsync", "on"))
	s.max_fps = int(data.get("maxFps", 0))
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
		"windowMode": window_mode,
		"screenIndex": screen_index,
		"resolutionW": resolution_w,
		"resolutionH": resolution_h,
		"vsync": vsync,
		"maxFps": max_fps,
	}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
