class_name DeskView
extends Control

const Display := preload("res://src/data/display_settings.gd")

signal closed

const PANEL_WIDTH: float = 700.0
const SCROLL_MAX: float = 520.0
const INK_HINT: Color = Color("2e2014")
const TAB_KEYS: Array[StringName] = [&"display", &"audio", &"visual", &"controls"]
const TAB_ICONS: Dictionary = {
	&"display": "icon-display",
	&"audio": "icon-audio",
	&"visual": "icon-visual",
	&"controls": "icon-controls",
}
const CONTROL_ACTIONS: Array[String] = [
	"move_up",
	"move_down",
	"move_left",
	"move_right",
	"fire_primary",
	"fire_secondary",
	"utility",
	"special",
	"interact",
]

var _dim: ColorRect
var _panel: PanelContainer
var _kicker: Label
var _title: Label
var _lead: Label
var _tab_strip: HBoxContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _confirm_bar: Control
var _confirm_label: Label
var _keep_btn: Button
var _revert_btn: Button
var _close_btn: Button
var _first_choice: Control
var _active_tab: StringName = &"display"
var _tab_btns: Dictionary = {}
var _bound: bool = false
var _rebuilding: bool = false
var _pending_snapshot: Dictionary = {}
var _confirm_left: float = 0.0
var _listening_action: String = ""
var _rebind_btns: Dictionary = {}


func _ready() -> void:
	z_index = 40
	set_process(false)
	_resolve_nodes()
	_apply_chrome()
	_bind()
	if get_tree() != null and get_tree().current_scene == self:
		call_deferred("refresh")


func is_listening() -> bool:
	return _listening_action != ""


func _input(event: InputEvent) -> void:
	if not visible or _listening_action == "":
		return
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
			_cancel_rebind()
			get_viewport().set_input_as_handled()
			return
		var key_code: Key = k.keycode
		var phys_code: Key = k.physical_keycode
		if key_code == 0 and phys_code == 0:
			return
		var new_key := InputEventKey.new()
		new_key.device = GameSettings.ALL_DEVICES
		new_key.keycode = key_code
		new_key.physical_keycode = phys_code
		_apply_rebind(_listening_action, new_key)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index in [
			MOUSE_BUTTON_WHEEL_UP,
			MOUSE_BUTTON_WHEEL_DOWN,
			MOUSE_BUTTON_WHEEL_LEFT,
			MOUSE_BUTTON_WHEEL_RIGHT,
		]:
			get_viewport().set_input_as_handled()
			return
		var new_mb := InputEventMouseButton.new()
		new_mb.device = GameSettings.ALL_DEVICES
		new_mb.button_index = mb.button_index
		_apply_rebind(_listening_action, new_mb)
		get_viewport().set_input_as_handled()


func refresh() -> void:
	_listening_action = ""
	_rebuild_rows()
	call_deferred("_center_panel")
	call_deferred("focus_primary")


func focus_primary() -> void:
	if _is_focusable_control(_first_choice):
		_first_choice.grab_focus()
		return
	if _is_focusable_control(_close_btn):
		_close_btn.grab_focus()


func _is_focusable_control(ctrl: Control) -> bool:
	if ctrl == null or not is_instance_valid(ctrl) or not ctrl.is_inside_tree():
		return false
	if not ctrl.is_visible_in_tree() or ctrl.focus_mode == Control.FOCUS_NONE:
		return false
	if ctrl is BaseButton:
		return not (ctrl as BaseButton).disabled
	if ctrl is Slider:
		return (ctrl as Slider).editable
	return true


func handle_back() -> bool:
	if not visible:
		return false
	if _listening_action != "":
		_cancel_rebind()
		return true
	_close()
	return true


func _process(delta: float) -> void:
	if _pending_snapshot.is_empty():
		set_process(false)
		return
	_confirm_left -= delta
	_refresh_confirm_label()
	if _confirm_left <= 0.0:
		_revert_display()


func _resolve_nodes() -> void:
	_dim = get_node_or_null("Dim") as ColorRect
	_panel = get_node_or_null("Panel") as PanelContainer
	_kicker = get_node_or_null("Panel/Inner/Kicker") as Label
	_title = get_node_or_null("Panel/Inner/Title") as Label
	_lead = get_node_or_null("Panel/Inner/Lead") as Label
	_tab_strip = get_node_or_null("Panel/Inner/TabStrip") as HBoxContainer
	if _tab_strip == null:
		var inner := get_node_or_null("Panel/Inner") as VBoxContainer
		if inner != null:
			_tab_strip = HBoxContainer.new()
			_tab_strip.name = "TabStrip"
			inner.add_child(_tab_strip)
	_scroll = get_node_or_null("Panel/Inner/Scroll") as ScrollContainer
	_body = get_node_or_null("Panel/Inner/Scroll/Body") as VBoxContainer
	if _body == null:
		_body = get_node_or_null("Panel/Inner/Body") as VBoxContainer
	_confirm_bar = get_node_or_null("Panel/Inner/ConfirmBar") as Control
	_confirm_label = get_node_or_null("Panel/Inner/ConfirmBar/ConfirmRow/ConfirmLabel") as Label
	_keep_btn = get_node_or_null("Panel/Inner/ConfirmBar/ConfirmRow/KeepBtn") as Button
	_revert_btn = get_node_or_null("Panel/Inner/ConfirmBar/ConfirmRow/RevertBtn") as Button
	_close_btn = get_node_or_null("Panel/Inner/CloseBtn") as Button


func _apply_chrome() -> void:
	if _dim != null:
		_dim.color = Color(0.047, 0.039, 0.051, 0.62)
		_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if _panel != null:
		_panel.add_theme_stylebox_override("panel", UiAtlas.nine_slice("parchment-panel", "idle", Vector4(40, 36, 40, 32)))
		_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	if _kicker != null:
		_kicker.text = tr("ui.settings.title")
		UiAtlas.apply_ink_label(_kicker, UiAtlas.TYPE_META, Color("2e2014"), 14)
	if _title != null:
		_title.text = tr("ui.settings.heading")
		UiAtlas.apply_ink_label(_title, UiAtlas.TYPE_DISPLAY, UiAtlas.PARCHMENT_INK, UiAtlas.SIZE_DISPLAY_M)
	if _lead != null:
		_lead.text = tr("ui.settings.lead")
		UiAtlas.apply_ink_label(_lead, UiAtlas.TYPE_BODY, Color("2e2014"), UiAtlas.SIZE_BODY)
		_lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _tab_strip != null:
		_tab_strip.add_theme_constant_override("separation", 8)
		_tab_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_build_tabs()
	if _scroll != null:
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _body != null:
		_body.add_theme_constant_override("separation", 0)
		_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _confirm_bar != null:
		_confirm_bar.visible = not _pending_snapshot.is_empty()
	if _confirm_label != null:
		UiAtlas.apply_ink_label(_confirm_label, UiAtlas.TYPE_META, UiAtlas.PARCHMENT_INK, UiAtlas.SIZE_META)
		_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_confirm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _keep_btn != null:
		_keep_btn.text = tr("ui.settings.keep.action").to_upper()
		UiAtlas.apply_button_styles(_keep_btn, "btn-plaque")
		_keep_btn.custom_minimum_size = Vector2(120, 40)
	if _revert_btn != null:
		_revert_btn.text = tr("ui.settings.revert").to_upper()
		UiAtlas.apply_button_styles(_revert_btn, "btn-plaque")
		_revert_btn.custom_minimum_size = Vector2(120, 40)
	if _close_btn != null:
		_close_btn.text = tr("ui.settings.close").to_upper()
		UiAtlas.apply_button_styles(_close_btn, "btn-plaque")
		_close_btn.custom_minimum_size = Vector2(0, 48)
		_close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := get_node_or_null("Panel/Inner") as VBoxContainer
	if inner != null:
		_move_named(inner, _kicker, 0)
		_move_named(inner, _title, 1)
		_move_named(inner, _lead, 2)
		var next_idx: int = 3
		if _tab_strip != null:
			_move_named(inner, _tab_strip, next_idx)
			next_idx += 1
		if _scroll != null:
			_move_named(inner, _scroll, next_idx)
			next_idx += 1
		elif _body != null:
			_move_named(inner, _body, next_idx)
			next_idx += 1
		if _confirm_bar != null:
			_move_named(inner, _confirm_bar, next_idx)
			next_idx += 1
		if _close_btn != null:
			_move_named(inner, _close_btn, next_idx)
	_center_panel()


func _build_tabs() -> void:
	if _tab_strip == null or not _tab_btns.is_empty():
		return
	for i: int in TAB_KEYS.size():
		var key: StringName = TAB_KEYS[i]
		var btn := Button.new()
		btn.name = "Tab_%s" % String(key)
		btn.text = ""
		btn.custom_minimum_size = Vector2(0, 38)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_ALL
		var row := HBoxContainer.new()
		row.name = "Row"
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10.0
		row.offset_right = -10.0
		row.offset_top = 4.0
		row.offset_bottom = -4.0
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(UiAtlas.make_icon(String(TAB_ICONS[key]), 24))
		var lab := Label.new()
		lab.name = "Label"
		var section_key: String = "ui.settings.section.%s" % String(key)
		lab.text = _t(section_key, String(key).capitalize()).to_upper()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiAtlas.apply_label(lab, UiAtlas.TYPE_META, UiAtlas.PARCHMENT, 13, true)
		row.add_child(lab)
		btn.add_child(row)
		var cap_key: StringName = key
		btn.pressed.connect(func() -> void: _select_tab(cap_key))
		_tab_strip.add_child(btn)
		_tab_btns[key] = btn
	_refresh_tab_styles()


func _refresh_tab_styles() -> void:
	for key: StringName in TAB_KEYS:
		var btn := _tab_btns.get(key) as Button
		if btn == null:
			continue
		var active: bool = key == _active_tab
		UiAtlas.style_desk_tab(btn, active)
		var lab := btn.get_node_or_null("Row/Label") as Label
		if lab != null:
			lab.add_theme_color_override("font_color", UiAtlas.BRASS_BRIGHT if active else UiAtlas.PARCHMENT)


func _select_tab(key: StringName) -> void:
	if key == _active_tab:
		return
	_active_tab = key
	_listening_action = ""
	_play_ui("click")
	_rebuild_rows()
	call_deferred("_center_panel")
	call_deferred("focus_primary")


func _wire_focus() -> void:
	var target: Control = _first_choice if (_first_choice != null and _first_choice.is_inside_tree()) else _close_btn
	for i: int in TAB_KEYS.size():
		var key: StringName = TAB_KEYS[i]
		var btn := _tab_btns.get(key) as Button
		if btn == null or not btn.is_inside_tree():
			continue
		if i > 0:
			var prev := _tab_btns.get(TAB_KEYS[i - 1]) as Button
			if prev != null:
				btn.focus_neighbor_left = btn.get_path_to(prev)
				prev.focus_neighbor_right = prev.get_path_to(btn)
		if target != null:
			btn.focus_neighbor_bottom = btn.get_path_to(target)
	var active_tab_btn := _tab_btns.get(_active_tab) as Button
	if _first_choice != null and _first_choice.is_inside_tree() and active_tab_btn != null and active_tab_btn.is_inside_tree():
		_first_choice.focus_neighbor_top = _first_choice.get_path_to(active_tab_btn)


func _move_named(inner: VBoxContainer, node: Node, index: int) -> void:
	if node == null or node.get_parent() != inner:
		return
	inner.move_child(node, mini(index, inner.get_child_count() - 1))


func _bind() -> void:
	if _bound:
		return
	_bound = true
	if _close_btn != null:
		_close_btn.pressed.connect(_on_close)
	if _keep_btn != null:
		_keep_btn.pressed.connect(_keep_display)
	if _revert_btn != null:
		_revert_btn.pressed.connect(_revert_display)
	if _dim != null:
		_dim.gui_input.connect(_on_dim_input)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_close()


func _on_close() -> void:
	_play_ui("close")
	_close()


func _close() -> void:
	_listening_action = ""
	if not _pending_snapshot.is_empty():
		_revert_display()
	visible = false
	closed.emit()


func _rebuild_rows() -> void:
	if _body == null:
		return
	_rebuilding = true
	_first_choice = null
	_rebind_btns.clear()
	_refresh_tab_styles()
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var app := get_node_or_null("/root/App")
	if app == null:
		_rebuilding = false
		return
	var settings: GameSettings = app.settings
	Display.sanitize(settings)
	match _active_tab:
		&"audio":
			_fill_audio(settings)
		&"visual":
			_fill_visual(settings)
		&"controls":
			_fill_controls()
		_:
			_fill_display(settings)
	_rebuilding = false
	_clamp_scroll()
	_wire_focus()


func _fill_display(settings: GameSettings) -> void:
	var mode_items: Array[String] = [
		tr("ui.settings.window_mode.windowed"),
		tr("ui.settings.window_mode.borderless"),
		tr("ui.settings.window_mode.exclusive"),
	]
	var mode_idx: int = Display.MODE_OPTIONS.find(settings.window_mode)
	_body.add_child(_choice_row(
		tr("ui.settings.window_mode"),
		tr("ui.settings.window_mode.hint"),
		mode_items,
		maxi(mode_idx, 0),
		false,
		func(idx: int) -> void: _set_window_mode(idx)
	))
	var screen_count: int = DisplayServer.get_screen_count()
	if screen_count > 1:
		var monitors: Array[String] = []
		for i: int in range(screen_count):
			var sz: Vector2i = Display.screen_size(i)
			monitors.append(
				tr("ui.settings.monitor.item")
					.replace("{n}", str(i + 1))
					.replace("{w}", str(sz.x))
					.replace("{h}", str(sz.y))
			)
		_body.add_child(_choice_row(
			tr("ui.settings.monitor"),
			tr("ui.settings.monitor.hint"),
			monitors,
			settings.screen_index,
			false,
			func(idx: int) -> void: _set_monitor(idx)
		))
	var borderless: bool = settings.window_mode == Display.MODE_BORDERLESS
	var native: Vector2i = Display.screen_size(settings.screen_index)
	var res_items: Array[String] = []
	var res_idx: int = 0
	if borderless:
		res_items.append(
			tr("ui.settings.resolution.native")
				.replace("{w}", str(native.x))
				.replace("{h}", str(native.y))
		)
	else:
		var allowed: Array[Vector2i] = Display.resolutions_for_screen(settings.screen_index)
		var chosen := Vector2i(settings.resolution_w, settings.resolution_h)
		for i: int in range(allowed.size()):
			res_items.append(Display.format_res(allowed[i]))
			if allowed[i] == chosen:
				res_idx = i
	_body.add_child(_choice_row(
		tr("ui.settings.resolution"),
		tr("ui.settings.resolution.hint"),
		res_items,
		res_idx,
		borderless,
		func(idx: int) -> void: _set_resolution(idx)
	))
	var vsync_items: Array[String] = [
		tr("ui.settings.vsync.off"),
		tr("ui.settings.vsync.on"),
		tr("ui.settings.vsync.adaptive"),
	]
	var vsync_idx: int = Display.VSYNC_OPTIONS.find(settings.vsync)
	_body.add_child(_choice_row(
		tr("ui.settings.vsync"),
		tr("ui.settings.vsync.hint"),
		vsync_items,
		maxi(vsync_idx, 0),
		false,
		func(idx: int) -> void: _set_vsync(idx)
	))
	var fps_items: Array[String] = []
	var fps_idx: int = 0
	for i: int in range(Display.FPS_OPTIONS.size()):
		var cap: int = Display.FPS_OPTIONS[i]
		fps_items.append(tr("ui.settings.fps.unlimited") if cap == 0 else str(cap))
		if cap == settings.max_fps:
			fps_idx = i
	_body.add_child(_choice_row(
		tr("ui.settings.fps"),
		tr("ui.settings.fps.hint"),
		fps_items,
		fps_idx,
		false,
		func(idx: int) -> void: _set_fps(idx)
	))


func _fill_audio(settings: GameSettings) -> void:
	_body.add_child(_range_row(
		tr("ui.settings.master"),
		tr("ui.settings.master.hint"),
		settings.master_volume,
		func(v: float) -> void: _set_volume("master", v)
	))
	_body.add_child(_range_row(
		tr("ui.settings.sfx"),
		tr("ui.settings.sfx.hint"),
		settings.sfx_volume,
		func(v: float) -> void: _set_volume("sfx", v)
	))
	_body.add_child(_range_row(
		tr("ui.settings.music"),
		tr("ui.settings.music.hint"),
		settings.music_volume,
		func(v: float) -> void: _set_volume("music", v)
	))
	_body.add_child(_check_row(
		tr("ui.settings.mute"),
		tr("ui.settings.mute.hint"),
		settings.muted,
		func(v: bool) -> void: _set_flag("muted", v)
	))


func _fill_visual(settings: GameSettings) -> void:
	_body.add_child(_check_row(
		tr("ui.settings.shake"),
		tr("ui.settings.shake.hint"),
		settings.screenshake,
		func(v: bool) -> void: _set_flag("screenshake", v)
	))
	_body.add_child(_check_row(
		tr("ui.settings.vfx"),
		tr("ui.settings.vfx.hint"),
		settings.reduce_vfx,
		func(v: bool) -> void: _set_flag("reduce_vfx", v)
	))


func _fill_controls() -> void:
	var labels: Dictionary = {
		"move_up": [_t("ui.settings.key.move_up", "Move Up"), _t("ui.settings.key.move_up.hint", "Step northward across the chamber.")],
		"move_down": [_t("ui.settings.key.move_down", "Move Down"), _t("ui.settings.key.move_down.hint", "Step southward across the chamber.")],
		"move_left": [_t("ui.settings.key.move_left", "Move Left"), _t("ui.settings.key.move_left.hint", "Step westward across the chamber.")],
		"move_right": [_t("ui.settings.key.move_right", "Move Right"), _t("ui.settings.key.move_right.hint", "Step eastward across the chamber.")],
		"fire_primary": [_t("ui.settings.key.primary", "Primary Art (I)"), _t("ui.settings.key.primary.hint", "Cast your vessel's primary skill.")],
		"fire_secondary": [_t("ui.settings.key.secondary", "Secondary Art (II)"), _t("ui.settings.key.secondary.hint", "Cast secondary skill or Critical Vent.")],
		"utility": [_t("ui.settings.key.utility", "Utility Art (III)"), _t("ui.settings.key.utility.hint", "Dash or invoke your defensive ward.")],
		"special": [_t("ui.settings.key.special", "Special Rite (IV)"), _t("ui.settings.key.special.hint", "Unleash your ultimate alchemical skill.")],
		"interact": [_t("ui.settings.key.interact", "Interact / Channel"), _t("ui.settings.key.interact.hint", "Activate Transmutation Circles, Obelisks, and Portals.")],
	}
	for action: String in CONTROL_ACTIONS:
		var meta: Array = labels.get(action, [action, ""])
		_body.add_child(_rebind_row(action, String(meta[0]), String(meta[1])))
	_body.add_child(_reset_controls_row())


func _rebind_row(action: String, title: String, hint: String) -> Control:
	var row_wrap := _row_shell(_body.get_child_count() == 0)
	var row := row_wrap.get_node("Row") as HBoxContainer
	row.add_child(_copy_col(title, hint))
	var btn := Button.new()
	btn.name = "Bind_%s" % action
	btn.custom_minimum_size = Vector2(220, 38)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_ALL
	_style_rebind_btn(btn, false)
	btn.text = _binding_label(action)
	var captured_action: String = action
	btn.pressed.connect(func() -> void: _start_rebind(captured_action))
	row.add_child(btn)
	_rebind_btns[action] = btn
	if _first_choice == null:
		_first_choice = btn
	return row_wrap


func _reset_controls_row() -> Control:
	var row_wrap := _row_shell(_body.get_child_count() == 0)
	var row := row_wrap.get_node("Row") as HBoxContainer
	row.add_child(_copy_col(
		_t("ui.settings.controls.reset", "Reset Controls to Default"),
		_t("ui.settings.controls.reset.hint", "Restore all movement, skill, and interact bindings.")
	))
	var btn := Button.new()
	btn.name = "ResetControlsBtn"
	btn.custom_minimum_size = Vector2(220, 38)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_ALL
	btn.text = _t("ui.settings.controls.reset_btn", "Reset to Default")
	_style_rebind_btn(btn, false)
	btn.pressed.connect(_reset_controls)
	row.add_child(btn)
	return row_wrap


func _style_rebind_btn(btn: Button, listening: bool) -> void:
	var bg := Color("4a2818") if listening else Color("2a2018")
	var border := Color("ffd46a") if listening else Color("6e3b1e")
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	normal.content_margin_top = 4.0
	normal.content_margin_bottom = 4.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.12)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", hover)
	if UiAtlas.ink_font() != null:
		btn.add_theme_font_override("font", UiAtlas.ink_font())
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color("ffe896") if listening else UiAtlas.PARCHMENT)
	btn.add_theme_color_override("font_hover_color", UiAtlas.GOLD_MOLTEN)
	btn.add_theme_color_override("font_focus_color", UiAtlas.GOLD_MOLTEN)


func _start_rebind(action: String) -> void:
	_play_ui("click")
	_listening_action = action
	_refresh_control_buttons()


func _cancel_rebind() -> void:
	_play_ui("close")
	_listening_action = ""
	_refresh_control_buttons()


func _apply_rebind(target_action: String, new_ev: InputEvent) -> void:
	if not InputMap.has_action(target_action):
		InputMap.add_action(target_action)
	var target_events: Array[InputEvent] = InputMap.action_get_events(target_action)
	var old_primary: InputEvent = target_events[0].duplicate() as InputEvent if not target_events.is_empty() else null
	for other: String in CONTROL_ACTIONS:
		if other == target_action or not InputMap.has_action(other):
			continue
		var other_events: Array[InputEvent] = InputMap.action_get_events(other)
		var conflict_idx: int = -1
		for j: int in other_events.size():
			if _events_match(other_events[j], new_ev):
				conflict_idx = j
				break
		if conflict_idx >= 0:
			var swapped: Array[InputEvent] = []
			for j: int in other_events.size():
				if j == conflict_idx:
					if old_primary != null:
						swapped.append(old_primary.duplicate() as InputEvent)
				else:
					swapped.append(other_events[j])
			InputMap.action_erase_events(other)
			for ev: InputEvent in swapped:
				InputMap.action_add_event(other, ev)
	var next_events: Array[InputEvent] = [new_ev]
	for k: int in range(1, target_events.size()):
		if not _events_match(target_events[k], new_ev):
			next_events.append(target_events[k])
	InputMap.action_erase_events(target_action)
	for ev: InputEvent in next_events:
		InputMap.action_add_event(target_action, ev)
	var app := get_node_or_null("/root/App")
	if app != null and app.settings != null:
		var settings: GameSettings = app.settings
		settings.capture_input_rebinds_from_input_map()
		var interact_list: Array[Dictionary] = []
		for ev: InputEvent in InputMap.action_get_events("interact"):
			var desc: Dictionary = _event_to_descriptor(ev)
			if not desc.is_empty():
				interact_list.append(desc)
		settings.input_rebinds["interact"] = interact_list
		settings.save()
	_listening_action = ""
	_play_ui("confirm")
	_refresh_control_buttons()


func _reset_controls() -> void:
	_listening_action = ""
	var app := get_node_or_null("/root/App")
	if app != null and app.settings != null:
		var settings: GameSettings = app.settings
		settings.reset_input_rebinds_to_default()
		if not InputMap.has_action("interact"):
			InputMap.add_action("interact")
		InputMap.action_erase_events("interact")
		var ev := InputEventKey.new()
		ev.device = GameSettings.ALL_DEVICES
		ev.physical_keycode = KEY_E
		InputMap.action_add_event("interact", ev)
		settings.save()
	_play_ui("click")
	_refresh_control_buttons()


func _refresh_control_buttons() -> void:
	for action_v: Variant in _rebind_btns.keys():
		var action: String = String(action_v)
		var btn: Button = _rebind_btns[action] as Button
		if btn == null:
			continue
		var listening: bool = action == _listening_action
		btn.text = _t("ui.settings.rebind.listen", "Press key/mouse... [Esc]") if listening else _binding_label(action)
		_style_rebind_btn(btn, listening)


func _binding_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "-"
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return _t("ui.settings.rebind.unbound", "Unbound")
	return events[0].as_text().replace(" (Physical)", "")


static func _events_match(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var ak: InputEventKey = a as InputEventKey
		var bk: InputEventKey = b as InputEventKey
		var ac: int = int(ak.physical_keycode) if int(ak.physical_keycode) != 0 else int(ak.keycode)
		var bc: int = int(bk.physical_keycode) if int(bk.physical_keycode) != 0 else int(bk.keycode)
		return ac != 0 and ac == bc
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


static func _event_to_descriptor(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k: InputEventKey = ev as InputEventKey
		return {
			"type": "key",
			"keycode": int(k.keycode),
			"physical_keycode": int(k.physical_keycode),
		}
	if ev is InputEventMouseButton:
		var m: InputEventMouseButton = ev as InputEventMouseButton
		return {
			"type": "mouse",
			"button_index": int(m.button_index),
		}
	if ev is InputEventJoypadButton:
		var jb: InputEventJoypadButton = ev as InputEventJoypadButton
		return {
			"type": "joy_button",
			"button_index": int(jb.button_index),
		}
	if ev is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = ev as InputEventJoypadMotion
		return {
			"type": "joy_axis",
			"axis": int(jm.axis),
			"axis_value": float(jm.axis_value),
		}
	return {}


func _t(key: String, fallback: String) -> String:
	var val: String = tr(key)
	return fallback if val == key else val


func _choice_row(
	title: String,
	hint: String,
	items: Array[String],
	selected: int,
	disabled: bool,
	cb: Callable
) -> Control:
	var row_wrap := _row_shell(_body.get_child_count() == 0)
	var row := row_wrap.get_node("Row") as HBoxContainer
	row.add_child(_copy_col(title, hint))
	var box := OptionButton.new()
	box.custom_minimum_size = Vector2(220, 40)
	box.fit_to_longest_item = false
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.focus_mode = Control.FOCUS_ALL
	if UiAtlas.ink_font() != null:
		box.add_theme_font_override("font", UiAtlas.ink_font())
	box.add_theme_font_size_override("font_size", UiAtlas.SIZE_META)
	box.add_theme_color_override("font_color", UiAtlas.PARCHMENT_INK)
	box.add_theme_color_override("font_hover_color", UiAtlas.PARCHMENT_INK)
	box.add_theme_color_override("font_focus_color", UiAtlas.PARCHMENT_INK)
	for i: int in range(items.size()):
		box.add_item(items[i], i)
	if items.is_empty():
		box.add_item("-", 0)
	box.select(clampi(selected, 0, maxi(box.item_count - 1, 0)))
	box.disabled = disabled or items.is_empty()
	box.item_selected.connect(func(idx: int) -> void:
		if _rebuilding:
			return
		_play_ui("click")
		cb.call(idx)
	)
	row.add_child(box)
	if _first_choice == null and not box.disabled:
		_first_choice = box
	return row_wrap


func _range_row(title: String, hint: String, value: float, cb: Callable) -> Control:
	var row_wrap := _row_shell(_body.get_child_count() == 0)
	var row := row_wrap.get_node("Row") as HBoxContainer
	row.add_child(_copy_col(title, hint))
	var control := HBoxContainer.new()
	control.add_theme_constant_override("separation", 8)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(140, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	var readout := Label.new()
	readout.text = _pct(value)
	readout.custom_minimum_size = Vector2(44, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiAtlas.apply_ink_label(readout, UiAtlas.TYPE_META, UiAtlas.PARCHMENT_INK, UiAtlas.SIZE_META)
	slider.value_changed.connect(func(v: float) -> void:
		readout.text = _pct(v)
		cb.call(v)
	)
	control.add_child(slider)
	control.add_child(readout)
	row.add_child(control)
	if _first_choice == null:
		_first_choice = slider
	return row_wrap


func _check_row(title: String, hint: String, value: bool, cb: Callable) -> Control:
	var row_wrap := _row_shell(_body.get_child_count() == 0)
	var row := row_wrap.get_node("Row") as HBoxContainer
	row.add_child(_copy_col(title, hint))
	var box := CheckBox.new()
	box.button_pressed = value
	box.focus_mode = Control.FOCUS_ALL
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_theme_icon_override("checked", UiAtlas.frame("desk-check-on"))
	box.add_theme_icon_override("unchecked", UiAtlas.frame("desk-check-off"))
	box.add_theme_icon_override("checked_disabled", UiAtlas.frame("desk-check-on"))
	box.add_theme_icon_override("unchecked_disabled", UiAtlas.frame("desk-check-off"))
	if UiAtlas.ink_font() != null:
		box.add_theme_font_override("font", UiAtlas.ink_font())
	box.add_theme_font_size_override("font_size", UiAtlas.SIZE_META)
	box.add_theme_color_override("font_color", UiAtlas.PARCHMENT_INK)
	box.toggled.connect(func(v: bool) -> void:
		_play_ui("click")
		cb.call(v)
	)
	row.add_child(box)
	if _first_choice == null:
		_first_choice = box
	return row_wrap


func _row_shell(first: bool) -> PanelContainer:
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rule := StyleBoxFlat.new()
	rule.bg_color = Color(0, 0, 0, 0)
	rule.border_color = Color(0.18, 0.125, 0.07, 0.25)
	rule.border_width_top = 0 if first else 1
	rule.content_margin_top = 8.0
	rule.content_margin_bottom = 8.0
	shell.add_theme_stylebox_override("panel", rule)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(row)
	return shell


func _copy_col(title: String, hint: String) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	var t := Label.new()
	t.text = title
	UiAtlas.apply_ink_label(t, UiAtlas.TYPE_BODY, UiAtlas.PARCHMENT_INK, UiAtlas.SIZE_BODY)
	var h := Label.new()
	h.text = hint
	UiAtlas.apply_ink_label(h, UiAtlas.TYPE_META, INK_HINT, UiAtlas.SIZE_META)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	col.add_child(h)
	return col


func _style_slider(slider: HSlider) -> void:
	var groov := StyleBoxFlat.new()
	groov.bg_color = Color("6e3b1e")
	groov.set_corner_radius_all(3)
	groov.content_margin_top = 4.0
	groov.content_margin_bottom = 4.0
	slider.add_theme_stylebox_override("slider", groov)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("6e3b1e")
	grab.set_corner_radius_all(8)
	grab.content_margin_left = 8.0
	grab.content_margin_right = 8.0
	grab.content_margin_top = 8.0
	grab.content_margin_bottom = 8.0
	slider.add_theme_stylebox_override("grabber_area", grab)
	slider.add_theme_color_override("font_color", UiAtlas.PARCHMENT_INK)


func _mutate_display(mutator: Callable) -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	var settings: GameSettings = app.settings
	if _pending_snapshot.is_empty():
		_pending_snapshot = Display.snapshot_display(settings)
	mutator.call(settings)
	Display.apply(settings)
	_begin_confirm()
	_rebuild_rows()
	call_deferred("_center_panel")


func _set_window_mode(idx: int) -> void:
	if idx < 0 or idx >= Display.MODE_OPTIONS.size():
		return
	_mutate_display(func(s: GameSettings) -> void:
		s.window_mode = Display.MODE_OPTIONS[idx]
	)


func _set_monitor(idx: int) -> void:
	_mutate_display(func(s: GameSettings) -> void:
		s.screen_index = idx
	)


func _set_resolution(idx: int) -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	var settings: GameSettings = app.settings
	if settings.window_mode == Display.MODE_BORDERLESS:
		return
	var allowed: Array[Vector2i] = Display.resolutions_for_screen(settings.screen_index)
	if idx < 0 or idx >= allowed.size():
		return
	var chosen: Vector2i = allowed[idx]
	_mutate_display(func(s: GameSettings) -> void:
		s.resolution_w = chosen.x
		s.resolution_h = chosen.y
	)


func _set_vsync(idx: int) -> void:
	if idx < 0 or idx >= Display.VSYNC_OPTIONS.size():
		return
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	var settings: GameSettings = app.settings
	settings.vsync = Display.VSYNC_OPTIONS[idx]
	Display.apply(settings)
	settings.save()


func _set_fps(idx: int) -> void:
	if idx < 0 or idx >= Display.FPS_OPTIONS.size():
		return
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	var settings: GameSettings = app.settings
	settings.max_fps = Display.FPS_OPTIONS[idx]
	Display.apply(settings)
	settings.save()


func _begin_confirm() -> void:
	_confirm_left = Display.CONFIRM_SECONDS
	if _confirm_bar != null:
		_confirm_bar.visible = true
	_refresh_confirm_label()
	set_process(true)


func _refresh_confirm_label() -> void:
	if _confirm_label == null:
		return
	_confirm_label.text = tr("ui.settings.keep").replace("{s}", str(maxi(ceili(_confirm_left), 0)))


func _keep_display() -> void:
	_play_ui("confirm")
	_pending_snapshot.clear()
	if _confirm_bar != null:
		_confirm_bar.visible = false
	set_process(false)
	var app := get_node_or_null("/root/App")
	if app != null:
		var settings: GameSettings = app.settings
		settings.save()
	call_deferred("_center_panel")


func _revert_display() -> void:
	if _pending_snapshot.is_empty():
		if _confirm_bar != null:
			_confirm_bar.visible = false
		set_process(false)
		return
	var app := get_node_or_null("/root/App")
	if app != null:
		var settings: GameSettings = app.settings
		Display.restore_display(settings, _pending_snapshot)
		Display.apply(settings)
	_pending_snapshot.clear()
	if _confirm_bar != null:
		_confirm_bar.visible = false
	set_process(false)
	_rebuild_rows()
	call_deferred("_center_panel")


func _set_volume(which: String, value: float) -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	var settings: GameSettings = app.settings
	match which:
		"master":
			settings.master_volume = clampf(value, 0.0, 1.0)
		"sfx":
			settings.sfx_volume = clampf(value, 0.0, 1.0)
			_play_ui("click")
		_:
			settings.music_volume = clampf(value, 0.0, 1.0)
	settings.save()
	_apply_audio(app)


func _set_flag(which: String, value: bool) -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	var settings: GameSettings = app.settings
	match which:
		"muted":
			settings.muted = value
			if not value:
				_play_ui("click")
		"screenshake":
			settings.screenshake = value
		_:
			settings.reduce_vfx = value
	settings.save()
	_apply_audio(app)


func _apply_audio(app: Node) -> void:
	var bus := get_node_or_null("/root/GameAudio")
	if bus != null:
		bus.apply_settings(app.settings)


func _pct(value: float) -> String:
	return "%d%%" % int(round(value * 100.0))


func _clamp_scroll() -> void:
	if _scroll == null or _body == null:
		return
	var content_h: float = _body.get_combined_minimum_size().y
	var max_h: float = SCROLL_MAX
	if size.y > 260.0:
		max_h = minf(SCROLL_MAX, size.y - 240.0)
	_scroll.custom_minimum_size = Vector2(0.0, minf(content_h, max_h))


func _center_panel() -> void:
	if _panel == null:
		return
	_clamp_scroll()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.reset_size()
	var sz: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = Vector2(maxf(PANEL_WIDTH, sz.x), sz.y)
	_panel.position = (size - _panel.size) * 0.5


func _play_ui(kind: String) -> void:
	var bus := get_node_or_null("/root/GameAudio")
	if bus != null:
		bus.play_ui(kind)
