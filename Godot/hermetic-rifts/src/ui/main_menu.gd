class_name MainMenuView
extends Control

signal archives_pressed
signal desk_pressed
signal commence_pressed

var _archives_btn: Button
var _desk_btn: Button
var _commence_btn: Button
var _brand_1: Label
var _brand_2: Label
var _commence_1: Label
var _commence_2: Label
var _logo: TextureRect
var _seal: TextureRect
var _preview: TextureRect
var _corner_tl: TextureRect
var _corner_tr: TextureRect
var _corner_bl: TextureRect
var _corner_br: TextureRect
var _pillar: Control
var _pillar_bg: ColorRect
var _stage: Control

var _preview_t: float = 0.0
var _survivor_id: String = "runner"
var _bound: bool = false
var _styled: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_resolve_nodes()
	_style()
	_bind()
	refresh_preview()
	call_deferred("_place_cta")
	call_deferred("_fit_nav")
	call_deferred("focus_primary")


func _process(dt: float) -> void:
	if not visible:
		return
	_preview_t += dt
	_fit_seal()
	_place_cta()
	_fit_nav()
	_sync_preview_frame()


func refresh_preview() -> void:
	var app := get_node_or_null("/root/App")
	if app != null:
		_survivor_id = String(app.selected_survivor)
	_preview_t = 0.0
	_sync_preview_frame()


func focus_primary() -> void:
	if _archives_btn != null and _archives_btn.is_inside_tree():
		_archives_btn.grab_focus()


func _resolve_nodes() -> void:
	_archives_btn = get_node_or_null("Content/Row/Pillar/PillarPad/PillarCol/NavWrap/Nav/ArchivesBtn") as Button
	_desk_btn = get_node_or_null("Content/Row/Pillar/PillarPad/PillarCol/NavWrap/Nav/DeskBtn") as Button
	_commence_btn = get_node_or_null("CommenceBtn") as Button
	_brand_1 = get_node_or_null("Content/Row/Pillar/Brand/BrandLine1") as Label
	_brand_2 = get_node_or_null("Content/Row/Pillar/Brand/BrandLine2") as Label
	_commence_1 = get_node_or_null("CommenceBtn/CommenceCopy/CommenceLine1") as Label
	_commence_2 = get_node_or_null("CommenceBtn/CommenceCopy/CommenceLine2") as Label
	_logo = get_node_or_null("Content/Row/Pillar/LogoCrest") as TextureRect
	_seal = get_node_or_null("Content/Row/Stage/Seal") as TextureRect
	_preview = get_node_or_null("Content/Row/Stage/Preview") as TextureRect
	_corner_tl = get_node_or_null("ScreenFrame/CornerTL") as TextureRect
	_corner_tr = get_node_or_null("ScreenFrame/CornerTR") as TextureRect
	_corner_bl = get_node_or_null("ScreenFrame/CornerBL") as TextureRect
	_corner_br = get_node_or_null("ScreenFrame/CornerBR") as TextureRect
	_pillar = get_node_or_null("Content/Row/Pillar") as Control
	_pillar_bg = get_node_or_null("Content/Row/Pillar/PillarBg") as ColorRect
	_stage = get_node_or_null("Content/Row/Stage") as Control


func _style() -> void:
	if _styled:
		return
	_styled = true
	var frame := get_node_or_null("ScreenFrame") as Control
	if frame != null:
		frame.z_index = 1
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiAtlas.ensure_loaded()
	var corner: AtlasTexture = UiAtlas.frame("screen-corner")
	_apply_corner(_corner_tl, corner)
	_apply_corner(_corner_tr, corner)
	_apply_corner(_corner_bl, corner)
	_apply_corner(_corner_br, corner)
	if _corner_tr != null:
		_corner_tr.flip_h = true
	if _corner_bl != null:
		_corner_bl.flip_v = true
	if _corner_br != null:
		_corner_br.flip_h = true
		_corner_br.flip_v = true
	_ignore_mouse(get_node_or_null("Background") as Control)
	_ignore_mouse(get_node_or_null("Content") as Control)
	_ignore_mouse(get_node_or_null("Content/Row") as Control)
	_ignore_mouse(get_node_or_null("Content/Row/Pillar/PillarPad") as Control)
	_ignore_mouse(get_node_or_null("Content/Row/Pillar/PillarPad/PillarCol") as Control)
	_ignore_mouse(get_node_or_null("Content/Row/Pillar/PillarPad/PillarCol/NavWrap") as Control)
	_ignore_mouse(get_node_or_null("Content/Row/Pillar/PillarPad/PillarCol/NavWrap/Nav") as Control)
	_ignore_mouse(get_node_or_null("Content/Row/Pillar/PillarPad/PillarCol/CrestBox") as Control)
	if _logo != null:
		_logo.texture = UiAtlas.frame("logo")
		_logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_logo.anchor_left = 0.5
		_logo.anchor_right = 0.5
		_logo.offset_left = -186.0
		_logo.offset_right = 186.0
		_logo.offset_top = 22.0
		_logo.offset_bottom = 251.0
		_logo.custom_minimum_size = Vector2(372, 229)
	var brand := get_node_or_null("Content/Row/Pillar/Brand") as Control
	if _logo != null and _logo.texture != null and brand != null:
		brand.visible = false
	else:
		_style_brand(_brand_1, tr("ui.menu.brand.line1"))
		_style_brand(_brand_2, tr("ui.menu.brand.line2"))
	var nav := get_node_or_null("Content/Row/Pillar/PillarPad/PillarCol/NavWrap/Nav") as VBoxContainer
	if nav != null:
		nav.add_theme_constant_override("separation", 18)
		nav.custom_minimum_size = Vector2(0, 0)
		nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_plaque(_archives_btn, tr("ui.menu.archives").to_upper())
	_style_plaque(_desk_btn, tr("ui.menu.desk").to_upper())
	if _commence_btn != null:
		_commence_btn.text = ""
		_commence_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_commence_btn.focus_mode = Control.FOCUS_ALL
		_commence_btn.z_index = 8
		_commence_btn.clip_contents = true
		_commence_btn.add_theme_stylebox_override("normal", _empty_sb())
		_commence_btn.add_theme_stylebox_override("hover", _empty_sb())
		_commence_btn.add_theme_stylebox_override("pressed", _empty_sb())
		_commence_btn.add_theme_stylebox_override("focus", _empty_sb())
		_attach_ninepatch(_commence_btn, "btn-cta")
		_place_cta()
	_style_cta_line(_commence_1, tr("ui.menu.commence.line1"))
	_style_cta_line(_commence_2, tr("ui.menu.commence.line2"))
	if _seal != null:
		var seal_tex: Texture2D = UiAtlas.env_image("cinder-circle")
		if seal_tex == null:
			seal_tex = UiAtlas.env_frame("cinder-circle")
		_seal.texture = seal_tex
		_seal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/cinder_circle.gdshader")
		_seal.material = mat
	if _preview != null:
		_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_preview.custom_minimum_size = Vector2(248, 248)
		_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview.z_index = 2
	if _pillar != null:
		_pillar.custom_minimum_size = Vector2(420, 0)
		_pillar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_pillar.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_pillar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pillar.clip_contents = false
	if _stage != null:
		_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _pillar_bg != null:
		var bg_mat := ShaderMaterial.new()
		bg_mat.shader = load("res://assets/shaders/menu_pillar.gdshader")
		_pillar_bg.material = bg_mat
		_pillar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _archives_btn != null and _desk_btn != null and _commence_btn != null:
		_archives_btn.focus_neighbor_bottom = _desk_btn.get_path()
		_desk_btn.focus_neighbor_top = _archives_btn.get_path()
		_desk_btn.focus_neighbor_bottom = _commence_btn.get_path()
		_commence_btn.focus_neighbor_top = _desk_btn.get_path()
		_commence_btn.focus_neighbor_left = _desk_btn.get_path()


func _bind() -> void:
	if _bound:
		return
	_bound = true
	if _archives_btn != null:
		_archives_btn.pressed.connect(func() -> void: archives_pressed.emit())
	if _desk_btn != null:
		_desk_btn.pressed.connect(func() -> void: desk_pressed.emit())
	if _commence_btn != null:
		_commence_btn.pressed.connect(func() -> void: commence_pressed.emit())


func _style_plaque(button: Button, text: String) -> void:
	if button == null:
		return
	UiAtlas.apply_button_styles(button, "btn-plaque")
	button.text = text
	button.clip_text = true
	button.custom_minimum_size = Vector2(0, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 16)


func _place_cta() -> void:
	if _commence_btn == null:
		return
	var w: float = 240.0
	var h: float = 96.0
	_commence_btn.anchor_left = 1.0
	_commence_btn.anchor_top = 1.0
	_commence_btn.anchor_right = 1.0
	_commence_btn.anchor_bottom = 1.0
	_commence_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_commence_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_commence_btn.offset_right = -28.0
	_commence_btn.offset_bottom = -24.0
	_commence_btn.offset_left = -28.0 - w
	_commence_btn.offset_top = -24.0 - h
	_commence_btn.custom_minimum_size = Vector2(w, h)
	_commence_btn.size = Vector2(w, h)


func _fit_nav() -> void:
	var wrap := get_node_or_null("Content/Row/Pillar/PillarPad/PillarCol/NavWrap") as Control
	if wrap == null:
		return
	var w: float = wrap.size.x
	if w < 8.0:
		return
	var nav := get_node_or_null("Content/Row/Pillar/PillarPad/PillarCol/NavWrap/Nav") as Control
	if nav != null:
		nav.custom_minimum_size = Vector2(w, 0)
		nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _archives_btn != null:
		_archives_btn.custom_minimum_size = Vector2(w, 52)
	if _desk_btn != null:
		_desk_btn.custom_minimum_size = Vector2(w, 52)


func _ignore_mouse(node: Control) -> void:
	if node != null:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _style_brand(label: Label, text: String) -> void:
	if label == null:
		return
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font: Font = UiAtlas.spaced_font(8)
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", UiAtlas.GOLD_MOLTEN)
	label.add_theme_color_override("font_shadow_color", Color("3a1a0e"))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 8)


func _style_cta_line(label: Label, text: String) -> void:
	if label == null:
		return
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = UiAtlas.spaced_font(2)
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", UiAtlas.PARCHMENT)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)


func _apply_corner(node: TextureRect, tex: Texture2D) -> void:
	if node == null:
		return
	node.texture = tex
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size = Vector2(96, 96)


func _fit_seal() -> void:
	if _seal == null or _stage == null:
		return
	var vmin: float = minf(_stage.size.x, _stage.size.y)
	var side: float = minf(540.0, vmin * 0.62)
	_center_rect(_seal, side, side)
	if _preview != null:
		_center_rect(_preview, 248.0, 248.0)


func _center_rect(node: Control, w: float, h: float) -> void:
	node.anchor_left = 0.5
	node.anchor_top = 0.5
	node.anchor_right = 0.5
	node.anchor_bottom = 0.5
	node.offset_left = -w * 0.5
	node.offset_top = -h * 0.5
	node.offset_right = w * 0.5
	node.offset_bottom = h * 0.5
	node.custom_minimum_size = Vector2(w, h)


func _attach_ninepatch(button: Button, atlas_id: String) -> void:
	var np := button.get_node_or_null("Slice") as NinePatchRect
	if np == null:
		np = NinePatchRect.new()
		np.name = "Slice"
		button.add_child(np)
		button.move_child(np, 0)
	np.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	np.texture = UiAtlas.frame_image(atlas_id, "idle")
	if np.texture == null:
		np.texture = UiAtlas.frame(atlas_id)
	if atlas_id == "btn-cta":
		np.patch_margin_left = 46
		np.patch_margin_top = 43
		np.patch_margin_right = 45
		np.patch_margin_bottom = 26
	elif atlas_id == "btn-plaque":
		np.patch_margin_left = 52
		np.patch_margin_top = 21
		np.patch_margin_right = 48
		np.patch_margin_bottom = 21
	if button.get_meta("slice_wired", false):
		return
	button.set_meta("slice_wired", true)
	button.mouse_entered.connect(func() -> void:
		np.texture = UiAtlas.frame_image(atlas_id, "hover")
	)
	button.mouse_exited.connect(func() -> void:
		np.texture = UiAtlas.frame_image(atlas_id, "idle")
	)
	button.button_down.connect(func() -> void:
		np.texture = UiAtlas.frame_image(atlas_id, "active")
	)
	button.button_up.connect(func() -> void:
		np.texture = UiAtlas.frame_image(atlas_id, "hover" if button.is_hovered() else "idle")
	)


func _empty_sb() -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 8.0
	return sb


func _sync_preview_frame() -> void:
	if _preview == null:
		return
	var tex: Texture2D = UiAtlas.entity_frame(_survivor_id, "idle", _preview_t)
	if tex != null:
		_preview.texture = tex
