extends Node

const VOICE_CAP: int = 12
const WINDOW_MS: int = 1000
const SFX_FULL_RANGE: float = 160.0
const SFX_MAX_RANGE: float = 520.0
const RATE: Dictionary = {
	"hit": 8,
	"death": 6,
	"gem": 10,
	"muzzle": 12,
}

var _master: float = 0.7
var _sfx: float = 0.8
var _music: float = 0.6
var _muted: bool = false
var _bed: AudioStreamPlayer
var _overlay: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _ui_player: AudioStreamPlayer
var _recent: Dictionary = {}
var _stream_cache: Dictionary = {}


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
	for _i: int in VOICE_CAP:
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX"
		add_child(voice)
		_sfx_pool.append(voice)
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


func play_fx(kind: int, tint: int = 0, distance: float = 0.0) -> void:
	var gain: float = _distance_gain(kind, distance)
	if gain <= 0.01:
		return
	var id: String = _sfx_id(kind, tint)
	if not _allowed(id):
		return
	var stream: AudioStream = _load_sfx(id)
	if stream == null:
		return
	var voice: AudioStreamPlayer = _free_voice()
	if voice == null:
		return
	voice.volume_db = linear_to_db(gain)
	voice.pitch_scale = randf_range(0.94, 1.06)
	voice.stream = stream
	voice.play()


func _distance_gain(kind: int, distance: float) -> float:
	if kind == FxIds.BOSS_EMERGE or kind == FxIds.HURT or kind == FxIds.DASH:
		return 1.0
	if distance <= SFX_FULL_RANGE:
		return 1.0
	if distance >= SFX_MAX_RANGE:
		return 0.0
	var t: float = (distance - SFX_FULL_RANGE) / (SFX_MAX_RANGE - SFX_FULL_RANGE)
	return (1.0 - t) * (1.0 - t)


func play_ui(kind: String) -> void:
	var path: String = "res://assets/audio/sfx/ui/%s.ogg" % kind
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/sfx/ui/click.ogg"
	if ResourceLoader.exists(path):
		_ui_player.stream = load(path)
		_ui_player.play()


func _sfx_id(kind: int, tint: int) -> String:
	match kind:
		FxIds.DEATH:
			return "break" if tint == 0xFF8844 else "death"
		FxIds.MUZZLE:
			return "muzzle"
		FxIds.DASH:
			return "dash"
		FxIds.STRIKE, FxIds.BOSS_EMERGE:
			return "strike"
		FxIds.HURT:
			return "hurt"
		FxIds.GEM, FxIds.ESSENCE_PICKUP:
			return "gem"
		_:
			return "hit"


func _allowed(id: String) -> bool:
	var cap: int = int(RATE.get(id, 0))
	if cap <= 0:
		return true
	var now: int = Time.get_ticks_msec()
	var prev: Array = _recent.get(id, []) as Array
	var kept: Array[int] = []
	for t_v: Variant in prev:
		var stamp: int = int(t_v)
		if now - stamp < WINDOW_MS:
			kept.append(stamp)
	if kept.size() >= cap:
		_recent[id] = kept
		return false
	kept.append(now)
	_recent[id] = kept
	return true


func _free_voice() -> AudioStreamPlayer:
	for voice: AudioStreamPlayer in _sfx_pool:
		if not voice.playing:
			return voice
	return null


func _load_sfx(id: String) -> AudioStream:
	if _stream_cache.has(id):
		return _stream_cache[id] as AudioStream
	var path: String = "res://assets/audio/sfx/combat/%s.ogg" % id
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/sfx/world/%s.ogg" % id
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path) as AudioStream
	_stream_cache[id] = stream
	return stream


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
	for voice: AudioStreamPlayer in _sfx_pool:
		voice.volume_db = 0.0
	_ui_player.volume_db = 0.0


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
