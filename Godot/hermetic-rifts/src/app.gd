extends Node

const Display := preload("res://src/data/display_settings.gd")

var catalog: Catalog
var settings: GameSettings
var records: ArchiveRecords
var world: SimWorld
var overlay_mode: StringName = &"menu"
var sim_paused: bool = false
var selected_survivor: String = "runner"
var run_outcome: StringName = &""
var run_start_items: Dictionary = {}
var run_start_survivors: Dictionary = {}


func _ready() -> void:
	Loc.load_en()
	catalog = Catalog.load_from_res()
	settings = GameSettings.load_or_default()
	records = ArchiveRecords.load_or_default()
	selected_survivor = settings.survivor_id
	Display.sanitize(settings)
	Display.apply(settings)
	var win: Window = get_window()
	if win != null:
		win.size_changed.connect(_sync_content_scale_stretch)
	_sync_content_scale_stretch()


func start_run() -> void:
	var unlocked: Array[String] = records.unlocked_item_ids(catalog)
	var lores: Array[String] = records.collected_lore_ids()
	var run_seed: int = SimRng.daily_seed() if settings.daily_rite else SimRng.random_run_seed()
	var daily: String = SimRng.utc_ymd() if settings.daily_rite else ""
	run_start_items = {}
	for item_id: String in unlocked:
		run_start_items[item_id] = true
	run_start_survivors = {}
	for surv: Dictionary in catalog.survivors:
		var sid: String = String(surv.get("id", ""))
		if sid != "" and records.meets_unlock(surv.get("unlock", null)):
			run_start_survivors[sid] = true
	run_outcome = &""
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
		run_outcome = &"abandon"
		overlay_mode = &"recap"
		sim_paused = true
		return
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
