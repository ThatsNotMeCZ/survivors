extends SceneTree

const UI_PNG: String = "res://assets/sprites/ui/atlas.png"
const UI_JSON: String = "res://assets/sprites/ui/atlas.json"
const ENV_PNG: String = "res://assets/sprites/env/atlas.png"
const ENV_JSON: String = "res://assets/sprites/env/atlas.json"
const MANIFEST: String = "res://assets/sprites/manifest.json"
const FONT_PATH: String = "res://assets/fonts/BillJilly.ttf"
const OUT_ROOT: String = "res://assets/ui"
const CINDER_SHADER: String = "res://assets/shaders/cinder_circle.gdshader"
const PILLAR_SHADER: String = "res://assets/shaders/menu_pillar.gdshader"
const RUNNER_PNG: String = "res://assets/sprites/entities/runner.png"

const CONTENT_MARGIN_L: float = 20.0
const CONTENT_MARGIN_R: float = 20.0
const CONTENT_MARGIN_T: float = 8.0
const CONTENT_MARGIN_B: float = 8.0

const STYLE_IDS: PackedStringArray = ["btn-plaque", "btn-cta"]
const STYLE_STATES: PackedStringArray = ["idle", "hover", "active"]


func _init() -> void:
	var wrote: int = _bake()
	print("bake_ui_atlas: wrote %d resources" % wrote)
	quit()


func _bake() -> int:
	var wrote: int = 0
	_ensure_dirs()
	var ui_tex: Texture2D = load(UI_PNG) as Texture2D
	var env_tex: Texture2D = load(ENV_PNG) as Texture2D
	if ui_tex == null:
		push_error("bake_ui_atlas: missing %s" % UI_PNG)
		return 0
	var ui_frames: Dictionary = _load_frames(UI_JSON)
	for id: String in ui_frames.keys():
		var entry: Dictionary = ui_frames[id]
		var states: Dictionary = _states_of(entry)
		if states.is_empty():
			if _save_atlas("%s/frames/ui/%s_idle.tres" % [OUT_ROOT, _safe(id)], ui_tex, _rect_from(entry)):
				wrote += 1
			continue
		for state: String in states.keys():
			var st: Dictionary = states[state]
			if _save_atlas("%s/frames/ui/%s_%s.tres" % [OUT_ROOT, _safe(id), _safe(state)], ui_tex, _rect_from(st)):
				wrote += 1
	var env_frames: Dictionary = _load_frames(ENV_JSON)
	var circle: Dictionary = env_frames.get("cinder-circle", {})
	if env_tex != null and _save_atlas("%s/frames/env/cinder-circle.tres" % OUT_ROOT, env_tex, _rect_from(circle)):
		wrote += 1
	wrote += _bake_runner_idle()
	for id: String in STYLE_IDS:
		var entry: Dictionary = ui_frames.get(id, {})
		var margins: Dictionary = {}
		var nine: Variant = entry.get("nineSlice", null)
		if typeof(nine) == TYPE_DICTIONARY:
			margins = (nine as Dictionary).get("margins", {})
		for state: String in STYLE_STATES:
			if _save_stylebox(id, state, margins):
				wrote += 1
	if _save_focus_ring():
		wrote += 1
	if _save_material("%s/materials/cinder_circle.tres" % OUT_ROOT, CINDER_SHADER):
		wrote += 1
	if _save_material("%s/materials/menu_pillar.tres" % OUT_ROOT, PILLAR_SHADER):
		wrote += 1
	if _save_theme():
		wrote += 1
	return wrote


func _bake_runner_idle() -> int:
	var sheet: Texture2D = load(RUNNER_PNG) as Texture2D
	if sheet == null:
		push_error("bake_ui_atlas: missing %s" % RUNNER_PNG)
		return 0
	var manifest: Dictionary = _load_json(MANIFEST)
	var entities: Dictionary = manifest.get("entities", {})
	var def: Dictionary = entities.get("runner", {})
	var fw: int = int(def.get("frameWidth", 48))
	var fh: int = int(def.get("frameHeight", 48))
	var anims: Dictionary = def.get("anims", {})
	var idle: Dictionary = anims.get("idle", {})
	var frames: Array = idle.get("frames", [0])
	var frame_i: int = int(frames[0]) if not frames.is_empty() else 0
	var cols: int = maxi(1, int(float(sheet.get_width()) / float(fw)))
	var col: int = frame_i % cols
	var row: int = int(float(frame_i) / float(cols))
	var region := Rect2(float(col * fw), float(row * fh), float(fw), float(fh))
	if _save_atlas("%s/frames/entities/runner_idle.tres" % OUT_ROOT, sheet, region):
		return 1
	return 0


func _save_atlas(path: String, sheet: Texture2D, region: Rect2) -> bool:
	if sheet == null or region.size.x <= 0.0 or region.size.y <= 0.0:
		return false
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	atlas.filter_clip = true
	return _save(atlas, path)


func _save_stylebox(id: String, state: String, margins: Dictionary) -> bool:
	var tex_path: String = "%s/frames/ui/%s_%s.tres" % [OUT_ROOT, _safe(id), _safe(state)]
	if not ResourceLoader.exists(tex_path):
		push_error("bake_ui_atlas: missing frame %s" % tex_path)
		return false
	var sb := StyleBoxTexture.new()
	sb.texture = load(tex_path) as Texture2D
	sb.texture_margin_left = float(margins.get("left", 0))
	sb.texture_margin_top = float(margins.get("top", 0))
	sb.texture_margin_right = float(margins.get("right", 0))
	sb.texture_margin_bottom = float(margins.get("bottom", 0))
	sb.content_margin_left = CONTENT_MARGIN_L
	sb.content_margin_right = CONTENT_MARGIN_R
	sb.content_margin_top = CONTENT_MARGIN_T
	sb.content_margin_bottom = CONTENT_MARGIN_B
	sb.draw_center = true
	return _save(sb, "%s/styleboxes/%s_%s.tres" % [OUT_ROOT, _safe(id), _safe(state)])


func _save_focus_ring() -> bool:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.draw_center = false
	sb.border_color = Color("d4b46a")
	sb.set_border_width_all(2)
	sb.content_margin_left = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 0.0
	return _save(sb, "%s/styleboxes/focus_ring.tres" % OUT_ROOT)


func _save_material(path: String, shader_path: String) -> bool:
	var shader: Shader = load(shader_path) as Shader
	if shader == null:
		push_error("bake_ui_atlas: missing shader %s" % shader_path)
		return false
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return _save(mat, path)


func _save_theme() -> bool:
	var theme := Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		theme.default_font = load(FONT_PATH) as Font
	theme.default_font_size = 16
	var parchment := Color("e8dcc8")
	theme.set_color("font_color", "Button", parchment)
	theme.set_color("font_hover_color", "Button", parchment)
	theme.set_color("font_pressed_color", "Button", parchment)
	theme.set_color("font_focus_color", "Button", parchment)
	theme.set_color("font_disabled_color", "Button", Color("8a6a32"))
	theme.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.85))
	theme.set_color("font_color", "Label", parchment)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 1))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 2)
	if ResourceLoader.exists("%s/styleboxes/focus_ring.tres" % OUT_ROOT):
		theme.set_stylebox("focus", "Button", load("%s/styleboxes/focus_ring.tres" % OUT_ROOT))
	return _save(theme, "%s/menu_theme.tres" % OUT_ROOT)


func _save(resource: Resource, path: String) -> bool:
	var err: Error = ResourceSaver.save(resource, path)
	if err != OK:
		push_error("bake_ui_atlas: save failed %s (%s)" % [path, error_string(err)])
		return false
	print("  %s" % path)
	return true


func _ensure_dirs() -> void:
	var dirs: PackedStringArray = [
		"%s/frames/ui" % OUT_ROOT,
		"%s/frames/env" % OUT_ROOT,
		"%s/frames/entities" % OUT_ROOT,
		"%s/styleboxes" % OUT_ROOT,
		"%s/materials" % OUT_ROOT,
	]
	for dir_path: String in dirs:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))


func _states_of(entry: Dictionary) -> Dictionary:
	var states: Variant = entry.get("states", null)
	if typeof(states) == TYPE_DICTIONARY:
		return states
	return {}


func _rect_from(entry: Dictionary) -> Rect2:
	return Rect2(
		float(entry.get("x", 0)),
		float(entry.get("y", 0)),
		float(entry.get("w", 0)),
		float(entry.get("h", 0))
	)


func _safe(id: String) -> String:
	return id.replace("/", "_")


func _load_frames(path: String) -> Dictionary:
	var data: Dictionary = _load_json(path)
	var frames: Variant = data.get("frames", {})
	if typeof(frames) == TYPE_DICTIONARY:
		return frames
	return {}


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}
