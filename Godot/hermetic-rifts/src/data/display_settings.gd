class_name DisplaySettings
extends RefCounted

const MODE_WINDOWED: String = "windowed"
const MODE_BORDERLESS: String = "borderless"
const MODE_EXCLUSIVE: String = "exclusive"

const VSYNC_OFF: String = "off"
const VSYNC_ON: String = "on"
const VSYNC_ADAPTIVE: String = "adaptive"

const CONFIRM_SECONDS: float = 15.0

const MODE_OPTIONS: Array[String] = [MODE_WINDOWED, MODE_BORDERLESS, MODE_EXCLUSIVE]
const VSYNC_OPTIONS: Array[String] = [VSYNC_OFF, VSYNC_ON, VSYNC_ADAPTIVE]
const FPS_OPTIONS: Array[int] = [0, 60, 120, 144, 240]


static func catalog_resolutions() -> Array[Vector2i]:
	return [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160),
	]


static func clamp_screen(index: int) -> int:
	var count: int = DisplayServer.get_screen_count()
	if count <= 0:
		return 0
	return clampi(index, 0, count - 1)


static func screen_size(index: int) -> Vector2i:
	return DisplayServer.screen_get_size(clamp_screen(index))


static func resolutions_for_screen(index: int) -> Array[Vector2i]:
	var native: Vector2i = screen_size(index)
	var out: Array[Vector2i] = []
	for res: Vector2i in catalog_resolutions():
		if native.x <= 0 or native.y <= 0 or (res.x <= native.x and res.y <= native.y):
			out.append(res)
	if native.x > 0 and native.y > 0 and not out.has(native):
		out.append(native)
	if out.is_empty():
		out.append(Vector2i(1280, 720))
	return out


static func sanitize(settings: GameSettings) -> void:
	if MODE_OPTIONS.find(settings.window_mode) < 0:
		settings.window_mode = MODE_WINDOWED
	if VSYNC_OPTIONS.find(settings.vsync) < 0:
		settings.vsync = VSYNC_ON
	if FPS_OPTIONS.find(settings.max_fps) < 0:
		settings.max_fps = 0
	settings.screen_index = clamp_screen(settings.screen_index)
	var allowed: Array[Vector2i] = resolutions_for_screen(settings.screen_index)
	var chosen := Vector2i(settings.resolution_w, settings.resolution_h)
	if allowed.has(chosen):
		return
	var fallback: Vector2i = allowed[allowed.size() - 1]
	for res: Vector2i in allowed:
		if res.x == 1920 and res.y == 1080:
			fallback = res
			break
	settings.resolution_w = fallback.x
	settings.resolution_h = fallback.y


static func snapshot_display(settings: GameSettings) -> Dictionary:
	return {
		"windowMode": settings.window_mode,
		"screenIndex": settings.screen_index,
		"resolutionW": settings.resolution_w,
		"resolutionH": settings.resolution_h,
	}


static func restore_display(settings: GameSettings, snap: Dictionary) -> void:
	settings.window_mode = String(snap.get("windowMode", MODE_WINDOWED))
	settings.screen_index = int(snap.get("screenIndex", 0))
	settings.resolution_w = int(snap.get("resolutionW", 1920))
	settings.resolution_h = int(snap.get("resolutionH", 1080))
	sanitize(settings)


static func apply(settings: GameSettings) -> void:
	sanitize(settings)
	_apply_vsync(settings.vsync)
	Engine.max_fps = settings.max_fps
	if OS.has_feature("editor"):
		return
	var screen: int = settings.screen_index
	var size := Vector2i(settings.resolution_w, settings.resolution_h)
	DisplayServer.window_set_current_screen(screen)
	match settings.window_mode:
		MODE_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		MODE_EXCLUSIVE:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_set_windowed_size(size, screen)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_set_windowed_size(size, screen)


static func format_res(size: Vector2i) -> String:
	return "%d×%d" % [size.x, size.y]


static func _apply_vsync(mode: String) -> void:
	match mode:
		VSYNC_OFF:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		VSYNC_ADAPTIVE:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
		_:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)


static func _set_windowed_size(size: Vector2i, screen: int) -> void:
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var w: int = size.x
	var h: int = size.y
	if usable.size.x > 0:
		w = mini(w, usable.size.x)
	if usable.size.y > 0:
		h = mini(h, usable.size.y)
	DisplayServer.window_set_size(Vector2i(w, h))
	if usable.size.x > 0 and usable.size.y > 0:
		var pos := Vector2i(
			usable.position.x + int((usable.size.x - w) / 2.0),
			usable.position.y + int((usable.size.y - h) / 2.0)
		)
		DisplayServer.window_set_position(pos)
