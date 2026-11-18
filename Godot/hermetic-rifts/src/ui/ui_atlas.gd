class_name UiAtlas
extends RefCounted

const UI_PNG: String = "res://assets/sprites/ui/atlas.png"
const UI_JSON: String = "res://assets/sprites/ui/atlas.json"
const ENV_PNG: String = "res://assets/sprites/env/atlas.png"
const ENV_JSON: String = "res://assets/sprites/env/atlas.json"
const MANIFEST: String = "res://assets/sprites/manifest.json"
const LUT_PATH: String = "res://assets/sprites/generated/resurrect-64-32x.png"
const FONT_PATH: String = "res://assets/fonts/BillJilly.ttf"
const INK_FONT_PATH: String = "res://assets/fonts/source-sans-3-latin-600-normal.woff"

const ENTITY_GENERATED_PATHS: Dictionary = {
	"flagellant": "players/vessel-flagellant.png",
	"astromancer": "players/vessel-astromancer.png",
	"slag-hound": "enemies/slag-hound.png",
	"aether-hexer": "enemies/aether-hexer.png",
	"voltaic-regent": "enemies/voltaic-regent.png",
	"voltaic-spire": "enemies/voltaic-spire.png",
}

const ENTITY_FALLBACK_IDS: Dictionary = {
	"viridian-alchemist": "penitent",
	"arch-alchemist": "voltaic-regent",
}

const TYPE_DISPLAY: StringName = &"display"
const TYPE_BODY: StringName = &"body"
const TYPE_META: StringName = &"meta"
const TYPE_MICRO: StringName = &"micro"

const SIZE_DISPLAY_XL: int = 64
const SIZE_DISPLAY_L: int = 44
const SIZE_DISPLAY_M: int = 28
const SIZE_DISPLAY_S: int = 22
const SIZE_CTA: int = 21
const SIZE_BODY: int = 16
const SIZE_META: int = 14
const SIZE_MICRO: int = 13

const INK: Color = Color("0c0a0d")
const MENU_BG: Color = Color("0d0a0e")
const BRASS: Color = Color("c4a35a")
const BRASS_BRIGHT: Color = Color("e5c878")
const BRASS_DIM: Color = Color("8a6a32")
const GOLD_MOLTEN: Color = Color("d4b46a")
const PARCHMENT: Color = Color("e8dcc8")
const PARCHMENT_INK: Color = Color("1e1610")
const PARCHMENT_MUTED: Color = Color("4a3a2a")
const PARCHMENT_SHEET: Color = Color("d5c4a1")
const ASH: Color = Color("a89890")
const PILLAR_TOP: Color = Color("1b171d")
const PILLAR_BOT: Color = Color("141116")
const RARITY_SPLASH: Dictionary = {
	"common": Color("d4b48473"),
	"uncommon": Color("88c0d073"),
	"rare": Color("e06a2873"),
	"lunar": Color("62e0ff73"),
}

static var _ui_frames: Dictionary = {}
static var _env_frames: Dictionary = {}
static var _manifest: Dictionary = {}
static var _ui_tex: Texture2D
static var _env_tex: Texture2D
static var _font: FontFile
static var _font_ink: FontFile
static var _tex_cache: Dictionary = {}
static var _atlas_cache: Dictionary = {}
static var _sidecar_defs: Dictionary = {}
static var _sidecar_mtime: Dictionary = {}
static var _loaded: bool = false
static var _splash_tex: Texture2D


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
		_configure_display_font(_font)
	if ResourceLoader.exists(INK_FONT_PATH):
		_font_ink = load(INK_FONT_PATH) as FontFile


static func display_font() -> Font:
	ensure_loaded()
	return _font


static func body_font() -> Font:
	ensure_loaded()
	return _font


static func ink_font() -> Font:
	ensure_loaded()
	if _font_ink != null:
		return _font_ink
	return body_font()


static func _configure_display_font(font: FontFile) -> void:
	font.multichannel_signed_distance_field = false
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.hinting = TextServer.HINTING_LIGHT
	font.force_autohinter = true
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED


static func spaced_font(px: int) -> Font:
	ensure_loaded()
	if _font == null:
		return ThemeDB.fallback_font
	if px <= 0:
		return _font
	var variation := FontVariation.new()
	variation.base_font = _font
	variation.spacing_glyph = px
	return variation


static func size_for(role: StringName, requested: int = 0) -> int:
	if requested <= 0:
		match role:
			TYPE_DISPLAY:
				return SIZE_DISPLAY_S
			TYPE_BODY:
				return SIZE_BODY
			TYPE_META:
				return SIZE_META
			_:
				return SIZE_MICRO
	if role == TYPE_DISPLAY:
		return requested
	if requested <= 12:
		return SIZE_MICRO
	if requested <= 14:
		return SIZE_META
	if requested < SIZE_BODY:
		return SIZE_BODY
	return requested


static func apply_label(label: Label, role: StringName, color: Color, size_px: int = 0, outlined: bool = false) -> void:
	ensure_loaded()
	if label == null:
		return
	var px: int = size_for(role, size_px)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	var use_display: bool = role == TYPE_DISPLAY and px >= 18
	var font: Font = display_font() if use_display else body_font()
	if font != null:
		if use_display:
			label.add_theme_font_override("font", spaced_font(_display_tracking(px)))
		else:
			label.add_theme_font_override("font", font)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", 0)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	if outlined:
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override("outline_size", 4 if role == TYPE_DISPLAY else 2)
	else:
		label.add_theme_constant_override("outline_size", 0)


static func apply_ink_label(label: Label, role: StringName, color: Color, size_px: int = 0) -> void:
	apply_label(label, role, color, size_px, false)
	if label == null:
		return
	var px: int = size_for(role, size_px)
	if role == TYPE_DISPLAY and px >= 18:
		return
	var font: Font = ink_font()
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_constant_override("outline_size", 0)


static func _display_tracking(px: int) -> int:
	if px >= 48:
		return 8
	if px >= 28:
		return 4
	if px >= 22:
		return 2
	return 0


static func frame(id: String) -> AtlasTexture:
	ensure_loaded()
	return _make_atlas(_ui_tex, _rect_for(_ui_frames, id, "idle"))


static func env_frame(id: String) -> AtlasTexture:
	ensure_loaded()
	var key: String = "envatlas:%s" % id
	if _atlas_cache.has(key):
		return _atlas_cache[key]
	var atlas: AtlasTexture = _make_atlas(_env_tex, _rect_for(_env_frames, id, "idle"))
	_atlas_cache[key] = atlas
	return atlas


static func env_image(id: String) -> ImageTexture:
	ensure_loaded()
	var key: String = "envimg:%s" % id
	if _atlas_cache.has(key):
		return _atlas_cache[key]
	var tex: ImageTexture = _blit(_env_tex, _rect_for(_env_frames, id, "idle"))
	_atlas_cache[key] = tex
	return tex


static func frame_image(id: String, state: String = "idle") -> ImageTexture:
	ensure_loaded()
	return _blit(_ui_tex, _rect_for(_ui_frames, id, state))


static func generated_tex(rel_path: String, fallback_size: int = 32, fallback_color: Color = Color("5ec8d4")) -> Texture2D:
	var path: String = "res://assets/sprites/generated/%s" % rel_path
	var tex: Texture2D = _load_tex(path)
	if tex != null:
		return tex
	return _procedural_fallback(fallback_size, fallback_size, fallback_color)


static func generated_frame(
	rel_path: String,
	frame_w: int,
	frame_h: int,
	frame_idx: int,
	fallback_color: Color = Color("5ec8d4"),
) -> Texture2D:
	var fw: int = maxi(1, frame_w)
	var fh: int = maxi(1, frame_h)
	var safe_idx: int = maxi(0, frame_idx)
	var key: String = "genframe:%s:%d:%d:%d" % [rel_path, fw, fh, safe_idx]
	if _atlas_cache.has(key):
		return _atlas_cache[key]
	var sheet: Texture2D = _load_tex("res://assets/sprites/generated/%s" % rel_path)
	if sheet == null:
		var fb: ImageTexture = _procedural_fallback(fw, fh, fallback_color)
		_atlas_cache[key] = fb
		return fb
	var cols: int = maxi(1, int(float(sheet.get_width()) / float(fw)))
	var col: int = safe_idx % cols
	var row: int = int(float(safe_idx) / float(cols))
	var region := Rect2(float(col * fw), float(row * fh), float(fw), float(fh))
	var cropped: ImageTexture = _blit(sheet, region)
	if cropped == null:
		cropped = _procedural_fallback(fw, fh, fallback_color)
	_atlas_cache[key] = cropped
	return cropped


static func lut_tex() -> Texture2D:
	return _load_tex(LUT_PATH)


static func apply_button_styles(button: Button, id: String) -> void:
	ensure_loaded()
	var entry: Dictionary = _ui_frames.get(id, {})
	var margins: Dictionary = {}
	var hover_outset: Dictionary = {}
	var nine: Variant = entry.get("nineSlice", null)
	if typeof(nine) == TYPE_DICTIONARY:
		var nine_dict: Dictionary = nine as Dictionary
		margins = nine_dict.get("margins", {})
		var ho: Variant = nine_dict.get("hoverOutset", null)
		if typeof(ho) == TYPE_DICTIONARY:
			hover_outset = ho as Dictionary
	button.add_theme_stylebox_override("normal", _stylebox(id, "idle", margins))
	button.add_theme_stylebox_override("hover", _stylebox(id, "hover", margins, hover_outset))
	button.add_theme_stylebox_override("focus", empty_focus())
	button.add_theme_stylebox_override("pressed", _stylebox(id, "active", margins))
	button.add_theme_stylebox_override("disabled", _stylebox(id, "idle", margins))
	if body_font() != null:
		button.add_theme_font_override("font", body_font())
	button.add_theme_font_size_override("font_size", SIZE_BODY)
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_hover_color", PARCHMENT)
	button.add_theme_color_override("font_pressed_color", PARCHMENT)
	button.add_theme_color_override("font_focus_color", PARCHMENT)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	button.add_theme_constant_override("outline_size", 2)


static func empty_focus() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


static func style_medallion_button(button: Button) -> void:
	if button == null:
		return
	button.text = ""
	apply_button_styles(button, "hall-medailon")
	button.custom_minimum_size = Vector2(48, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.clip_text = true
	button.offset_transform_enabled = true
	button.pivot_offset = Vector2(24, 24)
	_strip_button_padding(button)


static func tween_medallion_hover(host: Node, button: Button, on: bool) -> void:
	if host == null or button == null:
		return
	button.offset_transform_enabled = true
	var tw: Tween = host.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_QUAD)
	var hover_scale: Vector2 = Vector2(1.06, 1.06) if on else Vector2.ONE
	var tint: Color = Color("fff1d4") if on else Color.WHITE
	tw.tween_property(button, "offset_transform_scale", hover_scale, 0.12)
	tw.parallel().tween_property(button, "modulate", tint, 0.12)


static func nine_slice(id: String, state: String = "idle", pad: Vector4 = Vector4(20, 8, 20, 8)) -> StyleBoxTexture:
	ensure_loaded()
	var entry: Dictionary = _ui_frames.get(id, {})
	var margins: Dictionary = {}
	var nine: Variant = entry.get("nineSlice", null)
	if typeof(nine) == TYPE_DICTIONARY:
		margins = (nine as Dictionary).get("margins", {})
	var sb: StyleBoxTexture = _stylebox(id, state, margins)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


static func skill_tex(id: String) -> Texture2D:
	return _load_tex("res://assets/sprites/skills/%s.png" % id)


static func item_tex(id: String) -> Texture2D:
	return _load_tex("res://assets/sprites/items/%s.png" % id)


static func attach_rarity_splash(host: Control, rarity: String) -> void:
	var splash := TextureRect.new()
	splash.name = "RaritySplash"
	splash.texture = _rarity_splash_tex()
	var splash_col: Color = Color("d4b48473")
	if RARITY_SPLASH.has(rarity):
		splash_col = Color(RARITY_SPLASH[rarity])
	splash.modulate = splash_col
	splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(splash)


static func _rarity_splash_tex() -> Texture2D:
	if _splash_tex != null:
		return _splash_tex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	_splash_tex = tex
	return _splash_tex


static func env_atlas_tex() -> Texture2D:
	ensure_loaded()
	return _env_tex


static func env_has(id: String) -> bool:
	ensure_loaded()
	var rect: Rect2 = _rect_for(_env_frames, id, "idle")
	return rect.size.x > 0.0 and rect.size.y > 0.0


static func env_rect(id: String) -> Rect2:
	ensure_loaded()
	return _rect_for(_env_frames, id, "idle")


static func has_own_entity_tex(id: String) -> bool:
	return _load_entity_tex_direct(id) != null


static func entity_def(id: String) -> Dictionary:
	ensure_loaded()
	_refresh_sidecar(id)
	var entities: Dictionary = _manifest.get("entities", {})
	var base: Dictionary = entities.get(id, {})
	if not _sidecar_defs.has(id):
		return base
	var sidecar: Dictionary = _sidecar_defs[id]
	var merged: Dictionary = base.duplicate()
	if sidecar.has("frameWidth"):
		merged["frameWidth"] = sidecar["frameWidth"]
	if sidecar.has("frameHeight"):
		merged["frameHeight"] = sidecar["frameHeight"]
	if sidecar.has("anims"):
		merged["anims"] = sidecar["anims"]
	return merged


static func resolve_entity_anim(id: String, anim: String) -> String:
	var eff_id: String = _effective_entity_id(id)
	var def: Dictionary = entity_def(eff_id)
	var anims: Dictionary = def.get("anims", {})
	if anims.has(anim):
		return anim
	if anim != "idle" and anim != "walk" and anims.has("attack"):
		return "attack"
	if anim == "walk" and anims.has("idle"):
		return "idle"
	if anims.has("idle"):
		return "idle"
	return anim


static func entity_anim_duration(id: String, anim: String) -> float:
	var eff_id: String = _effective_entity_id(id)
	var def: Dictionary = entity_def(eff_id)
	var anims: Dictionary = def.get("anims", {})
	var resolved: String = resolve_entity_anim(eff_id, anim)
	var spec: Dictionary = anims.get(resolved, anims.get("idle", {}))
	var frames: Array = spec.get("frames", [0])
	if frames.is_empty():
		return 0.0
	var rate: float = maxf(0.001, float(spec.get("frameRate", 8.0)))
	return float(frames.size()) / rate


static func entity_frame(id: String, anim: String, t: float) -> Texture2D:
	var eff_id: String = _effective_entity_id(id)
	var full: Texture2D = _load_entity_tex_direct(eff_id)
	if full == null:
		var fb_col := Color("6bd968") if id == "viridian-alchemist" else (Color("ffae42") if id == "arch-alchemist" else Color("5ec8d4"))
		return _procedural_fallback(32, 32, fb_col)
	var def: Dictionary = entity_def(eff_id)
	var fw: int = int(def.get("frameWidth", full.get_width()))
	var fh: int = int(def.get("frameHeight", full.get_height()))
	if fw <= 0:
		fw = full.get_width()
	if fh <= 0:
		fh = full.get_height()
	var anims: Dictionary = def.get("anims", {})
	var resolved: String = resolve_entity_anim(eff_id, anim)
	var spec: Dictionary = anims.get(resolved, anims.get("idle", {}))
	var frames: Array = spec.get("frames", [0])
	if frames.is_empty():
		frames = [0]
	var rate: float = float(spec.get("frameRate", 8.0))
	var is_loop: bool = resolved == "idle" or resolved == "walk" or resolved.begins_with("idle-") or resolved.begins_with("walk-") or resolved.begins_with("channel")
	var repeat: int = int(spec.get("repeat", -1 if is_loop else 0))
	var raw_i: int = int(floor(maxf(0.0, t) * rate))
	var idx: int = clampi(raw_i, 0, frames.size() - 1) if repeat == 0 else raw_i % frames.size()
	var frame_i: int = int(frames[idx])
	var key: String = "%s:%d:%d:%d" % [eff_id, fw, fh, frame_i]
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


static func _effective_entity_id(id: String) -> String:
	if _load_entity_tex_direct(id) != null:
		return id
	if ENTITY_FALLBACK_IDS.has(id):
		return String(ENTITY_FALLBACK_IDS[id])
	return id


static func _load_entity_tex_direct(id: String) -> Texture2D:
	var direct: Texture2D = _load_tex("res://assets/sprites/entities/%s.png" % id)
	if direct != null:
		return direct
	if ENTITY_GENERATED_PATHS.has(id):
		return _load_tex("res://assets/sprites/generated/%s" % String(ENTITY_GENERATED_PATHS[id]))
	return null


static func _procedural_fallback(w: int, h: int, color: Color) -> ImageTexture:
	var cw: int = maxi(4, w)
	var ch: int = maxi(4, h)
	var key: String = "procfallback:%dx%d:%s" % [cw, ch, color.to_html()]
	if _atlas_cache.has(key):
		return _atlas_cache[key]
	var img := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = float(cw) * 0.5
	var cy: float = float(ch) * 0.5
	var rx: float = maxf(1.5, cx - 2.0)
	var ry: float = maxf(1.5, cy - 2.0)
	var dark: Color = color.darkened(0.45)
	var hi: Color = color.lightened(0.35)
	for y: int in ch:
		for x: int in cw:
			var dx: float = absf(float(x) + 0.5 - cx) / rx
			var dy: float = absf(float(y) + 0.5 - cy) / ry
			var d: float = dx + dy
			if d <= 1.05 and d > 0.85:
				img.set_pixel(x, y, INK)
			elif d <= 0.85:
				var c: Color = hi if (float(x) < cx and float(y) < cy and d < 0.45) else (dark if float(y) > cy else color)
				img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_atlas_cache[key] = tex
	return tex


static func _strip_button_padding(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBox = button.get_theme_stylebox(state)
		if sb is StyleBoxTexture:
			var tex := (sb as StyleBoxTexture).duplicate() as StyleBoxTexture
			tex.content_margin_left = 0.0
			tex.content_margin_right = 0.0
			tex.content_margin_top = 0.0
			tex.content_margin_bottom = 0.0
			tex.texture_margin_left = 0.0
			tex.texture_margin_right = 0.0
			tex.texture_margin_top = 0.0
			tex.texture_margin_bottom = 0.0
			button.add_theme_stylebox_override(state, tex)
		elif sb is StyleBoxFlat:
			var flat := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			flat.content_margin_left = 0.0
			flat.content_margin_right = 0.0
			flat.content_margin_top = 0.0
			flat.content_margin_bottom = 0.0
			button.add_theme_stylebox_override(state, flat)


static func _stylebox(id: String, state: String, margins: Dictionary, outset: Dictionary = {}) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _make_atlas(_ui_tex, _rect_for(_ui_frames, id, state))
	var out_l: float = float(outset.get("left", 0))
	var out_t: float = float(outset.get("top", 0))
	var out_r: float = float(outset.get("right", 0))
	var out_b: float = float(outset.get("bottom", 0))
	sb.texture_margin_left = float(margins.get("left", 0)) + out_l
	sb.texture_margin_top = float(margins.get("top", 0)) + out_t
	sb.texture_margin_right = float(margins.get("right", 0)) + out_r
	sb.texture_margin_bottom = float(margins.get("bottom", 0)) + out_b
	sb.expand_margin_left = out_l
	sb.expand_margin_top = out_t
	sb.expand_margin_right = out_r
	sb.expand_margin_bottom = out_b
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
	var rx: int = int(region.position.x)
	var ry: int = int(region.position.y)
	var rw: int = int(region.size.x)
	var rh: int = int(region.size.y)
	if rx < 0 or ry < 0 or rx + rw > src.get_width() or ry + rh > src.get_height():
		return null
	var cropped: Image = src.get_region(Rect2i(rx, ry, rw, rh))
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


static func _refresh_sidecar(id: String) -> void:
	var path := "res://assets/sprites/entities/%s.json" % id
	if not FileAccess.file_exists(path):
		_sidecar_defs.erase(id)
		_sidecar_mtime.erase(id)
		return
	var mtime: int = int(FileAccess.get_modified_time(path))
	if int(_sidecar_mtime.get(id, -1)) == mtime:
		return
	_sidecar_mtime[id] = mtime
	var sidecar: Dictionary = _load_json(path)
	if sidecar.has("anims"):
		_sidecar_defs[id] = sidecar
	else:
		_sidecar_defs.erase(id)


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
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var loaded: Variant = load(path)
		if loaded is Texture2D:
			tex = loaded as Texture2D
	if tex == null:
		var abs_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path) or FileAccess.file_exists(abs_path):
			var img: Image = Image.load_from_file(abs_path)
			if img == null or img.is_empty():
				img = Image.load_from_file(path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex
