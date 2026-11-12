extends Node

var _master: float = 0.7
var _sfx: float = 0.8
var _music: float = 0.6
var _muted: bool = false
var _bed: AudioStreamPlayer
var _overlay: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _last_fx: Dictionary = {}


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("UI")
	_bed = AudioStreamPlayer.new()
	_bed.bus = "Music"
	add_child(_bed)
	_overlay = AudioStreamPlayer.new()
	_overlay.bus = "Music"
	_overlay.volume_db = -9.0
	add_child(_overlay)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "UI"
	add_child(_ui_player)
	_apply()


func apply_settings(settings: GameSettings) -> void:
	_master = settings.master_volume
	_sfx = settings.sfx_volume
	_music = settings.music_volume
	_muted = settings.muted
	_apply()


func play_menu() -> void:
	_play_folder(_bed, "res://assets/audio/music/menu")
	_overlay.stop()


func play_stage(stage_id: String) -> void:
	_play_folder(_bed, "res://assets/audio/music/maps/%s" % stage_id)
	_overlay.stop()


func play_boss(boss_id: String) -> void:
	_play_folder(_bed, "res://assets/audio/music/boss/%s" % boss_id)
	_overlay.stop()


func set_chill(on: bool) -> void:
	if on:
		_bed.volume_db = linear_to_db(maxf(0.001, _music * 0.35 * (0.0 if _muted else _master)))
		_play_folder(_overlay, "res://assets/audio/music/overlay")
	else:
		_overlay.stop()
		_apply()


func play_fx(kind: int) -> void:
	var now: int = Time.get_ticks_msec()
	if int(_last_fx.get(kind, 0)) + 80 > now:
		return
	_last_fx[kind] = now
	var id: String = "hit"
	match kind:
		FxIds.DEATH:
			id = "death"
		FxIds.MUZZLE:
			id = "muzzle"
		FxIds.DASH:
			id = "dash"
		FxIds.STRIKE:
			id = "strike"
		FxIds.HURT:
			id = "hurt"
		FxIds.GEM:
			id = "gem"
		_:
			id = "hit"
	var path: String = "res://assets/audio/sfx/combat/%s.ogg" % id
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/sfx/world/%s.ogg" % id
	if ResourceLoader.exists(path):
		_sfx_player.pitch_scale = randf_range(0.94, 1.06)
		_sfx_player.stream = load(path)
		_sfx_player.play()


func play_ui(kind: String) -> void:
	var path: String = "res://assets/audio/sfx/ui/%s.ogg" % kind
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/sfx/ui/click.ogg"
	if ResourceLoader.exists(path):
		_ui_player.stream = load(path)
		_ui_player.play()


func _play_folder(player: AudioStreamPlayer, dir: String) -> void:
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	var tracks: Array[String] = []
	for f: String in files:
		if f.ends_with(".ogg"):
			tracks.append("%s/%s" % [dir, f])
	if tracks.is_empty():
		return
	player.stream = load(tracks[randi() % tracks.size()])
	player.play()


func _apply() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	var music_idx: int = AudioServer.get_bus_index("Music")
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	var ui_idx: int = AudioServer.get_bus_index("UI")
	if master_idx != -1:
		AudioServer.set_bus_mute(master_idx, _muted)
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(maxf(0.001, _master)))
	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(maxf(0.001, _music)))
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(maxf(0.001, _sfx)))
	if ui_idx != -1:
		AudioServer.set_bus_volume_db(ui_idx, 0.0)
	_bed.volume_db = 0.0
	_sfx_player.volume_db = 0.0
	_ui_player.volume_db = 0.0


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
