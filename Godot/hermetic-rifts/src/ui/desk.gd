class_name DeskView
extends Control

signal closed

var _dim: ColorRect
var _panel: PanelContainer
var _kicker: Label
var _title: Label
var _lead: Label
var _body: VBoxContainer
var _close_btn: Button
var _bound: bool = false


func _ready() -> void:
	z_index = 40
	_resolve_nodes()
	_apply_chrome()
	_bind()
	if get_tree() != null and get_tree().current_scene == self:
		call_deferred("refresh")


func refresh() -> void:
	_rebuild_rows()
	call_deferred("_center_panel")
	call_deferred("focus_primary")


func focus_primary() -> void:
	if _close_btn != null and _close_btn.is_inside_tree():
		_close_btn.grab_focus()


func handle_back() -> bool:
	if visible:
		_close()
		return true
	return false


func _resolve_nodes() -> void:
	_dim = get_node_or_null("Dim") as ColorRect
	_panel = get_node_or_null("Panel") as PanelContainer
	_kicker = get_node_or_null("Panel/Inner/Kicker") as Label
	_title = get_node_or_null("Panel/Inner/Title") as Label
	_lead = get_node_or_null("Panel/Inner/Lead") as Label
	_body = get_node_or_null("Panel/Inner/Body") as VBoxContainer
	_close_btn = get_node_or_null("Panel/Inner/CloseBtn") as Button


func _apply_chrome() -> void:
	if _dim != null:
		_dim.color = Color(0.047, 0.039, 0.051, 0.62)
		_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if _panel != null:
		_panel.add_theme_stylebox_override("panel", UiAtlas.nine_slice("parchment-panel", "idle", Vector4(40, 36, 40, 32)))
		_panel.custom_minimum_size = Vector2(480, 0)
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
	if _close_btn != null:
		_close_btn.text = tr("ui.settings.close").to_upper()
		UiAtlas.apply_button_styles(_close_btn, "btn-plaque")
		_close_btn.custom_minimum_size = Vector2(0, 48)
		_close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _body != null:
		_body.add_theme_constant_override("separation", 0)
	var inner := get_node_or_null("Panel/Inner") as VBoxContainer
	if inner != null:
		if _kicker != null:
			inner.move_child(_kicker, 0)
		if _title != null:
			inner.move_child(_title, 1)
		if _lead != null:
			inner.move_child(_lead, 2)
		if _body != null:
			inner.move_child(_body, 3)
		if _close_btn != null:
			inner.move_child(_close_btn, 4)
	_center_panel()


func _bind() -> void:
	if _bound:
		return
	_bound = true
	if _close_btn != null:
		_close_btn.pressed.connect(_on_close)
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
	visible = false
	closed.emit()


func _rebuild_rows() -> void:
	if _body == null:
		return
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	var settings: GameSettings = app.settings
	_body.add_child(_action_row(
		tr("ui.settings.fullscreen"),
		tr("ui.settings.fullscreen.hint"),
		tr("ui.settings.fullscreen.toggle"),
		_toggle_fullscreen
	))
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


func _action_row(title: String, hint: String, action: String, cb: Callable) -> Control:
	var row_wrap := _row_shell(_body.get_child_count() == 0)
	var row := row_wrap.get_node("Row") as HBoxContainer
	row.add_child(_copy_col(title, hint))
	var btn := Button.new()
	btn.text = action
	UiAtlas.apply_button_styles(btn, "btn-plaque")
	btn.custom_minimum_size = Vector2(160, 40)
	btn.pressed.connect(func() -> void:
		_play_ui("click")
		cb.call()
	)
	row.add_child(btn)
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
	return row_wrap


func _check_row(title: String, hint: String, value: bool, cb: Callable) -> Control:
	var row_wrap := _row_shell(_body.get_child_count() == 0)
	var row := row_wrap.get_node("Row") as HBoxContainer
	row.add_child(_copy_col(title, hint))
	var box := CheckBox.new()
	box.button_pressed = value
	box.focus_mode = Control.FOCUS_ALL
	box.add_theme_color_override("font_color", UiAtlas.PARCHMENT_INK)
	box.toggled.connect(func(v: bool) -> void:
		_play_ui("click")
		cb.call(v)
	)
	row.add_child(box)
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
	UiAtlas.apply_ink_label(h, UiAtlas.TYPE_META, Color("2e2014"), UiAtlas.SIZE_META)
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


func _toggle_fullscreen() -> void:
	var mode: int = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


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


func _center_panel() -> void:
	if _panel == null:
		return
	_panel.custom_minimum_size = Vector2(480, 0)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.reset_size()
	var sz: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = Vector2(maxf(480.0, sz.x), sz.y)
	_panel.position = (size - _panel.size) * 0.5


func _play_ui(kind: String) -> void:
	var bus := get_node_or_null("/root/GameAudio")
	if bus != null:
		bus.play_ui(kind)
