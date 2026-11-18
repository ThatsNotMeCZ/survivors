class_name RecapView
extends Control

signal again_pressed
signal hall_pressed

const STATS_W: float = 390.0
const DETAILS_W: float = 520.0
const INV_PAD: float = 64.0
const INV_H: float = 220.0
const CTA_W: float = 220.0
const CTA_H: float = 58.0
const PLAQUE_W: float = 190.0
const BTN_H: float = 58.0
const STEAM_WISHLIST_URL: String = "https://store.steampowered.com/app/0/"

var _kicker: Label
var _title: Label
var _sub: Label
var _stats_rows: VBoxContainer
var _unlocks: VBoxContainer
var _inv_list: GridContainer
var _inv_empty: Label
var _tooltip: ItemTooltip
var _catalog: Catalog
var _again_btn: Button
var _hall_btn: Button
var _wishlist_btn: Button
var _wishlist_lab: Label
var _built: bool = false


func _ready() -> void:
	_build()


func refresh(world: SimWorld, kind: String, rec: ArchiveRecords, catalog: Catalog, start_items: Dictionary, start_survivors: Dictionary) -> void:
	if not _built:
		_build()
	visible = true
	_catalog = catalog
	_fill_header(world, kind)
	_fill_stats(world, rec)
	_fill_unlocks(rec, catalog, start_items, start_survivors)
	_fill_inventory(world)
	_sync_wishlist_cta(world)
	if _again_btn != null:
		_again_btn.grab_focus()


func focus_primary() -> void:
	if _again_btn != null:
		_again_btn.grab_focus()


func _build() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("08060a")
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.15, 0.10, 0.125, 0.55)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 32.0
	col.offset_right = -32.0
	col.offset_top = 24.0
	col.offset_bottom = -32.0
	col.add_theme_constant_override("separation", 20)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	col.add_child(_build_header())
	col.add_child(_build_content())
	col.add_child(_build_actions())
	_tooltip = ItemTooltip.new()
	_tooltip.name = "ItemTooltip"
	add_child(_tooltip)


func _build_header() -> Control:
	var banner := PanelContainer.new()
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	banner.add_theme_stylebox_override("panel", UiAtlas.nine_slice("sting-banner", "idle", Vector4(104, 18, 104, 34)))
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.add_child(inner)
	_kicker = Label.new()
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiAtlas.apply_label(_kicker, UiAtlas.TYPE_DISPLAY, UiAtlas.GOLD_MOLTEN, 13, true)
	inner.add_child(_kicker)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiAtlas.apply_label(_title, UiAtlas.TYPE_DISPLAY, UiAtlas.PARCHMENT, 36, true)
	inner.add_child(_title)
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiAtlas.apply_label(_sub, UiAtlas.TYPE_META, UiAtlas.ASH, 15, true)
	inner.add_child(_sub)
	return banner


func _build_content() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_build_stats())
	row.add_child(_build_details())
	return row


func _build_stats() -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(STATS_W, 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_stylebox_override("panel", UiAtlas.nine_slice("parchment-panel", "idle", Vector4(48, 44, 48, 46)))
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	box.add_child(inner)
	var head := Label.new()
	head.text = tr("ui.recap.stats")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiAtlas.apply_ink_label(head, UiAtlas.TYPE_DISPLAY, UiAtlas.PARCHMENT_INK, 18)
	inner.add_child(head)
	_stats_rows = VBoxContainer.new()
	_stats_rows.add_theme_constant_override("separation", 4)
	inner.add_child(_stats_rows)
	return box


func _build_details() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.custom_minimum_size = Vector2(DETAILS_W, 0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var unlocks := PanelContainer.new()
	unlocks.add_theme_stylebox_override("panel", UiAtlas.nine_slice("parchment-panel", "idle", Vector4(48, 44, 48, 46)))
	col.add_child(unlocks)
	var u_inner := VBoxContainer.new()
	u_inner.add_theme_constant_override("separation", 8)
	unlocks.add_child(u_inner)
	var u_head := Label.new()
	u_head.text = tr("ui.recap.discoveries")
	u_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiAtlas.apply_ink_label(u_head, UiAtlas.TYPE_DISPLAY, UiAtlas.PARCHMENT_INK, 18)
	u_inner.add_child(u_head)
	_unlocks = VBoxContainer.new()
	_unlocks.add_theme_constant_override("separation", 8)
	u_inner.add_child(_unlocks)
	var inv_section := VBoxContainer.new()
	inv_section.add_theme_constant_override("separation", 8)
	inv_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(inv_section)
	var inv_head := Label.new()
	inv_head.text = tr("ui.recap.relics")
	inv_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiAtlas.apply_label(inv_head, UiAtlas.TYPE_DISPLAY, UiAtlas.PARCHMENT, 18, true)
	inv_section.add_child(inv_head)
	var inv_box := PanelContainer.new()
	inv_box.custom_minimum_size = Vector2(DETAILS_W, INV_H)
	inv_box.add_theme_stylebox_override("panel", UiAtlas.nine_slice("pause-inventory", "idle", Vector4(INV_PAD, INV_PAD, INV_PAD, INV_PAD)))
	inv_section.add_child(inv_box)
	var inv_stage := Control.new()
	inv_stage.custom_minimum_size = Vector2(DETAILS_W - INV_PAD * 2.0, INV_H - INV_PAD * 2.0)
	inv_box.add_child(inv_stage)
	_inv_list = GridContainer.new()
	_inv_list.columns = 8
	_inv_list.add_theme_constant_override("h_separation", 10)
	_inv_list.add_theme_constant_override("v_separation", 10)
	_inv_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inv_stage.add_child(_inv_list)
	_inv_empty = Label.new()
	_inv_empty.text = tr("ui.recap.relics.empty")
	_inv_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inv_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_inv_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inv_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiAtlas.apply_label(_inv_empty, UiAtlas.TYPE_MICRO, UiAtlas.ASH, 13)
	inv_stage.add_child(_inv_empty)
	return col


func _build_actions() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_again_btn = Button.new()
	_again_btn.text = ""
	_again_btn.custom_minimum_size = Vector2(CTA_W, CTA_H)
	_again_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_again_btn.clip_contents = false
	UiAtlas.apply_button_styles(_again_btn, "btn-cta")
	var again_lab := Label.new()
	again_lab.text = tr("ui.recap.again")
	again_lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	again_lab.offset_left = 28.0
	again_lab.offset_right = -28.0
	again_lab.offset_top = 0.0
	again_lab.offset_bottom = 0.0
	again_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	again_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiAtlas.apply_label(again_lab, UiAtlas.TYPE_DISPLAY, UiAtlas.PARCHMENT, UiAtlas.SIZE_CTA)
	again_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_again_btn.add_child(again_lab)
	_again_btn.pressed.connect(func() -> void: again_pressed.emit())
	row.add_child(_again_btn)
	_hall_btn = _plaque_btn(tr("ui.recap.hall"))
	_hall_btn.pressed.connect(func() -> void: hall_pressed.emit())
	row.add_child(_hall_btn)
	_wishlist_btn = Button.new()
	_wishlist_btn.name = "WishlistBtn"
	_wishlist_btn.text = ""
	_wishlist_btn.custom_minimum_size = Vector2(PLAQUE_W + 30.0, BTN_H)
	_wishlist_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_wishlist_btn.clip_contents = false
	UiAtlas.apply_button_styles(_wishlist_btn, "btn-plaque")
	_wishlist_lab = Label.new()
	_wishlist_lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wishlist_lab.offset_left = 14.0
	_wishlist_lab.offset_right = -14.0
	_wishlist_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wishlist_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wishlist_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiAtlas.apply_label(_wishlist_lab, UiAtlas.TYPE_META, UiAtlas.GOLD_MOLTEN, 14, true)
	_wishlist_btn.add_child(_wishlist_lab)
	_wishlist_btn.pressed.connect(func() -> void: OS.shell_open(STEAM_WISHLIST_URL))
	row.add_child(_wishlist_btn)
	return row


func _sync_wishlist_cta(world: SimWorld) -> void:
	if _wishlist_btn == null or _wishlist_lab == null:
		return
	var app: Node = get_node_or_null("/root/App")
	var demo_win: bool = world != null and world.demo_completed
	var demo_active: bool = demo_win or (world != null and world.demo_mode) or (app != null and app.has_method("is_demo_mode") and bool(app.call("is_demo_mode")))
	var label_txt: String = tr("ui.menu.wishlist")
	if label_txt == "ui.menu.wishlist" or label_txt == "":
		label_txt = "Wishlist on Steam"
	_wishlist_lab.text = label_txt.to_upper() if demo_win else label_txt
	if demo_win:
		UiAtlas.apply_button_styles(_wishlist_btn, "btn-cta")
		_wishlist_btn.custom_minimum_size = Vector2(CTA_W + 40.0, CTA_H)
		UiAtlas.apply_label(_wishlist_lab, UiAtlas.TYPE_DISPLAY, UiAtlas.GOLD_MOLTEN, 16)
	elif demo_active:
		UiAtlas.apply_button_styles(_wishlist_btn, "btn-plaque")
		_wishlist_btn.custom_minimum_size = Vector2(PLAQUE_W + 30.0, BTN_H)
		UiAtlas.apply_label(_wishlist_lab, UiAtlas.TYPE_META, UiAtlas.GOLD_MOLTEN, 14, true)
	else:
		UiAtlas.apply_button_styles(_wishlist_btn, "btn-plaque")
		_wishlist_btn.custom_minimum_size = Vector2(PLAQUE_W + 24.0, BTN_H)
		UiAtlas.apply_label(_wishlist_lab, UiAtlas.TYPE_META, UiAtlas.PARCHMENT, 14, true)


func _plaque_btn(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(PLAQUE_W, BTN_H)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiAtlas.apply_button_styles(btn, "btn-plaque")
	var lab := Label.new()
	lab.text = label_text
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiAtlas.apply_label(lab, UiAtlas.TYPE_META, UiAtlas.PARCHMENT, 14, true)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lab)
	return btn


func _fill_header(world: SimWorld, kind: String) -> void:
	var demo_done: bool = world != null and world.demo_completed
	if demo_done:
		_kicker.text = "HERMETIC RIFTS · DEMO SEAL BROKEN"
		_title.text = "DEMO COMPLETE"
		_title.add_theme_color_override("font_color", UiAtlas.GOLD_MOLTEN)
		_sub.text = "Wishlisting fuels the Great Work · %s" % Loc.format_time(world.run_time)
		return
	if kind == "true_victory":
		var k_key: String = "ui.recap.kicker.true_victory"
		var t_key: String = "ui.recap.true_victory"
		var k_txt: String = tr(k_key)
		var t_txt: String = tr(t_key)
		_kicker.text = "PRIMA MATERIA SHATTERED" if (k_txt == k_key or k_txt == "") else k_txt
		_title.text = ("TRUE VICTORY" if (t_txt == t_key or t_txt == "") else t_txt).to_upper()
		_title.add_theme_color_override("font_color", UiAtlas.GOLD_MOLTEN)
	else:
		_kicker.text = tr("ui.recap.kicker.%s" % kind)
		_title.text = tr("ui.recap.%s" % kind).to_upper()
		if kind == "defeat" or kind == "abandon":
			_title.add_theme_color_override("font_color", Color("f1dedb"))
		else:
			_title.add_theme_color_override("font_color", UiAtlas.PARCHMENT)
	if world == null:
		_sub.text = ""
		return
	var stage: Dictionary = SimLoop.current_stage(world)
	if kind == "victory" or kind == "true_victory":
		_sub.text = tr("ui.recap.sub.victory").replace("{time}", Loc.format_time(world.run_time))
	else:
		_sub.text = tr("ui.recap.sub.run").replace("{stage}", Loc.stage_name(String(stage.get("id", "")))).replace("{time}", Loc.format_time(world.run_time))


func _fill_stats(world: SimWorld, rec: ArchiveRecords = null) -> void:
	for child: Node in _stats_rows.get_children():
		_stats_rows.remove_child(child)
		child.free()
	if world == null:
		return
	var sid: String = String(world.survivor.get("id", ""))
	var stage: Dictionary = SimLoop.current_stage(world)
	var banked_essence: int = world.run_essence
	if rec != null and rec.data.has("lastRunEssence"):
		banked_essence = int(rec.data.get("lastRunEssence", world.run_essence))
	var rows: Array[Array] = [
		[tr("ui.recap.row.vessel"), Loc.survivor_name(sid)],
		[tr("ui.recap.row.chamber"), Loc.stage_name(String(stage.get("id", "")))],
		[tr("ui.recap.row.time"), Loc.format_time(world.run_time)],
		[tr("ui.recap.row.level"), str(world.level)],
		[tr("ui.recap.row.kills"), str(world.kills_total)],
		[tr("ui.recap.row.bosses"), str(world.bosses_defeated)],
		[tr("ui.recap.row.dealt"), _fmt_num(world.damage_dealt)],
		[tr("ui.recap.row.taken"), _fmt_num(world.damage_taken)],
		[tr("ui.recap.row.healed"), _fmt_num(world.healing_done)],
		[tr("ui.recap.row.essence"), str(world.gems_collected)],
		[tr("ui.recap.row.essence_banked"), str(banked_essence)],
		[tr("ui.recap.row.seals"), str(world.ascension_tier)],
	]
	for row_v: Array in rows:
		var row := HBoxContainer.new()
		var k := Label.new()
		k.text = String(row_v[0])
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiAtlas.apply_ink_label(k, UiAtlas.TYPE_META, UiAtlas.PARCHMENT_INK, 14)
		var v := Label.new()
		v.text = String(row_v[1])
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		UiAtlas.apply_ink_label(v, UiAtlas.TYPE_META, UiAtlas.PARCHMENT_INK, 14)
		row.add_child(k)
		row.add_child(v)
		_stats_rows.add_child(row)


func _fill_unlocks(rec: ArchiveRecords, catalog: Catalog, start_items: Dictionary, start_survivors: Dictionary) -> void:
	for child: Node in _unlocks.get_children():
		_unlocks.remove_child(child)
		child.free()
	var cards: Array[Dictionary] = []
	if catalog != null and rec != null:
		for item_def: Dictionary in catalog.items:
			var id: String = String(item_def.get("id", ""))
			if id == "" or bool(start_items.get(id, false)):
				continue
			if rec.meets_unlock(item_def.get("unlock", null)):
				var state: Dictionary = rec.check_unlock(item_def.get("unlock", null), catalog)
				cards.append({
					"kind": "item",
					"id": id,
					"name": Loc.item_name(id),
					"desc": tr("ui.recap.unlock.item").replace("{cond}", String(state.get("label", ""))),
				})
		for surv: Dictionary in catalog.survivors:
			var id: String = String(surv.get("id", ""))
			if id == "" or bool(start_survivors.get(id, false)):
				continue
			var state: Dictionary = rec.check_unlock(surv.get("unlock", null), catalog)
			if bool(state.get("unlocked", true)):
				cards.append({
					"kind": "survivor",
					"id": id,
					"name": Loc.survivor_name(id),
					"desc": tr("ui.recap.unlock.vessel").replace("{cond}", String(state.get("label", ""))),
				})
	if cards.is_empty():
		var empty := Label.new()
		empty.text = tr("ui.recap.unlock.empty")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiAtlas.apply_ink_label(empty, UiAtlas.TYPE_META, UiAtlas.PARCHMENT_MUTED, 13)
		_unlocks.add_child(empty)
		return
	for card_v: Dictionary in cards:
		var card := HBoxContainer.new()
		card.add_theme_constant_override("separation", 12)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if String(card_v.get("kind", "")) == "item":
			icon.texture = UiAtlas.item_tex(String(card_v.get("id", "")))
		card.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title_lab := Label.new()
		title_lab.text = tr("ui.recap.unlock.name").replace("{name}", String(card_v.get("name", "")))
		UiAtlas.apply_ink_label(title_lab, UiAtlas.TYPE_META, UiAtlas.PARCHMENT_INK, 14)
		info.add_child(title_lab)
		var desc := Label.new()
		desc.text = String(card_v.get("desc", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiAtlas.apply_ink_label(desc, UiAtlas.TYPE_MICRO, UiAtlas.PARCHMENT_MUTED, 12)
		info.add_child(desc)
		card.add_child(info)
		_unlocks.add_child(card)


func _fill_inventory(world: SimWorld) -> void:
	for child: Node in _inv_list.get_children():
		_inv_list.remove_child(child)
		child.free()
	if _tooltip != null:
		_tooltip.hide_tip()
	var n: int = 0 if world == null else world.inventory.size()
	_inv_empty.visible = n == 0
	_inv_list.visible = n > 0
	if n == 0:
		return
	_inv_list.columns = clampi(int(ceil(sqrt(float(n)))), 4, 8)
	for inst: ItemInstance in world.inventory:
		var cat: Catalog = _catalog
		if cat == null:
			cat = world.catalog
		var rarity: String = "common"
		if cat != null and cat.has_item(inst.id):
			rarity = String(cat.item(inst.id).get("rarity", "common"))
		var chip := Button.new()
		chip.custom_minimum_size = Vector2(44, 44)
		chip.flat = true
		UiAtlas.attach_rarity_splash(chip, rarity)
		var icon := TextureRect.new()
		icon.texture = UiAtlas.item_tex(inst.id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(icon)
		var count := Label.new()
		count.text = str(inst.stacks)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiAtlas.apply_label(count, UiAtlas.TYPE_MICRO, UiAtlas.PARCHMENT, 10, true)
		chip.add_child(count)
		_tooltip.bind_chip(chip, inst.id, inst.stacks, cat)
		_inv_list.add_child(chip)


func _fmt_num(value: float) -> String:
	return str(int(round(value)))
