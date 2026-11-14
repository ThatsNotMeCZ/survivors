extends Node

var catalog: Catalog
var settings: GameSettings
var records: ArchiveRecords
var world: SimWorld
var overlay_mode: StringName = &"menu"
var sim_paused: bool = false
var selected_survivor: String = "runner"


func _ready() -> void:
	Loc.load_en()
	catalog = Catalog.load_from_res()
	settings = GameSettings.load_or_default()
	records = ArchiveRecords.load_or_default()
	selected_survivor = settings.survivor_id
	var win: Window = get_window()
	if win != null:
		win.size_changed.connect(_sync_content_scale_stretch)
	_sync_content_scale_stretch()


func start_run() -> void:
	var unlocked: Array[String] = records.unlocked_item_ids(catalog)
	var lores: Array[String] = records.collected_lore_ids()
	var run_seed: int = SimRng.daily_seed() if settings.daily_rite else SimRng.random_run_seed()
	var daily: String = SimRng.utc_ymd() if settings.daily_rite else ""
	world = SimWorld.create(catalog, selected_survivor, unlocked, lores, run_seed, daily)
	overlay_mode = &"hidden"
	sim_paused = false
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null:
		audio.apply_settings(settings)
		audio.play_stage(String(SimLoop.current_stage(world).get("id", "")))


func pause_run() -> void:
	if overlay_mode != &"hidden":
		return
	overlay_mode = &"pause"
	sim_paused = true


func resume_run() -> void:
	overlay_mode = &"hidden"
	sim_paused = false


func abandon_run() -> void:
	if world != null:
		records.record_run_end(world, "abandon")
	world = null
	overlay_mode = &"menu"
	sim_paused = false
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null:
		audio.play_menu()


func is_sim_paused() -> bool:
	return sim_paused or overlay_mode == &"levelup" or overlay_mode == &"pause" or overlay_mode == &"archives"


func _sync_content_scale_stretch() -> void:
	var win: Window = get_window()
	if win == null:
		return
	var base: Vector2i = win.content_scale_size
	if base.x <= 0 or base.y <= 0:
		return
	var fits: bool = win.size.x >= base.x and win.size.y >= base.y
	win.content_scale_stretch = (
		Window.CONTENT_SCALE_STRETCH_INTEGER if fits
		else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	)
