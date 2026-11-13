class_name MainMenuView
extends Control

signal archives_pressed
signal desk_pressed
signal commence_pressed

var _archives_btn: Button
var _desk_btn: Button
var _commence_btn: Button
var _commence_1: Label
var _commence_2: Label
var _brand: Control
var _brand_1: Label
var _brand_2: Label
var _seal: TextureRect
var _preview: TextureRect
var _stage: Control

var _preview_t: float = 0.0
var _survivor_id: String = "runner"
var _bound: bool = false
var _laid_out_size: Vector2 = Vector2.ZERO
var _layout_tries: int = 0


func _ready() -> void:
	_resolve_nodes()
	_flatten_seal_texture()
	_apply_copy()
	_bind()
	refresh_preview()
	_layout_tries = 0
	call_deferred("_layout_chrome")
	call_deferred("_wire_focus")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	if not _is_focus_request(event):
		return
	focus_primary()


func _notification(what: int) -> void:
	if not visible:
		return
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_layout_chrome()
		return
	if what == NOTIFICATION_RESIZED and not size.is_equal_approx(_laid_out_size):
		_layout_chrome()


func _process(dt: float) -> void:
	if not visible:
		return
	_preview_t += dt
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


func _is_focus_request(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventJoypadButton:
		return true
	return (
		event.is_action("ui_up")
		or event.is_action("ui_down")
		or event.is_action("ui_left")
		or event.is_action("ui_right")
		or event.is_action("ui_focus_next")
		or event.is_action("ui_focus_prev")
		or event.is_action("ui_accept")
	)


func _resolve_nodes() -> void:
	_archives_btn = get_node_or_null("Content/Row/Pillar/PillarPad/PillarCol/NavWrap/Nav/ArchivesBtn") as Button
	_desk_btn = get_node_or_null("Content/Row/Pillar/PillarPad/PillarCol/NavWrap/Nav/DeskBtn") as Button
	_commence_btn = get_node_or_null("CommenceBtn") as Button
	_commence_1 = get_node_or_null("CommenceBtn/CommenceCopy/CommenceLine1") as Label
	_commence_2 = get_node_or_null("CommenceBtn/CommenceCopy/CommenceLine2") as Label
	_brand = get_node_or_null("Content/Row/Pillar/Brand") as Control
	_brand_1 = get_node_or_null("Content/Row/Pillar/Brand/BrandLine1") as Label
	_brand_2 = get_node_or_null("Content/Row/Pillar/Brand/BrandLine2") as Label
	_seal = get_node_or_null("Content/Row/Stage/Seal") as TextureRect
	_preview = get_node_or_null("Content/Row/Stage/Preview") as TextureRect
	_stage = get_node_or_null("Content/Row/Stage") as Control


func _apply_copy() -> void:
	if _brand != null:
		_brand.visible = true
	_style_brand(_brand_1, tr("ui.menu.brand.line1"))
	_style_brand(_brand_2, tr("ui.menu.brand.line2"))
	if _archives_btn != null:
		_archives_btn.text = tr("ui.menu.archives").to_upper()
	if _desk_btn != null:
		_desk_btn.text = tr("ui.menu.desk").to_upper()
	_style_cta_line(_commence_1, tr("ui.menu.commence.line1"))
	_style_cta_line(_commence_2, tr("ui.menu.commence.line2"))


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


func _style_brand(label: Label, text: String) -> void:
	if label == null:
		return
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UiAtlas.spaced_font(8))
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
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _place_cta() -> void:
	if _commence_btn == null:
		return
	const PAD_L: float = 28.0
	const PAD_R: float = 28.0
	const PAD_T: float = 36.0
	const PAD_B: float = 22.0
	const MIN_W: float = 240.0
	const MIN_H: float = 96.0
	var copy := _commence_btn.get_node_or_null("CommenceCopy") as VBoxContainer
	if copy != null:
		copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		copy.offset_left = PAD_L
		copy.offset_top = PAD_T
		copy.offset_right = -PAD_R
		copy.offset_bottom = -PAD_B
		copy.alignment = BoxContainer.ALIGNMENT_CENTER
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_w: float = 0.0
	var text_h: float = 0.0
	if _commence_1 != null:
		var s1: Vector2 = _commence_1.get_minimum_size()
		text_w = maxf(text_w, s1.x)
		text_h += s1.y
	if _commence_2 != null:
		var s2: Vector2 = _commence_2.get_minimum_size()
		text_w = maxf(text_w, s2.x)
		text_h += s2.y
	if copy != null:
		text_h += float(copy.get_theme_constant("separation"))
	var w: float = maxf(MIN_W, text_w + PAD_L + PAD_R)
	var h: float = maxf(MIN_H, text_h + PAD_T + PAD_B)
	_commence_btn.clip_contents = false
	_commence_btn.anchor_left = 1.0
	_commence_btn.anchor_top = 1.0
	_commence_btn.anchor_right = 1.0
	_commence_btn.anchor_bottom = 1.0
	_commence_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_commence_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var left: float = -28.0 - w
	var top: float = -24.0 - h
	if not is_equal_approx(_commence_btn.offset_left, left) or not is_equal_approx(_commence_btn.offset_top, top):
		_commence_btn.offset_right = -28.0
		_commence_btn.offset_bottom = -24.0
		_commence_btn.offset_left = left
		_commence_btn.offset_top = top
	if not _commence_btn.custom_minimum_size.is_equal_approx(Vector2(w, h)):
		_commence_btn.custom_minimum_size = Vector2(w, h)


func _wire_focus() -> void:
	if _archives_btn == null or _desk_btn == null or _commence_btn == null:
		return
	if not _archives_btn.is_inside_tree() or not _desk_btn.is_inside_tree() or not _commence_btn.is_inside_tree():
		return
	_archives_btn.focus_neighbor_bottom = _archives_btn.get_path_to(_desk_btn)
	_desk_btn.focus_neighbor_top = _desk_btn.get_path_to(_archives_btn)
	_desk_btn.focus_neighbor_bottom = _desk_btn.get_path_to(_commence_btn)
	_commence_btn.focus_neighbor_top = _commence_btn.get_path_to(_desk_btn)
	_commence_btn.focus_neighbor_left = _commence_btn.get_path_to(_desk_btn)


func _layout_chrome() -> void:
	if size.x < 8.0 or size.y < 8.0:
		_layout_tries += 1
		if _layout_tries < 8:
			call_deferred("_layout_chrome")
		return
	_place_cta()
	var nav_ok: bool = _fit_nav()
	var seal_ok: bool = _fit_seal()
	if not nav_ok or not seal_ok:
		_layout_tries += 1
		if _layout_tries < 8:
			call_deferred("_layout_chrome")
		return
	_layout_tries = 0
	_laid_out_size = size


func _fit_nav() -> bool:
	var nav_wrap := get_node_or_null("Content/Row/Pillar/PillarPad/PillarCol/NavWrap") as Control
	if nav_wrap == null:
		return true
	var w: float = nav_wrap.size.x
	if w < 8.0:
		return false
	var nav := get_node_or_null("Content/Row/Pillar/PillarPad/PillarCol/NavWrap/Nav") as Control
	if nav != null:
		if not is_equal_approx(nav.custom_minimum_size.x, w):
			nav.custom_minimum_size = Vector2(w, 0)
		nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _archives_btn != null and not is_equal_approx(_archives_btn.custom_minimum_size.x, w):
		_archives_btn.custom_minimum_size = Vector2(w, 52)
	if _desk_btn != null and not is_equal_approx(_desk_btn.custom_minimum_size.x, w):
		_desk_btn.custom_minimum_size = Vector2(w, 52)
	return true


func _fit_seal() -> bool:
	if _seal == null or _stage == null:
		return true
	if _stage.size.x < 8.0 or _stage.size.y < 8.0:
		return false
	var vmin: float = minf(_stage.size.x, _stage.size.y)
	var side: float = minf(540.0, vmin * 0.62)
	_center_rect(_seal, side, side)
	if _preview != null:
		_center_rect(_preview, 248.0, 248.0)
	return true


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


func _sync_preview_frame() -> void:
	if _preview == null:
		return
	var tex: Texture2D = UiAtlas.entity_frame(_survivor_id, "idle", _preview_t)
	if tex != null:
		_preview.texture = tex


func _flatten_seal_texture() -> void:
	if _seal == null:
		return
	var atlas := _seal.texture as AtlasTexture
	if atlas == null or atlas.atlas == null:
		return
	var src: Image = atlas.atlas.get_image()
	if src == null:
		return
	var region: Rect2 = atlas.region
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return
	var cropped: Image = src.get_region(Rect2i(int(region.position.x), int(region.position.y), int(region.size.x), int(region.size.y)))
	cropped.fix_alpha_edges()
	_seal.texture = ImageTexture.create_from_image(cropped)
