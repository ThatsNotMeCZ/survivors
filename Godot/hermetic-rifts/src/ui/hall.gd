class_name HallView
extends Control

signal back_pressed
signal commence_pressed

const SLOTS: Array[String] = ["primary", "secondary", "utility", "special"]
const GLYPHS: Array[String] = ["I", "II", "III", "IV"]
const STAT_ICONS: Array[String] = ["♥", "⚔", "🥾", "🛡"]

var _back_btn: Button
var _brand: Label
var _nav: VBoxContainer
var _nav_arrow: TextureRect
var _preview: TextureRect
var _preview_host: Control
var _backdrop: ColorRect
var _dossier: PanelContainer
var _dossier_header: Label
var _dossier_name: Label
var _dossier_lore: Label
var _stats: GridContainer
var _skills: HBoxContainer
var _tip: PanelContainer
var _tip_name: Label
var _tip_hook: Label
var _tip_lore: Label
var _rite_toggle: Button
var _rite_kicker: Label
var _rite_label: Label
var _rite_switch: Panel
var _rite_knob: ColorRect
var _rite_seed: Label
var _commence_btn: Button
var _commence_1: Label
var _commence_2: Label
var _header: PanelContainer
var _sidebar_bg: ColorRect

var _inspected_id: String = ""
var _preview_t: float = 0.0
var _bound: bool = false
var _locked: bool = false
var _laid_out_size: Vector2 = Vector2.ZERO
var _layout_tries: int = 0


func _ready() -> void:
	_resolve_nodes()
	_apply_chrome()
	_bind()
	call_deferred("_layout_chrome")
	if get_tree() != null and get_tree().current_scene == self:
		call_deferred("refresh")


func _process(dt: float) -> void:
	if not visible:
		return
	_preview_t += dt
	_sync_preview_frame()
	_sync_backdrop()


func _notification(what: int) -> void:
	if not visible:
		return
	if what == NOTIFICATION_VISIBILITY_CHANGED or (what == NOTIFICATION_RESIZED and not size.is_equal_approx(_laid_out_size)):
		_layout_chrome()


func refresh() -> void:
	var app := _app()
	if app == null:
		return
	if _inspected_id == "" or not app.catalog.has_survivor(_inspected_id):
		_inspected_id = String(app.selected_survivor)
	_refresh_nav(app)
	_refresh_dossier(app)
	_refresh_rite(app)
	call_deferred("_layout_chrome")
	_refresh_commence()
	_sync_preview_frame()
	_sync_backdrop()
	call_deferred("focus_primary")


func inspected_id() -> String:
	return _inspected_id


func is_inspected_locked() -> bool:
	return _locked


func focus_primary() -> void:
	if _commence_btn != null and _commence_btn.is_inside_tree() and not _commence_btn.disabled:
		_commence_btn.grab_focus()
		return
	if _back_btn != null and _back_btn.is_inside_tree():
		_back_btn.grab_focus()


func activate_primary() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focused is Button and (focused as Button).is_inside_tree() and is_ancestor_of(focused):
		(focused as Button).emit_signal("pressed")
		return
	if not _locked:
		_play_ui("confirm")
		commence_pressed.emit()


func _app() -> Node:
	return get_node_or_null("/root/App")


func _resolve_nodes() -> void:
	_backdrop = get_node_or_null("Backdrop") as ColorRect
	_sidebar_bg = get_node_or_null("SidebarBg") as ColorRect
	_header = get_node_or_null("Header") as PanelContainer
	_back_btn = get_node_or_null("Header/HeaderRow/BackBtn") as Button
	_brand = get_node_or_null("Header/HeaderRow/Brand") as Label
	_nav = get_node_or_null("Sidebar/Nav") as VBoxContainer
	_nav_arrow = get_node_or_null("Sidebar/NavArrow") as TextureRect
	_preview_host = get_node_or_null("Preview") as Control
	_preview = get_node_or_null("Preview/VesselPreview") as TextureRect
	_dossier = get_node_or_null("Dossier") as PanelContainer
	_dossier_header = get_node_or_null("Dossier/DossierInner/DossierHeader") as Label
	_dossier_name = get_node_or_null("Dossier/DossierInner/DossierName") as Label
	_dossier_lore = get_node_or_null("Dossier/DossierInner/DossierLore") as Label
	_stats = get_node_or_null("Dossier/DossierInner/StatsGrid") as GridContainer
	_skills = get_node_or_null("Dossier/DossierInner/Skills") as HBoxContainer
	_tip = get_node_or_null("SkillTip") as PanelContainer
	_tip_name = get_node_or_null("SkillTip/SkillTipInner/TipName") as Label
	_tip_hook = get_node_or_null("SkillTip/SkillTipInner/TipHook") as Label
	_tip_lore = get_node_or_null("SkillTip/SkillTipInner/TipLore") as Label
	_rite_toggle = get_node_or_null("Rite/RiteToggle") as Button
	_rite_kicker = get_node_or_null("Rite/RiteToggle/RiteRow/RiteCopy/RiteKicker") as Label
	_rite_label = get_node_or_null("Rite/RiteToggle/RiteRow/RiteCopy/RiteLabel") as Label
	_rite_switch = get_node_or_null("Rite/RiteToggle/RiteRow/RiteSwitch") as Panel
	_rite_knob = get_node_or_null("Rite/RiteToggle/RiteRow/RiteSwitch/RiteKnob") as ColorRect
	_rite_seed = get_node_or_null("Rite/RiteSeed") as Label
	_commence_btn = get_node_or_null("CommenceBtn") as Button
	_commence_1 = get_node_or_null("CommenceBtn/CommenceCopy/CommenceLine1") as Label
	_commence_2 = get_node_or_null("CommenceBtn/CommenceCopy/CommenceLine2") as Label


func _apply_chrome() -> void:
	if _backdrop != null:
		move_child(_backdrop, 0)
	if _sidebar_bg != null:
		move_child(_sidebar_bg, 1)
	if _brand != null:
		_brand.text = tr("ui.hall.brand")
		_brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UiAtlas.apply_label(_brand, UiAtlas.TYPE_DISPLAY, UiAtlas.GOLD_MOLTEN, UiAtlas.SIZE_DISPLAY_M)
		_brand.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		_brand.add_theme_constant_override("shadow_offset_y", 2)
	if _back_btn != null:
		UiAtlas.style_medallion_button(_back_btn)
	if _header != null:
		_header.add_theme_stylebox_override("panel", UiAtlas.nine_slice("hall-banner", "idle", Vector4(6, 6, 46, 6)))
	if _dossier != null:
		_dossier.add_theme_stylebox_override("panel", UiAtlas.nine_slice("parchment-panel", "idle", Vector4(36, 34, 36, 32)))
		var inner := get_node_or_null("Dossier/DossierInner") as VBoxContainer
		if inner != null:
			inner.add_theme_constant_override("separation", 12)
			inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fit_rite_row()
	var circle := get_node_or_null("Preview/StageCircle") as ColorRect
	if circle != null:
		circle.visible = false
	var pedestal := get_node_or_null("Preview/Pedestal") as ColorRect
	if pedestal != null:
		pedestal.color = Color(0, 0, 0, 0.0)
	if _nav != null:
		_nav.add_theme_constant_override("separation", 18)
	if _nav_arrow != null:
		_nav_arrow.texture = UiAtlas.frame("nav-arrow")
		_nav_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_nav_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_nav_arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_nav_arrow.custom_minimum_size = Vector2(32, 32)
		_nav_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _preview != null:
		_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _rite_kicker != null:
		_rite_kicker.text = tr("ui.hall.rite.kicker")
		UiAtlas.apply_label(_rite_kicker, UiAtlas.TYPE_MICRO, UiAtlas.ASH, 10)
		_rite_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _rite_label != null:
		_rite_label.text = tr("ui.hall.daily").to_upper()
		UiAtlas.apply_label(_rite_label, UiAtlas.TYPE_META, UiAtlas.PARCHMENT, 13)
		_rite_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _rite_toggle != null:
		_rite_toggle.text = ""
		_style_rite_toggle(false)
	if _rite_seed != null:
		UiAtlas.apply_label(_rite_seed, UiAtlas.TYPE_MICRO, UiAtlas.BRASS, 12)
		_rite_seed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _commence_btn != null:
		UiAtlas.apply_button_styles(_commence_btn, "btn-cta")
	if _commence_1 != null:
		_style_cta_line(_commence_1)
	if _commence_2 != null:
		_style_cta_line(_commence_2)
	if _tip != null:
		_tip.visible = false
		_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tip_sb := StyleBoxFlat.new()
		tip_sb.bg_color = Color("140e12")
		tip_sb.border_color = UiAtlas.BRASS
		tip_sb.set_border_width_all(1)
		tip_sb.content_margin_left = 12.0
		tip_sb.content_margin_right = 12.0
		tip_sb.content_margin_top = 10.0
		tip_sb.content_margin_bottom = 10.0
		tip_sb.shadow_color = Color(0, 0, 0, 0.85)
		tip_sb.shadow_size = 8
		_tip.add_theme_stylebox_override("panel", tip_sb)
	_style_dossier_copy()
	if _backdrop != null:
		var mat: ShaderMaterial = _backdrop.material as ShaderMaterial
		if mat == null:
			var packed: ShaderMaterial = load("res://assets/ui/materials/hall_backdrop.tres") as ShaderMaterial
			if packed != null:
				mat = packed.duplicate() as ShaderMaterial
				_backdrop.material = mat
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _style_dossier_copy() -> void:
	_ink_label(_dossier_header, UiAtlas.SIZE_DISPLAY_S, true)
	_ink_label(_dossier_name, 18, true)
	_ink_label(_dossier_lore, UiAtlas.SIZE_META, false)
	if _dossier_lore != null:
		_dossier_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _stats != null:
		_stats.columns = 2
		_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats.add_theme_constant_override("h_separation", 14)
		_stats.add_theme_constant_override("v_separation", 8)
		_stats.custom_minimum_size = Vector2(0, 52)
	if _skills != null:
		_skills.add_theme_constant_override("separation", 10)
		_skills.alignment = BoxContainer.ALIGNMENT_CENTER


func _ink_label(label: Label, size_px: int, display: bool) -> void:
	if label == null:
		return
	var role: StringName = UiAtlas.TYPE_DISPLAY if display else UiAtlas.TYPE_META
	UiAtlas.apply_ink_label(label, role, UiAtlas.PARCHMENT_INK, size_px)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _style_cta_line(label: Label) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiAtlas.apply_label(label, UiAtlas.TYPE_DISPLAY, UiAtlas.PARCHMENT, UiAtlas.SIZE_CTA)


func _bind() -> void:
	if _bound:
		return
	_bound = true
	if _back_btn != null:
		_back_btn.pressed.connect(_on_back)
		_back_btn.mouse_entered.connect(_on_back_hover.bind(true))
		_back_btn.mouse_exited.connect(_on_back_hover.bind(false))
	if _rite_toggle != null:
		_rite_toggle.pressed.connect(_on_rite)
	if _commence_btn != null:
		_commence_btn.pressed.connect(_on_commence)


func _on_back() -> void:
	_play_ui("close")
	back_pressed.emit()


func _on_back_hover(on: bool) -> void:
	UiAtlas.tween_medallion_hover(self, _back_btn, on)


func _on_rite() -> void:
	var app := _app()
	if app == null:
		return
	_play_ui("click")
	app.settings.daily_rite = not app.settings.daily_rite
	app.settings.save()
	_refresh_rite(app)


func _on_commence() -> void:
	if _locked:
		_play_ui("error")
		return
	_play_ui("confirm")
	commence_pressed.emit()


func _refresh_nav(app: Node) -> void:
	if _nav == null:
		return
	for child: Node in _nav.get_children():
		_nav.remove_child(child)
		child.queue_free()
	var rec: ArchiveRecords = app.records
	var catalog: Catalog = app.catalog
	for surv: Dictionary in catalog.survivors:
		var sid: String = String(surv.get("id", ""))
		var unlock: Dictionary = rec.check_unlock(surv.get("unlock", null), catalog)
		var unlocked: bool = bool(unlock.get("unlocked", true))
		var btn := Button.new()
		btn.name = sid
		btn.custom_minimum_size = Vector2(154, 150)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = false
		var active: bool = sid == _inspected_id
		_style_vessel_pick(btn, active, unlocked)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 8.0
		col.offset_right = -8.0
		col.offset_top = 8.0
		col.offset_bottom = -10.0
		col.add_theme_constant_override("separation", 8)
		var portrait := PanelContainer.new()
		portrait.custom_minimum_size = Vector2(0, 112)
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var well := StyleBoxFlat.new()
		well.bg_color = Color("120f14")
		well.border_color = Color(0.769, 0.639, 0.353, 0.35)
		well.set_border_width_all(1)
		portrait.add_theme_stylebox_override("panel", well)
		var art := TextureRect.new()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_meta("hall_anim", sid)
		art.modulate = Color.WHITE if unlocked else Color(0.0, 0.0, 0.0, 0.38)
		var tex: Texture2D = UiAtlas.entity_frame(sid, "idle", 0.0)
		if tex != null:
			art.texture = tex
		portrait.add_child(art)
		col.add_child(portrait)
		var plate := Label.new()
		plate.text = Loc.survivor_name(sid).to_upper() if unlocked else tr("ui.hall.???")
		plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiAtlas.apply_label(plate, UiAtlas.TYPE_META, UiAtlas.PARCHMENT if unlocked else UiAtlas.ASH, 12)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(plate)
		btn.add_child(col)
		var captured: String = sid
		var captured_unlocked: bool = unlocked
		btn.pressed.connect(func() -> void: _select_vessel(captured, captured_unlocked))
		_nav.add_child(btn)
	_wire_nav_focus()


func _select_vessel(sid: String, unlocked: bool) -> void:
	_play_ui("click")
	_inspected_id = sid
	var app := _app()
	if unlocked and app != null:
		app.selected_survivor = sid
		app.settings.survivor_id = sid
		app.settings.save()
	refresh()


func _style_vessel_pick(btn: Button, active: bool, unlocked: bool) -> void:
	var bg := Color("3a241c") if active else (Color("161319") if not unlocked else Color("1c191e"))
	var border := UiAtlas.GOLD_MOLTEN if active else (Color("35303b") if not unlocked else Color("585c66"))
	var hover := _pick_sb(Color("2a221c"), UiAtlas.BRASS_BRIGHT, active)
	btn.add_theme_stylebox_override("normal", _pick_sb(bg, border, active))
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", _pick_sb(Color("3a241c"), UiAtlas.GOLD_MOLTEN, true))
	btn.add_theme_stylebox_override("focus", UiAtlas.empty_focus())
	btn.add_theme_color_override("font_color", Color(0, 0, 0, 0))


func _pick_sb(bg: Color, border: Color, glow: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.content_margin_left = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 0.0
	if glow:
		sb.shadow_color = Color("d48c4273")
		sb.shadow_size = 8
	return sb


func _refresh_dossier(app: Node) -> void:
	var catalog: Catalog = app.catalog
	var rec: ArchiveRecords = app.records
	var surv: Dictionary = catalog.survivor(_inspected_id) if catalog.has_survivor(_inspected_id) else {}
	var unlock: Dictionary = rec.check_unlock(surv.get("unlock", null), catalog)
	_locked = not bool(unlock.get("unlocked", true))
	if _dossier_header != null:
		_dossier_header.text = tr("ui.hall.dossier.sealed") if _locked else tr("ui.hall.dossier.header")
	if _dossier_name != null:
		_dossier_name.text = tr("ui.prompt.???") if _locked else Loc.survivor_name(_inspected_id).to_upper()
	if _dossier_lore != null:
		if _locked:
			_dossier_lore.text = tr("ui.hall.unsealing").replace("{label}", String(unlock.get("label", ""))).replace("{progress}", String(unlock.get("progress", "")))
			_style_locked_lore(_dossier_lore, true)
		else:
			_dossier_lore.text = Loc.survivor_lore(_inspected_id)
			_style_locked_lore(_dossier_lore, false)
	_fill_stats(surv, unlock)
	_fill_skills(surv)
	if _preview != null:
		_preview.modulate = Color(0.0, 0.0, 0.0, 0.38) if _locked else Color.WHITE


func _style_locked_lore(label: Label, locked: bool) -> void:
	if locked:
		label.add_theme_color_override("font_color", Color("d6c5a6"))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("0e0b10db")
		sb.border_color = Color(0.769, 0.639, 0.353, 0.45)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.content_margin_left = 12.0
		sb.content_margin_right = 12.0
		sb.content_margin_top = 10.0
		sb.content_margin_bottom = 10.0
		label.add_theme_stylebox_override("normal", sb)
	else:
		label.add_theme_color_override("font_color", Color("2c2016"))
		label.remove_theme_stylebox_override("normal")


func _fill_stats(surv: Dictionary, unlock: Dictionary) -> void:
	if _stats == null:
		return
	for child: Node in _stats.get_children():
		_stats.remove_child(child)
		child.queue_free()
	var texts: Array[String] = []
	if _locked:
		texts = [
			tr("ui.hall.stat.vitality.hidden"),
			tr("ui.hall.stat.role.hidden"),
			tr("ui.hall.stat.stride.hidden"),
			tr("ui.hall.stat.seal").replace("{n}", String(unlock.get("progress", ""))),
		]
	else:
		var stats: Dictionary = DictUtil.d(surv, "stats")
		var speed: float = float(stats.get("speed", 0))
		var stride: String = tr("ui.hall.stat.stride.swift") if speed >= 260.0 else tr("ui.hall.stat.stride.measured")
		texts = [
			tr("ui.hall.stat.vitality").replace("{n}", str(int(stats.get("maxHp", 0)))),
			Loc.survivor_title(_inspected_id).to_upper(),
			stride,
			tr("ui.hall.stat.frame"),
		]
	for i: int in texts.size():
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size = Vector2(150, 22)
		var ic := Label.new()
		ic.text = STAT_ICONS[i]
		UiAtlas.apply_ink_label(ic, UiAtlas.TYPE_META, Color("6e3b1e"), 14)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tx := Label.new()
		tx.text = texts[i]
		UiAtlas.apply_ink_label(tx, UiAtlas.TYPE_META, UiAtlas.PARCHMENT_INK, 12)
		tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tx.autowrap_mode = TextServer.AUTOWRAP_OFF
		tx.clip_text = false
		tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(ic)
		cell.add_child(tx)
		_stats.add_child(cell)


func _fill_skills(surv: Dictionary) -> void:
	if _skills == null:
		return
	for child: Node in _skills.get_children():
		_skills.remove_child(child)
		child.queue_free()
	var skills: Dictionary = DictUtil.d(surv, "skills")
	for i: int in SLOTS.size():
		var slot: String = SLOTS[i]
		var skill_id: String = String(skills.get(slot, ""))
		var unit := VBoxContainer.new()
		unit.add_theme_constant_override("separation", 6)
		unit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(58, 58)
		cell.focus_mode = Control.FOCUS_ALL
		var empty: bool = _locked or skill_id == ""
		_style_skill_cell(cell, empty)
		if empty:
			cell.text = "?" if _locked else "—"
			cell.disabled = true
		else:
			cell.text = ""
			var icon := TextureRect.new()
			icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 6.0
			icon.offset_top = 6.0
			icon.offset_right = -6.0
			icon.offset_bottom = -6.0
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tex: Texture2D = UiAtlas.skill_tex(skill_id)
			if tex != null:
				icon.texture = tex
			else:
				var glyph := Label.new()
				glyph.text = GLYPHS[i]
				glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				UiAtlas.apply_label(glyph, UiAtlas.TYPE_META, UiAtlas.PARCHMENT, 14)
				glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cell.add_child(glyph)
			cell.add_child(icon)
			var captured: String = skill_id
			cell.mouse_entered.connect(func() -> void: _show_tip(cell, captured))
			cell.mouse_exited.connect(_hide_tip)
			cell.focus_entered.connect(func() -> void: _show_tip(cell, captured))
			cell.focus_exited.connect(_hide_tip)
		var lab := Label.new()
		if empty:
			lab.text = tr("ui.prompt.???") if _locked else tr("ui.hall.skill.empty")
		else:
			lab.text = Loc.skill_name(skill_id)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiAtlas.apply_ink_label(lab, UiAtlas.TYPE_MICRO, UiAtlas.PARCHMENT_INK, 11)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unit.add_child(cell)
		unit.add_child(lab)
		_skills.add_child(unit)


func _style_skill_cell(btn: Button, locked: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("181214")
	sb.border_color = Color("5c4224")
	sb.set_border_width_all(2)
	if locked:
		sb.border_color = Color("5c4224")
	var hover := sb.duplicate() as StyleBoxFlat
	hover.border_color = UiAtlas.BRASS_BRIGHT
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", UiAtlas.empty_focus())
	btn.add_theme_stylebox_override("disabled", sb)
	btn.add_theme_color_override("font_color", UiAtlas.PARCHMENT)
	btn.add_theme_color_override("font_disabled_color", UiAtlas.ASH)
	btn.modulate = Color(1, 1, 1, 0.5) if locked else Color.WHITE


func _show_tip(anchor: Control, skill_id: String) -> void:
	if _tip == null:
		return
	if _tip_name != null:
		_tip_name.text = Loc.skill_name(skill_id)
		UiAtlas.apply_label(_tip_name, UiAtlas.TYPE_META, UiAtlas.GOLD_MOLTEN, 14)
	if _tip_hook != null:
		_tip_hook.text = Loc.skill_hook(skill_id)
		UiAtlas.apply_label(_tip_hook, UiAtlas.TYPE_META, UiAtlas.PARCHMENT, 12)
		_tip_hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _tip_lore != null:
		_tip_lore.text = Loc.skill_lore(skill_id)
		UiAtlas.apply_label(_tip_lore, UiAtlas.TYPE_META, UiAtlas.ASH, 12)
		_tip_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.visible = true
	_tip.reset_size()
	var pos: Vector2 = anchor.global_position - global_position
	_tip.position = Vector2(pos.x + anchor.size.x - 220.0, pos.y - _tip.size.y - 10.0)
	if _tip.position.x < 8.0:
		_tip.position.x = 8.0
	if _tip.position.y < 8.0:
		_tip.position.y = pos.y + anchor.size.y + 10.0


func _hide_tip() -> void:
	if _tip != null:
		_tip.visible = false


func _refresh_rite(app: Node) -> void:
	var on: bool = bool(app.settings.daily_rite)
	_style_rite_toggle(on)
	if _rite_seed == null:
		return
	if on:
		var date: String = SimRng.utc_ymd()
		_rite_seed.text = tr("ui.hall.rite.seed.on").replace("{tag}", SimRng.format_seed_tag(SimRng.daily_seed(date))).replace("{date}", date)
	else:
		_rite_seed.text = tr("ui.hall.rite.seed.random")


func _style_rite_toggle(on: bool) -> void:
	if _rite_toggle == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("140e12eb")
	sb.border_color = UiAtlas.BRASS_BRIGHT if on else UiAtlas.BRASS
	sb.set_border_width_all(1)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 8
	_rite_toggle.add_theme_stylebox_override("normal", sb)
	_rite_toggle.add_theme_stylebox_override("hover", sb)
	_rite_toggle.add_theme_stylebox_override("pressed", sb)
	_rite_toggle.add_theme_stylebox_override("focus", sb)
	if _rite_switch != null:
		var track := StyleBoxFlat.new()
		track.bg_color = Color("5c2418") if on else Color("2a242c")
		track.border_color = Color("b82934") if on else UiAtlas.BRASS_DIM
		track.set_border_width_all(1)
		track.corner_radius_top_left = 2
		track.corner_radius_top_right = 2
		track.corner_radius_bottom_left = 2
		track.corner_radius_bottom_right = 2
		_rite_switch.add_theme_stylebox_override("panel", track)
		_rite_switch.custom_minimum_size = Vector2(18, 18)
		_rite_switch.custom_maximum_size = Vector2(18, 18)
		_rite_switch.propagate_maximum_size = true
		_rite_switch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_rite_switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _rite_knob != null:
		_rite_knob.color = UiAtlas.GOLD_MOLTEN if on else Color(0.12, 0.1, 0.12, 0.0)
		_rite_knob.position = Vector2(3, 3)
		_rite_knob.size = Vector2(12, 12)
		_rite_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh_commence() -> void:
	if _commence_1 != null:
		_commence_1.text = tr("ui.hall.sealed.line1") if _locked else tr("ui.hall.commence.line1")
	if _commence_2 != null:
		_commence_2.text = tr("ui.hall.sealed.line2") if _locked else tr("ui.hall.commence.line2")
	if _commence_btn != null:
		_commence_btn.disabled = _locked
		_commence_btn.modulate = Color(1, 1, 1, 0.55) if _locked else Color.WHITE


func _sync_preview_frame() -> void:
	if _preview == null or _inspected_id == "":
		return
	var tex: Texture2D = UiAtlas.entity_frame(_inspected_id, "idle", _preview_t)
	if tex != null:
		_preview.texture = tex
	_place_ground_light()
	_sync_nav_frames()


func _sync_nav_frames() -> void:
	if _nav == null:
		return
	_sync_anim_in(_nav)


func _sync_anim_in(node: Node) -> void:
	if node is TextureRect and node.has_meta("hall_anim"):
		var rect := node as TextureRect
		var tex: Texture2D = UiAtlas.entity_frame(String(rect.get_meta("hall_anim")), "idle", _preview_t)
		if tex != null:
			rect.texture = tex
	for child: Node in node.get_children():
		_sync_anim_in(child)


func _sync_backdrop() -> void:
	if _backdrop == null:
		return
	var mat := _backdrop.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("u_res", size)
	mat.set_shader_parameter("u_locked", 1.0 if _locked else 0.0)
	if size.x > 1.0 and size.y > 1.0:
		mat.set_shader_parameter("u_center", _preview_feet_in_hall() / size)


func _layout_chrome() -> void:
	if size.x < 8.0 or size.y < 8.0:
		_layout_tries += 1
		if _layout_tries < 8:
			call_deferred("_layout_chrome")
		return
	_place_header()
	_place_sidebar()
	_place_preview()
	_place_dossier()
	_place_rite()
	_place_cta()
	_layout_tries = 0
	_laid_out_size = size


func _place_header() -> void:
	if _header == null:
		return
	_header.anchor_left = 0.0
	_header.anchor_top = 0.0
	_header.anchor_right = 0.0
	_header.anchor_bottom = 0.0
	_header.offset_left = 0.0
	_header.offset_top = 0.0
	_header.offset_right = 420.0
	_header.offset_bottom = 64.0
	_header.custom_minimum_size = Vector2(320, 64)


func _place_sidebar() -> void:
	var sidebar := get_node_or_null("Sidebar") as Control
	if sidebar != null:
		sidebar.anchor_left = 0.0
		sidebar.anchor_top = 0.0
		sidebar.anchor_right = 0.0
		sidebar.anchor_bottom = 1.0
		sidebar.offset_left = 0.0
		sidebar.offset_top = 64.0
		sidebar.offset_right = 230.0
		sidebar.offset_bottom = 0.0
	if _sidebar_bg != null:
		_sidebar_bg.anchor_left = 0.0
		_sidebar_bg.anchor_top = 0.0
		_sidebar_bg.anchor_right = 0.0
		_sidebar_bg.anchor_bottom = 1.0
		_sidebar_bg.offset_left = 0.0
		_sidebar_bg.offset_top = 64.0
		_sidebar_bg.offset_right = 230.0
		_sidebar_bg.offset_bottom = 0.0
		_sidebar_bg.color = Color("0e0c10e6")
		_sidebar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _place_preview() -> void:
	if _preview_host == null:
		return
	_preview_host.anchor_left = 0.0
	_preview_host.anchor_top = 0.0
	_preview_host.anchor_right = 1.0
	_preview_host.anchor_bottom = 1.0
	_preview_host.offset_left = 230.0
	_preview_host.offset_top = 0.0
	_preview_host.offset_right = -380.0
	_preview_host.offset_bottom = 0.0
	if _preview != null:
		_center_rect(_preview, 280.0, 280.0)
	_place_ground_light()


func _place_dossier() -> void:
	if _dossier == null:
		return
	const MARGIN_R: float = 32.0
	const WIDTH: float = 378.0
	const CLEAR_BOTTOM: float = 228.0
	const MARGIN_TOP: float = 24.0
	_dossier.anchor_left = 1.0
	_dossier.anchor_top = 0.0
	_dossier.anchor_right = 1.0
	_dossier.anchor_bottom = 0.0
	_dossier.offset_left = -MARGIN_R - WIDTH
	_dossier.offset_right = -MARGIN_R
	_dossier.custom_minimum_size = Vector2(WIDTH, 0)
	_dossier.reset_size()
	var h: float = maxf(_dossier.get_combined_minimum_size().y, 320.0)
	var max_h: float = maxf(size.y - MARGIN_TOP - CLEAR_BOTTOM, 240.0)
	h = minf(h, max_h)
	var top: float = MARGIN_TOP + maxf(0.0, (size.y - MARGIN_TOP - CLEAR_BOTTOM - h) * 0.5)
	_dossier.offset_top = top
	_dossier.offset_bottom = top + h


func _place_rite() -> void:
	var rite := get_node_or_null("Rite") as Control
	if rite == null:
		return
	if rite is VBoxContainer:
		(rite as VBoxContainer).alignment = BoxContainer.ALIGNMENT_END
		(rite as VBoxContainer).add_theme_constant_override("separation", 8)
	if _rite_toggle != null:
		_rite_toggle.custom_minimum_size = Vector2(280, 52)
		_rite_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rite_toggle.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_rite_toggle.clip_contents = true
	_fit_rite_row()
	if _rite_seed != null:
		_rite_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rite_seed.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rite.custom_minimum_size = Vector2(280, 0)
	rite.reset_size()
	var h: float = rite.get_combined_minimum_size().y
	if h < 52.0:
		h = 52.0
	rite.anchor_left = 1.0
	rite.anchor_top = 1.0
	rite.anchor_right = 1.0
	rite.anchor_bottom = 1.0
	rite.offset_right = -28.0
	rite.offset_bottom = -132.0
	rite.offset_left = -28.0 - 280.0
	rite.offset_top = -132.0 - h
	rite.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rite.grow_vertical = Control.GROW_DIRECTION_BEGIN
	move_child(rite, get_child_count() - 1)


func _fit_rite_row() -> void:
	var rite_row := get_node_or_null("Rite/RiteToggle/RiteRow") as Control
	if rite_row == null:
		return
	rite_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rite_row.offset_left = 14.0
	rite_row.offset_right = -14.0
	rite_row.offset_top = 10.0
	rite_row.offset_bottom = -10.0
	rite_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rite_row is HBoxContainer:
		(rite_row as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
		(rite_row as HBoxContainer).add_theme_constant_override("separation", 16)
	var rite_copy := get_node_or_null("Rite/RiteToggle/RiteRow/RiteCopy") as Control
	if rite_copy != null:
		rite_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rite_copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rite_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _rite_switch != null:
		_rite_switch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_rite_switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_rite_switch.custom_minimum_size = Vector2(18, 18)
		_rite_switch.custom_maximum_size = Vector2(18, 18)
		_rite_switch.propagate_maximum_size = true
		_rite_switch.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _place_ground_light() -> void:
	if _preview_host == null:
		return
	var feet_host: Vector2 = _preview_feet_in_host()
	var circle := get_node_or_null("Preview/StageCircle") as Control
	if circle != null:
		circle.visible = false
		_center_at(circle, feet_host, Vector2(340, 340))
	var pedestal := get_node_or_null("Preview/Pedestal") as Control
	if pedestal != null:
		pedestal.visible = false
		_center_at(pedestal, feet_host, Vector2(240, 46))


func _preview_feet_in_host() -> Vector2:
	if _preview == null:
		return _preview_host.size * Vector2(0.5, 0.62)
	var box: Vector2 = _preview.size
	var pos: Vector2 = _preview.position
	var tex: Texture2D = _preview.texture
	if tex == null or box.x <= 1.0 or box.y <= 1.0:
		return pos + Vector2(box.x * 0.5, box.y)
	var ts := Vector2(float(tex.get_width()), float(tex.get_height()))
	if ts.x < 1.0 or ts.y < 1.0:
		return pos + Vector2(box.x * 0.5, box.y)
	var s: float = minf(box.x / ts.x, box.y / ts.y)
	var drawn: Vector2 = ts * s
	var origin: Vector2 = pos + (box - drawn) * 0.5
	return origin + Vector2(drawn.x * 0.5, drawn.y)


func _preview_feet_in_hall() -> Vector2:
	if _preview_host == null:
		return size * Vector2(0.5, 0.62)
	return (_preview_host.global_position - global_position) + _preview_feet_in_host()


func _center_at(node: Control, center: Vector2, wh: Vector2) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = center.x - wh.x * 0.5
	node.offset_top = center.y - wh.y * 0.5
	node.offset_right = center.x + wh.x * 0.5
	node.offset_bottom = center.y + wh.y * 0.5
	node.custom_minimum_size = wh


func _place_cta() -> void:
	if _commence_btn == null:
		return
	const PAD_L: float = 28.0
	const PAD_R: float = 28.0
	const PAD_T: float = 36.0
	const PAD_B: float = 22.0
	var copy := _commence_btn.get_node_or_null("CommenceCopy") as VBoxContainer
	if copy != null:
		copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		copy.offset_left = PAD_L
		copy.offset_top = PAD_T
		copy.offset_right = -PAD_R
		copy.offset_bottom = -PAD_B
		copy.alignment = BoxContainer.ALIGNMENT_CENTER
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w: float = 240.0
	var h: float = 96.0
	_commence_btn.anchor_left = 1.0
	_commence_btn.anchor_top = 1.0
	_commence_btn.anchor_right = 1.0
	_commence_btn.anchor_bottom = 1.0
	_commence_btn.offset_right = -28.0
	_commence_btn.offset_bottom = -24.0
	_commence_btn.offset_left = -28.0 - w
	_commence_btn.offset_top = -24.0 - h
	_commence_btn.custom_minimum_size = Vector2(w, h)
	_commence_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_commence_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	move_child(_commence_btn, get_child_count() - 1)


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


func _wire_nav_focus() -> void:
	if _back_btn == null or _nav == null or _nav.get_child_count() == 0:
		return
	var first: Control = _nav.get_child(0) as Control
	if first != null:
		_back_btn.focus_neighbor_bottom = _back_btn.get_path_to(first)
		first.focus_neighbor_top = first.get_path_to(_back_btn)
	for i: int in _nav.get_child_count():
		var btn: Control = _nav.get_child(i) as Control
		if btn == null:
			continue
		if i + 1 < _nav.get_child_count():
			var nxt: Control = _nav.get_child(i + 1) as Control
			btn.focus_neighbor_bottom = btn.get_path_to(nxt)
			nxt.focus_neighbor_top = nxt.get_path_to(btn)
		if _commence_btn != null:
			btn.focus_neighbor_right = btn.get_path_to(_commence_btn)


func _play_ui(kind: String) -> void:
	var bus := get_node_or_null("/root/GameAudio")
	if bus != null:
		bus.play_ui(kind)
