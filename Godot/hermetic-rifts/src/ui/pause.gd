class_name PauseView
extends Control

signal resume_pressed
signal archives_pressed
signal settings_pressed
signal seal_pressed
signal abandon_pressed

const ACTION_W: float = 288.0
const ACTION_H: float = 58.0
const PANEL_W: float = 340.0
const INV_PAD: float = 32.0
const GLYPHS: Array[String] = ["⚶", "🜍", "⟁", "🜂", "☿"]

var _title_1: Label
var _title_2: Label
var _tablet: TextureRect
var _actions: VBoxContainer
var _resume_btn: Button
var _archives_btn: Button
var _settings_btn: Button
var _seal_btn: Button
var _abandon_btn: Button
var _summary_rows: VBoxContainer
var _inv_list: GridContainer
var _inv_empty: Label
var _tooltip: PanelContainer
var _tooltip_title: Label
var _tooltip_body: Label
var _built: bool = false


func _ready() -> void:
	_build()


func refresh(world: SimWorld) -> void:
	if not _built:
		_build()
	visible = true
	_fill_summary(world)
	_fill_inventory(world)
	var can_seal: bool = world != null and SimLoop.can_seal(world)
	if _seal_btn != null:
		_seal_btn.visible = can_seal
	if _resume_btn != null:
		_resume_btn.grab_focus()


func focus_primary() -> void:
	if _resume_btn != null:
		_resume_btn.grab_focus()


func _build() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stage := CenterContainer.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 36)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(grid)
	grid.add_child(_build_left())
	grid.add_child(_build_right())


func _build_left() -> Control:
	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 12)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_1 = _display(tr("ui.pause.title.line1"), 42)
	_title_2 = _display(tr("ui.pause.title.line2"), 42)
	left.add_child(_title_1)
	left.add_child(_title_2)
	var tablet_stage := Control.new()
	tablet_stage.custom_minimum_size = Vector2(460, 410)
	tablet_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(tablet_stage)
	_tablet = TextureRect.new()
	_tablet.texture = UiAtlas.frame("pause-tablet")
	_tablet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tablet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tablet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tablet.position = Vector2(90, 10)
	_tablet.size = Vector2(370, 390)
	tablet_stage.add_child(_tablet)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 12)
	_actions.position = Vector2(0, 80)
	_actions.size = Vector2(320, 260)
	tablet_stage.add_child(_actions)
	_resume_btn = _plaque(tr("ui.pause.resume"), GLYPHS[0], 0.0)
	_resume_btn.name = "ResumeBtn"
	_archives_btn = _plaque(tr("ui.pause.archives"), GLYPHS[1], 12.0)
	_settings_btn = _plaque(tr("ui.pause.settings"), GLYPHS[2], 24.0)
	_seal_btn = _plaque(tr("ui.pause.seal"), GLYPHS[3], 36.0)
	_abandon_btn = _plaque(tr("ui.pause.abandon"), GLYPHS[4], 36.0)
	_resume_btn.pressed.connect(func() -> void: resume_pressed.emit())
	_archives_btn.pressed.connect(func() -> void: archives_pressed.emit())
	_settings_btn.pressed.connect(func() -> void: settings_pressed.emit())
	_seal_btn.pressed.connect(func() -> void: seal_pressed.emit())
	_abandon_btn.pressed.connect(func() -> void: abandon_pressed.emit())
	_actions.add_child(_resume_btn)
	_actions.add_child(_archives_btn)
	_actions.add_child(_settings_btn)
	_actions.add_child(_seal_btn)
	_actions.add_child(_abandon_btn)
	return left


func _build_right() -> Control:
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 20)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var summary := PanelContainer.new()
	summary.name = "SummaryBox"
	summary.custom_minimum_size = Vector2(PANEL_W, 0)
	summary.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	summary.add_theme_stylebox_override("panel", UiAtlas.nine_slice("parchment-panel", "idle", Vector4(30, 22, 30, 56)))
	right.add_child(summary)
	var sum_inner := VBoxContainer.new()
	sum_inner.add_theme_constant_override("separation", 8)
	summary.add_child(sum_inner)
	var sum_head := Label.new()
	sum_head.text = tr("ui.pause.summary")
	sum_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiAtlas.apply_ink_label(sum_head, UiAtlas.TYPE_DISPLAY, UiAtlas.PARCHMENT_INK, 18)
	sum_inner.add_child(sum_head)
	_summary_rows = VBoxContainer.new()
	_summary_rows.add_theme_constant_override("separation", 6)
	sum_inner.add_child(_summary_rows)
	var inv_section := VBoxContainer.new()
	inv_section.add_theme_constant_override("separation", 8)
	inv_section.custom_minimum_size.x = PANEL_W
	inv_section.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	inv_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(inv_section)
	var inv_head := Label.new()
	inv_head.text = tr("ui.pause.inventory")
	inv_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiAtlas.apply_label(inv_head, UiAtlas.TYPE_DISPLAY, UiAtlas.PARCHMENT, 18, true)
	inv_section.add_child(inv_head)
	var inv_box := PanelContainer.new()
	inv_box.name = "InventoryBox"
	inv_box.custom_minimum_size = Vector2(PANEL_W, PANEL_W)
	inv_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_box.add_theme_stylebox_override("panel", UiAtlas.nine_slice("pause-inventory", "idle", Vector4(INV_PAD, INV_PAD, INV_PAD, INV_PAD)))
	inv_section.add_child(inv_box)
	var inv_stage := Control.new()
	inv_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_stage.custom_minimum_size = Vector2(PANEL_W - INV_PAD * 2.0, PANEL_W - INV_PAD * 2.0)
	inv_box.add_child(inv_stage)
	_inv_list = GridContainer.new()
	_inv_list.columns = 4
	_inv_list.add_theme_constant_override("h_separation", 6)
	_inv_list.add_theme_constant_override("v_separation", 6)
	_inv_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inv_stage.add_child(_inv_list)
	_inv_empty = Label.new()
	_inv_empty.name = "EmptyInv"
	_inv_empty.text = tr("ui.pause.empty_inv")
	_inv_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inv_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_inv_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inv_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiAtlas.apply_label(_inv_empty, UiAtlas.TYPE_MICRO, UiAtlas.ASH, 13)
	inv_stage.add_child(_inv_empty)
	_tooltip = PanelContainer.new()
	_tooltip.visible = false
	_tooltip.add_theme_stylebox_override("panel", UiAtlas.nine_slice("parchment-panel", "idle", Vector4(16, 12, 16, 12)))
	_tooltip.custom_minimum_size = Vector2(220, 0)
	inv_section.add_child(_tooltip)
	var tip_col := VBoxContainer.new()
	_tooltip.add_child(tip_col)
	_tooltip_title = Label.new()
	UiAtlas.apply_ink_label(_tooltip_title, UiAtlas.TYPE_META, UiAtlas.PARCHMENT_INK, 14)
	tip_col.add_child(_tooltip_title)
	_tooltip_body = Label.new()
	_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_body.custom_minimum_size = Vector2(200, 0)
	UiAtlas.apply_ink_label(_tooltip_body, UiAtlas.TYPE_BODY, Color("2e2014"), 13)
	tip_col.add_child(_tooltip_body)
	return right


func _fill_summary(world: SimWorld) -> void:
	for child: Node in _summary_rows.get_children():
		_summary_rows.remove_child(child)
		child.free()
	if world == null:
		return
	var rows: Array[Array] = [
		[tr("ui.pause.row.cycle"), SimRng.cycle_numeral(world.cycle_index)],
		[tr("ui.pause.row.time"), Loc.format_time(world.run_time)],
		[tr("ui.pause.row.level"), str(world.level)],
		[tr("ui.pause.row.kills"), str(world.kills_total)],
		[tr("ui.pause.row.bosses"), str(world.kills_boss)],
		[tr("ui.pause.row.damage"), str(int(round(world.damage_dealt)))],
		[tr("ui.pause.row.items"), str(world.inventory.size())],
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
		_summary_rows.add_child(row)


func _fill_inventory(world: SimWorld) -> void:
	for child: Node in _inv_list.get_children():
		_inv_list.remove_child(child)
		child.free()
	_tooltip.visible = false
	var n: int = 0 if world == null else world.inventory.size()
	_inv_empty.visible = n == 0
	_inv_list.visible = n > 0
	if n == 0:
		return
	_inv_list.columns = maxi(4, int(ceil(sqrt(float(n)))))
	for inst: ItemInstance in world.inventory:
		var chip := Button.new()
		chip.custom_minimum_size = Vector2(36, 36)
		chip.flat = true
		var icon := TextureRect.new()
		icon.texture = UiAtlas.item_tex(inst.id)
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
		var item_id: String = inst.id
		chip.mouse_entered.connect(func() -> void: _show_tip(item_id))
		chip.mouse_exited.connect(func() -> void: _tooltip.visible = false)
		chip.focus_entered.connect(func() -> void: _show_tip(item_id))
		_inv_list.add_child(chip)


func _show_tip(item_id: String) -> void:
	_tooltip_title.text = Loc.item_name(item_id)
	_tooltip_body.text = Loc.item_lore(item_id)
	_tooltip.visible = true


func _plaque(text: String, glyph: String, indent: float) -> Button:
	var btn := Button.new()
	btn.text = "%s    %s" % [text.to_upper(), glyph]
	btn.custom_minimum_size = Vector2(ACTION_W, ACTION_H)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.offset_transform_enabled = true
	btn.offset_transform_position = Vector2(indent, 0.0)
	UiAtlas.apply_button_styles(btn, "btn-plaque")
	btn.add_theme_font_size_override("font_size", 16)
	return btn


func _display(text: String, px: int) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiAtlas.apply_label(lab, UiAtlas.TYPE_DISPLAY, UiAtlas.GOLD_MOLTEN, px, true)
	return lab
