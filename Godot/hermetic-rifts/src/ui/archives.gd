class_name ArchivesView
extends Control

signal back_pressed

const TAB_IDS: Array[StringName] = [&"howto", &"lore", &"entities", &"reliquary", &"stats"]
const TAB_GLYPHS: Array[String] = ["⚶", "☉", "🜂", "🜍", "☿"]

var _back_btn: Button
var _kicker: Label
var _title: Label
var _ribbon: Dictionary = {}
var _nav: VBoxContainer
var _tab_btns: Dictionary = {}
var _foot: Label
var _stage_scroll: ScrollContainer
var _stage_inner: VBoxContainer
var _split_host: Control
var _split_grid: VBoxContainer
var _dossier: VBoxContainer
var _header: HBoxContainer
var _header_bg: ColorRect
var _header_rule: ColorRect
var _ribbon_host: HBoxContainer
var _back_hover: bool = false

var _tab: StringName = &"howto"
var _lore_sub: StringName = &"work"
var _howto_vessel: String = ""
var _entity_filter: String = "all"
var _selected_entity: String = ""
var _item_rarity: String = "all"
var _selected_item: String = ""
var _confirm_purge: bool = false
var _anim_t: float = 0.0
var _bound: bool = false


func _ready() -> void:
	_resolve_nodes()
	_apply_copy()
	_bind()
	call_deferred("_wire_focus")
	if get_tree() != null and get_tree().current_scene == self:
		_tab = &"entities"
		call_deferred("refresh")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_header_chrome()


func _process(dt: float) -> void:
	if not visible:
		return
	_anim_t += dt
	_sync_anim_frames()


func refresh() -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	var rec: ArchiveRecords = app.records
	var catalog: Catalog = app.catalog
	if _howto_vessel == "":
		_howto_vessel = String(app.selected_survivor)
	var surv: Dictionary = catalog.survivor(_howto_vessel) if catalog.has_survivor(_howto_vessel) else {}
	if surv.is_empty() or not bool(rec.check_unlock(surv.get("unlock", null), catalog).get("unlocked", true)):
		_howto_vessel = String(catalog.world.get("defaultSurvivor", "runner"))
	if _selected_entity == "" and not catalog.entities.is_empty():
		_selected_entity = String(catalog.entities[0].get("id", ""))
	if _selected_item == "" and not catalog.items.is_empty():
		_selected_item = String(catalog.items[0].get("id", ""))
	_refresh_ribbon(rec, catalog)
	_refresh_tabs()
	if _stage_inner != null and _stage_scroll != null:
		var gutter: float = 28.0
		var vbar: VScrollBar = _stage_scroll.get_v_scroll_bar()
		if vbar != null:
			gutter = maxf(gutter, vbar.get_combined_minimum_size().x + 12.0)
		_stage_inner.custom_minimum_size.x = maxf(0.0, _stage_scroll.size.x - gutter)
	_rebuild_stage(rec, catalog)
	call_deferred("focus_primary")


func handle_back() -> bool:
	if _confirm_purge:
		_confirm_purge = false
		refresh()
		return true
	return false


func focus_primary() -> void:
	if _back_btn != null and _back_btn.is_inside_tree():
		_back_btn.grab_focus()


func _resolve_nodes() -> void:
	_header = get_node_or_null("Shell/Header") as HBoxContainer
	_header_bg = get_node_or_null("HeaderBg") as ColorRect
	_back_btn = get_node_or_null("Shell/Header/BrandGroup/BackBtn") as Button
	_kicker = get_node_or_null("Shell/Header/BrandGroup/TitleWrap/Kicker") as Label
	_title = get_node_or_null("Shell/Header/BrandGroup/TitleWrap/Title") as Label
	_ribbon_host = get_node_or_null("Shell/Header/Ribbon") as HBoxContainer
	_nav = get_node_or_null("Shell/Body/Sidebar/Nav") as VBoxContainer
	_foot = get_node_or_null("Shell/Body/Sidebar/Foot") as Label
	_stage_scroll = get_node_or_null("Shell/Body/StageHost/StageScroll") as ScrollContainer
	_stage_inner = get_node_or_null("Shell/Body/StageHost/StageScroll/StageInner") as VBoxContainer
	_split_host = get_node_or_null("Shell/Body/StageHost/SplitHost") as Control
	_split_grid = get_node_or_null("Shell/Body/StageHost/SplitHost/SplitLeft/SplitGrid") as VBoxContainer
	_dossier = get_node_or_null("Shell/Body/StageHost/SplitHost/Dossier/DossierInner") as VBoxContainer
	var ribbon_ids: Array[String] = ["Workings", "Transmutations", "Dross", "Bestiary", "Treatises", "Reliquary"]
	for id: String in ribbon_ids:
		_ribbon[id] = {
			"k": get_node_or_null("Shell/Header/Ribbon/%s/K" % id) as Label,
			"v": get_node_or_null("Shell/Header/Ribbon/%s/V" % id) as Label,
		}


func _apply_copy() -> void:
	if _kicker != null:
		_kicker.text = tr("ui.archives.kicker")
		_style_kicker(_kicker)
	if _title != null:
		_title.text = tr("ui.archives.title")
		_style_title(_title)
	if _foot != null:
		_foot.text = tr("ui.archives.foot")
		_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiAtlas.apply_label(_foot, UiAtlas.TYPE_MICRO, UiAtlas.BRASS_DIM, 12)
	_style_header()
	_style_back_btn()
	if _nav != null:
		_nav.add_theme_constant_override("separation", 10)
	if _stage_inner != null:
		_stage_inner.add_theme_constant_override("separation", 16)
	if _split_grid != null:
		_split_grid.add_theme_constant_override("separation", 12)
	if _dossier != null:
		_dossier.add_theme_constant_override("separation", 12)
	_style_dossier()
	_build_tabs()
	_style_ribbon_copy()


func _bind() -> void:
	if _bound:
		return
	_bound = true
	if _back_btn != null:
		_back_btn.pressed.connect(_on_back)
		_back_btn.mouse_entered.connect(_on_back_hover.bind(true))
		_back_btn.mouse_exited.connect(_on_back_hover.bind(false))
		_back_btn.focus_entered.connect(_on_back_hover.bind(true))
		_back_btn.focus_exited.connect(_on_back_hover.bind(false))


func _on_back() -> void:
	if handle_back():
		_play_ui("click")
		return
	_play_ui("close")
	back_pressed.emit()


func _build_tabs() -> void:
	if _nav == null:
		return
	for child: Node in _nav.get_children():
		_nav.remove_child(child)
		child.queue_free()
	_tab_btns.clear()
	for i: int in TAB_IDS.size():
		var id: StringName = TAB_IDS[i]
		var btn := Button.new()
		btn.name = String(id)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 64)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_nav.add_child(btn)
		_tab_btns[id] = btn
		var captured: StringName = id
		btn.pressed.connect(func() -> void: _set_tab(captured))
	_style_tab_buttons()


func _set_tab(id: StringName) -> void:
	if _tab == id:
		return
	_play_ui("click")
	_tab = id
	_confirm_purge = false
	refresh()


func _refresh_tabs() -> void:
	_style_tab_buttons()


func _style_tab_buttons() -> void:
	for i: int in TAB_IDS.size():
		var id: StringName = TAB_IDS[i]
		var btn: Button = _tab_btns.get(id, null)
		if btn == null:
			continue
		var active: bool = id == _tab
		for child: Node in btn.get_children():
			btn.remove_child(child)
			child.queue_free()
		btn.text = ""
		var bg := Color("3c251c") if active else Color("1a161c")
		var border := UiAtlas.GOLD_MOLTEN if active else Color("4e4a54")
		btn.add_theme_stylebox_override("normal", _tab_sb(bg, border))
		btn.add_theme_stylebox_override("hover", _tab_sb(Color("2a221c"), UiAtlas.BRASS_BRIGHT))
		btn.add_theme_stylebox_override("pressed", _tab_sb(Color("3c251c"), UiAtlas.GOLD_MOLTEN))
		btn.add_theme_stylebox_override("focus", _tab_sb(bg, UiAtlas.GOLD_MOLTEN))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10.0
		row.offset_right = -10.0
		row.offset_top = 8.0
		row.offset_bottom = -8.0
		row.add_theme_constant_override("separation", 10)
		var glyph := Label.new()
		glyph.text = TAB_GLYPHS[i]
		glyph.custom_minimum_size = Vector2(28, 28)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UiAtlas.apply_label(glyph, UiAtlas.TYPE_META, UiAtlas.GOLD_MOLTEN, 14)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(glyph)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lab := Label.new()
		lab.text = tr("ui.archives.tab.%s" % String(id))
		UiAtlas.apply_label(lab, UiAtlas.TYPE_META, UiAtlas.PARCHMENT, 13)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sub := Label.new()
		sub.text = tr("ui.archives.tab.%s.sub" % String(id))
		UiAtlas.apply_label(sub, UiAtlas.TYPE_MICRO, Color("a89890"), 10)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.add_child(lab)
		copy.add_child(sub)
		row.add_child(copy)
		btn.add_child(row)


func _refresh_ribbon(rec: ArchiveRecords, catalog: Catalog) -> void:
	var discovered: int = 0
	var lores: int = 0
	for entity: Dictionary in catalog.entities:
		var eid: String = String(entity.get("id", ""))
		if rec.is_entity_seen(eid):
			discovered += 1
		if rec.has_lore(eid):
			lores += 1
	var bound: int = 0
	for item: Dictionary in catalog.items:
		if rec.is_item_bound(String(item.get("id", ""))):
			bound += 1
	_set_pill("Workings", tr("ui.archives.ribbon.workings"), str(int(rec.data.get("totalRuns", 0))))
	_set_pill("Transmutations", tr("ui.archives.ribbon.transmutations"), str(int(rec.data.get("victories", 0))))
	_set_pill("Dross", tr("ui.archives.ribbon.dross"), str(int(rec.data.get("totalKills", 0))))
	_set_pill("Bestiary", tr("ui.archives.ribbon.bestiary"), "%d / %d" % [discovered, catalog.entities.size()])
	_set_pill("Treatises", tr("ui.archives.ribbon.treatises"), "%d / %d" % [lores, catalog.entities.size()])
	_set_pill("Reliquary", tr("ui.archives.ribbon.reliquary"), "%d / %d" % [bound, catalog.items.size()])


func _set_pill(id: String, k: String, v: String) -> void:
	var pair: Dictionary = _ribbon.get(id, {})
	var k_l: Label = pair.get("k", null)
	var v_l: Label = pair.get("v", null)
	if k_l != null:
		k_l.text = k
	if v_l != null:
		v_l.text = v


func _style_ribbon_copy() -> void:
	if _ribbon_host != null:
		_ribbon_host.add_theme_constant_override("separation", 10)
		_ribbon_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_ribbon_host.alignment = BoxContainer.ALIGNMENT_END
	for id: Variant in _ribbon.keys():
		var pair: Dictionary = _ribbon[id]
		var k_l: Label = pair.get("k", null)
		var v_l: Label = pair.get("v", null)
		if k_l != null:
			UiAtlas.apply_label(k_l, UiAtlas.TYPE_MICRO, Color("a89890"), 9)
			k_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if v_l != null:
			UiAtlas.apply_label(v_l, UiAtlas.TYPE_META, UiAtlas.GOLD_MOLTEN, 14)
			v_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if k_l != null and v_l != null and k_l.get_parent() == v_l.get_parent():
			var box: Node = k_l.get_parent()
			if k_l.get_index() > v_l.get_index():
				box.move_child(k_l, 0)
			_style_ribbon_pill(box)


func _rebuild_stage(rec: ArchiveRecords, catalog: Catalog) -> void:
	var split: bool = _tab == &"entities" or _tab == &"reliquary"
	if _stage_scroll != null:
		_stage_scroll.visible = not split
	if _split_host != null:
		_split_host.visible = split
	if split:
		ArchivesContent.clear(_split_grid)
		ArchivesContent.clear(_dossier)
		if _tab == &"entities":
			ArchivesContent.fill_bestiary(_split_grid, _dossier, rec, catalog, _entity_filter, _selected_entity, Callable(self, "_on_entity_filter"), Callable(self, "_on_select_entity"))
		else:
			ArchivesContent.fill_reliquary(_split_grid, _dossier, rec, catalog, _item_rarity, _selected_item, Callable(self, "_on_item_rarity"), Callable(self, "_on_select_item"))
		return
	ArchivesContent.clear(_stage_inner)
	match String(_tab):
		"howto":
			ArchivesContent.fill_howto(_stage_inner, rec, catalog, _howto_vessel, Callable(self, "_on_howto_vessel"))
		"lore":
			ArchivesContent.fill_lore(_stage_inner, rec, catalog, _lore_sub, Callable(self, "_on_lore_sub"))
		_:
			ArchivesContent.fill_ledger(_stage_inner, rec, catalog, _confirm_purge, Callable(self, "_on_purge"))
	if _stage_scroll != null:
		_stage_scroll.scroll_vertical = 0


func _on_howto_vessel(id: String) -> void:
	_play_ui("click")
	_howto_vessel = id
	refresh()


func _on_lore_sub(id: StringName) -> void:
	_play_ui("click")
	_lore_sub = id
	refresh()


func _on_entity_filter(id: String) -> void:
	_play_ui("click")
	_entity_filter = id
	refresh()


func _on_select_entity(id: String) -> void:
	_play_ui("click")
	_selected_entity = id
	refresh()


func _on_item_rarity(id: String) -> void:
	_play_ui("click")
	_item_rarity = id
	refresh()


func _on_select_item(id: String) -> void:
	_play_ui("click")
	_selected_item = id
	refresh()


func _on_purge() -> void:
	if not _confirm_purge:
		_play_ui("click")
		_confirm_purge = true
		refresh()
		return
	_play_ui("error")
	var app := get_node_or_null("/root/App")
	if app != null:
		app.records.reset()
	_confirm_purge = false
	refresh()


func _style_dossier() -> void:
	if _dossier == null:
		return
	var host := _dossier.get_parent() as ScrollContainer
	if host == null:
		return
	host.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.clip_contents = true
	_dossier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1c161cf0")
	sb.border_color = UiAtlas.BRASS_DIM
	sb.set_border_width_all(2)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 22.0
	sb.content_margin_bottom = 22.0
	sb.shadow_color = Color(0, 0, 0, 0.85)
	sb.shadow_size = 10
	host.add_theme_stylebox_override("panel", sb)


func _sync_anim_frames() -> void:
	_sync_anim_in(self)


func _sync_anim_in(node: Node) -> void:
	if node is TextureRect and node.has_meta("archive_anim"):
		var rect := node as TextureRect
		var tex: Texture2D = UiAtlas.entity_frame(String(rect.get_meta("archive_anim")), "idle", _anim_t)
		if tex != null:
			rect.texture = tex
	for child: Node in node.get_children():
		_sync_anim_in(child)


func _wire_focus() -> void:
	if _back_btn == null or _nav == null:
		return
	if _nav.get_child_count() == 0:
		return
	var first: Control = _nav.get_child(0) as Control
	_back_btn.focus_neighbor_bottom = _back_btn.get_path_to(first)
	if first != null:
		first.focus_neighbor_top = first.get_path_to(_back_btn)
	for i: int in _nav.get_child_count():
		var btn: Control = _nav.get_child(i) as Control
		if btn == null:
			continue
		if i + 1 < _nav.get_child_count():
			var nxt: Control = _nav.get_child(i + 1) as Control
			btn.focus_neighbor_bottom = btn.get_path_to(nxt)
			nxt.focus_neighbor_top = nxt.get_path_to(btn)


func _style_header() -> void:
	if _header != null:
		_header.custom_minimum_size = Vector2(0, 68)
		_header.add_theme_constant_override("separation", 20)
		_header.alignment = BoxContainer.ALIGNMENT_CENTER
		_ensure_header_pad("PadLeft", 18.0, 0)
		_ensure_header_pad("PadRight", 32.0, -1)
		var brand := _header.get_node_or_null("BrandGroup") as HBoxContainer
		if brand != null:
			brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			brand.add_theme_constant_override("separation", 14)
		var title_wrap := _header.get_node_or_null("BrandGroup/TitleWrap") as VBoxContainer
		if title_wrap != null:
			title_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			title_wrap.add_theme_constant_override("separation", 1)
	if _header_bg != null:
		_header_bg.color = Color("1c181d")
		_header_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_header_rule()
	call_deferred("_sync_header_chrome")


func _ensure_header_pad(node_name: String, width: float, index: int) -> void:
	if _header == null:
		return
	var pad := _header.get_node_or_null(node_name) as Control
	if pad == null:
		pad = Control.new()
		pad.name = node_name
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_header.add_child(pad)
		if index < 0:
			_header.move_child(pad, _header.get_child_count() - 1)
		else:
			_header.move_child(pad, index)
	pad.custom_minimum_size = Vector2(width, 0)
	pad.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pad.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _ensure_header_rule() -> void:
	_header_rule = get_node_or_null("HeaderRule") as ColorRect
	if _header_rule == null:
		_header_rule = ColorRect.new()
		_header_rule.name = "HeaderRule"
		_header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_header_rule.color = UiAtlas.BRASS
		add_child(_header_rule)
		move_child(_header_rule, 1)
	_header_rule.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_header_rule.offset_left = 0.0
	_header_rule.offset_right = 0.0


func _sync_header_chrome() -> void:
	if _header == null:
		return
	var h: float = maxf(_header.size.y, _header.custom_minimum_size.y)
	if _header_bg != null:
		_header_bg.offset_top = 0.0
		_header_bg.offset_bottom = h
	if _header_rule != null:
		_header_rule.offset_top = h - 2.0
		_header_rule.offset_bottom = h


func _style_back_btn() -> void:
	if _back_btn == null:
		return
	_back_btn.text = ""
	UiAtlas.apply_button_styles(_back_btn, "hall-medailon")
	_back_btn.custom_minimum_size = Vector2(48, 48)
	_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_back_btn.clip_text = true
	_back_btn.offset_transform_enabled = true
	_back_btn.pivot_offset = Vector2(24, 24)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBox = _back_btn.get_theme_stylebox(state)
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
			_back_btn.add_theme_stylebox_override(state, tex)
		elif sb is StyleBoxFlat:
			var flat := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			flat.content_margin_left = 0.0
			flat.content_margin_right = 0.0
			flat.content_margin_top = 0.0
			flat.content_margin_bottom = 0.0
			_back_btn.add_theme_stylebox_override(state, flat)


func _on_back_hover(on: bool) -> void:
	_back_hover = on
	if _back_btn == null:
		return
	_back_btn.offset_transform_enabled = true
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_QUAD)
	var hover_scale: Vector2 = Vector2(1.06, 1.06) if on else Vector2.ONE
	var tint: Color = Color("fff1d4") if on else Color.WHITE
	tw.tween_property(_back_btn, "offset_transform_scale", hover_scale, 0.12)
	tw.parallel().tween_property(_back_btn, "modulate", tint, 0.12)


func _style_ribbon_pill(box: Node) -> void:
	var host: Control = box as Control
	if host == null:
		return
	host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if host is VBoxContainer:
		(host as VBoxContainer).add_theme_constant_override("separation", 0)
		(host as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	var parent := host.get_parent()
	if parent != null and parent is PanelContainer:
		_apply_ribbon_pill_sb(parent as PanelContainer)
		return
	if host is PanelContainer:
		_apply_ribbon_pill_sb(host as PanelContainer)
		return
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_ribbon_pill_sb(pill)
	var idx: int = host.get_index()
	var ribbon: Node = host.get_parent()
	if ribbon == null:
		return
	ribbon.remove_child(host)
	pill.add_child(host)
	ribbon.add_child(pill)
	ribbon.move_child(pill, idx)


func _apply_ribbon_pill_sb(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0c0a0ec7")
	sb.border_color = Color("c4a35a59")
	sb.set_border_width_all(1)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	sb.shadow_color = Color(0, 0, 0, 0.65)
	sb.shadow_size = 4
	panel.add_theme_stylebox_override("panel", sb)


func _style_kicker(label: Label) -> void:
	UiAtlas.apply_label(label, UiAtlas.TYPE_MICRO, UiAtlas.BRASS, 10)


func _style_title(label: Label) -> void:
	UiAtlas.apply_label(label, UiAtlas.TYPE_DISPLAY, UiAtlas.GOLD_MOLTEN, UiAtlas.SIZE_DISPLAY_M)


func _tab_sb(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


func _play_ui(kind: String) -> void:
	var bus := get_node_or_null("/root/GameAudio")
	if bus != null:
		bus.play_ui(kind)
