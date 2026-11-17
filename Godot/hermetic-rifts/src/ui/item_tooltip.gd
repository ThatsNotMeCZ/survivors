class_name ItemTooltip
extends PanelContainer

const OFFSET: Vector2 = Vector2(16, 16)
const PAD: float = 12.0
const TIP_W: float = 300.0
const HOOK_UP: Color = Color("1f7a2c")
const HOOK_DOWN: Color = Color("a61c1c")
const LORE_INK: Color = Color("2e2218")

var _icon: TextureRect
var _name: Label
var _hooks: VBoxContainer
var _lore: Label
var _built: bool = false


func _init() -> void:
	_build()


func bind_chip(chip: Control, item_id: String, stacks: int, catalog: Catalog) -> void:
	chip.mouse_entered.connect(func() -> void:
		show_item(item_id, stacks, catalog)
		place_at(chip.get_global_mouse_position())
	)
	chip.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseMotion and visible:
			place_at(chip.get_global_mouse_position())
	)
	chip.mouse_exited.connect(hide_tip)
	chip.focus_entered.connect(func() -> void:
		show_item(item_id, stacks, catalog)
		var r: Rect2 = chip.get_global_rect()
		place_at(Vector2(r.position.x + r.size.x, r.position.y))
	)
	chip.focus_exited.connect(hide_tip)


func show_item(item_id: String, stacks: int, catalog: Catalog) -> void:
	_build()
	_icon.texture = UiAtlas.item_tex(item_id)
	var title: String = Loc.item_name(item_id).to_upper()
	_name.text = "%s ×%d" % [title, stacks] if stacks > 1 else title
	for child: Node in _hooks.get_children():
		_hooks.remove_child(child)
		child.free()
	if catalog != null and catalog.has_item(item_id):
		var def: Dictionary = catalog.item(item_id)
		var hooks_v: Variant = def.get("hooks", [])
		if typeof(hooks_v) == TYPE_ARRAY:
			var hooks: Array = hooks_v
			for hook_v: Variant in hooks:
				var formatted: Dictionary = ArchivesContent._format_hook(hook_v)
				var hook_lab := Label.new()
				hook_lab.text = String(formatted.get("text", ""))
				hook_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				hook_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hook_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var up: bool = bool(formatted.get("up", true))
				UiAtlas.apply_ink_label(hook_lab, UiAtlas.TYPE_META, HOOK_UP if up else HOOK_DOWN, 14)
				_hooks.add_child(hook_lab)
	_lore.text = Loc.item_lore(item_id)
	visible = true
	reset_size()


func hide_tip() -> void:
	visible = false


func place_at(global_pos: Vector2) -> void:
	if not visible:
		return
	reset_size()
	var sz: Vector2 = size
	if sz.x < 1.0:
		sz.x = TIP_W
	if sz.y < 1.0:
		sz.y = 220.0
	var vp: Vector2 = get_viewport_rect().size
	var pos: Vector2 = global_pos + OFFSET
	if pos.x + sz.x + PAD > vp.x:
		pos.x = maxf(PAD, global_pos.x - sz.x - OFFSET.x)
	if pos.y + sz.y + PAD > vp.y:
		pos.y = maxf(PAD, global_pos.y - sz.y - OFFSET.y)
	global_position = pos


func _build() -> void:
	if _built:
		return
	_built = true
	visible = false
	top_level = true
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(TIP_W, 0.0)
	add_theme_stylebox_override("panel", UiAtlas.nine_slice("parchment-panel", "idle", Vector4(46, 38, 46, 44)))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(64, 64)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_icon)
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiAtlas.apply_ink_label(_name, UiAtlas.TYPE_META, UiAtlas.PARCHMENT_INK, 15)
	col.add_child(_name)
	_hooks = VBoxContainer.new()
	_hooks.add_theme_constant_override("separation", 2)
	_hooks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_hooks)
	_lore = Label.new()
	_lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore.custom_minimum_size = Vector2(TIP_W - 92.0, 0.0)
	_lore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lore.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiAtlas.apply_ink_label(_lore, UiAtlas.TYPE_BODY, LORE_INK, 12)
	var italic := FontVariation.new()
	italic.base_font = UiAtlas.ink_font()
	italic.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.22, 1.0), Vector2.ZERO)
	_lore.add_theme_font_override("font", italic)
	col.add_child(_lore)
