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

var _banner: TextureRect
var _title: Label
var _row: HBoxContainer
var _cards: Array[Button] = []
var _built: bool = false
var _offer_key: String = ""


func _ready() -> void:
	_build()


func refresh(world: SimWorld) -> void:
	if not _built:
		_build()
	visible = true
	if world == null:
		return
	var key: String = ""
	for item: Dictionary in world.offer:
		key += String(item.get("id", "")) + "|"
	if key == _offer_key and _cards.size() == world.offer.size():
		_focus_first()
		return
	_offer_key = key
	_rebuild_cards(world)


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
	col.add_theme_constant_override("separation", 28)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(col)
	var header := CenterContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(header)
	_banner = TextureRect.new()
	_banner.texture = UiAtlas.frame("sting-banner")
	_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_banner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_banner.custom_minimum_size = Vector2(560, 72)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_banner)
	_title = Label.new()
	_title.text = tr("ui.levelup.title")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiAtlas.apply_label(_title, UiAtlas.TYPE_DISPLAY, UiAtlas.GOLD_MOLTEN, 28, true)
	_banner.add_child(_title)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 28)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_row)


func _rebuild_cards(world: SimWorld) -> void:
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.free()
	_cards.clear()
	for i: int in world.offer.size():
		var item: Dictionary = world.offer[i]
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 14)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card := _make_card(item, i)
		col.add_child(card)
		var key := Label.new()
		key.text = "[%d]" % (i + 1)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiAtlas.apply_label(key, UiAtlas.TYPE_DISPLAY, UiAtlas.PARCHMENT, 22, true)
		col.add_child(key)
		_row.add_child(col)
		_cards.append(card)
	_focus_first()


func _make_card(item: Dictionary, index: int) -> Button:
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
	var name_lab := Label.new()
	name_lab.text = Loc.item_name(id)
	name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiAtlas.apply_label(name_lab, UiAtlas.TYPE_DISPLAY, UiAtlas.PARCHMENT, 17, true)
	inner.add_child(name_lab)
	var art := TextureRect.new()
	art.texture = UiAtlas.item_tex(id)
	art.custom_minimum_size = Vector2(96, 96)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(art)
	var rarity_lab := Label.new()
	rarity_lab.text = tr("ui.levelup.rarity.%s" % rarity)
	rarity_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rarity_color: Color = RARITY_TEXT.get(rarity, UiAtlas.PARCHMENT)
	UiAtlas.apply_label(rarity_lab, UiAtlas.TYPE_META, rarity_color, 14, true)
	inner.add_child(rarity_lab)
	var desc := VBoxContainer.new()
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_constant_override("separation", 2)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(desc)
	var hooks: Variant = item.get("hooks", [])
	if typeof(hooks) == TYPE_ARRAY:
		for hook_v: Variant in hooks:
			var formatted: Dictionary = ArchivesContent._format_hook(hook_v)
			var hook_lab := Label.new()
			hook_lab.text = String(formatted.get("text", ""))
			hook_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var hook_color: Color = Color("7dff9a") if bool(formatted.get("up", true)) else Color("ff7a6e")
			UiAtlas.apply_label(hook_lab, UiAtlas.TYPE_META, hook_color, 15, true)
			desc.add_child(hook_lab)
	var lore := Label.new()
	lore.text = Loc.item_lore(id)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	return btn


func _focus_first() -> void:
	if _cards.is_empty():
		return
	_cards[0].grab_focus()
