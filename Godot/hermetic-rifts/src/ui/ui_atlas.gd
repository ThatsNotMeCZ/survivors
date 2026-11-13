class_name UiAtlas
extends RefCounted

const UI_PNG: String = "res://assets/sprites/ui/atlas.png"
const UI_JSON: String = "res://assets/sprites/ui/atlas.json"
const ENV_PNG: String = "res://assets/sprites/env/atlas.png"
const ENV_JSON: String = "res://assets/sprites/env/atlas.json"
const MANIFEST: String = "res://assets/sprites/manifest.json"
const FONT_PATH: String = "res://assets/fonts/BillJilly.ttf"

const INK: Color = Color("0c0a0d")
const MENU_BG: Color = Color("0d0a0e")
const BRASS: Color = Color("c4a35a")
const BRASS_BRIGHT: Color = Color("e5c878")
const BRASS_DIM: Color = Color("8a6a32")
const GOLD_MOLTEN: Color = Color("d4b46a")
const PARCHMENT: Color = Color("e8dcc8")
const PILLAR_TOP: Color = Color("1b171d")
const PILLAR_BOT: Color = Color("141116")

static var _ui_frames: Dictionary = {}
static var _env_frames: Dictionary = {}
static var _manifest: Dictionary = {}
static var _ui_tex: Texture2D
static var _env_tex: Texture2D
static var _font: FontFile
static var _tex_cache: Dictionary = {}
static var _atlas_cache: Dictionary = {}
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_ui_tex = _load_tex(UI_PNG)
	_env_tex = _load_tex(ENV_PNG)
	_ui_frames = _load_frames(UI_JSON)
	_env_frames = _load_frames(ENV_JSON)
	_manifest = _load_json(MANIFEST)
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as FontFile


static func display_font() -> Font:
	ensure_loaded()
	return _font


static func spaced_font(px: int) -> Font:
	ensure_loaded()
	if _font == null:
		return ThemeDB.fallback_font
	var variation := FontVariation.new()
	variation.base_font = _font
	variation.spacing_glyph = px
	return variation


static func frame(id: String) -> AtlasTexture:
	ensure_loaded()
	return _make_atlas(_ui_tex, _rect_for(_ui_frames, id, "idle"))


static func env_frame(id: String) -> AtlasTexture:
	ensure_loaded()
	return _make_atlas(_env_tex, _rect_for(_env_frames, id, "idle"))


static func env_image(id: String) -> ImageTexture:
	ensure_loaded()
	return _blit(_env_tex, _rect_for(_env_frames, id, "idle"))


static func frame_image(id: String, state: String = "idle") -> ImageTexture:
	ensure_loaded()
	return _blit(_ui_tex, _rect_for(_ui_frames, id, state))


static func apply_button_styles(button: Button, id: String) -> void:
	ensure_loaded()
	var entry: Dictionary = _ui_frames.get(id, {})
	var margins: Dictionary = {}
	var nine: Variant = entry.get("nineSlice", null)
	if typeof(nine) == TYPE_DICTIONARY:
		margins = (nine as Dictionary).get("margins", {})
	button.add_theme_stylebox_override("normal", _stylebox(id, "idle", margins))
	button.add_theme_stylebox_override("hover", _stylebox(id, "hover", margins))
	button.add_theme_stylebox_override("focus", _focus_ring())
	button.add_theme_stylebox_override("pressed", _stylebox(id, "active", margins))
	button.add_theme_stylebox_override("disabled", _stylebox(id, "idle", margins))
	if _font != null:
		button.add_theme_font_override("font", spaced_font(1))
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_hover_color", PARCHMENT)
	button.add_theme_color_override("font_pressed_color", PARCHMENT)
	button.add_theme_color_override("font_focus_color", PARCHMENT)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))


static func entity_frame(id: String, anim: String, t: float) -> Texture2D:
	ensure_loaded()
	var entities: Dictionary = _manifest.get("entities", {})
	var def: Dictionary = entities.get(id, {})
	var full: Texture2D = _load_tex("res://assets/sprites/entities/%s.png" % id)
	if full == null:
		return null
	var fw: int = int(def.get("frameWidth", full.get_width()))
	var fh: int = int(def.get("frameHeight", full.get_height()))
	if fw <= 0:
		fw = full.get_width()
	if fh <= 0:
		fh = full.get_height()
	var anims: Dictionary = def.get("anims", {})
	var spec: Dictionary = anims.get(anim, anims.get("idle", {}))
	var frames: Array = spec.get("frames", [0])
	if frames.is_empty():
		frames = [0]
	var rate: float = float(spec.get("frameRate", 8.0))
	var frame_i: int = int(frames[int(floor(t * rate)) % frames.size()])
	var key: String = "%s:%d:%d:%d" % [id, fw, fh, frame_i]
	if _atlas_cache.has(key):
		return _atlas_cache[key]
	var cols: int = maxi(1, int(float(full.get_width()) / float(fw)))
	var col: int = frame_i % cols
	var row: int = int(float(frame_i) / float(cols))
	var region := Rect2(float(col * fw), float(row * fh), float(fw), float(fh))
	var blitted: ImageTexture = _blit(full, region)
	if blitted != null:
		_atlas_cache[key] = blitted
		return blitted
	var atlas := AtlasTexture.new()
	atlas.atlas = full
	atlas.filter_clip = true
	atlas.region = region
	_atlas_cache[key] = atlas
	return atlas


static func _focus_ring() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.draw_center = false
	sb.border_color = GOLD_MOLTEN
	sb.set_border_width_all(2)
	sb.content_margin_left = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 0.0
	return sb


static func _stylebox(id: String, state: String, margins: Dictionary) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _make_atlas(_ui_tex, _rect_for(_ui_frames, id, state))
	sb.texture_margin_left = float(margins.get("left", 0))
	sb.texture_margin_top = float(margins.get("top", 0))
	sb.texture_margin_right = float(margins.get("right", 0))
	sb.texture_margin_bottom = float(margins.get("bottom", 0))
	# Keep content padding smaller than 9-slice margins so labels don't inflate the button.
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	sb.draw_center = true
	return sb


static func _rect_for(frames: Dictionary, id: String, state: String) -> Rect2:
	var entry: Dictionary = frames.get(id, {})
	var states: Variant = entry.get("states", null)
	if typeof(states) == TYPE_DICTIONARY:
		var st: Dictionary = (states as Dictionary).get(state, {})
		if not st.is_empty():
			return Rect2(float(st.get("x", 0)), float(st.get("y", 0)), float(st.get("w", 0)), float(st.get("h", 0)))
	return Rect2(float(entry.get("x", 0)), float(entry.get("y", 0)), float(entry.get("w", 0)), float(entry.get("h", 0)))


static func _blit(sheet: Texture2D, region: Rect2) -> ImageTexture:
	if sheet == null or region.size.x <= 0.0 or region.size.y <= 0.0:
		return null
	var src: Image = sheet.get_image()
	if src == null:
		return null
	var cropped: Image = src.get_region(Rect2i(int(region.position.x), int(region.position.y), int(region.size.x), int(region.size.y)))
	cropped.fix_alpha_edges()
	return ImageTexture.create_from_image(cropped)


static func _make_atlas(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	if sheet == null or region.size.x <= 0.0 or region.size.y <= 0.0:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	atlas.filter_clip = true
	return atlas


static func _load_frames(path: String) -> Dictionary:
	var data: Dictionary = _load_json(path)
	var frames: Variant = data.get("frames", {})
	if typeof(frames) == TYPE_DICTIONARY:
		return frames
	return {}


static func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


static func _load_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	if not ResourceLoader.exists(path):
		_tex_cache[path] = null
		return null
	var tex: Texture2D = load(path)
	_tex_cache[path] = tex
	return tex
