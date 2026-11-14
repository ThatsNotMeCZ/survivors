extends CanvasLayer

var _root: Control
var _dim: ColorRect
var _chrome: Control
var _title: Label
var _body: Label
var _buttons: VBoxContainer
var _hud: HudView
var _menu: MainMenuView
var _archives: ArchivesView
var _hall: HallView
var _desk: DeskView
var _desk_layer: CanvasLayer
var _pause: PauseView
var _levelup: LevelUpView
var _last_mode: StringName = &""
var _last_offer: int = -1


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.name = "OverlayRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.color = Color(0.05, 0.04, 0.07, 0.88)
	_root.add_child(_dim)
	_bind_hud()
	_chrome = CenterContainer.new()
	_chrome.name = "GenericChrome"
	_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_chrome)
	_bind_main_menu()
	_bind_archives()
	_bind_hall()
	_bind_desk()
	_bind_pause()
	_bind_levelup()
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(640, 0)
	col.add_theme_constant_override("separation", 18)
	_chrome.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiAtlas.apply_label(_title, UiAtlas.TYPE_DISPLAY, Color(0.97, 0.9, 0.74), UiAtlas.SIZE_DISPLAY_L)
	col.add_child(_title)
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(640, 0)
	UiAtlas.apply_label(_body, UiAtlas.TYPE_BODY, Color(0.82, 0.76, 0.66), 20)
	col.add_child(_body)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	col.add_child(_buttons)


func _process(_dt: float) -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	_sync(app)


func _unhandled_input(event: InputEvent) -> void:
	var app := get_node_or_null("/root/App")
	if app == null or event.is_echo() or not event.is_pressed():
		return
	if not (event.is_action("pause") or event.is_action("back")):
		return
	if event.is_action("pause") and (app.overlay_mode == &"menu" or app.overlay_mode == &"hall" or app.overlay_mode == &"levelup"):
		return
	if app.overlay_mode == &"hidden" and app.world != null:
		app.pause_run()
		get_viewport().set_input_as_handled()
		return
	if app.overlay_mode == &"pause" and (event.is_action("pause") or event.is_action("back")):
		app.resume_run()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	var app := get_node_or_null("/root/App")
	if app == null or app.overlay_mode == &"hidden":
		return
	if event.is_echo() or not event.is_pressed():
		return
	if event.is_action("pause") and app.overlay_mode == &"pause":
		app.resume_run()
		get_viewport().set_input_as_handled()
		return
	if event.is_action("confirm"):
		_activate_primary(app)
		get_viewport().set_input_as_handled()
		return
	if event.is_action("back"):
		_go_back(app)
		get_viewport().set_input_as_handled()
		return
	if app.overlay_mode != &"levelup":
		return
	if event.is_action("offer_1"):
		_pick(app, 0)
		get_viewport().set_input_as_handled()
	elif event.is_action("offer_2"):
		_pick(app, 1)
		get_viewport().set_input_as_handled()
	elif event.is_action("offer_3"):
		_pick(app, 2)
		get_viewport().set_input_as_handled()


func _sync(app: Node) -> void:
	var offer_n: int = 0
	if app.world != null:
		offer_n = app.world.offer.size()
	if app.overlay_mode == _last_mode and not (app.overlay_mode == &"levelup" and offer_n != _last_offer):
		if app.overlay_mode == &"hidden":
			_show_hud(app.world)
		_raise_desk()
		return
	_last_mode = app.overlay_mode
	_last_offer = offer_n
	_clear_buttons()
	var is_menu: bool = app.overlay_mode == &"menu"
	var is_archives: bool = app.overlay_mode == &"archives"
	var is_hall: bool = app.overlay_mode == &"hall"
	var is_pause: bool = app.overlay_mode == &"pause"
	var is_levelup: bool = app.overlay_mode == &"levelup"
	if _menu != null:
		_menu.visible = is_menu
		if is_menu:
			_root.move_child(_menu, _root.get_child_count() - 1)
	if _hall != null:
		_hall.visible = is_hall
		if is_hall:
			_root.move_child(_hall, _root.get_child_count() - 1)
	if _archives != null:
		_archives.visible = is_archives
		if is_archives:
			_root.move_child(_archives, _root.get_child_count() - 1)
	if _pause != null:
		_pause.visible = is_pause
		if is_pause:
			_root.move_child(_pause, _root.get_child_count() - 1)
	if _levelup != null:
		_levelup.visible = is_levelup
		if is_levelup:
			_root.move_child(_levelup, _root.get_child_count() - 1)
	if _desk != null:
		var keep_desk: bool = is_menu or is_hall or app.overlay_mode == &"pause" or app.overlay_mode == &"settings"
		if not keep_desk:
			_desk.visible = false
			if _desk_layer != null:
				_desk_layer.visible = false
		else:
			_raise_desk()
	_chrome.visible = (
		not is_menu
		and not is_archives
		and not is_hall
		and not is_pause
		and not is_levelup
		and app.overlay_mode != &"hidden"
	)
	_dim.visible = (
		app.overlay_mode != &"hidden"
		and not is_menu
		and not is_archives
		and not is_hall
	)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP if _dim.visible else Control.MOUSE_FILTER_IGNORE
	_root.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE if app.overlay_mode == &"hidden" else Control.MOUSE_FILTER_STOP
	)
	_title.visible = _chrome.visible
	_body.visible = _chrome.visible
	match String(app.overlay_mode):
		"menu":
			_hide_hud()
			if _menu != null:
				_menu.refresh_preview()
			return
		"archives":
			_hide_hud()
			if _archives != null:
				_archives.refresh()
			return
		"hall":
			_hide_hud()
			if _hall != null:
				_hall.refresh()
			return
		"hidden":
			_title.text = ""
			_body.text = ""
			_show_hud(app.world)
		"pause":
			_hide_hud()
			if _pause != null:
				_pause.refresh(app.world)
			return
		"levelup":
			_hide_hud()
			if _levelup != null:
				_levelup.refresh(app.world)
			return
		"recap":
			_hide_hud()
			var kind: String = "victory" if app.world != null and app.world.won else "defeat"
			_title.text = tr("ui.recap.%s" % kind)
			_body.text = _recap_text(app.world)
			_add_btn(tr("ui.recap.again"), func() -> void: app.start_run())
			_add_btn(tr("ui.recap.hall"), func() -> void:
				app.world = null
				app.overlay_mode = &"hall"
			)
		"settings":
			_hide_hud()
			_open_desk()
			return
	_focus_primary()


func _activate_primary(app: Node) -> void:
	match String(app.overlay_mode):
		"menu":
			var focused_m: Control = get_viewport().gui_get_focus_owner()
			if focused_m is Button:
				(focused_m as Button).emit_signal("pressed")
			else:
				_play_ui("confirm")
				app.overlay_mode = &"hall"
		"hall":
			if _hall != null:
				_hall.activate_primary()
			elif not app.records.meets_unlock(app.catalog.survivor(app.selected_survivor).get("unlock", null)):
				pass
			else:
				app.start_run()
		"pause":
			var focused_p: Control = get_viewport().gui_get_focus_owner()
			if focused_p is Button:
				(focused_p as Button).emit_signal("pressed")
			else:
				app.resume_run()
		"levelup":
			_pick(app, 0)
		"recap":
			app.start_run()
		"settings":
			if _desk != null and _desk.visible:
				_desk.handle_back()
			else:
				_go_back(app)
		"archives":
			var focused_a: Control = get_viewport().gui_get_focus_owner()
			if focused_a is Button:
				(focused_a as Button).emit_signal("pressed")
		_:
			var focused: Control = get_viewport().gui_get_focus_owner()
			if focused is Button:
				(focused as Button).emit_signal("pressed")


func _go_back(app: Node) -> void:
	if _desk != null and _desk.visible:
		_desk.handle_back()
		return
	if app.overlay_mode == &"archives" and _archives != null and _archives.handle_back():
		return
	match String(app.overlay_mode):
		"hall", "archives", "settings":
			app.overlay_mode = &"pause" if app.world != null else &"menu"
		"pause":
			app.resume_run()
		"menu":
			pass
		"levelup":
			pass
		"recap":
			app.world = null
			app.overlay_mode = &"hall"


func _pick(app: Node, index: int) -> void:
	if app.world == null:
		return
	var pick_id: String = ""
	if index >= 0 and index < app.world.offer.size():
		pick_id = String(app.world.offer[index].get("id", ""))
	if not SimLevel.apply_choice(app.world, index):
		return
	if pick_id != "":
		app.records.record_item_pick(pick_id)
	if app.world.phase == &"play":
		app.resume_run()
	elif app.world.phase == &"victory":
		app.overlay_mode = &"recap"


func _bind_hud() -> void:
	_hud = get_node_or_null("Hud") as HudView
	if _hud == null:
		_hud = _root.get_node_or_null("Hud") as HudView
	if _hud == null:
		var packed: PackedScene = load("res://scenes/ui/hud.tscn")
		if packed != null:
			_hud = packed.instantiate() as HudView
	if _hud == null:
		_hud = HudView.new()
		_hud.name = "Hud"
	if _hud.get_parent() != _root:
		var old_parent: Node = _hud.get_parent()
		if old_parent != null:
			old_parent.remove_child(_hud)
		_root.add_child(_hud)
	_hud.visible = false
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_hud(world: SimWorld) -> void:
	if _hud == null:
		return
	_hud.visible = true
	_hud.sync(world)


func _hide_hud() -> void:
	if _hud != null:
		_hud.visible = false


func _recap_text(world: SimWorld) -> String:
	if world == null:
		return ""
	return "Lv %d  |  kills %d  |  %.0fs  |  seed %s" % [world.level, world.kills_total, world.run_time, SimRng.format_seed_tag(world.run_seed)]


func _add_btn(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 44)
	if UiAtlas.body_font() != null:
		b.add_theme_font_override("font", UiAtlas.body_font())
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func() -> void:
		_play_ui("click")
		cb.call()
	)
	_buttons.add_child(b)


func _focus_primary() -> void:
	if _buttons.get_child_count() == 0:
		return
	var first: Node = _buttons.get_child(0)
	if first is Button:
		(first as Button).grab_focus()


func _play_ui(kind: String) -> void:
	var bus := get_node_or_null("/root/GameAudio")
	if bus != null:
		bus.play_ui(kind)


func _apply_audio(app: Node) -> void:
	var bus := get_node_or_null("/root/GameAudio")
	if bus != null:
		bus.apply_settings(app.settings)


func _clear_buttons() -> void:
	for child: Node in _buttons.get_children():
		_buttons.remove_child(child)
		child.free()


func _bind_main_menu() -> void:
	_menu = get_node_or_null("MainMenu") as MainMenuView
	if _menu == null:
		_menu = _root.get_node_or_null("MainMenu") as MainMenuView
	if _menu == null:
		var packed: PackedScene = load("res://scenes/ui/main_menu.tscn")
		if packed != null:
			_menu = packed.instantiate() as MainMenuView
	if _menu == null:
		return
	if _menu.get_parent() != _root:
		var old_parent: Node = _menu.get_parent()
		if old_parent != null:
			old_parent.remove_child(_menu)
		_root.add_child(_menu)
	_menu.visible = false
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.move_child(_menu, _root.get_child_count() - 1)
	if not _menu.archives_pressed.is_connected(_on_menu_archives):
		_menu.archives_pressed.connect(_on_menu_archives)
	if not _menu.desk_pressed.is_connected(_on_menu_desk):
		_menu.desk_pressed.connect(_on_menu_desk)
	if not _menu.commence_pressed.is_connected(_on_menu_commence):
		_menu.commence_pressed.connect(_on_menu_commence)


func _on_menu_archives() -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	_play_ui("click")
	app.overlay_mode = &"archives"


func _on_menu_desk() -> void:
	_play_ui("click")
	_open_desk()


func _on_menu_commence() -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	_play_ui("confirm")
	app.overlay_mode = &"hall"


func _bind_archives() -> void:
	_archives = get_node_or_null("Archives") as ArchivesView
	if _archives == null:
		_archives = _root.get_node_or_null("Archives") as ArchivesView
	if _archives == null:
		var packed: PackedScene = load("res://scenes/ui/archives.tscn")
		if packed != null:
			_archives = packed.instantiate() as ArchivesView
	if _archives == null:
		return
	if _archives.get_parent() != _root:
		var old_parent: Node = _archives.get_parent()
		if old_parent != null:
			old_parent.remove_child(_archives)
		_root.add_child(_archives)
	_archives.visible = false
	_archives.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.move_child(_archives, _root.get_child_count() - 1)
	if not _archives.back_pressed.is_connected(_on_archives_back):
		_archives.back_pressed.connect(_on_archives_back)


func _on_archives_back() -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	app.overlay_mode = &"pause" if app.world != null else &"menu"


func _bind_hall() -> void:
	_hall = get_node_or_null("Hall") as HallView
	if _hall == null:
		_hall = _root.get_node_or_null("Hall") as HallView
	if _hall == null:
		var packed: PackedScene = load("res://scenes/ui/hall.tscn")
		if packed != null:
			_hall = packed.instantiate() as HallView
	if _hall == null:
		return
	if _hall.get_parent() != _root:
		var old_parent: Node = _hall.get_parent()
		if old_parent != null:
			old_parent.remove_child(_hall)
		_root.add_child(_hall)
	_hall.visible = false
	_hall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.move_child(_hall, _root.get_child_count() - 1)
	if not _hall.back_pressed.is_connected(_on_hall_back):
		_hall.back_pressed.connect(_on_hall_back)
	if not _hall.commence_pressed.is_connected(_on_hall_commence):
		_hall.commence_pressed.connect(_on_hall_commence)


func _on_hall_back() -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	app.overlay_mode = &"menu"


func _on_hall_commence() -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	if _hall != null and _hall.is_inspected_locked():
		return
	app.start_run()


func _bind_pause() -> void:
	_pause = get_node_or_null("Pause") as PauseView
	if _pause == null:
		_pause = _root.get_node_or_null("Pause") as PauseView
	if _pause == null:
		var packed: PackedScene = load("res://scenes/ui/pause.tscn")
		if packed != null:
			_pause = packed.instantiate() as PauseView
	if _pause == null:
		_pause = PauseView.new()
		_pause.name = "Pause"
	if _pause.get_parent() != _root:
		var old_parent: Node = _pause.get_parent()
		if old_parent != null:
			old_parent.remove_child(_pause)
		_root.add_child(_pause)
	_pause.visible = false
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not _pause.resume_pressed.is_connected(_on_pause_resume):
		_pause.resume_pressed.connect(_on_pause_resume)
	if not _pause.archives_pressed.is_connected(_on_pause_archives):
		_pause.archives_pressed.connect(_on_pause_archives)
	if not _pause.settings_pressed.is_connected(_on_pause_settings):
		_pause.settings_pressed.connect(_on_pause_settings)
	if not _pause.seal_pressed.is_connected(_on_pause_seal):
		_pause.seal_pressed.connect(_on_pause_seal)
	if not _pause.abandon_pressed.is_connected(_on_pause_abandon):
		_pause.abandon_pressed.connect(_on_pause_abandon)


func _on_pause_resume() -> void:
	var app := get_node_or_null("/root/App")
	if app != null:
		_play_ui("click")
		app.resume_run()


func _on_pause_archives() -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	_play_ui("click")
	app.overlay_mode = &"archives"


func _on_pause_settings() -> void:
	_play_ui("click")
	_open_desk()


func _on_pause_seal() -> void:
	var app := get_node_or_null("/root/App")
	if app == null or app.world == null:
		return
	_play_ui("confirm")
	SimLoop.complete_working(app.world)
	app.overlay_mode = &"recap"


func _on_pause_abandon() -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	_play_ui("click")
	app.abandon_run()


func _bind_levelup() -> void:
	_levelup = get_node_or_null("LevelUp") as LevelUpView
	if _levelup == null:
		_levelup = _root.get_node_or_null("LevelUp") as LevelUpView
	if _levelup == null:
		var packed: PackedScene = load("res://scenes/ui/levelup.tscn")
		if packed != null:
			_levelup = packed.instantiate() as LevelUpView
	if _levelup == null:
		_levelup = LevelUpView.new()
		_levelup.name = "LevelUp"
	if _levelup.get_parent() != _root:
		var old_parent: Node = _levelup.get_parent()
		if old_parent != null:
			old_parent.remove_child(_levelup)
		_root.add_child(_levelup)
	_levelup.visible = false
	_levelup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not _levelup.choice_picked.is_connected(_on_levelup_choice):
		_levelup.choice_picked.connect(_on_levelup_choice)


func _on_levelup_choice(index: int) -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	_play_ui("confirm")
	_pick(app, index)


func _desk_host() -> CanvasLayer:
	if _desk_layer != null:
		return _desk_layer
	_desk_layer = get_node_or_null("DeskLayer") as CanvasLayer
	if _desk_layer == null:
		_desk_layer = CanvasLayer.new()
		_desk_layer.name = "DeskLayer"
		add_child(_desk_layer)
	_desk_layer.layer = 20
	return _desk_layer


func _bind_desk() -> void:
	_desk = get_node_or_null("Desk") as DeskView
	if _desk == null:
		_desk = _root.get_node_or_null("Desk") as DeskView
	if _desk == null:
		var packed: PackedScene = load("res://scenes/ui/desk.tscn")
		if packed != null:
			_desk = packed.instantiate() as DeskView
	if _desk == null:
		return
	var host: CanvasLayer = _desk_host()
	if _desk.get_parent() != host:
		var old_parent: Node = _desk.get_parent()
		if old_parent != null:
			old_parent.remove_child(_desk)
		host.add_child(_desk)
	_desk.visible = false
	_desk.z_index = 40
	_desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raise_desk()
	if not _desk.closed.is_connected(_on_desk_closed):
		_desk.closed.connect(_on_desk_closed)


func _open_desk() -> void:
	if _desk == null:
		return
	_desk.visible = true
	_desk.z_index = 40
	_raise_desk()
	_desk.refresh()


func _raise_desk() -> void:
	if _desk == null:
		return
	var host: CanvasLayer = _desk_host()
	if _desk.get_parent() != host:
		var old_parent: Node = _desk.get_parent()
		if old_parent != null:
			old_parent.remove_child(_desk)
		host.add_child(_desk)
	host.layer = 20
	host.visible = _desk.visible


func _on_desk_closed() -> void:
	if _desk_layer != null:
		_desk_layer.visible = false
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	if app.overlay_mode == &"settings":
		app.overlay_mode = &"pause" if app.world != null else &"menu"
	_focus_underlying(app)


func _focus_underlying(app: Node) -> void:
	match String(app.overlay_mode):
		"menu":
			if _menu != null:
				_menu.focus_primary()
		"hall":
			if _hall != null:
				_hall.focus_primary()
		"archives":
			if _archives != null:
				_archives.focus_primary()
		"pause":
			if _pause != null:
				_pause.focus_primary()
		"levelup":
			if _levelup != null:
				_levelup.focus_primary()
		_:
			_focus_primary()
