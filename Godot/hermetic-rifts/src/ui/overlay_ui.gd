extends CanvasLayer

var _root: Control
var _dim: ColorRect
var _chrome: Control
var _title: Label
var _body: Label
var _buttons: VBoxContainer
var _hud: Label
var _menu: MainMenuView
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
	_hud = Label.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud.offset_left = 24.0
	_hud.offset_right = -24.0
	_hud.offset_top = 16.0
	_hud.offset_bottom = 56.0
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_theme_font_size_override("font_size", 22)
	_hud.add_theme_color_override("font_color", Color(0.93, 0.86, 0.72))
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)
	_chrome = CenterContainer.new()
	_chrome.name = "GenericChrome"
	_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_chrome)
	_bind_main_menu()
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(640, 0)
	col.add_theme_constant_override("separation", 18)
	_chrome.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", Color(0.97, 0.9, 0.74))
	col.add_child(_title)
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(640, 0)
	_body.add_theme_font_size_override("font_size", 20)
	_body.add_theme_color_override("font_color", Color(0.82, 0.76, 0.66))
	col.add_child(_body)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	col.add_child(_buttons)


func _process(_dt: float) -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	_sync(app)
	_handle_actions(app)


func _sync(app: Node) -> void:
	var offer_n: int = 0
	if app.world != null:
		offer_n = app.world.offer.size()
	if app.overlay_mode == _last_mode and not (app.overlay_mode == &"levelup" and offer_n != _last_offer):
		if app.overlay_mode == &"hidden":
			_hud.text = _hud_text(app.world)
		return
	_last_mode = app.overlay_mode
	_last_offer = offer_n
	_clear_buttons()
	var is_menu: bool = app.overlay_mode == &"menu"
	if _menu != null:
		_menu.visible = is_menu
		if is_menu:
			_root.move_child(_menu, _root.get_child_count() - 1)
	_chrome.visible = not is_menu and app.overlay_mode != &"hidden"
	_dim.visible = app.overlay_mode != &"hidden" and not is_menu
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP if _dim.visible else Control.MOUSE_FILTER_IGNORE
	_root.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE if app.overlay_mode == &"hidden" else Control.MOUSE_FILTER_STOP
	)
	_title.visible = _chrome.visible
	_body.visible = _chrome.visible
	match String(app.overlay_mode):
		"menu":
			_hud.visible = false
			if _menu != null:
				_menu.refresh_preview()
			return
		"hall":
			_hud.visible = false
			_title.text = Loc.survivor_name(app.selected_survivor)
			var locked: bool = not app.records.meets_unlock(app.catalog.survivor(app.selected_survivor).get("unlock", null))
			_body.text = tr("ui.hall.???") if locked else tr("survivor.%s.lore" % app.selected_survivor)
			if locked:
				_add_btn(tr("ui.hall.sealed"), func() -> void: pass)
			else:
				_add_btn(tr("ui.hall.commence"), func() -> void: app.start_run())
			_add_btn(tr("ui.hall.daily") + (": ON" if app.settings.daily_rite else ": OFF"), func() -> void:
				app.settings.daily_rite = not app.settings.daily_rite
				app.settings.save()
				_last_mode = &""
			)
			for surv: Dictionary in app.catalog.survivors:
				var sid: String = String(surv.get("id", ""))
				_add_btn(Loc.survivor_name(sid), func() -> void:
					app.selected_survivor = sid
					app.settings.survivor_id = sid
					app.settings.save()
					_last_mode = &""
				)
			_add_btn(tr("ui.hall.back"), func() -> void: app.overlay_mode = &"menu")
		"hidden":
			_title.text = ""
			_body.text = ""
			_hud.visible = true
			_hud.text = _hud_text(app.world)
		"pause":
			_hud.visible = false
			_title.text = tr("ui.pause.title")
			_body.text = _recap_text(app.world)
			_add_btn(tr("ui.pause.resume"), func() -> void: app.resume_run())
			_add_btn(tr("ui.pause.archives"), func() -> void: app.overlay_mode = &"archives")
			_add_btn(tr("ui.pause.settings"), func() -> void: app.overlay_mode = &"settings")
			if app.world != null and SimLoop.can_seal(app.world):
				_add_btn(tr("ui.pause.seal"), func() -> void:
					SimLoop.complete_working(app.world)
					app.overlay_mode = &"recap"
				)
			_add_btn(tr("ui.pause.abandon"), func() -> void: app.abandon_run())
		"levelup":
			_hud.visible = false
			_title.text = tr("ui.levelup.hint")
			_body.text = ""
			if app.world != null:
				for i: int in app.world.offer.size():
					var item: Dictionary = app.world.offer[i]
					var id: String = String(item.get("id", ""))
					var idx: int = i
					_add_btn("%d. %s" % [i + 1, Loc.item_name(id)], func() -> void: _pick(app, idx))
		"recap":
			_hud.visible = false
			var kind: String = "victory" if app.world != null and app.world.won else "defeat"
			_title.text = tr("ui.recap.%s" % kind)
			_body.text = _recap_text(app.world)
			_add_btn(tr("ui.recap.again"), func() -> void: app.start_run())
			_add_btn(tr("ui.recap.hall"), func() -> void:
				app.world = null
				app.overlay_mode = &"hall"
			)
		"archives":
			_hud.visible = false
			_title.text = tr("ui.menu.archives")
			_body.text = _archives_text(app)
			_add_btn(tr("ui.archives.howto"), func() -> void: pass)
			_add_btn(tr("ui.archives.lore"), func() -> void: pass)
			_add_btn(tr("ui.archives.bestiary"), func() -> void: pass)
			_add_btn(tr("ui.archives.reliquary"), func() -> void: pass)
			_add_btn(tr("ui.archives.ledger"), func() -> void: pass)
			_add_btn(tr("ui.archives.purge"), func() -> void: app.records.reset())
			_add_btn(tr("ui.hall.back"), func() -> void:
				app.overlay_mode = &"pause" if app.world != null else &"menu"
			)
		"settings":
			_hud.visible = false
			_title.text = tr("ui.settings.title")
			_body.text = ""
			_add_btn(tr("ui.settings.mute"), func() -> void:
				app.settings.muted = not app.settings.muted
				app.settings.save()
				_apply_audio(app)
				_last_mode = &""
			)
			_add_btn(tr("ui.settings.shake"), func() -> void:
				app.settings.screenshake = not app.settings.screenshake
				app.settings.save()
				_last_mode = &""
			)
			_add_btn(tr("ui.settings.vfx"), func() -> void:
				app.settings.reduce_vfx = not app.settings.reduce_vfx
				app.settings.save()
				_last_mode = &""
			)
			_add_btn(tr("ui.settings.fullscreen"), func() -> void:
				var mode: int = DisplayServer.window_get_mode()
				if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				else:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			)
			_add_btn(tr("ui.hall.back"), func() -> void:
				app.overlay_mode = &"pause" if app.world != null else &"menu"
			)
	_focus_primary()


func _handle_actions(app: Node) -> void:
	if Input.is_action_just_pressed("confirm"):
		_activate_primary(app)
	if Input.is_action_just_pressed("back"):
		_go_back(app)
	if app.overlay_mode == &"levelup":
		if Input.is_action_just_pressed("offer_1"):
			_pick(app, 0)
		if Input.is_action_just_pressed("offer_2"):
			_pick(app, 1)
		if Input.is_action_just_pressed("offer_3"):
			_pick(app, 2)


func _activate_primary(app: Node) -> void:
	match String(app.overlay_mode):
		"menu":
			_play_ui("confirm")
			app.overlay_mode = &"hall"
		"hall":
			var locked: bool = not app.records.meets_unlock(app.catalog.survivor(app.selected_survivor).get("unlock", null))
			if not locked:
				app.start_run()
		"pause":
			app.resume_run()
		"levelup":
			_pick(app, 0)
		"recap":
			app.start_run()
		"archives", "settings":
			_go_back(app)
		_:
			var focused: Control = get_viewport().gui_get_focus_owner()
			if focused is Button:
				(focused as Button).emit_signal("pressed")


func _go_back(app: Node) -> void:
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
	SimLevel.apply_choice(app.world, index)
	if app.world.phase == &"play":
		app.resume_run()
	elif app.world.phase == &"victory":
		app.overlay_mode = &"recap"


func _hud_text(world: SimWorld) -> String:
	if world == null:
		return ""
	var obj: String = tr("ui.hud.seal")
	if world.portal_open:
		obj = tr("ui.hud.ouroboros") if SimLoop.is_last_stage(world) else tr("ui.hud.descend")
	elif world.boss_spawned and world.counts_boss > 0:
		obj = tr("ui.hud.slay").replace("{name}", Loc.entity_name(world.focus_id))
	elif world.teleporter_state == &"charging":
		obj = tr("ui.hud.channel")
	return "%s  |  HP %.0f/%.0f  |  Lv %d  |  %.0fs" % [obj, world.player.hp, world.player.max_hp, world.level, world.run_time]


func _recap_text(world: SimWorld) -> String:
	if world == null:
		return ""
	return "Lv %d  |  kills %d  |  %.0fs  |  seed %s" % [world.level, world.kills_total, world.run_time, SimRng.format_seed_tag(world.run_seed)]


func _archives_text(app: Node) -> String:
	var d: Dictionary = app.records.data
	return "runs %s  |  victories %s  |  kills %s" % [d.get("totalRuns", 0), d.get("victories", 0), d.get("totalKills", 0)]


func _add_btn(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 44)
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
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	_play_ui("click")
	app.overlay_mode = &"settings"


func _on_menu_commence() -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	_play_ui("confirm")
	app.overlay_mode = &"hall"
