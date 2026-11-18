class_name CrucibleModal
extends Control

signal closed
signal changed

const PANEL_W: float = 800.0

var _dim: ColorRect
var _panel: PanelContainer
var _essence_badge: Label
var _seals_label: Label
var _seals_bonus: Label
var _seal_minus: Button
var _seal_plus: Button
var _scroll: ScrollContainer
var _list: VBoxContainer
var _refund_btn: Button
var _return_btn: Button
var _first_focus: Button
var _built: bool = false
var _bound_rec: ArchiveRecords
var _bound_cat: Catalog


func _ready() -> void:
	visible = false
	z_index = 35
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built:
		_sync_scroll_height()


func open(p_rec: ArchiveRecords = null, p_catalog: Catalog = null) -> void:
	if not _built:
		_build()
	visible = true
	refresh(p_rec, p_catalog)
	call_deferred("focus_primary")


func close() -> void:
	if not visible:
		return
	visible = false
	_play_ui("close")
	closed.emit()


func handle_back() -> bool:
	if not visible:
		return false
	close()
	return true


func focus_primary() -> void:
	if _first_focus != null and _first_focus.is_inside_tree() and not _first_focus.disabled:
		_first_focus.grab_focus()
		return
	if _return_btn != null and _return_btn.is_inside_tree():
		_return_btn.grab_focus()


func refresh(p_rec: ArchiveRecords = null, p_catalog: Catalog = null) -> void:
	if not _built:
		_build()
	var app: Node = get_node_or_null("/root/App")
	var rec: ArchiveRecords = p_rec if p_rec != null else (app.records as ArchiveRecords if app != null else null)
	var catalog: Catalog = p_catalog if p_catalog != null else (app.catalog as Catalog if app != null else null)
	_bound_rec = rec
	_bound_cat = catalog
	if rec == null or catalog == null:
		return
	if _essence_badge != null:
		_essence_badge.text = tr("ui.crucible.essence").replace("{n}", str(rec.essence_balance()))
	_refresh_seals(rec)
	_rebuild_list(rec, catalog)
	_refresh_refund(rec, catalog)
	_sync_scroll_height()


func _build() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.035, 0.028, 0.042, 0.84)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	_panel.add_theme_stylebox_override("panel", _panel_sb(Color("141016f5"), UiAtlas.BRASS, 2, Vector4(26, 22, 26, 22)))
	center.add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	_panel.add_child(root)

	root.add_child(_build_header())
	root.add_child(_build_seals_bar())

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 380)
	root.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)

	root.add_child(_build_footer())
	_sync_scroll_height()


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 2)

	var kicker := Label.new()
	kicker.text = tr("ui.crucible.kicker")
	UiAtlas.apply_label(kicker, UiAtlas.TYPE_MICRO, UiAtlas.BRASS, 11)
	left.add_child(kicker)

	var title := Label.new()
	title.text = tr("ui.crucible.title")
	UiAtlas.apply_label(title, UiAtlas.TYPE_DISPLAY, UiAtlas.GOLD_MOLTEN, UiAtlas.SIZE_DISPLAY_M, true)
	left.add_child(title)

	var sub := Label.new()
	sub.text = tr("ui.crucible.sub")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiAtlas.apply_label(sub, UiAtlas.TYPE_META, UiAtlas.ASH, 13)
	left.add_child(sub)
	row.add_child(left)

	var badge_box := PanelContainer.new()
	badge_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge_box.add_theme_stylebox_override("panel", _panel_sb(Color("1e141a"), UiAtlas.GOLD_MOLTEN, 1, Vector4(16, 10, 16, 10)))
	_essence_badge = Label.new()
	_essence_badge.text = tr("ui.crucible.essence").replace("{n}", "0")
	UiAtlas.apply_label(_essence_badge, UiAtlas.TYPE_DISPLAY, UiAtlas.GOLD_MOLTEN, 18, true)
	badge_box.add_child(_essence_badge)
	row.add_child(badge_box)
	return row


func _build_seals_bar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _panel_sb(Color("1b151de6"), UiAtlas.BRASS_DIM, 1, Vector4(14, 10, 14, 10)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var head := Label.new()
	head.text = tr("ui.crucible.seals.title")
	UiAtlas.apply_label(head, UiAtlas.TYPE_MICRO, UiAtlas.BRASS, 11)
	info.add_child(head)

	var detail := HBoxContainer.new()
	detail.add_theme_constant_override("separation", 16)
	_seals_label = Label.new()
	UiAtlas.apply_label(_seals_label, UiAtlas.TYPE_META, UiAtlas.PARCHMENT, 14)
	detail.add_child(_seals_label)

	_seals_bonus = Label.new()
	UiAtlas.apply_label(_seals_bonus, UiAtlas.TYPE_META, Color("7dff9a"), 13)
	detail.add_child(_seals_bonus)
	info.add_child(detail)
	row.add_child(info)

	_seal_minus = _small_btn("-")
	_seal_minus.name = "SealMinusBtn"
	_seal_minus.pressed.connect(func() -> void: _step_seal(-1))
	row.add_child(_seal_minus)

	_seal_plus = _small_btn("+")
	_seal_plus.name = "SealPlusBtn"
	_seal_plus.pressed.connect(func() -> void: _step_seal(1))
	row.add_child(_seal_plus)
	return bar


func _build_footer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	_refund_btn = Button.new()
	_refund_btn.name = "RefundBtn"
	_refund_btn.text = tr("ui.crucible.reset")
	_refund_btn.custom_minimum_size = Vector2(220, 44)
	_style_action_btn(_refund_btn, Color("2e181b"), Color("b84444"))
	_refund_btn.pressed.connect(_on_refund_pressed)
	row.add_child(_refund_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	_return_btn = Button.new()
	_return_btn.text = tr("ui.crucible.back").to_upper()
	_return_btn.custom_minimum_size = Vector2(180, 44)
	UiAtlas.apply_button_styles(_return_btn, "btn-plaque")
	_return_btn.pressed.connect(close)
	row.add_child(_return_btn)
	return row


func _rebuild_list(rec: ArchiveRecords, catalog: Catalog) -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_first_focus = null
	for upg: Dictionary in catalog.crucible_upgrades:
		var card: Control = _make_upgrade_card(upg, rec)
		_list.add_child(card)


func _make_upgrade_card(upg: Dictionary, rec: ArchiveRecords) -> Control:
	var id: String = String(upg.get("id", ""))
	var max_lv: int = maxi(1, int(upg.get("maxLevel", 1)))
	var lvl: int = clampi(rec.upgrade_level(id), 0, max_lv)
	var costs: Array = DictUtil.a(upg, "costs")
	var maxed: bool = lvl >= max_lv
	var next_cost: int = int(costs[lvl]) if (not maxed and lvl < costs.size()) else 0
	var can_afford: bool = (not maxed) and rec.essence_balance() >= next_cost

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border_col: Color = UiAtlas.GOLD_MOLTEN if maxed else (UiAtlas.BRASS if can_afford else UiAtlas.BRASS_DIM)
	card.add_theme_stylebox_override("panel", _panel_sb(Color("1c161fe6"), border_col, 1, Vector4(14, 12, 14, 12)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 4)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var name_lab := Label.new()
	name_lab.text = _t("upgrade.%s.name" % id, String(upg.get("name", id)))
	UiAtlas.apply_label(name_lab, UiAtlas.TYPE_DISPLAY, UiAtlas.PARCHMENT, 17, true)
	top.add_child(name_lab)

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for p: int in max_lv:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(14, 8)
		var pip_sb := StyleBoxFlat.new()
		pip_sb.bg_color = UiAtlas.GOLD_MOLTEN if p < lvl else Color("28212b")
		pip_sb.border_color = UiAtlas.BRASS_BRIGHT if p < lvl else UiAtlas.BRASS_DIM
		pip_sb.set_border_width_all(1)
		pip.add_theme_stylebox_override("panel", pip_sb)
		pips.add_child(pip)
	top.add_child(pips)

	var rank_lab := Label.new()
	rank_lab.text = tr("ui.crucible.rank").replace("{have}", str(lvl)).replace("{max}", str(max_lv))
	UiAtlas.apply_label(rank_lab, UiAtlas.TYPE_MICRO, UiAtlas.GOLD_MOLTEN if lvl > 0 else UiAtlas.ASH, 12)
	top.add_child(rank_lab)
	copy.add_child(top)

	var desc_lab := Label.new()
	desc_lab.text = _t("upgrade.%s.desc" % id, String(upg.get("desc", "")))
	desc_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiAtlas.apply_label(desc_lab, UiAtlas.TYPE_META, UiAtlas.PARCHMENT, 13)
	copy.add_child(desc_lab)

	var lore_lab := Label.new()
	lore_lab.text = _t("upgrade.%s.lore" % id, String(upg.get("lore", "")))
	lore_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiAtlas.apply_label(lore_lab, UiAtlas.TYPE_MICRO, UiAtlas.ASH, 12)
	copy.add_child(lore_lab)
	row.add_child(copy)

	var btn := Button.new()
	btn.name = "Buy_%s" % id
	btn.custom_minimum_size = Vector2(210, 44)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if maxed:
		btn.text = tr("ui.crucible.maxed")
		btn.disabled = true
		_style_action_btn(btn, Color("241e18"), UiAtlas.GOLD_MOLTEN)
	elif can_afford:
		btn.text = tr("ui.crucible.upgrade").replace("{cost}", str(next_cost))
		_style_action_btn(btn, Color("3c2418"), UiAtlas.GOLD_MOLTEN)
	else:
		btn.text = tr("ui.crucible.insufficient").replace("{cost}", str(next_cost))
		btn.disabled = true
		_style_action_btn(btn, Color("17131a"), Color("4a424d"))
	var captured_id: String = id
	var captured_lvl: int = lvl
	var captured_cost: int = next_cost
	btn.pressed.connect(func() -> void: _on_upgrade_pressed(captured_id, captured_lvl, captured_cost))
	row.add_child(btn)
	if _first_focus == null and not btn.disabled:
		_first_focus = btn
	return card


func _on_upgrade_pressed(upgrade_id: String, current_lvl: int, cost: int) -> void:
	if _bound_rec == null or _bound_cat == null:
		return
	if not _bound_rec.spend_essence(cost):
		_play_ui("error")
		return
	_bound_rec.set_upgrade_level(upgrade_id, current_lvl + 1)
	_play_ui("confirm")
	refresh(_bound_rec, _bound_cat)
	changed.emit()


func _on_refund_pressed() -> void:
	if _bound_rec == null or _bound_cat == null:
		return
	var refund: int = _total_spent_essence(_bound_rec, _bound_cat)
	if refund > 0:
		_bound_rec.grant_essence(refund)
	for upg: Dictionary in _bound_cat.crucible_upgrades:
		var uid: String = String(upg.get("id", ""))
		if uid != "":
			_bound_rec.set_upgrade_level(uid, 0)
	_bound_rec.set_ascension_tier(0)
	_play_ui("click")
	refresh(_bound_rec, _bound_cat)
	changed.emit()


func _step_seal(delta: int) -> void:
	if _bound_rec == null:
		return
	var cur: int = _bound_rec.ascension_tier()
	var next: int = clampi(cur + delta, 0, _bound_rec.max_ascension_unlocked())
	if next == cur:
		return
	_bound_rec.set_ascension_tier(next)
	_play_ui("click")
	refresh(_bound_rec, _bound_cat)
	changed.emit()


func _refresh_seals(rec: ArchiveRecords) -> void:
	var tier: int = rec.ascension_tier()
	var max_tier: int = rec.max_ascension_unlocked()
	if _seals_label != null:
		_seals_label.text = tr("ui.crucible.seals.active").replace("{n}", str(tier)).replace("{max}", str(max_tier))
	if _seals_bonus != null:
		_seals_bonus.text = tr("ui.crucible.seals.bonus").replace("{pct}", str(tier * 15))
	if _seal_minus != null:
		_seal_minus.disabled = tier <= 0
	if _seal_plus != null:
		_seal_plus.disabled = tier >= max_tier


func _refresh_refund(rec: ArchiveRecords, catalog: Catalog) -> void:
	if _refund_btn == null:
		return
	var refund: int = _total_spent_essence(rec, catalog)
	var has_any: bool = refund > 0
	if not has_any:
		for upg: Dictionary in catalog.crucible_upgrades:
			if rec.upgrade_level(String(upg.get("id", ""))) > 0:
				has_any = true
				break
	_refund_btn.disabled = not has_any
	var base: String = tr("ui.crucible.reset")
	_refund_btn.text = "%s (100%% · +%d)" % [base, refund] if refund > 0 else base


func _total_spent_essence(rec: ArchiveRecords, catalog: Catalog) -> int:
	var total: int = 0
	for upg: Dictionary in catalog.crucible_upgrades:
		var uid: String = String(upg.get("id", ""))
		var lvl: int = rec.upgrade_level(uid)
		var costs: Array = DictUtil.a(upg, "costs")
		for k: int in range(mini(lvl, costs.size())):
			total += maxi(0, int(costs[k]))
	return total


func _sync_scroll_height() -> void:
	if _scroll == null:
		return
	var target_h: float = 380.0
	if size.y > 100.0:
		target_h = clampf(size.y - 290.0, 220.0, 490.0)
	_scroll.custom_minimum_size = Vector2(0, target_h)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close()


func _small_btn(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(36, 36)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_action_btn(btn, Color("241c24"), UiAtlas.BRASS)
	return btn


func _style_action_btn(btn: Button, bg: Color, border: Color) -> void:
	btn.add_theme_stylebox_override("normal", _panel_sb(bg, border, 1, Vector4(12, 6, 12, 6)))
	btn.add_theme_stylebox_override("hover", _panel_sb(bg.lightened(0.12), UiAtlas.BRASS_BRIGHT, 1, Vector4(12, 6, 12, 6)))
	btn.add_theme_stylebox_override("pressed", _panel_sb(bg.lightened(0.2), UiAtlas.GOLD_MOLTEN, 1, Vector4(12, 6, 12, 6)))
	btn.add_theme_stylebox_override("disabled", _panel_sb(Color("141116"), Color("3a333e"), 1, Vector4(12, 6, 12, 6)))
	btn.add_theme_stylebox_override("focus", UiAtlas.empty_focus())
	if UiAtlas.body_font() != null:
		btn.add_theme_font_override("font", UiAtlas.body_font())
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", UiAtlas.PARCHMENT)
	btn.add_theme_color_override("font_hover_color", UiAtlas.PARCHMENT)
	btn.add_theme_color_override("font_pressed_color", UiAtlas.GOLD_MOLTEN)
	btn.add_theme_color_override("font_disabled_color", UiAtlas.ASH)


func _panel_sb(bg: Color, border: Color, border_w: int, pad: Vector4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


func _t(key: String, fallback: String) -> String:
	var val: String = tr(key)
	return fallback if val == key else val


func _play_ui(kind: String) -> void:
	var bus: Node = get_node_or_null("/root/GameAudio")
	if bus != null:
		bus.play_ui(kind)
