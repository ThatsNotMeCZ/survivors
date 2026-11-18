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
var demo_mode: bool = false


func _ready() -> void:
	Loc.load_en()
	catalog = Catalog.load_from_res()
	_ensure_interact_action()
	demo_mode = _parse_demo_flag()
	settings = GameSettings.load_or_default()
	if demo_mode:
		settings.demo_mode = true
	records = ArchiveRecords.load_or_default()
	selected_survivor = settings.survivor_id
	Display.sanitize(settings)
	Display.apply(settings)


func is_demo_mode() -> bool:
	return demo_mode or (settings != null and settings.demo_mode)


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
	var run_config: Dictionary = {
		"demo_mode": is_demo_mode(),
		"ascension_tier": records.ascension_tier(),
		"loadout": records.loadout_for(selected_survivor),
		"crucible_upgrades": DictUtil.d(records.data, "crucibleUpgrades"),
	}
	world = SimWorld.create(catalog, selected_survivor, unlocked, lores, run_seed, daily, run_config)
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
		if run_outcome == &"":
			var outcome: String = "true_victory" if world.true_victory else ("victory" if world.won else "abandon")
			records.record_run_end(world, outcome)
			run_outcome = StringName(outcome)
		overlay_mode = &"recap"
		sim_paused = true
		return
	overlay_mode = &"menu"
	sim_paused = false
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null:
		audio.play_menu()


func is_sim_paused() -> bool:
	return (
		sim_paused
		or overlay_mode == &"levelup"
		or overlay_mode == &"pause"
		or overlay_mode == &"archives"
		or overlay_mode == &"recap"
		or overlay_mode == &"crucible"
	)


func _ensure_interact_action() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
	if InputMap.action_get_events("interact").is_empty():
		var ev := InputEventKey.new()
		ev.device = GameSettings.ALL_DEVICES
		ev.physical_keycode = KEY_E
		InputMap.action_add_event("interact", ev)


func _parse_demo_flag() -> bool:
	var all_args: PackedStringArray = OS.get_cmdline_args()
	all_args.append_array(OS.get_cmdline_user_args())
	for arg: String in all_args:
		if arg == "--demo":
			return true
	return false
