class_name LevelUpView
extends Control

signal choice_picked(index: int)

const CARD_SIZE: Vector2 = Vector2(273, 390)
const CARD_TILT: Array[float] = [-4.5, 0.0, 4.5]
const RARITY_TEXT: Dictionary = {
	"common": Color("d4b484"),
	"uncommon": Color("88c0d0"),
	"rare": Color("d4b46a"),
	"lunar": Color("62e0ff"),
}

var _banner: PanelContainer
var _title: Label
var _row: HBoxContainer
var _meta_bar: HBoxContainer
var _reroll_btn: Button
var _cards: Array[Button] = []
var _built: bool = false
var _offer_key: String = ""
var _world: SimWorld


func _ready() -> void:
	_build()


static func compute_offer_key(world: SimWorld) -> String:
	if world == null:
		return ""
	var key: String = "%d|%d|%d|%s|" % [world.rerolls_left, world.banishes_left, world.locks_left, world.locked_item_id]
	for item: Dictionary in world.offer:
		key += String(item.get("id", "")) + "|"
	return key


func refresh(world: SimWorld) -> void:
	if not _built:
		_build()
	visible = true
	_world = world
	if world == null:
		return
	var key: String = compute_offer_key(world)
	if key == _offer_key and _cards.size() == world.offer.size():
		_refresh_meta_bar(world)
		_focus_first()
		return
	_offer_key = key
	_rebuild_cards(world)


func reroll(world: SimWorld = null) -> bool:
	var target: SimWorld = world if world != null else _world
	if target == null:
		return false
	if not SimLevel.reroll_choices(target):
		_play_ui("error")
		return false
	_play_ui("click")
	refresh(target)
	return true


func focus_primary() -> void:
	_focus_first()


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
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(col)
	var header := CenterContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(header)
	_banner = PanelContainer.new()
	_banner.name = "TitleBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_banner.custom_minimum_size = Vector2(0, 63)
	# Caps are 94px; keep copy in the stretchable middle only.
	_banner.add_theme_stylebox_override("panel", UiAtlas.nine_slice("sting-banner", "idle", Vector4(100, 12, 100, 20)))
	header.add_child(_banner)
	_title = Label.new()
	_title.text = tr("ui.levelup.title")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiAtlas.apply_label(_title, UiAtlas.TYPE_DISPLAY, UiAtlas.GOLD_MOLTEN, 28, true)
	_banner.add_child(_title)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 28)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_row)
	_meta_bar = HBoxContainer.new()
	_meta_bar.name = "MetaActionBar"
	_meta_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_meta_bar.add_theme_constant_override("separation", 16)
	_meta_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_meta_bar)
	_reroll_btn = Button.new()
	_reroll_btn.name = "RerollBtn"
	_reroll_btn.custom_minimum_size = Vector2(220, 44)
	_reroll_btn.text = "%s [R]" % tr("ui.levelup.reroll").replace("{n}", "0")
	_style_meta_btn(_reroll_btn, Color("2e2018"), UiAtlas.GOLD_MOLTEN)
	_reroll_btn.pressed.connect(func() -> void: reroll(_world))
	_meta_bar.add_child(_reroll_btn)


func _rebuild_cards(world: SimWorld) -> void:
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_cards.clear()
	for i: int in world.offer.size():
		var item: Dictionary = world.offer[i]
		var id: String = String(item.get("id", ""))
		var is_locked: bool = (id != "" and world.locked_item_id == id)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 10)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card := _make_card(item, i, is_locked)
		col.add_child(card)
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		actions.add_theme_constant_override("separation", 8)
		var lock_btn := Button.new()
		lock_btn.name = "LockBtn_%d" % i
		lock_btn.custom_minimum_size = Vector2(124, 34)
		lock_btn.text = tr("ui.levelup.locked") if is_locked else tr("ui.levelup.lock").replace("{n}", str(world.locks_left))
		lock_btn.disabled = (not is_locked) and (world.locks_left <= 0 and world.locked_item_id == "")
		_style_meta_btn(
			lock_btn,
			Color("1c2a34") if is_locked else Color("1d1822"),
			Color("62e0ff") if is_locked else UiAtlas.BRASS
		)
		var captured_lock_i: int = i
		lock_btn.pressed.connect(func() -> void: _on_lock_pressed(captured_lock_i))
		actions.add_child(lock_btn)

		var banish_btn := Button.new()
		banish_btn.name = "BanishBtn_%d" % i
		banish_btn.custom_minimum_size = Vector2(124, 34)
		banish_btn.text = tr("ui.levelup.banish").replace("{n}", str(world.banishes_left))
		banish_btn.disabled = world.banishes_left <= 0
		_style_meta_btn(banish_btn, Color("2c171b"), Color("b84444"))
		var captured_banish_i: int = i
		banish_btn.pressed.connect(func() -> void: _on_banish_pressed(captured_banish_i))
		actions.add_child(banish_btn)

		col.add_child(actions)
		_row.add_child(col)
		_cards.append(card)
	_refresh_meta_bar(world)
	_focus_first()


func _make_card(item: Dictionary, index: int, is_locked: bool = false) -> Button:
	var id: String = String(item.get("id", ""))
	var rarity: String = String(item.get("rarity", "common"))
	var btn := Button.new()
	btn.custom_minimum_size = CARD_SIZE
	btn.clip_contents = true
	btn.offset_transform_enabled = true
	btn.pivot_offset = CARD_SIZE * 0.5
	var tilt: float = CARD_TILT[index] if index < CARD_TILT.size() else 0.0
	btn.offset_transform_rotation = deg_to_rad(tilt)
	btn.flat = true
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", UiAtlas.empty_focus())
	btn.add_theme_stylebox_override("disabled", empty)
	var card_art := TextureRect.new()
	card_art.texture = UiAtlas.frame("card-%s" % rarity)
	card_art.stretch_mode = TextureRect.STRETCH_SCALE
	card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(card_art)
	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 22.0
	inner.offset_right = -22.0
	inner.offset_top = 20.0
	inner.offset_bottom = -18.0
	inner.add_theme_constant_override("separation", 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(inner)
	var name_box := PanelContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_box.add_theme_stylebox_override("panel", _card_inset(Color(10.0 / 255.0, 8.0 / 255.0, 14.0 / 255.0, 0.78), Color(196.0 / 255.0, 163.0 / 255.0, 90.0 / 255.0, 0.28), Vector4(10, 4, 10, 4)))
	inner.add_child(name_box)
	var name_lab := Label.new()
	name_lab.text = Loc.item_name(id)
	name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lab.custom_minimum_size = Vector2(0, 32)
	name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiAtlas.apply_label(name_lab, UiAtlas.TYPE_DISPLAY, UiAtlas.PARCHMENT, 17, true)
	name_box.add_child(name_lab)
	var art := TextureRect.new()
	art.texture = UiAtlas.item_tex(id)
	art.custom_minimum_size = Vector2(96, 96)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(art)
	var rarity_lab := Label.new()
	rarity_lab.text = tr("ui.levelup.rarity.%s" % rarity)
	rarity_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rarity_color: Color = RARITY_TEXT.get(rarity, UiAtlas.PARCHMENT)
	UiAtlas.apply_label(rarity_lab, UiAtlas.TYPE_META, rarity_color, 14, true)
	inner.add_child(rarity_lab)
	var desc_box := PanelContainer.new()
	desc_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_box.add_theme_stylebox_override("panel", _card_inset(Color(10.0 / 255.0, 8.0 / 255.0, 14.0 / 255.0, 0.68), Color(196.0 / 255.0, 163.0 / 255.0, 90.0 / 255.0, 0.22), Vector4(10, 8, 10, 8)))
	inner.add_child(desc_box)
	var desc := VBoxContainer.new()
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_constant_override("separation", 6)
	desc.alignment = BoxContainer.ALIGNMENT_CENTER
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_box.add_child(desc)
	var hooks: Variant = item.get("hooks", [])
	if typeof(hooks) == TYPE_ARRAY:
		for hook_v: Variant in hooks:
			var formatted: Dictionary = ArchivesContent._format_hook(hook_v)
			var hook_lab := Label.new()
			hook_lab.text = String(formatted.get("text", ""))
			hook_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hook_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var hook_color: Color = Color("7dff9a") if bool(formatted.get("up", true)) else Color("ff7a6e")
			UiAtlas.apply_label(hook_lab, UiAtlas.TYPE_META, hook_color, 15, true)
			desc.add_child(hook_lab)
	var divider := ColorRect.new()
	divider.color = Color(196.0 / 255.0, 163.0 / 255.0, 90.0 / 255.0, 0.28)
	divider.custom_minimum_size = Vector2(0, 1)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.add_child(divider)
	var lore := Label.new()
	lore.text = Loc.item_lore(id)
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lore.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiAtlas.apply_label(lore, UiAtlas.TYPE_MICRO, UiAtlas.ASH, 13)
	desc.add_child(lore)
	btn.pressed.connect(func() -> void: choice_picked.emit(index))
	btn.mouse_entered.connect(func() -> void:
		btn.offset_transform_rotation = 0.0
		btn.offset_transform_scale = Vector2(1.03, 1.03)
	)
	btn.mouse_exited.connect(func() -> void:
		btn.offset_transform_rotation = deg_to_rad(tilt)
		btn.offset_transform_scale = Vector2.ONE
	)
	if is_locked:
		var lock_badge := PanelContainer.new()
		lock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_badge.add_theme_stylebox_override("panel", _card_inset(Color("10222ce6"), Color("62e0ff"), Vector4(8, 2, 8, 2)))
		lock_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		lock_badge.offset_left = -92.0
		lock_badge.offset_right = -14.0
		lock_badge.offset_top = 8.0
		lock_badge.offset_bottom = 30.0
		var lock_lab := Label.new()
		lock_lab.text = tr("ui.levelup.locked")
		lock_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiAtlas.apply_label(lock_lab, UiAtlas.TYPE_MICRO, Color("62e0ff"), 10, true)
		lock_badge.add_child(lock_lab)
		btn.add_child(lock_badge)
	return btn


func _refresh_meta_bar(world: SimWorld) -> void:
	if _reroll_btn == null or world == null:
		return
	_reroll_btn.text = "%s [R]" % tr("ui.levelup.reroll").replace("{n}", str(world.rerolls_left))
	_reroll_btn.disabled = world.rerolls_left <= 0


func _on_lock_pressed(index: int) -> void:
	if _world == null:
		return
	if not SimLevel.toggle_lock_choice(_world, index):
		_play_ui("error")
		return
	_play_ui("click")
	refresh(_world)


func _on_banish_pressed(index: int) -> void:
	if _world == null:
		return
	if not SimLevel.banish_choice(_world, index):
		_play_ui("error")
		return
	_play_ui("click")
	refresh(_world)


func _style_meta_btn(btn: Button, bg: Color, border: Color) -> void:
	var normal := _card_inset(bg, border, Vector4(12, 6, 12, 6))
	var hover := _card_inset(bg.lightened(0.14), UiAtlas.BRASS_BRIGHT, Vector4(12, 6, 12, 6))
	var disabled := _card_inset(Color("141116"), Color("3a333e"), Vector4(12, 6, 12, 6))
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", UiAtlas.empty_focus())
	if UiAtlas.body_font() != null:
		btn.add_theme_font_override("font", UiAtlas.body_font())
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", UiAtlas.PARCHMENT)
	btn.add_theme_color_override("font_hover_color", UiAtlas.GOLD_MOLTEN)
	btn.add_theme_color_override("font_disabled_color", UiAtlas.ASH)


func _card_inset(fill: Color, border: Color, pad: Vector4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


func _focus_first() -> void:
	if _cards.is_empty():
		return
	_cards[0].grab_focus()


func _play_ui(kind: String) -> void:
	var bus: Node = get_node_or_null("/root/GameAudio")
	if bus != null:
		bus.play_ui(kind)
