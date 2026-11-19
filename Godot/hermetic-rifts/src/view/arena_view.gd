extends Node2D

const GHOST_CAP: int = 10
const SPARK_CAP: int = 24
const IMPACT_CAP: int = 12
const ARC_CAP: int = 16
const DASH_GHOST_CD: float = 0.04
const MOVE_GHOST_CD: float = 0.055
const TRAIL_SPEED: float = 18.0
const GEM_TEXTURE_PATHS: PackedStringArray = [
	"pickups/xp-drop-small.png",
	"pickups/xp-drop-medium.png",
	"pickups/xp-cluster-gold.png",
	"pickups/essence-crystal.png",
]
const GEM_FALLBACK_COLORS: Array[Color] = [
	Color("5ec8d4"),
	Color("5ec8d4"),
	Color("e5c878"),
	Color("e84a5f"),
]
const GEM_FALLBACK_SIZES: PackedInt32Array = [12, 16, 20, 16]

@onready var camera: Camera2D = $Camera2D
@onready var world_root: Node2D = $WorldRoot
@onready var player_sprite: Sprite2D = $WorldRoot/Player
@onready var crosshair: Sprite2D = $WorldRoot/Crosshair

var _fodder_layers: Dictionary = {}
var _fodder_sprites: Array[Sprite2D] = []
var _fodder_attack_played: PackedByteArray = PackedByteArray()
var _elite_sprites: Array[Sprite2D] = []
var _proj_sprites: Array[Sprite2D] = []
var _hazard_sprites: Array[Sprite2D] = []
var _hazard_pool_mats: Array[ShaderMaterial] = []
var _hazard_ring_mats: Array[ShaderMaterial] = []
var _obstacle_sprites: Array[Sprite2D] = []
var _obs_mats: Array[Dictionary] = []
var _volatile_glows: Array[Sprite2D] = []
var _vent_overlays: Array[Sprite2D] = []
var _vent_mats: Array[ShaderMaterial] = []
var _zone_sprites: Array[Sprite2D] = []
var _zone_mats: Array[Dictionary] = []
var _portal_sprites: Array[Sprite2D] = []
var _portal_mats: Array[ShaderMaterial] = []
var _lore_sprites: Array[Sprite2D] = []
var _lore_glows: Array[Sprite2D] = []
var _ghosts: Array[Sprite2D] = []
var _ghost_life: PackedFloat32Array = PackedFloat32Array()
var _ghost_max: PackedFloat32Array = PackedFloat32Array()
var _ghost_init_a: PackedFloat32Array = PackedFloat32Array()
var _ghost_cd: float = 0.0
var _sparks: Array[Sprite2D] = []
var _spark_life: PackedFloat32Array = PackedFloat32Array()
var _impact_sprites: Array[Sprite2D] = []
var _impact_life: PackedFloat32Array = PackedFloat32Array()
var _impact_max: PackedFloat32Array = PackedFloat32Array()
var _impact_mats: Array[ShaderMaterial] = []
var _arc_x0: PackedFloat32Array = PackedFloat32Array()
var _arc_y0: PackedFloat32Array = PackedFloat32Array()
var _arc_x1: PackedFloat32Array = PackedFloat32Array()
var _arc_y1: PackedFloat32Array = PackedFloat32Array()
var _arc_life: PackedFloat32Array = PackedFloat32Array()
var _arc_max: PackedFloat32Array = PackedFloat32Array()
var _arc_colors: Array[Color] = []
var _chain_winding_prev: PackedByteArray = PackedByteArray()
var _enemy_last_x: PackedFloat32Array = PackedFloat32Array()
var _enemy_last_y: PackedFloat32Array = PackedFloat32Array()
var _enemy_anim: PackedStringArray = PackedStringArray()
var _enemy_anim_t0: PackedFloat32Array = PackedFloat32Array()
var _enemy_windup: PackedFloat32Array = PackedFloat32Array()
var _shake: float = 0.0
var _hurt_flash: float = 0.0
var _hurt_mat: ShaderMaterial
var _mat_tether: ShaderMaterial
var _mat_impact: ShaderMaterial
var _mat_brim: ShaderMaterial
var _mat_cracks: ShaderMaterial
var _mat_ritual_ring: ShaderMaterial
var _mat_boss_emerge: ShaderMaterial
var _mat_laser: ShaderMaterial
var _laser: Sprite2D
var _ambient: Sprite2D
var _floor_root: Node2D
var _floor_void: Sprite2D
var _floor_chunks: Array[Sprite2D] = []
var _circle: Sprite2D
var _ritual_ring: Sprite2D
var _circle_cracks: Sprite2D
var _boss_emerge: Sprite2D
var _portal: Sprite2D
var _player_glow: Sprite2D
var _decoy: Sprite2D
var _gem_layers: Array[MultiMeshInstance2D] = []
var _lut_tex: Texture2D
var _prism_tex: Texture2D
var _pickup_spark_tex: Texture2D
var _charge_active: float = 0.0
var _tex_cache: Dictionary = {}
var _last_px: float = 0.0
var _last_py: float = 0.0
var _trail_px: float = 0.0
var _trail_py: float = 0.0
var _trail_inited: bool = false
var _last_stage: int = -1
var _last_stage_gen: int = -1
var _last_boss: bool = false
var _last_overlay: StringName = &""
var _walk_phase: float = 0.0
var _last_facing_left: bool = false
var _last_move_x: float = 0.0
var _last_move_y: float = 0.0


func _ready() -> void:
	if camera == null:
		camera = Camera2D.new()
		add_child(camera)
	camera.make_current()
	_ensure_debug_actions()
	if world_root == null:
		world_root = Node2D.new()
		world_root.name = "WorldRoot"
		add_child(world_root)
	world_root.y_sort_enabled = true
	if player_sprite == null:
		player_sprite = Sprite2D.new()
		player_sprite.name = "Player"
		world_root.add_child(player_sprite)
	if crosshair == null:
		crosshair = Sprite2D.new()
		crosshair.name = "Crosshair"
		world_root.add_child(crosshair)
	_lut_tex = UiAtlas.lut_tex()
	_prism_tex = _make_prism_texture()
	_pickup_spark_tex = _make_pickup_spark_texture()
	_floor_root = Node2D.new()
	_floor_root.z_index = -30
	add_child(_floor_root)
	_floor_void = Sprite2D.new()
	_floor_void.texture = _placeholder(FloorStamp.VOID_COLOR, 16)
	_floor_void.z_index = -1
	_floor_root.add_child(_floor_void)
	_circle_cracks = Sprite2D.new()
	_circle_cracks.z_index = -20
	_circle_cracks.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_circle_cracks.texture = _placeholder(Color.WHITE, 64)
	_mat_cracks = _mat_lut("res://assets/shaders/circle_cracks.gdshader")
	_circle_cracks.material = _mat_cracks
	_circle_cracks.visible = false
	add_child(_circle_cracks)
	_ambient = Sprite2D.new()
	_ambient.centered = false
	_ambient.z_index = 40
	_ambient.texture = _placeholder(Color(1, 1, 1, 1), 64)
	_ambient.material = _mat("res://assets/shaders/ambient_biome.gdshader")
	add_child(_ambient)
	_circle = Sprite2D.new()
	_circle.z_index = -8
	_circle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_circle.visible = false
	world_root.add_child(_circle)
	_ritual_ring = Sprite2D.new()
	_ritual_ring.z_index = -7
	_ritual_ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ritual_ring.texture = _placeholder(Color(1, 1, 1, 1), 64)
	_mat_ritual_ring = _mat_lut("res://assets/shaders/teleporter_ring.gdshader")
	_ritual_ring.material = _mat_ritual_ring
	_ritual_ring.visible = false
	world_root.add_child(_ritual_ring)
	_boss_emerge = Sprite2D.new()
	_boss_emerge.z_index = 6
	_boss_emerge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_boss_emerge.texture = _placeholder(Color.WHITE, 64)
	_mat_boss_emerge = _mat_lut("res://assets/shaders/boss_emerge.gdshader")
	_boss_emerge.material = _mat_boss_emerge
	_boss_emerge.visible = false
	world_root.add_child(_boss_emerge)
	_portal = Sprite2D.new()
	_portal.z_index = -7
	_portal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portal.visible = false
	world_root.add_child(_portal)
	_player_glow = Sprite2D.new()
	_player_glow.z_index = 5
	_player_glow.texture = _radial(Color(1.0, 0.87, 0.56, 0.5), 48)
	world_root.add_child(_player_glow)
	_decoy = Sprite2D.new()
	_decoy.z_index = 5
	_decoy.visible = false
	world_root.add_child(_decoy)
	_hurt_mat = _mat("res://assets/shaders/player_hurt.gdshader")
	_mat_tether = _mat("res://assets/shaders/tether.gdshader")
	_mat_impact = _mat("res://assets/shaders/skill_impact.gdshader")
	_mat_brim = _mat("res://assets/shaders/brimstone_line.gdshader")
	_mat_laser = _mat("res://assets/shaders/boss_laser.gdshader")
	_laser = Sprite2D.new()
	_laser.z_index = 6
	_laser.texture = _placeholder(Color(1, 1, 1, 1), 64)
	_laser.material = _mat_laser
	_laser.visible = false
	world_root.add_child(_laser)
	player_sprite.material = _hurt_mat
	player_sprite.z_index = 5
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_sprite.texture = UiAtlas.entity_frame("runner", "idle", 0.0)
	if player_sprite.texture == null:
		player_sprite.texture = _placeholder(Color(0.85, 0.95, 1.0), 32)
	crosshair.z_index = 18
	crosshair.texture = _make_crosshair("runner")
	_ghost_life.resize(GHOST_CAP)
	_ghost_max.resize(GHOST_CAP)
	_ghost_init_a.resize(GHOST_CAP)
	_spark_life.resize(SPARK_CAP)
	_impact_life.resize(IMPACT_CAP)
	_impact_max.resize(IMPACT_CAP)
	_arc_x0.resize(ARC_CAP)
	_arc_y0.resize(ARC_CAP)
	_arc_x1.resize(ARC_CAP)
	_arc_y1.resize(ARC_CAP)
	_arc_life.resize(ARC_CAP)
	_arc_max.resize(ARC_CAP)
	for _a: int in ARC_CAP:
		_arc_colors.append(Color("5ad4ff"))
	for _i: int in GHOST_CAP:
		var g := Sprite2D.new()
		g.z_index = 4
		g.visible = false
		g.modulate = Color(1, 1, 1, 0.0)
		g.material = _mat("res://assets/shaders/dash_afterimage.gdshader")
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		world_root.add_child(g)
		_ghosts.append(g)
	for _k: int in IMPACT_CAP:
		var impact := Sprite2D.new()
		impact.z_index = 8
		impact.visible = false
		impact.texture = _placeholder(Color(1, 1, 1, 1), 64)
		var imat: ShaderMaterial = _mat("res://assets/shaders/skill_impact.gdshader")
		impact.material = imat
		world_root.add_child(impact)
		_impact_sprites.append(impact)
		_impact_mats.append(imat)
	for _j: int in SPARK_CAP:
		var s := Sprite2D.new()
		s.z_index = 12
		s.visible = false
		world_root.add_child(s)
		_sparks.append(s)
	_init_gem_layers()


func _init_gem_layers() -> void:
	_gem_layers.clear()
	for k: int in GEM_TEXTURE_PATHS.size():
		var tex: Texture2D = _load_pickup_tex(GEM_TEXTURE_PATHS[k], GEM_FALLBACK_SIZES[k], GEM_FALLBACK_COLORS[k])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		var gw: float = maxf(float(GEM_FALLBACK_SIZES[k]), float(tex.get_width()))
		var gh: float = maxf(float(GEM_FALLBACK_SIZES[k]), float(tex.get_height()))
		var quad := QuadMesh.new()
		quad.size = Vector2(gw, -gh)
		mm.mesh = quad
		mm.instance_count = 64
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance2D.new()
		mmi.multimesh = mm
		mmi.z_index = 2
		mmi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mmi.texture = tex
		world_root.add_child(mmi)
		_gem_layers.append(mmi)


func _process(dt: float) -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	if app.world == null:
		_sync_menu_camera()
		return
	_debug_editor_cheats(app)
	if app.overlay_mode == &"hidden" and app.world.phase == &"levelup":
		app.overlay_mode = &"levelup"
		app.sim_paused = true
	if app.overlay_mode == &"hidden" and (app.world.phase == &"defeat" or app.world.phase == &"victory"):
		app.overlay_mode = &"recap"
		app.sim_paused = true
		if app.world.phase == &"defeat":
			app.records.record_run_end(app.world, "defeat")
		else:
			app.records.record_run_end(app.world, "victory")
	if not app.is_sim_paused():
		var mouse: Vector2 = get_global_mouse_position()
		var frame: InputFrame = DeviceMap.read_frame(0, mouse)
		_last_move_x = frame.move_x
		_last_move_y = frame.move_y
		var frames: Array[InputFrame] = [frame]
		app.world.step(frames, dt)
		_consume_fx(app)
	_sync_music(app)
	_sync(app.world, dt, bool(app.settings.reduce_vfx), bool(app.settings.screenshake))


func _sync_menu_camera() -> void:
	camera.position = Vector2.ZERO
	camera.offset = Vector2.ZERO
	camera.zoom = Vector2(0.92, 0.92)
	_ambient.visible = false
	if _floor_root != null:
		_floor_root.visible = false
	if _circle_cracks != null:
		_circle_cracks.visible = false
	if world_root != null:
		world_root.visible = false
	queue_redraw()


func _sync(world: SimWorld, dt: float, reduce_vfx: bool, screenshake: bool) -> void:
	if world_root != null:
		world_root.visible = true
	_ambient.visible = not reduce_vfx
	if _floor_root != null:
		_floor_root.visible = true
	var stage: Dictionary = SimLoop.current_stage(world)
	var stage_id: String = String(stage.get("id", ""))
	var biome: String = ArenaBiome.from_stage(stage_id)
	var theme: String = ArenaBiome.theme_from_stage(stage_id)
	if world.stage_gen != _last_stage_gen:
		_last_stage_gen = world.stage_gen
		_apply_stage_art(world, theme)
		crosshair.texture = _make_crosshair(String(world.survivor.get("id", "runner")))
		_trail_inited = false
		_clear_arcs()
	_sync_player(world, dt, biome, reduce_vfx)
	_step_dash_trail(world, dt, biome, reduce_vfx)
	crosshair.position = Vector2(world.aim_x, world.aim_y)
	var zoom: float = float(world.catalog.world.get("viewZoom", 2.5))
	camera.zoom = Vector2(zoom, zoom)
	var focus := Vector2(world.player.x, world.player.y)
	if screenshake and _shake > 0.0 and not reduce_vfx:
		focus += Vector2(sin(_shake * 9.0) * _shake, cos(_shake * 11.0) * _shake * 0.7)
	_shake = maxf(0.0, _shake - dt * 18.0)
	camera.offset = Vector2.ZERO
	camera.position = _clamp_arena_camera(world, focus)
	_sync_ambient(world, biome, reduce_vfx)
	_sync_circle(world, stage_id, biome, theme, dt, reduce_vfx)
	_sync_portal(world, reduce_vfx)
	_sync_obstacles(world, biome, theme, reduce_vfx)
	_sync_fodder(world)
	_sync_elites(world, reduce_vfx)
	_sync_projectiles(world, biome, reduce_vfx)
	_sync_zones(world, reduce_vfx)
	_sync_hazards(world, reduce_vfx)
	_sync_laser(world, reduce_vfx)
	_sync_gems(world)
	_sync_lores(world)
	_step_ghosts(dt)
	_step_sparks(dt)
	_step_impacts(dt, world.run_time, reduce_vfx)
	_step_arcs(dt)
	queue_redraw()


func _apply_stage_art(world: SimWorld, theme: String) -> void:
	var circular: bool = world.arena_shape == "circle"
	var r: float = world.arena_radius
	var width: int = maxi(64, int(ceil(r * 2.0))) if circular else int(world.catalog.world.get("width", 6000))
	var height: int = maxi(64, int(ceil(r * 2.0))) if circular else int(world.catalog.world.get("height", 6000))
	var chunks: Array[Dictionary] = FloorStamp.build_chunks(theme, width, height, circular, r)
	if _floor_void != null:
		if circular:
			var span: float = r * 2.0 + 4096.0
			_floor_void.position = Vector2.ZERO
			_floor_void.scale = Vector2(span / 16.0, span / 16.0)
		else:
			var pad_w: float = float(width) + 4096.0
			var pad_h: float = float(height) + 4096.0
			_floor_void.position = Vector2(float(width) * 0.5, float(height) * 0.5)
			_floor_void.scale = Vector2(pad_w / 16.0, pad_h / 16.0)
	while _floor_chunks.size() < chunks.size():
		var cspr := Sprite2D.new()
		cspr.centered = false
		cspr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_floor_root.add_child(cspr)
		_floor_chunks.append(cspr)
	for i: int in chunks.size():
		var cdict: Dictionary = chunks[i]
		var rect: Rect2 = cdict.get("rect", Rect2())
		var tex: Texture2D = cdict.get("texture", null)
		var cspr: Sprite2D = _floor_chunks[i]
		cspr.texture = tex
		cspr.position = rect.position
		cspr.scale = Vector2.ONE
		cspr.visible = tex != null
	for i: int in range(chunks.size(), _floor_chunks.size()):
		_floor_chunks[i].visible = false


func _sync_player(world: SimWorld, dt: float, biome: String, reduce_vfx: bool) -> void:
	var sid: String = String(world.survivor.get("id", "runner"))
	var moving: bool = absf(world.player.x - _last_px) + absf(world.player.y - _last_py) > 0.4
	_last_px = world.player.x
	_last_py = world.player.y
	if moving and world.player.dash_remain <= 0.0:
		_walk_phase += dt * 8.0
	var bob: float = sin(_walk_phase) * 1.5 if moving else 0.0
	if absf(_last_move_x) >= absf(_last_move_y) and not is_zero_approx(_last_move_x):
		_last_facing_left = _last_move_x < 0.0
	var ptex: Texture2D = UiAtlas.entity_frame(sid, "walk" if moving else "idle", world.run_time)
	if ptex != null:
		player_sprite.texture = ptex
	player_sprite.position = Vector2(world.player.x, world.player.y + bob)
	player_sprite.flip_h = _last_facing_left
	player_sprite.modulate = Color(1, 1, 1, 0.45 if world.player.iframe_remain > 0.0 else 1.0)
	if _hurt_flash > 0.0:
		_hurt_flash = maxf(0.0, _hurt_flash - dt * 4.0)
	if _hurt_mat != null:
		_hurt_mat.set_shader_parameter("flash", 0.0 if reduce_vfx else _hurt_flash)
	_player_glow.position = player_sprite.position
	_player_glow.modulate = Color(1.0, 0.87, 0.56, 0.48 if biome == "cinder" else 0.32)
	_player_glow.visible = not reduce_vfx
	if world.decoy.active:
		_decoy.visible = true
		_decoy.texture = player_sprite.texture
		_decoy.position = Vector2(world.decoy.x, world.decoy.y)
		_decoy.modulate = Color(0.77, 0.63, 0.35, 0.3 + 0.2 * sin(world.run_time * 8.0))
		_decoy.flip_h = _last_facing_left
	else:
		_decoy.visible = false


func _sync_ambient(world: SimWorld, biome: String, reduce_vfx: bool) -> void:
	var vis: Rect2 = _view_rect()
	var pad: float = 16.0
	var origin: Vector2 = vis.position - Vector2(pad, pad)
	var view_size: Vector2 = vis.size + Vector2(pad * 2.0, pad * 2.0)
	_ambient.centered = false
	_ambient.position = origin
	_ambient.scale = Vector2(view_size.x / 64.0, view_size.y / 64.0)
	_ambient.visible = not reduce_vfx
	if _ambient.material is ShaderMaterial:
		var mat: ShaderMaterial = _ambient.material as ShaderMaterial
		mat.set_shader_parameter("u_time", world.run_time)
		mat.set_shader_parameter("u_biome", 0.0 if biome == "cinder" else 1.0)
		mat.set_shader_parameter("u_view_origin", origin)
		mat.set_shader_parameter("u_view_size", view_size)


func _sync_circle(
	world: SimWorld,
	stage_id: String,
	biome: String,
	theme: String,
	dt: float,
	reduce_vfx: bool,
) -> void:
	var tel_hidden: bool = world.teleporter_state == &"hidden"
	var charging: bool = world.teleporter_state == &"charging"
	var tel_r: float = SimLoop.effective_teleporter_radius(world)
	var in_zone: bool = (
		charging
		and Vector2(world.player.x, world.player.y).distance_to(Vector2(world.teleporter_x, world.teleporter_y))
		<= tel_r
	)
	var circle_id: String = ArenaBiome.env_id(theme, "circle")
	if not tel_hidden and UiAtlas.env_has(circle_id):
		_circle.texture = UiAtlas.env_frame(circle_id)
		_circle.visible = true
		_circle.position = Vector2(world.teleporter_x, world.teleporter_y)
		_fit_sprite(_circle, tel_r * 2.0, tel_r * 2.0)
	else:
		_circle.visible = false
	var style: float = _stage_shader_style(stage_id, biome)
	var prog: float = 1.0 if world.teleporter_state == &"done" else clampf(world.teleporter_charge / maxf(world.teleporter_hold, 0.001), 0.0, 1.0)
	_ritual_ring.visible = not tel_hidden
	if _ritual_ring.visible:
		_ritual_ring.position = Vector2(world.teleporter_x, world.teleporter_y)
		var ring_span: float = tel_r * 2.08
		_ritual_ring.scale = Vector2(ring_span / 64.0, ring_span / 64.0)
		var active_v: float = 1.0 if charging else (0.55 if world.teleporter_state == &"ready" else 0.25)
		if reduce_vfx:
			active_v *= 0.6
		if _mat_ritual_ring != null:
			_mat_ritual_ring.set_shader_parameter("u_time", world.run_time)
			_mat_ritual_ring.set_shader_parameter("u_progress", prog)
			_mat_ritual_ring.set_shader_parameter("u_tier", float(world.ritual_tier))
			_mat_ritual_ring.set_shader_parameter("u_active", active_v)
			_mat_ritual_ring.set_shader_parameter("u_style", style)
	if reduce_vfx or not charging:
		_charge_active = maxf(0.0, _charge_active - dt * 4.0)
	else:
		var target: float = 1.0 if in_zone else 0.72
		_charge_active += (target - _charge_active) * minf(1.0, dt * 5.0)
	if _circle_cracks != null:
		_circle_cracks.visible = not reduce_vfx and _charge_active > 0.01
		if _circle_cracks.visible:
			var is_circ: bool = world.arena_shape == "circle"
			var span_w: float = world.arena_radius * 2.0 if is_circ else float(world.catalog.world.get("width", 6000.0))
			var span_h: float = world.arena_radius * 2.0 if is_circ else float(world.catalog.world.get("height", 6000.0))
			_circle_cracks.position = Vector2.ZERO if is_circ else Vector2(span_w * 0.5, span_h * 0.5)
			_circle_cracks.scale = Vector2(maxf(1.0, span_w) / 64.0, maxf(1.0, span_h) / 64.0)
			if _mat_cracks != null:
				var cuv_x: float = 0.5 + world.teleporter_x / maxf(span_w, 1.0) if is_circ else world.teleporter_x / maxf(span_w, 1.0)
				var cuv_y: float = 0.5 + world.teleporter_y / maxf(span_h, 1.0) if is_circ else world.teleporter_y / maxf(span_h, 1.0)
				_mat_cracks.set_shader_parameter("u_time", world.run_time)
				_mat_cracks.set_shader_parameter("u_progress", prog)
				_mat_cracks.set_shader_parameter("u_tier", float(world.ritual_tier))
				_mat_cracks.set_shader_parameter("u_active", _charge_active)
				_mat_cracks.set_shader_parameter("u_circle_uv", Vector2(cuv_x, cuv_y))
				_mat_cracks.set_shader_parameter("u_circular", 1.0 if is_circ else 0.0)
				_mat_cracks.set_shader_parameter("u_grid_px", clampf(maxf(span_w, span_h) * 0.5, 256.0, 6000.0))


func _sync_portal(world: SimWorld, _reduce_vfx: bool) -> void:
	_portal.visible = false
	if not world.portal_open or world.portals.is_empty():
		for spr: Sprite2D in _portal_sprites:
			spr.visible = false
		return
	var needed: int = world.portals.size()
	while _portal_sprites.size() < needed:
		var spr := Sprite2D.new()
		spr.z_index = -7
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.texture = _placeholder(Color.WHITE, 64)
		var mat: ShaderMaterial = _mat_lut("res://assets/shaders/portal_vortex.gdshader")
		spr.material = mat
		world_root.add_child(spr)
		_portal_sprites.append(spr)
		_portal_mats.append(mat)
	var hold_need: float = maxf(float(world.catalog.loop.get("portalHold", 1.4)), 0.001)
	var default_r: float = float(world.catalog.loop.get("portalRadius", 70.0))
	for i: int in needed:
		var portal: Dictionary = world.portals[i]
		var spr: Sprite2D = _portal_sprites[i]
		var mat: ShaderMaterial = _portal_mats[i]
		var px: float = float(portal.get("x", 0.0))
		var py: float = float(portal.get("y", 0.0))
		var pr: float = float(portal.get("radius", default_r))
		var hold_pct: float = clampf(float(portal.get("hold", 0.0)) / hold_need, 0.0, 1.0)
		var kind_str: String = String(portal.get("kind", "next"))
		spr.visible = true
		spr.position = Vector2(px, py)
		var span: float = pr * 2.0
		spr.scale = Vector2(span / 64.0, span / 64.0)
		spr.modulate = Color.WHITE
		if mat != null:
			mat.set_shader_parameter("u_kind", _portal_kind_index(kind_str))
			mat.set_shader_parameter("u_hold", hold_pct)
			mat.set_shader_parameter("u_time", world.run_time)
	for i: int in range(needed, _portal_sprites.size()):
		_portal_sprites[i].visible = false


func _portal_kind_index(kind: String) -> float:
	match kind:
		"branch":
			return 1.0
		"secret":
			return 2.0
		"silver":
			return 3.0
		"gold", "demo-seal":
			return 4.0
		"crimson", "true-ending":
			return 5.0
		_:
			return 0.0


func _sync_obstacles(world: SimWorld, biome: String, theme: String, reduce_vfx: bool) -> void:
	while _obstacle_sprites.size() < world.obstacles.cap:
		var spr := Sprite2D.new()
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.z_index = 5
		world_root.add_child(spr)
		_obstacle_sprites.append(spr)
		_obs_mats.append({})
		var glow := Sprite2D.new()
		glow.texture = _radial(Color(1.0, 0.55, 0.15, 0.35), 32)
		glow.z_index = 1
		glow.visible = false
		world_root.add_child(glow)
		_volatile_glows.append(glow)
		var vent_ov := Sprite2D.new()
		vent_ov.texture = _placeholder(Color.WHITE, 64)
		vent_ov.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		vent_ov.offset = Vector2(0.0, -12.0)
		vent_ov.scale = Vector2(136.0 / 64.0, 192.0 / 64.0)
		vent_ov.z_index = 1
		vent_ov.visible = false
		var vmat: ShaderMaterial = _mat_lut("res://assets/shaders/vent_erupt.gdshader")
		vent_ov.material = vmat
		world_root.add_child(vent_ov)
		_vent_overlays.append(vent_ov)
		_vent_mats.append(vmat)
	var hazard_frame: int = 0 if int(floor(world.run_time / 0.45)) % 2 == 0 else 1
	var vent_cfg: Dictionary = DictUtil.d(world.catalog.obstacles, "alchemicalVent")
	var ob_cfg: Dictionary = DictUtil.d(world.catalog.obstacles, "siphonObelisk")
	var burn_cfg: Dictionary = DictUtil.d(world.catalog.loop, "burn")
	for i: int in world.obstacles.cap:
		var spr: Sprite2D = _obstacle_sprites[i]
		var glow: Sprite2D = _volatile_glows[i]
		var vent_ov: Sprite2D = _vent_overlays[i]
		if world.obstacles.alive[i] == 0:
			spr.visible = false
			glow.visible = false
			vent_ov.visible = false
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		if obs.type != &"vent":
			vent_ov.visible = false
		spr.visible = true
		spr.position = Vector2(obs.x, obs.y)
		spr.centered = true
		spr.rotation = 0.0
		spr.modulate = Color.WHITE
		spr.offset = Vector2.ZERO
		spr.scale = Vector2.ONE
		if obs.type == &"vent":
			_sync_vent_obstacle(spr, glow, vent_ov, _vent_mats[i], i, obs, vent_cfg, world.run_time, reduce_vfx)
		elif obs.type == &"conduit":
			_sync_conduit_obstacle(spr, glow, i, obs, world.run_time, reduce_vfx)
		elif obs.type == &"obelisk":
			_sync_obelisk_obstacle(spr, glow, i, obs, ob_cfg, world.run_time, reduce_vfx)
		elif obs.type == &"geode":
			_sync_geode_obstacle(spr, glow, obs, world.run_time, reduce_vfx)
		elif obs.type == &"burn_trail":
			_sync_burn_trail_obstacle(spr, glow, i, obs, burn_cfg, world.run_time)
		elif obs.type == &"hazard":
			_sync_hazard_obstacle(spr, glow, i, obs, world, biome, theme, hazard_frame, reduce_vfx)
		elif obs.type == &"volatile":
			_sync_volatile_obstacle(spr, glow, obs, theme, world.run_time, reduce_vfx)
		else:
			_sync_pillar_obstacle(spr, glow, obs, theme, world.player.x, world.player.y)


func _sync_vent_obstacle(
	spr: Sprite2D,
	glow: Sprite2D,
	vent_ov: Sprite2D,
	ov_mat: ShaderMaterial,
	slot: int,
	obs: SimObstacle,
	vent_cfg: Dictionary,
	run_time: float,
	reduce_vfx: bool,
) -> void:
	spr.remove_meta("env_id")
	spr.texture = UiAtlas.generated_tex("env/env-vent-grate.png", 32, Color("d47a32"))
	spr.scale = Vector2(1.5, 1.5)
	spr.z_index = 1
	glow.visible = false
	var mat: ShaderMaterial = _slot_mat(_obs_mats, slot, "vent", "res://assets/shaders/vent_heat.gdshader", true)
	spr.material = mat
	var st: float = 0.0
	var prog: float = 0.0
	if obs.state == &"telegraph":
		st = 1.0
		var tdur: float = maxf(float(vent_cfg.get("telegraphDuration", 1.2)), 0.001)
		prog = 1.0 - clampf(obs.timer / tdur, 0.0, 1.0)
	elif obs.state == &"erupting":
		st = 2.0
		var adur: float = maxf(float(vent_cfg.get("activeDuration", 1.0)), 0.001)
		prog = 1.0 - clampf(obs.timer / adur, 0.0, 1.0)
	else:
		var cdur: float = maxf(float(vent_cfg.get("cycleInterval", 9.0)), 0.001)
		prog = clampf(obs.cycle_timer / cdur, 0.0, 1.0)
	if mat != null:
		mat.set_shader_parameter("u_state", st)
		mat.set_shader_parameter("u_progress", prog)
		mat.set_shader_parameter("u_time", run_time)
	if obs.state == &"telegraph" or obs.state == &"erupting":
		vent_ov.visible = true
		vent_ov.z_index = 1 if (obs.state == &"telegraph" or reduce_vfx) else 6
		vent_ov.position = Vector2(obs.x, obs.y - 0.5) if obs.state == &"telegraph" else Vector2(obs.x, obs.y)
		if ov_mat != null:
			ov_mat.set_shader_parameter("u_state", st)
			ov_mat.set_shader_parameter("u_progress", prog)
			ov_mat.set_shader_parameter("u_time", run_time)
			ov_mat.set_shader_parameter("u_seed", float(obs.id) * 1.37)
			ov_mat.set_shader_parameter("u_reduce", 1.0 if reduce_vfx else 0.0)
	else:
		vent_ov.visible = false


func _sync_conduit_obstacle(
	spr: Sprite2D,
	glow: Sprite2D,
	slot: int,
	obs: SimObstacle,
	run_time: float,
	reduce_vfx: bool,
) -> void:
	spr.remove_meta("env_id")
	spr.texture = UiAtlas.generated_tex("env/env-conduit-base.png", 32, Color("5ec8d4"))
	spr.z_index = 5
	_apply_pillar_origin(spr, obs.radius, float(spr.texture.get_height()))
	var mat: ShaderMaterial = _slot_mat(_obs_mats, slot, "conduit", "res://assets/shaders/conduit_charge.gdshader", true)
	spr.material = mat
	if mat != null:
		mat.set_shader_parameter("u_mask_tex", UiAtlas.generated_tex("env/env-conduit-mask.png", 32, Color.BLACK))
		mat.set_shader_parameter("u_charges", float(obs.charges))
		mat.set_shader_parameter("u_depleted", 1.0 if obs.state == &"depleted" else 0.0)
		mat.set_shader_parameter("u_time", run_time)
	glow.visible = not reduce_vfx and obs.state != &"depleted" and obs.charges > 0
	if glow.visible:
		glow.position = Vector2(obs.x, obs.y)
		glow.modulate = Color(0.35, 0.88, 1.0, 0.16 + 0.14 * float(obs.charges))
		glow.scale = Vector2(1.4 + 0.25 * float(obs.charges), 1.4 + 0.25 * float(obs.charges))


func _sync_obelisk_obstacle(
	spr: Sprite2D,
	glow: Sprite2D,
	slot: int,
	obs: SimObstacle,
	ob_cfg: Dictionary,
	run_time: float,
	reduce_vfx: bool,
) -> void:
	spr.remove_meta("env_id")
	var rel: String = "env/obelisk-essence.png"
	var variant: float = 0.0
	var gcol := Color("5ec8d4")
	if obs.sub_kind == "obelisk-reliquary":
		rel = "env/obelisk-reliquary.png"
		variant = 1.0
		gcol = Color("e5c878")
	elif obs.sub_kind == "obelisk-blood":
		rel = "env/obelisk-blood.png"
		variant = 2.0
		gcol = Color("e83b3b")
	spr.texture = UiAtlas.generated_tex(rel, 32, gcol)
	spr.z_index = 5
	_apply_pillar_origin(spr, obs.radius, float(spr.texture.get_height()))
	var st: float = 0.0
	if obs.state == &"channeling":
		st = 1.0
	elif obs.state == &"trial_active":
		st = 2.0
	elif obs.state == &"completed":
		st = 3.0
	var chan_dur: float = maxf(float(ob_cfg.get("channelDuration", 2.0)), 0.001)
	var mat: ShaderMaterial = _slot_mat(_obs_mats, slot, "obelisk", "res://assets/shaders/obelisk_state.gdshader", true)
	spr.material = mat
	if mat != null:
		mat.set_shader_parameter("u_mask_tex", UiAtlas.generated_tex("env/obelisk-mask.png", 32, Color.BLACK))
		mat.set_shader_parameter("u_state", st)
		mat.set_shader_parameter("u_progress", clampf(obs.progress / chan_dur, 0.0, 1.0))
		mat.set_shader_parameter("u_variant", variant)
		mat.set_shader_parameter("u_time", run_time)
	glow.visible = not reduce_vfx and obs.state != &"completed"
	if glow.visible:
		glow.position = Vector2(obs.x, obs.y)
		var a: float = 0.45 if obs.state == &"trial_active" else (0.35 if obs.state == &"channeling" else 0.22)
		glow.modulate = Color(gcol.r, gcol.g, gcol.b, a)
		glow.scale = Vector2(2.0, 2.0) if obs.state == &"trial_active" else Vector2(1.5, 1.5)


func _sync_geode_obstacle(
	spr: Sprite2D,
	glow: Sprite2D,
	obs: SimObstacle,
	run_time: float,
	reduce_vfx: bool,
) -> void:
	spr.remove_meta("env_id")
	spr.material = null
	var collapse_warn: bool = obs.state == &"intact" and obs.collapse_timer >= 0.0 and obs.collapse_timer < 6.0
	var frame_idx: int = 0
	if obs.state == &"depleted":
		frame_idx = 2
	elif obs.state == &"cracked" or (collapse_warn and int(floor(run_time * 8.0)) % 2 == 0):
		frame_idx = 1
	spr.texture = UiAtlas.generated_frame("env/mercury-geode.png", 32, 32, frame_idx, Color("7ad4ff"))
	spr.z_index = 2 if obs.state == &"depleted" else 5
	_apply_pillar_origin(spr, obs.radius, float(spr.texture.get_height()))
	if collapse_warn and int(floor(run_time * 10.0)) % 2 == 0:
		spr.modulate = Color(1.3, 1.08, 0.68)
	glow.visible = not reduce_vfx and obs.state != &"depleted"
	if glow.visible:
		glow.position = Vector2(obs.x, obs.y)
		glow.modulate = Color(0.55, 0.92, 1.0, 0.45 if obs.state == &"cracked" else 0.28)
		glow.scale = Vector2(1.7, 1.7)


func _sync_burn_trail_obstacle(
	spr: Sprite2D,
	glow: Sprite2D,
	slot: int,
	obs: SimObstacle,
	burn_cfg: Dictionary,
	run_time: float,
) -> void:
	spr.remove_meta("env_id")
	spr.texture = _placeholder(Color.WHITE, 64)
	var diam: float = maxf(24.0, obs.radius * 2.0)
	spr.scale = Vector2(diam / 64.0, diam / 64.0)
	spr.z_index = 1
	glow.visible = false
	var mat: ShaderMaterial = _slot_mat(_obs_mats, slot, "miasma", "res://assets/shaders/miasma_pool.gdshader", true)
	spr.material = mat
	var dur: float = maxf(float(burn_cfg.get("trailDuration", 2.2)), 0.001)
	if mat != null:
		mat.set_shader_parameter("u_kind", 1.0)
		mat.set_shader_parameter("u_time", run_time)
		mat.set_shader_parameter("u_progress", 1.0 - clampf(obs.timer / dur, 0.0, 1.0))
		mat.set_shader_parameter("u_seed", float(slot + 1) * 5.17)
		mat.set_shader_parameter("u_has_tex", 0.0)


func _sync_hazard_obstacle(
	spr: Sprite2D,
	glow: Sprite2D,
	slot: int,
	obs: SimObstacle,
	world: SimWorld,
	biome: String,
	theme: String,
	hazard_frame: int,
	reduce_vfx: bool,
) -> void:
	glow.visible = false
	spr.z_index = 1
	var is_frozen: bool = obs.sub_kind == "frozen"
	var timed: bool = obs.timer > 0.0
	if is_frozen or timed or theme == "putrid":
		spr.remove_meta("env_id")
		spr.texture = _placeholder(Color.WHITE, 64)
		var diam: float = maxf(24.0, obs.radius * 2.0)
		spr.scale = Vector2(diam / 64.0, diam / 64.0)
		var mat: ShaderMaterial = _slot_mat(_obs_mats, slot, "miasma", "res://assets/shaders/miasma_pool.gdshader", true)
		spr.material = mat
		var prog: float = 0.0
		if is_frozen:
			prog = 1.0 - clampf(obs.reaction_cooldown / 4.0, 0.0, 1.0)
		elif timed:
			prog = 1.0 - clampf(obs.timer / 6.0, 0.0, 1.0)
		if mat != null:
			mat.set_shader_parameter("u_kind", 2.0 if is_frozen else 0.0)
			mat.set_shader_parameter("u_time", world.run_time)
			mat.set_shader_parameter("u_progress", prog)
			mat.set_shader_parameter("u_seed", float(slot + 1) * 11.13)
			mat.set_shader_parameter("u_has_tex", 0.0)
		return
	var env_id: String = ArenaBiome.env_id(theme, "hazard-%d" % hazard_frame)
	if not UiAtlas.env_has(env_id):
		env_id = ArenaBiome.env_id(theme, "hazard-0")
	var has_tex: bool = UiAtlas.env_has(env_id)
	if str(spr.get_meta("env_id", "")) != env_id:
		spr.set_meta("env_id", env_id)
		if has_tex:
			var img: ImageTexture = UiAtlas.env_image(env_id)
			spr.texture = img if img != null else UiAtlas.env_frame(env_id)
		else:
			spr.texture = _placeholder(Color.WHITE, 64)
	var diam_e: float = obs.radius * 2.0
	var tw: float = maxf(1.0, float(spr.texture.get_width())) if spr.texture != null else 64.0
	var th: float = maxf(1.0, float(spr.texture.get_height())) if spr.texture != null else 64.0
	spr.scale = Vector2(diam_e / tw, diam_e / th)
	var hm: ShaderMaterial = _slot_mat(_obs_mats, slot, "env_hazard", "res://assets/shaders/env_hazard.gdshader", false)
	spr.material = hm
	if hm != null:
		var player_in: float = 1.0 if Vector2(world.player.x, world.player.y).distance_to(Vector2(obs.x, obs.y)) <= obs.radius + world.player.radius else 0.0
		var style: float = 2.0 if theme == "glacial" else (1.0 if biome == "rime" else 0.0)
		hm.set_shader_parameter("u_time", world.run_time)
		hm.set_shader_parameter("u_style", style)
		hm.set_shader_parameter("u_player_in", player_in)
		hm.set_shader_parameter("u_seed", float(slot + 1) * 13.37)
		hm.set_shader_parameter("u_fade", 1.0)
		hm.set_shader_parameter("u_has_tex", 1.0 if has_tex else 0.0)
		hm.set_shader_parameter("u_reduce", 1.0 if reduce_vfx else 0.0)


func _sync_volatile_obstacle(
	spr: Sprite2D,
	glow: Sprite2D,
	obs: SimObstacle,
	theme: String,
	run_time: float,
	reduce_vfx: bool,
) -> void:
	spr.material = null
	var env_id: String = ArenaBiome.env_id(theme, "volatile")
	if str(spr.get_meta("env_id", "")) != env_id:
		spr.set_meta("env_id", env_id)
		spr.texture = UiAtlas.env_frame(env_id) if UiAtlas.env_has(env_id) else _placeholder(Color(0.7, 0.35, 0.15), int(obs.radius * 2.0))
	spr.z_index = 5
	glow.visible = not reduce_vfx
	glow.position = Vector2(obs.x, obs.y)
	var primed: bool = obs.state == &"primed"
	glow.modulate = Color(1.0, 0.85, 0.3, 0.55 if primed else 0.22)
	glow.scale = Vector2(2.4, 2.4) if primed else Vector2(1.6, 1.6)
	if primed and int(floor(run_time * 16.0)) % 2 == 0:
		spr.modulate = Color(1.4, 1.1, 0.6)


func _sync_pillar_obstacle(
	spr: Sprite2D,
	glow: Sprite2D,
	obs: SimObstacle,
	theme: String,
	px: float,
	py: float,
) -> void:
	spr.material = null
	glow.visible = false
	var env_id: String = ArenaBiome.env_id(theme, "pillar")
	if str(spr.get_meta("env_id", "")) != env_id:
		spr.set_meta("env_id", env_id)
		spr.texture = UiAtlas.env_frame(env_id) if UiAtlas.env_has(env_id) else _placeholder(Color(0.35, 0.28, 0.22), int(obs.radius * 2.0))
	spr.z_index = 5
	var env_size: Vector2 = UiAtlas.env_rect(env_id).size
	var th: float = maxf(1.0, env_size.y if env_size.y > 0.0 else (float(spr.texture.get_height()) if spr.texture != null else 48.0))
	_apply_pillar_origin(spr, obs.radius, th)
	var near: bool = Vector2(px, py).distance_to(Vector2(obs.x, obs.y)) < 170.0
	spr.modulate = Color("ffe8d0") if near else Color.WHITE


func _sync_fodder(world: SimWorld) -> void:
	while _fodder_sprites.size() < world.enemies.cap:
		var spr := Sprite2D.new()
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.z_index = 2
		world_root.add_child(spr)
		_fodder_sprites.append(spr)
	if _enemy_last_x.size() < world.enemies.cap:
		_enemy_last_x.resize(world.enemies.cap)
		_enemy_last_y.resize(world.enemies.cap)
		_enemy_anim.resize(world.enemies.cap)
		_enemy_anim_t0.resize(world.enemies.cap)
		_enemy_windup.resize(world.enemies.cap)
	if _fodder_attack_played.size() < world.enemies.cap:
		_fodder_attack_played.resize(world.enemies.cap)
	for id: Variant in _fodder_layers.keys():
		(_fodder_layers[id] as MultiMeshInstance2D).multimesh.instance_count = 0
	for i: int in world.enemies.cap:
		var spr: Sprite2D = _fodder_sprites[i]
		if world.enemies.alive[i] == 0 or world.enemies.role[i] != EnemyPool.ROLE_FODDER:
			spr.visible = false
			_fodder_attack_played[i] = 0
			continue
		spr.visible = true
		spr.position = Vector2(world.enemies.x[i], world.enemies.y[i])
		spr.flip_h = world.enemies.facing[i] == 255
		var moved: float = absf(world.enemies.x[i] - _enemy_last_x[i]) + absf(world.enemies.y[i] - _enemy_last_y[i])
		_enemy_last_x[i] = world.enemies.x[i]
		_enemy_last_y[i] = world.enemies.y[i]
		var def_id: String = world.enemies.def_id[i]
		var attacking: bool = world.enemies.attack_remain[i] > 0.0 or world.enemies.windup[i] > 0.0
		var attack_key: String = world.enemies.anim_name[i] if world.enemies.anim_name[i] != "" else "attack"
		var anim: String = "idle"
		if attacking:
			var attack_dur: float = UiAtlas.entity_anim_duration(def_id, attack_key)
			if _fodder_attack_played[i] != 0:
				var elapsed: float = world.run_time - _enemy_anim_t0[i]
				if attack_dur > 0.0 and elapsed < attack_dur:
					anim = attack_key
				else:
					anim = "walk" if moved > 0.35 else "idle"
			else:
				_fodder_attack_played[i] = 1
				_enemy_anim_t0[i] = world.run_time
				anim = attack_key
		else:
			_fodder_attack_played[i] = 0
			anim = "walk" if moved > 0.35 else "idle"
		var clip: String = "%s:%s" % [def_id, anim]
		var wu: float = world.enemies.windup[i]
		if clip != _enemy_anim[i] or wu > _enemy_windup[i] + 0.001:
			var restart_t: bool = wu > _enemy_windup[i] + 0.001
			if clip != _enemy_anim[i] and anim != attack_key:
				restart_t = true
			_enemy_anim[i] = clip
			if restart_t:
				_enemy_anim_t0[i] = world.run_time
		_enemy_windup[i] = wu
		var anim_t: float = world.run_time if anim == "idle" or anim == "walk" else world.run_time - _enemy_anim_t0[i]
		var tex: Texture2D = UiAtlas.entity_frame(def_id, anim, anim_t)
		if tex != null:
			spr.texture = tex
		elif spr.texture == null:
			spr.texture = _placeholder(Color(0.85, 0.4, 0.25), 24)
		spr.modulate = Color(1.0, 0.85, 0.65) if world.enemies.burn_remain[i] > 0.0 else Color.WHITE


func _sync_elites(world: SimWorld, reduce_vfx: bool) -> void:
	var needed: int = 0
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] != 0 and world.enemies.role[i] != EnemyPool.ROLE_FODDER:
			needed += 1
	while _elite_sprites.size() < needed:
		var spr := Sprite2D.new()
		spr.texture = _placeholder(Color(0.4, 0.7, 1.0), 40)
		spr.material = _mat_lut("res://assets/shaders/elite_outline.gdshader")
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.z_index = 5
		world_root.add_child(spr)
		_elite_sprites.append(spr)
	if _chain_winding_prev.size() < world.enemies.cap:
		_chain_winding_prev.resize(world.enemies.cap)
	var n: int = 0
	var boss_emerging: bool = false
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0:
			_chain_winding_prev[i] = 0
			continue
		var winding_chain: bool = (
			world.enemies.role[i] == EnemyPool.ROLE_ELITE
			and world.enemies.affix[i] == "chain_lightning"
			and world.enemies.chain_cd[i] < 0.0
		)
		if _chain_winding_prev[i] != 0 and not winding_chain and world.enemies.ai_state[i] != EnemyPool.AI_STATE_STUN:
			_emit_chain_lightning_arcs(world, i)
		_chain_winding_prev[i] = 1 if winding_chain else 0
		if world.enemies.role[i] == EnemyPool.ROLE_FODDER:
			continue
		var spr: Sprite2D = _elite_sprites[n]
		spr.visible = true
		spr.position = Vector2(world.enemies.x[i], world.enemies.y[i])
		spr.flip_h = world.enemies.facing[i] == 255
		spr.scale = Vector2.ONE
		spr.offset = Vector2.ZERO
		if _enemy_last_x.size() < world.enemies.cap:
			_enemy_last_x.resize(world.enemies.cap)
			_enemy_last_y.resize(world.enemies.cap)
			_enemy_anim.resize(world.enemies.cap)
			_enemy_anim_t0.resize(world.enemies.cap)
			_enemy_windup.resize(world.enemies.cap)
		var moved: float = absf(world.enemies.x[i] - _enemy_last_x[i]) + absf(world.enemies.y[i] - _enemy_last_y[i])
		_enemy_last_x[i] = world.enemies.x[i]
		_enemy_last_y[i] = world.enemies.y[i]
		var def_id: String = world.enemies.def_id[i]
		var attacking: bool = world.enemies.attack_remain[i] > 0.0 or world.enemies.windup[i] > 0.0
		var anim: String = world.enemies.anim_name[i]
		if not attacking or anim == "":
			anim = "walk" if moved > 0.35 else "idle"
		var clip: String = "%s:%s" % [def_id, anim]
		var wu: float = world.enemies.windup[i]
		if clip != _enemy_anim[i] or wu > _enemy_windup[i] + 0.001:
			_enemy_anim[i] = clip
			_enemy_anim_t0[i] = world.run_time
		_enemy_windup[i] = wu
		var anim_t: float = world.run_time if anim == "idle" or anim == "walk" else world.run_time - _enemy_anim_t0[i]
		var tex: Texture2D = UiAtlas.entity_frame(def_id, anim, anim_t)
		if tex != null:
			spr.texture = tex
		spr.modulate = _entity_modulate(def_id)
		if world.enemies.role[i] == EnemyPool.ROLE_BOSS and world.boss.enemy_index == i and world.boss.emerge_remain > 0.0:
			boss_emerging = true
			var e_prog: float = 1.0 - clampf(world.boss.emerge_remain / BossState.EMERGE_DURATION, 0.0, 1.0)
			if not reduce_vfx:
				spr.offset = Vector2(0.0, lerpf(10.0, 0.0, e_prog))
				spr.scale = Vector2(lerpf(0.72, 1.0, e_prog), lerpf(0.50, 1.0, e_prog))
			if _boss_emerge != null:
				var span_e: float = maxf(world.enemies.radius[i] * 3.4, 96.0)
				_boss_emerge.visible = true
				_boss_emerge.position = Vector2(world.enemies.x[i], world.enemies.y[i])
				_boss_emerge.scale = Vector2(span_e / 64.0, span_e / 64.0)
				if _mat_boss_emerge != null:
					_mat_boss_emerge.set_shader_parameter("u_progress", e_prog)
					_mat_boss_emerge.set_shader_parameter("u_time", world.run_time)
					_mat_boss_emerge.set_shader_parameter("u_style", _boss_emerge_style(def_id))
					_mat_boss_emerge.set_shader_parameter("u_reduce", 1.0 if reduce_vfx else 0.0)
		var affix_val: float = 0.0
		var shield_on: float = 0.0
		var corpse: float = 1.0 if world.enemies.corpse_remain[i] > 0.0 else 0.0
		var affix_id: String = world.enemies.affix[i]
		if world.enemies.shielder[i] != 0 or affix_id == "shielder":
			affix_val = 1.0
			shield_on = 1.0 if world.enemies.shield_hp[i] > 0.0 else 0.0
		elif world.enemies.noxious[i] != 0 or affix_id == "noxious":
			affix_val = 2.0
		elif affix_id == "burn":
			affix_val = 3.0
		elif affix_id == "chain_lightning":
			affix_val = 4.0
		if reduce_vfx:
			affix_val = 0.0
		if spr.material is ShaderMaterial:
			var sm: ShaderMaterial = spr.material as ShaderMaterial
			sm.set_shader_parameter("u_affix", affix_val)
			sm.set_shader_parameter("u_shield_active", shield_on)
			sm.set_shader_parameter("u_corpse", corpse)
			sm.set_shader_parameter("u_time", world.run_time)
		n += 1
	for i: int in range(n, _elite_sprites.size()):
		_elite_sprites[i].visible = false
	if not boss_emerging and _boss_emerge != null:
		_boss_emerge.visible = false


func _boss_emerge_style(def_id: String) -> float:
	if def_id == "frost-sovereign" or def_id == "frost-emperor":
		return 1.0
	if def_id == "viridian-alchemist":
		return 2.0
	if def_id == "voltaic-regent":
		return 3.0
	return 0.0


func _entity_modulate(def_id: String) -> Color:
	if UiAtlas.has_own_entity_tex(def_id):
		return Color.WHITE
	if def_id == "viridian-alchemist":
		return Color("7af092")
	if def_id == "arch-alchemist":
		return Color("ffbe55")
	return Color.WHITE


func _emit_chain_lightning_arcs(world: SimWorld, idx: int) -> void:
	var cfg: Dictionary = DictUtil.d(world.catalog.loop, "chainLightning")
	var range_v: float = float(cfg.get("range", 230.0)) + world.player.radius + 20.0
	var ex: float = world.enemies.x[idx]
	var ey: float = world.enemies.y[idx]
	var pdx: float = world.player.x - ex
	var pdy: float = world.player.y - ey
	var pdist: float = sqrt(pdx * pdx + pdy * pdy)
	var bx: float = ex
	var by: float = ey
	if pdist <= range_v:
		_spawn_arc(ex, ey, world.player.x, world.player.y, Color("8ce8ff"), 0.22)
		bx = world.player.x
		by = world.player.y
	var bounce_r: float = float(cfg.get("bounceRange", 160.0))
	var b_max2: float = bounce_r * bounce_r
	var best_idx: int = -1
	var best_d2: float = b_max2
	for o: int in world.obstacles.cap:
		if world.obstacles.alive[o] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[o]
		if obs.type != &"conduit" and obs.type != &"volatile":
			continue
		var d2: float = (obs.x - bx) * (obs.x - bx) + (obs.y - by) * (obs.y - by)
		if d2 <= best_d2:
			best_d2 = d2
			best_idx = o
	if best_idx >= 0:
		var target_obs: SimObstacle = world.obstacles.items[best_idx]
		_spawn_arc(bx, by, target_obs.x, target_obs.y, Color("ffe870"), 0.22)


func _sync_projectiles(world: SimWorld, biome: String, reduce_vfx: bool) -> void:
	var needed: int = 0
	for i: int in world.projectiles.alive.size():
		if world.projectiles.alive[i] != 0:
			needed += 1
	while _proj_sprites.size() < needed:
		var spr := Sprite2D.new()
		spr.texture = _placeholder(Color(1.0, 0.85, 0.4), 8)
		spr.z_index = 6
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		world_root.add_child(spr)
		_proj_sprites.append(spr)
	var n: int = 0
	for i: int in world.projectiles.alive.size():
		if world.projectiles.alive[i] == 0:
			continue
		var spr: Sprite2D = _proj_sprites[n]
		spr.visible = true
		spr.position = Vector2(world.projectiles.x[i], world.projectiles.y[i])
		spr.rotation = atan2(world.projectiles.vy[i], world.projectiles.vx[i])
		spr.modulate = Color.WHITE
		spr.scale = Vector2.ONE
		var flags: int = int(world.projectiles.flags[i])
		var team: int = int(world.projectiles.team[i])
		var tag: String = world.projectiles.skill_tag[i]
		var elem: String = world.projectiles.element[i]
		if reduce_vfx:
			spr.material = null
			spr.texture = _placeholder(Color(1.0, 0.85, 0.4), 8)
		elif flags & ProjectilePool.FLAG_TETHER != 0:
			spr.material = _mat_tether
			spr.texture = _fx_texture("skill-condemn-tether")
			if _mat_tether != null:
				_mat_tether.set_shader_parameter("u_time", world.run_time)
		elif flags & ProjectilePool.FLAG_IMPACT != 0:
			spr.material = null
			spr.texture = _fx_texture("skill-censer-lob")
		else:
			spr.material = null
			if team == ProjectilePool.TEAM_ENEMY:
				var spit: String = "cinder-spit" if biome == "cinder" else "frost-spit"
				spr.texture = _fx_texture(spit)
				if elem == "burn":
					spr.modulate = Color("ff7a3a")
			elif flags & ProjectilePool.FLAG_PIERCE != 0:
				spr.texture = _fx_texture("skill-aether-pierce")
				if tag == "parry":
					spr.modulate = Color("dff6ff")
				elif tag == "prism_shard":
					spr.modulate = Color("c9adff")
			else:
				spr.texture = _fx_texture("bolt")
				if tag == "harpoon":
					spr.modulate = Color("ffb05c")
					spr.scale = Vector2(1.4, 1.1)
				elif tag == "prism":
					spr.modulate = Color("c9adff")
		if spr.texture == null:
			spr.texture = _placeholder(Color(1.0, 0.85, 0.4), 8)
		n += 1
	for i: int in range(n, _proj_sprites.size()):
		_proj_sprites[i].visible = false


func _sync_zones(world: SimWorld, reduce_vfx: bool) -> void:
	while _zone_sprites.size() < world.zones.cap:
		var spr := Sprite2D.new()
		spr.z_index = 3
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.visible = false
		world_root.add_child(spr)
		_zone_sprites.append(spr)
		_zone_mats.append({})
	for i: int in world.zones.cap:
		var spr: Sprite2D = _zone_sprites[i]
		if world.zones.alive[i] == 0:
			spr.visible = false
			continue
		var k: int = world.zones.kind[i]
		if reduce_vfx and k != ZonePool.ZONE_HEX_SIGIL and k != ZonePool.ZONE_PRISM and k != ZonePool.ZONE_SOLAR_BEAM:
			spr.visible = false
			continue
		spr.visible = true
		spr.modulate = Color.WHITE
		spr.rotation = 0.0
		spr.scale = Vector2.ONE
		spr.z_index = 3
		var progress: float = 1.0 - clampf(world.zones.remain[i] / maxf(world.zones.duration[i], 0.001), 0.0, 1.0)
		if k == ZonePool.ZONE_LINE:
			var bm: ShaderMaterial = _slot_mat(_zone_mats, i, "brim", "res://assets/shaders/brimstone_line.gdshader", false)
			spr.material = bm
			spr.texture = _fx_texture("skill-brimstone-line")
			if spr.texture == null:
				spr.texture = _placeholder(Color(0.9, 0.3, 0.1, 0.8), 16)
			var dx: float = world.zones.dir_x[i]
			var dy: float = world.zones.dir_y[i]
			var length: float = world.zones.length[i]
			var width: float = maxf(world.zones.width[i], 12.0)
			spr.position = Vector2(world.zones.x[i] + dx * length * 0.5, world.zones.y[i] + dy * length * 0.5)
			spr.rotation = atan2(dy, dx)
			spr.scale = Vector2(length / maxf(float(spr.texture.get_width()), 1.0), width / maxf(float(spr.texture.get_height()), 1.0))
			if bm != null:
				bm.set_shader_parameter("u_time", world.run_time)
				bm.set_shader_parameter("u_progress", progress)
				bm.set_shader_parameter("u_seed", float(i) * 0.37)
		elif k == ZonePool.ZONE_PRISM:
			spr.material = null
			spr.texture = _prism_tex
			spr.position = Vector2(world.zones.x[i], world.zones.y[i])
			spr.z_index = 4
			var pulse: float = 0.88 + 0.12 * sin(world.run_time * 6.0)
			var diam_p: float = maxf(world.zones.radius[i] * 1.4, 28.0) * pulse
			spr.scale = Vector2(diam_p / 32.0, diam_p / 32.0)
			spr.rotation = sin(world.run_time * 2.2) * 0.12
			spr.modulate = Color(0.85, 0.72, 1.0, 0.95)
		elif k == ZonePool.ZONE_SOLAR_BEAM:
			var sm_beam: ShaderMaterial = _slot_mat(_zone_mats, i, "solar", "res://assets/shaders/boss_laser.gdshader", false)
			spr.material = sm_beam
			spr.texture = _placeholder(Color.WHITE, 64)
			var dx_b: float = world.zones.dir_x[i]
			var dy_b: float = world.zones.dir_y[i]
			var len_b: float = maxf(world.zones.length[i], 24.0)
			var w_b: float = maxf(world.zones.width[i], 14.0)
			spr.position = Vector2(world.zones.x[i] + dx_b * len_b * 0.5, world.zones.y[i] + dy_b * len_b * 0.5)
			spr.rotation = atan2(dy_b, dx_b)
			spr.scale = Vector2(len_b / 64.0, (w_b * 2.4) / 64.0)
			spr.modulate = Color(1.3, 0.95, 0.42, 0.95)
			spr.z_index = 6
			if sm_beam != null:
				sm_beam.set_shader_parameter("u_time", world.run_time)
				sm_beam.set_shader_parameter("u_channeling", 1.0)
				sm_beam.set_shader_parameter("u_progress", progress)
		elif k == ZonePool.ZONE_CENSURE_BELL or k == ZonePool.ZONE_SWAP_ANCHOR:
			var sm_wave: ShaderMaterial = _slot_mat(_zone_mats, i, "shock", "res://assets/shaders/boss_shockwave.gdshader", true)
			spr.material = sm_wave
			spr.texture = _placeholder(Color.WHITE, 64)
			spr.position = Vector2(world.zones.x[i], world.zones.y[i])
			var span_w: float = maxf(world.zones.radius[i] * 2.0, 32.0)
			spr.scale = Vector2(span_w / 64.0, span_w / 64.0)
			spr.z_index = 4
			if sm_wave != null:
				sm_wave.set_shader_parameter("u_progress", clampf(progress, 0.05, 1.0))
				sm_wave.set_shader_parameter("u_thickness", 0.18)
				sm_wave.set_shader_parameter("u_style", 2.0)
				sm_wave.set_shader_parameter("u_time", world.run_time)
		elif k == ZonePool.ZONE_SMOKE_CLOUD:
			var sm_smoke: ShaderMaterial = _slot_mat(_zone_mats, i, "miasma", "res://assets/shaders/miasma_pool.gdshader", true)
			spr.material = sm_smoke
			spr.texture = _placeholder(Color.WHITE, 64)
			spr.position = Vector2(world.zones.x[i], world.zones.y[i])
			var span_s: float = maxf(world.zones.radius[i] * 2.0, 32.0)
			spr.scale = Vector2(span_s / 64.0, span_s / 64.0)
			spr.z_index = 4
			spr.modulate = Color(0.82, 0.92, 0.85, 0.58)
			if sm_smoke != null:
				sm_smoke.set_shader_parameter("u_kind", 0.0)
				sm_smoke.set_shader_parameter("u_time", world.run_time)
				sm_smoke.set_shader_parameter("u_progress", progress)
				sm_smoke.set_shader_parameter("u_seed", float(i + 1) * 4.7)
				sm_smoke.set_shader_parameter("u_has_tex", 0.0)
		elif k == ZonePool.ZONE_FROZEN_PATCH:
			var sm_ice: ShaderMaterial = _slot_mat(_zone_mats, i, "miasma", "res://assets/shaders/miasma_pool.gdshader", true)
			spr.material = sm_ice
			spr.texture = _placeholder(Color.WHITE, 64)
			spr.position = Vector2(world.zones.x[i], world.zones.y[i])
			var span_f: float = maxf(world.zones.radius[i] * 2.0, 32.0)
			spr.scale = Vector2(span_f / 64.0, span_f / 64.0)
			spr.z_index = 1
			if sm_ice != null:
				sm_ice.set_shader_parameter("u_kind", 2.0)
				sm_ice.set_shader_parameter("u_time", world.run_time)
				sm_ice.set_shader_parameter("u_progress", progress)
				sm_ice.set_shader_parameter("u_seed", float(i + 1) * 3.1)
				sm_ice.set_shader_parameter("u_has_tex", 0.0)
		elif k == ZonePool.ZONE_HEX_SIGIL:
			var sm_hex: ShaderMaterial = _slot_mat(_zone_mats, i, "shock", "res://assets/shaders/boss_shockwave.gdshader", true)
			spr.material = sm_hex
			spr.texture = _placeholder(Color.WHITE, 64)
			spr.position = Vector2(world.zones.x[i], world.zones.y[i])
			var span_x: float = maxf(world.zones.radius[i] * 2.0, 32.0)
			spr.scale = Vector2(span_x / 64.0, span_x / 64.0)
			spr.z_index = 2
			spr.modulate = Color(0.88, 0.56, 1.0, 0.92)
			if sm_hex != null:
				sm_hex.set_shader_parameter("u_progress", clampf(0.18 + progress * 0.78, 0.0, 0.96))
				sm_hex.set_shader_parameter("u_thickness", 0.14)
				sm_hex.set_shader_parameter("u_style", 2.0)
				sm_hex.set_shader_parameter("u_time", world.run_time)
		else:
			var im: ShaderMaterial = _slot_mat(_zone_mats, i, "impact", "res://assets/shaders/skill_impact.gdshader", false)
			spr.material = im
			spr.texture = _fx_texture("skill-crucible-cull")
			if spr.texture == null:
				spr.texture = _placeholder(Color(1, 1, 1, 1), 64)
			spr.position = Vector2(world.zones.x[i], world.zones.y[i])
			var rad: float = maxf(world.zones.radius[i] * 2.0, 24.0)
			var tw2: float = float(spr.texture.get_width())
			spr.scale = Vector2(rad / maxf(tw2, 1.0), rad / maxf(tw2, 1.0))
			if im != null:
				im.set_shader_parameter("u_time", world.run_time)
				im.set_shader_parameter("u_progress", progress)
				im.set_shader_parameter("u_kind", 1.0)


func _sync_hazards(world: SimWorld, reduce_vfx: bool) -> void:
	var needed: int = 0
	for i: int in world.boss_hazards.cap:
		if world.boss_hazards.alive[i] != 0:
			needed += 1
	while _hazard_sprites.size() < needed:
		var spr := Sprite2D.new()
		spr.texture = _placeholder(Color(1, 1, 1, 1), 64)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var pmat: ShaderMaterial = _mat("res://assets/shaders/hazard_pool.gdshader")
		var rmat: ShaderMaterial = _mat_lut("res://assets/shaders/boss_shockwave.gdshader")
		spr.material = pmat
		spr.z_index = 1
		world_root.add_child(spr)
		_hazard_sprites.append(spr)
		_hazard_pool_mats.append(pmat)
		_hazard_ring_mats.append(rmat)
	var n: int = 0
	for i: int in world.boss_hazards.cap:
		if world.boss_hazards.alive[i] == 0:
			continue
		var spr: Sprite2D = _hazard_sprites[n]
		var hkind: int = int(world.boss_hazards.kind[i])
		spr.visible = not reduce_vfx or hkind == BossHazardPool.HAZ_RING
		spr.position = Vector2(world.boss_hazards.x[i], world.boss_hazards.y[i])
		if hkind == BossHazardPool.HAZ_RING:
			var max_r: float = maxf(world.boss_hazards.pool_radius[i], 1.0)
			var cur_r: float = clampf(world.boss_hazards.radius[i], 0.0, max_r)
			var thick_px: float = maxf(14.0, world.boss_hazards.angle[i])
			var span_r: float = max_r * 2.0 / 64.0
			spr.scale = Vector2(span_r, span_r)
			spr.z_index = 4
			var rmat: ShaderMaterial = _hazard_ring_mats[n]
			spr.material = rmat
			if rmat != null:
				rmat.set_shader_parameter("u_progress", clampf(cur_r / max_r, 0.02, 0.98))
				rmat.set_shader_parameter("u_thickness", clampf(thick_px / max_r, 0.04, 0.40))
				rmat.set_shader_parameter("u_style", float(world.boss_hazards.style[i]))
				rmat.set_shader_parameter("u_time", world.run_time)
		else:
			spr.z_index = 1
			var span: float = maxf(world.boss_hazards.radius[i] * 2.0 / 64.0, 0.2)
			spr.scale = Vector2(span, span)
			var hm: ShaderMaterial = _hazard_pool_mats[n]
			spr.material = hm
			if hm != null:
				var dur: float = maxf(world.boss_hazards.duration[i], 0.001)
				var progress: float = clampf(world.boss_hazards.elapsed[i] / dur, 0.0, 1.0)
				hm.set_shader_parameter("u_time", world.run_time)
				hm.set_shader_parameter("u_kind", float(hkind))
				hm.set_shader_parameter("u_style", float(world.boss_hazards.style[i]))
				hm.set_shader_parameter("u_state", float(world.boss_hazards.state[i]))
				hm.set_shader_parameter("u_progress", progress)
				hm.set_shader_parameter("u_angle", world.boss_hazards.angle[i])
				hm.set_shader_parameter("u_dir", Vector2(world.boss_hazards.dir_x[i], world.boss_hazards.dir_y[i]))
				hm.set_shader_parameter("u_radius", world.boss_hazards.radius[i])
				if hkind == BossHazardPool.HAZ_PULSE:
					var pillars: Array[Projection] = _pulse_pillar_projections(world, world.boss_hazards.x[i], world.boss_hazards.y[i])
					hm.set_shader_parameter("u_pillars0", pillars[0])
					hm.set_shader_parameter("u_pillars1", pillars[1])
					hm.set_shader_parameter("u_pillars2", pillars[2])
					hm.set_shader_parameter("u_pillars3", pillars[3])
				else:
					var empty := Projection(Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO)
					hm.set_shader_parameter("u_pillars0", empty)
					hm.set_shader_parameter("u_pillars1", empty)
					hm.set_shader_parameter("u_pillars2", empty)
					hm.set_shader_parameter("u_pillars3", empty)
		n += 1
	for i: int in range(n, _hazard_sprites.size()):
		_hazard_sprites[i].visible = false


func _sync_laser(world: SimWorld, reduce_vfx: bool) -> void:
	if _laser == null:
		return
	var boss: BossState = world.boss
	var idx: int = boss.enemy_index
	if reduce_vfx or idx < 0 or world.enemies.alive[idx] == 0 or boss.active_attack < 0 or boss.phase == &"none":
		_laser.visible = false
		return
	var def_id: String = world.enemies.def_id[idx]
	if def_id == "":
		_laser.visible = false
		return
	var ai: Dictionary = DictUtil.d(world.catalog.entity(def_id), "ai")
	if String(ai.get("type", "")) != "boss":
		_laser.visible = false
		return
	var attacks: Array = DictUtil.a(ai, "attacks")
	if boss.active_attack >= attacks.size():
		_laser.visible = false
		return
	var atk: Dictionary = attacks[boss.active_attack]
	if String(atk.get("type", "")) != "laser":
		_laser.visible = false
		return
	var bx: float = world.enemies.x[idx]
	var by: float = world.enemies.y[idx]
	var ex: float = boss.laser_end_x
	var ey: float = boss.laser_end_y
	var dx: float = ex - bx
	var dy: float = ey - by
	var length: float = maxf(24.0, sqrt(dx * dx + dy * dy))
	var hit_r: float = float(atk.get("hitRadius", 28.0))
	var tw: float = 64.0
	_laser.visible = true
	_laser.position = Vector2((bx + ex) * 0.5, (by + ey) * 0.5)
	_laser.rotation = atan2(dy, dx)
	_laser.scale = Vector2(length / tw, (hit_r * 3.0) / tw)
	if _mat_laser != null:
		_mat_laser.set_shader_parameter("u_time", world.run_time)
		_mat_laser.set_shader_parameter("u_channeling", 1.0 if boss.phase == &"channel" else 0.0)
		var dur: float = boss.duration if boss.duration > 0.0 else 1.0
		_mat_laser.set_shader_parameter("u_progress", clampf(boss.elapsed / dur, 0.0, 1.0))


func _pulse_pillar_projections(world: SimWorld, px: float, py: float) -> Array[Projection]:
	var zero := Projection(Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO)
	var mats: Array[Projection] = [zero, zero, zero, zero]
	var slot: int = 0
	for i: int in world.obstacles.cap:
		if slot >= 16:
			break
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		if obs.type != &"pillar":
			continue
		var mat_i: int = slot >> 2
		var col: int = slot & 3
		var v := Vector4(obs.x - px, obs.y - py, obs.radius + EnemyPool.PILLAR_COVER_EXTRA_RADIUS, 1.0)
		var mat: Projection = mats[mat_i]
		match col:
			0:
				mat.x = v
			1:
				mat.y = v
			2:
				mat.z = v
			_:
				mat.w = v
		mats[mat_i] = mat
		slot += 1
	return mats


func _sync_gems(world: SimWorld) -> void:
	var counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	for i: int in world.gems.cap:
		if world.gems.alive[i] == 0:
			continue
		var k: int = clampi(int(world.gems.kind[i]), 0, 3)
		counts[k] += 1
	for k: int in _gem_layers.size():
		var mm: MultiMesh = _gem_layers[k].multimesh
		if mm.instance_count < counts[k]:
			mm.instance_count = maxi(64, counts[k])
		mm.visible_instance_count = counts[k]
	var cursors: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	for i: int in world.gems.cap:
		if world.gems.alive[i] == 0:
			continue
		var k: int = clampi(int(world.gems.kind[i]), 0, 3)
		var slot: int = cursors[k]
		_gem_layers[k].multimesh.set_instance_transform_2d(slot, Transform2D(0.0, Vector2(world.gems.x[i], world.gems.y[i])))
		cursors[k] = slot + 1


func _sync_lores(world: SimWorld) -> void:
	while _lore_sprites.size() < world.lores.cap:
		var glow := Sprite2D.new()
		glow.texture = _radial(Color(1.0, 0.83, 0.35, 0.4), 24)
		glow.z_index = 2
		world_root.add_child(glow)
		_lore_glows.append(glow)
		var spr := Sprite2D.new()
		spr.texture = _placeholder(Color("ffd35a"), 10)
		spr.z_index = 3
		world_root.add_child(spr)
		_lore_sprites.append(spr)
	for i: int in world.lores.cap:
		var glow: Sprite2D = _lore_glows[i]
		var spr: Sprite2D = _lore_sprites[i]
		var on: bool = world.lores.alive[i] != 0
		glow.visible = on
		spr.visible = on
		if not on:
			continue
		var pos := Vector2(world.lores.x[i], world.lores.y[i])
		glow.position = pos
		spr.position = pos
		spr.scale = Vector2(1.5, 1.5)
		glow.scale = Vector2(1.6 + 0.2 * sin(world.run_time * 5.0), 1.6)


func _clamp_arena_camera(world: SimWorld, focus: Vector2) -> Vector2:
	var zx: float = camera.zoom.x if absf(camera.zoom.x) > 0.0001 else 1.0
	var zy: float = camera.zoom.y if absf(camera.zoom.y) > 0.0001 else 1.0
	var view: Vector2 = get_viewport_rect().size
	var half := Vector2(view.x / zx, view.y / zy) * 0.5
	if world.arena_shape == "circle":
		var margin: float = 32.0
		var max_r: float = maxf(0.0, world.arena_radius - minf(half.x, half.y) + margin)
		var dist: float = focus.length()
		if dist > max_r and dist > 0.001:
			return focus * (max_r / dist)
		return focus
	var bounds: Dictionary = world.catalog.world
	var arena := Rect2(0.0, 0.0, float(bounds.get("width", 6000.0)), float(bounds.get("height", 6000.0)))
	return Vector2(
		_clamp_camera_axis(focus.x, arena.position.x, arena.end.x, half.x),
		_clamp_camera_axis(focus.y, arena.position.y, arena.end.y, half.y),
	)


func _clamp_camera_axis(value: float, lo: float, hi: float, half: float) -> float:
	var min_c: float = lo + half
	var max_c: float = hi - half
	if min_c > max_c:
		return (lo + hi) * 0.5
	return clampf(value, min_c, max_c)


func _view_rect() -> Rect2:
	var size: Vector2 = get_viewport_rect().size / camera.zoom
	return Rect2(camera.position - size * 0.5, size)


func _draw() -> void:
	var app := get_node_or_null("/root/App")
	if app == null or app.world == null:
		draw_rect(Rect2(-2000, -1200, 4000, 2400), Color(0.07, 0.05, 0.06), true)
		return
	var world: SimWorld = app.world
	var biome: String = ArenaBiome.from_stage(String(SimLoop.current_stage(world).get("id", "")))
	if world.teleporter_state != &"hidden" and not _circle.visible:
		draw_circle(Vector2(world.teleporter_x, world.teleporter_y), SimLoop.effective_teleporter_radius(world), Color(0.77, 0.64, 0.35, 0.18))
	if world.portal_open and _portal_sprites.is_empty():
		var color := Color(0.9, 0.75, 0.2, 0.45) if SimLoop.can_seal(world) or biome == "cinder" else Color(0.87, 0.96, 1.0, 0.4)
		draw_circle(Vector2(world.portal_x, world.portal_y), float(world.catalog.loop.get("portalRadius", 70.0)), color)
	_draw_telegraphs(world, biome)


func _draw_telegraphs(world: SimWorld, biome: String) -> void:
	var flash: bool = int(floor(world.run_time * 12.0)) % 2 == 0
	var line: Color = Color.WHITE if flash else (Color("ff7a3a") if biome == "cinder" else Color("55ffff"))
	_draw_player_buff_rings(world)
	_draw_obstacle_telegraphs(world, flash)
	_draw_zone_telegraphs(world, flash)
	_draw_spire_tethers(world, flash)
	_draw_boss_dash_telegraph(world, flash)
	_draw_enemy_telegraphs(world, line, flash)
	_draw_arcs()


func _draw_player_buff_rings(world: SimWorld) -> void:
	var ppos := Vector2(world.player.x, world.player.y)
	if world.player.parry_remain > 0.0:
		draw_arc(ppos, world.player.radius + 7.0, 0.0, TAU, 24, Color("dff6ff"), 2.0)
	if world.player.bulwark_remain > 0.0:
		draw_arc(ppos, world.player.radius + 9.0, -PI * 0.65, PI * 0.65, 20, Color("ffb347"), 2.5)
	if world.player.bell_armor_remain > 0.0:
		draw_arc(ppos, world.player.radius + 5.0, 0.0, TAU, 24, Color(0.9, 0.78, 0.42, 0.55), 1.5)


func _draw_obstacle_telegraphs(world: SimWorld, flash: bool) -> void:
	var ob_cfg: Dictionary = DictUtil.d(world.catalog.obstacles, "siphonObelisk")
	var chan_dur: float = maxf(float(ob_cfg.get("channelDuration", 2.0)), 0.001)
	var geode_dur: float = maxf(float(DictUtil.d(world.catalog.loop, "mercuryGeode").get("collapseDuration", 12.0)), 0.001)
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		var opos := Vector2(obs.x, obs.y)
		if obs.type == &"obelisk":
			if obs.state == &"channeling" and obs.progress > 0.0:
				var pct: float = clampf(obs.progress / chan_dur, 0.0, 1.0)
				var col_o := Color("e5c878") if obs.sub_kind == "obelisk-reliquary" else (Color("e83b3b") if obs.sub_kind == "obelisk-blood" else Color("5ad4ff"))
				draw_arc(opos, obs.radius + 10.0, -PI * 0.5, -PI * 0.5 + TAU * pct, 24, col_o, 2.5)
			elif obs.state == &"trial_active" and obs.sub_kind == "obelisk-reliquary":
				draw_arc(opos, obs.radius + 12.0, 0.0, TAU, 24, Color(0.9, 0.78, 0.35, 0.65), 2.0)
		elif obs.type == &"geode" and obs.state == &"intact" and obs.collapse_timer >= 0.0:
			var frac: float = clampf(obs.collapse_timer / geode_dur, 0.0, 1.0)
			var gcol := Color("ff5533") if obs.collapse_timer < 4.0 and flash else Color("7ad4ff")
			draw_arc(opos, obs.radius + 8.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 20, gcol, 2.0)


func _draw_zone_telegraphs(world: SimWorld, flash: bool) -> void:
	for i: int in world.zones.cap:
		if world.zones.alive[i] == 0:
			continue
		var k: int = world.zones.kind[i]
		var zpos := Vector2(world.zones.x[i], world.zones.y[i])
		var prog: float = 1.0 - clampf(world.zones.remain[i] / maxf(world.zones.duration[i], 0.001), 0.0, 1.0)
		if k == ZonePool.ZONE_HEX_SIGIL:
			var zr: float = world.zones.radius[i]
			var rim := Color.WHITE if (prog > 0.75 and flash) else Color("c48aff")
			draw_circle(zpos, zr * prog, Color(0.60, 0.33, 0.91, 0.24))
			draw_arc(zpos, zr, 0.0, TAU, 28, rim, 2.0)
		elif k == ZonePool.ZONE_PRISM:
			var pr: float = world.zones.radius[i]
			draw_arc(zpos, pr, 0.0, TAU, 16, Color(0.76, 0.64, 1.0, 0.45), 1.5)


func _draw_spire_tethers(world: SimWorld, flash: bool) -> void:
	var b_idx: int = world.boss.enemy_index
	if b_idx < 0 or world.enemies.alive[b_idx] == 0:
		return
	var bpos := Vector2(world.enemies.x[b_idx], world.enemies.y[b_idx])
	for s: int in world.enemies.cap:
		if world.enemies.alive[s] == 0 or world.enemies.def_id[s] != "voltaic-spire":
			continue
		var spos := Vector2(world.enemies.x[s], world.enemies.y[s])
		var outer := Color(0.95, 0.78, 0.25, 0.55) if flash else Color(0.35, 0.85, 1.0, 0.55)
		var core := Color("fff8d6") if flash else Color("7ae8ff")
		draw_line(bpos, spos, outer, 6.0)
		draw_line(bpos, spos, core, 2.0)


func _draw_boss_dash_telegraph(world: SimWorld, flash: bool) -> void:
	var boss: BossState = world.boss
	var idx: int = boss.enemy_index
	if idx < 0 or world.enemies.alive[idx] == 0 or boss.active_attack < 0:
		return
	if boss.phase != &"windup" and boss.phase != &"dash":
		return
	var def_id: String = world.enemies.def_id[idx]
	if def_id == "":
		return
	var attacks: Array = DictUtil.a(DictUtil.d(world.catalog.entity(def_id), "ai"), "attacks")
	if boss.active_attack >= attacks.size():
		return
	var atk: Dictionary = attacks[boss.active_attack]
	if String(atk.get("type", "")) != "dash_slam":
		return
	var bpos := Vector2(world.enemies.x[idx], world.enemies.y[idx])
	var dir := Vector2(boss.dash_dir_x, boss.dash_dir_y)
	var dash_len: float = float(atk.get("dashSpeed", 520.0)) * float(atk.get("dashDuration", 0.42))
	var rem_frac: float = 1.0 if boss.phase == &"windup" else maxf(0.0, 1.0 - clampf(boss.elapsed / maxf(boss.duration, 0.001), 0.0, 1.0))
	var end_pos: Vector2 = bpos + dir * (dash_len * rem_frac)
	var slam_r: float = float(atk.get("slamRadius", 96.0))
	var col := Color(1.0, 0.55, 0.22, 0.45) if flash else Color(1.0, 0.85, 0.35, 0.35)
	draw_line(bpos, end_pos, col, world.enemies.radius[idx] * 1.4)
	draw_circle(end_pos, slam_r, Color(1.0, 0.38, 0.16, 0.12))
	draw_arc(end_pos, slam_r, 0.0, TAU, 28, Color("ffaa44") if flash else Color("ff5533"), 2.0)


func _draw_enemy_telegraphs(world: SimWorld, line: Color, flash: bool) -> void:
	var pop: float = float(DictUtil.d(world.catalog.loop, "noxious").get("popRadius", 48.0))
	var chain_range: float = float(DictUtil.d(world.catalog.loop, "chainLightning").get("range", 230.0))
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0:
			continue
		var epos := Vector2(world.enemies.x[i], world.enemies.y[i])
		if world.enemies.corpse_remain[i] > 0.0:
			draw_arc(epos, pop, 0.0, TAU, 24, Color("33cc66") if not flash else Color("ccffdd"), 2.0)
		if world.enemies.ai_state[i] == EnemyPool.AI_STATE_STUN:
			var star_ang: float = world.run_time * 6.0
			var head_pos := epos + Vector2(0.0, -world.enemies.radius[i] - 8.0)
			for s: int in 3:
				var sa: float = star_ang + float(s) * (TAU / 3.0)
				draw_circle(head_pos + Vector2(cos(sa) * 7.0, sin(sa) * 3.0), 2.0, Color("ffe870"))
		if world.enemies.role[i] == EnemyPool.ROLE_ELITE and world.enemies.affix[i] == "chain_lightning" and world.enemies.chain_cd[i] < 0.0:
			var c_col := Color("fff4a8") if flash else Color("5ad4ff")
			draw_arc(epos, chain_range, 0.0, TAU, 32, Color(c_col.r, c_col.g, c_col.b, 0.38), 1.5)
			draw_line(epos, Vector2(world.enemies.aim_x[i], world.enemies.aim_y[i]), c_col, 2.0)
		var def_id: String = world.enemies.def_id[i]
		if def_id == "":
			continue
		var ai: Dictionary = DictUtil.d(world.catalog.entity(def_id), "ai")
		var ai_type: String = String(ai.get("type", ""))
		if ai_type == "charger" and world.enemies.ai_state[i] == EnemyPool.AI_STATE_ACTIVE:
			var c_col2 := Color(1.0, 0.45, 0.16, 0.55)
			draw_line(epos, Vector2(world.enemies.aim_x[i], world.enemies.aim_y[i]), c_col2, 2.0)
			continue
		if world.enemies.windup[i] <= 0.0:
			continue
		if ai_type == "sniper":
			var laser: Color = Color("ff2244") if flash else Color("4488ff")
			var dx: float = world.enemies.aim_x[i] - epos.x
			var dy: float = world.enemies.aim_y[i] - epos.y
			var aim_len: float = sqrt(dx * dx + dy * dy)
			if aim_len <= 0.001:
				continue
			var far := Vector2(epos.x + (dx / aim_len) * 980.0, epos.y + (dy / aim_len) * 980.0)
			draw_line(epos, far, laser, 2.0)
		elif ai_type == "cleaver":
			var adx: float = world.enemies.aim_x[i] - epos.x
			var ady: float = world.enemies.aim_y[i] - epos.y
			var alen: float = sqrt(adx * adx + ady * ady)
			var base_ang: float = atan2(ady, adx) if alen > 0.001 else (PI if world.enemies.facing[i] == 255 else 0.0)
			var slash_r: float = float(ai.get("slashRadius", 88.0))
			var half_arc: float = deg_to_rad(float(ai.get("arcDeg", 120.0)) * 0.5)
			_draw_cleave_cone(epos, slash_r, base_ang - half_arc, base_ang + half_arc, flash)
		elif ai_type == "charger":
			var cdx: float = world.enemies.aim_x[i] - epos.x
			var cdy: float = world.enemies.aim_y[i] - epos.y
			var clen: float = sqrt(cdx * cdx + cdy * cdy)
			if clen > 0.001:
				var ux: float = cdx / clen
				var uy: float = cdy / clen
				var rush_len: float = float(ai.get("dashSpeed", 540.0)) * float(ai.get("dashDuration", 0.48)) + world.enemies.radius[i]
				var end_pt := epos + Vector2(ux * rush_len, uy * rush_len)
				var lane_w: float = world.enemies.radius[i] * 2.0
				draw_line(epos, end_pt, Color(1.0, 0.36, 0.14, 0.24), lane_w)
				var rail := Color("ffaa44") if flash else Color("ff4422")
				var perp := Vector2(-uy, ux) * (lane_w * 0.5)
				draw_line(epos + perp, end_pt + perp, rail, 1.5)
				draw_line(epos - perp, end_pt - perp, rail, 1.5)
		elif ai_type == "hexer":
			var tpos := Vector2(world.enemies.aim_x[i], world.enemies.aim_y[i])
			var hex_r: float = float(ai.get("hexRadius", 44.0))
			var hcol := Color("e4b8ff") if flash else Color("9855e8")
			draw_line(epos, tpos, Color(hcol.r, hcol.g, hcol.b, 0.45), 1.5)
			draw_arc(tpos, hex_r, 0.0, TAU, 20, hcol, 1.5)
		elif ai_type != "boss":
			draw_line(epos, Vector2(world.enemies.aim_x[i], world.enemies.aim_y[i]), line, 1.5)


func _draw_cleave_cone(origin: Vector2, rad: float, a0: float, a1: float, flash: bool) -> void:
	var pts := PackedVector2Array()
	pts.append(origin)
	var segs: int = 12
	for k: int in segs + 1:
		var ang: float = lerpf(a0, a1, float(k) / float(segs))
		pts.append(origin + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, Color(1.0, 0.38, 0.18, 0.22 if flash else 0.14))
	var edge := Color("ffd6a0") if flash else Color("ff5533")
	draw_arc(origin, rad, a0, a1, segs, edge, 2.0)
	draw_line(origin, origin + Vector2(cos(a0), sin(a0)) * rad, edge, 1.5)
	draw_line(origin, origin + Vector2(cos(a1), sin(a1)) * rad, edge, 1.5)


func _draw_arcs() -> void:
	for i: int in ARC_CAP:
		if _arc_life[i] <= 0.0:
			continue
		var t: float = clampf(_arc_life[i] / maxf(_arc_max[i], 0.001), 0.0, 1.0)
		var p0 := Vector2(_arc_x0[i], _arc_y0[i])
		var p1 := Vector2(_arc_x1[i], _arc_y1[i])
		var d: Vector2 = p1 - p0
		var dist: float = d.length()
		if dist < 1.0:
			continue
		var perp := Vector2(-d.y, d.x) / dist
		var c: Color = _arc_colors[i]
		c.a = t
		var pts := PackedVector2Array()
		pts.append(p0)
		var segs: int = 5
		for k: int in range(1, segs):
			var frac: float = float(k) / float(segs)
			var jitter: float = sin(float(i * 17 + k * 23) + _arc_life[i] * 55.0) * 10.0
			pts.append(p0.lerp(p1, frac) + perp * jitter)
		pts.append(p1)
		for k: int in pts.size() - 1:
			draw_line(pts[k], pts[k + 1], Color(c.r, c.g, c.b, t * 0.45), 5.0)
			draw_line(pts[k], pts[k + 1], Color(1.0, 0.98, 0.85, t), 1.8)


func _shake_for_fx(kind: int, tint: int) -> float:
	match kind:
		FxIds.HURT:
			return 6.0
		FxIds.CRUCIBLE_IMPACT:
			return 10.0 if tint == 0xFF4422 else 8.0
		FxIds.CENSER_IMPACT:
			return 7.0 if tint == 0xFF4422 else 5.0
		FxIds.TETHER_LATCH:
			return 5.0
		FxIds.STRIKE:
			return 6.0
		FxIds.RITUAL_TIER_1:
			return 4.0
		FxIds.RITUAL_TIER_2:
			return 5.5
		FxIds.RITUAL_RUPTURE:
			return 11.0
		FxIds.OVERHEAT_BACKFIRE:
			return 8.5
		FxIds.CRITICAL_VENT:
			return 5.5
		FxIds.CONDUIT_DISCHARGE:
			return 6.5
		FxIds.VENT_ERUPT:
			return 0.0
		FxIds.BOSS_EMERGE:
			return 7.5
		FxIds.ALCHEMY_FLASH:
			return 6.5
		FxIds.ALCHEMY_FROST:
			return 5.0
		FxIds.GEODE_CRACK:
			return 5.0
		FxIds.PARRY_REFLECT:
			return 4.5
		FxIds.DEATH:
			# Enemy kill (0xFFD35A) and noxious pop (0x66FF88) do not shake.
			if tint == 0xFFD35A or tint == 0x66FF88:
				return 0.0
			return 6.0
		_:
			return 0.0


func _consume_fx(app: Node) -> void:
	var world: SimWorld = app.world
	var reduce_vfx: bool = bool(app.settings.reduce_vfx)
	for i: int in world.fx.count:
		var kind: int = int(world.fx.kind[i])
		var tint: int = int(world.fx.tint[i])
		var fx_x: float = world.fx.x[i]
		var fx_y: float = world.fx.y[i]
		var fx_r: float = world.fx.radius[i]
		if app.settings.screenshake and not reduce_vfx:
			_shake = maxf(_shake, _shake_for_fx(kind, tint))
		match kind:
			FxIds.HURT:
				_hurt_flash = 1.0
			FxIds.DASH:
				_spawn_dash_ghost(world, true)
			FxIds.CENSER_IMPACT:
				_spawn_impact(fx_x, fx_y, 0.0, fx_r, 0.34, tint == 0xFF4422)
			FxIds.CRUCIBLE_IMPACT:
				_spawn_impact(fx_x, fx_y, 1.0, fx_r, 0.50, tint == 0xFF4422)
			FxIds.TETHER_LATCH:
				_spawn_impact(fx_x, fx_y, 2.0, fx_r, 0.38, tint == 0xFF4422)
			FxIds.RITUAL_TIER_1:
				_spawn_impact(fx_x, fx_y, 2.0, maxf(fx_r, 90.0), 0.45, false)
			FxIds.RITUAL_TIER_2:
				_spawn_impact(fx_x, fx_y, 0.0, maxf(fx_r, 110.0), 0.50, false)
			FxIds.RITUAL_RUPTURE:
				_spawn_impact(fx_x, fx_y, 1.0, maxf(fx_r, 140.0), 0.62, true)
			FxIds.OVERHEAT_BACKFIRE:
				_spawn_impact(fx_x, fx_y, 1.0, maxf(fx_r, 75.0), 0.45, true)
			FxIds.CRITICAL_VENT:
				_spawn_impact(fx_x, fx_y, 0.0, maxf(fx_r, 75.0), 0.36, false)
			FxIds.CONDUIT_DISCHARGE:
				_spawn_impact(fx_x, fx_y, 2.0, maxf(fx_r, 90.0), 0.44, false)
			FxIds.VENT_ERUPT, FxIds.BOSS_EMERGE:
				pass
			FxIds.ALCHEMY_FLASH:
				_spawn_impact(fx_x, fx_y, 1.0, maxf(fx_r, 75.0), 0.42, true)
			FxIds.ALCHEMY_FROST:
				_spawn_impact(fx_x, fx_y, 2.0, maxf(fx_r, 75.0), 0.42, false)
			FxIds.GEODE_CRACK:
				_spawn_impact(fx_x, fx_y, 0.0, maxf(fx_r, 48.0), 0.36, false)
			FxIds.PARRY_REFLECT:
				_spawn_impact(fx_x, fx_y, 2.0, maxf(fx_r, 32.0), 0.28, false)
			FxIds.STRIKE:
				if fx_r > 0.0:
					_spawn_impact(fx_x, fx_y, 0.0, fx_r, 0.32, false)
			FxIds.HIT, FxIds.MUZZLE, FxIds.DEATH, FxIds.GEM, FxIds.ESSENCE_PICKUP:
				_spawn_spark(fx_x, fx_y, kind, tint)
	var bus := get_node_or_null("/root/GameAudio")
	if bus != null:
		for i: int in world.fx.count:
			bus.play_fx(int(world.fx.kind[i]), int(world.fx.tint[i]))


func _step_dash_trail(world: SimWorld, dt: float, _biome: String, reduce_vfx: bool) -> void:
	_ghost_cd = maxf(0.0, _ghost_cd - dt)
	var px: float = world.player.x
	var py: float = world.player.y
	if not _trail_inited:
		_trail_inited = true
		_trail_px = px
		_trail_py = py
		return
	if reduce_vfx:
		_trail_px = px
		_trail_py = py
		return
	var dashing: bool = world.player.dash_remain > 0.0
	var moving: bool = absf(_last_move_x) + absf(_last_move_y) > 0.0
	var pdist: float = Vector2(px - _trail_px, py - _trail_py).length()
	var pspeed: float = pdist / dt if dt > 0.0 else 0.0
	if _ghost_cd <= 0.0 and (dashing or (moving and pspeed > TRAIL_SPEED)):
		_ghost_cd = DASH_GHOST_CD if dashing else MOVE_GHOST_CD
		_spawn_dash_ghost(world, dashing)
	_trail_px = px
	_trail_py = py


func _spawn_dash_ghost(world: SimWorld, dashing: bool) -> void:
	for i: int in GHOST_CAP:
		if _ghost_life[i] > 0.0:
			continue
		var life: float = 0.24 if dashing else 0.16
		_ghost_life[i] = life
		_ghost_max[i] = life
		_ghost_init_a[i] = 0.55 if dashing else 0.38
		_ghosts[i].texture = player_sprite.texture
		_ghosts[i].position = Vector2(world.player.x, world.player.y)
		_ghosts[i].flip_h = player_sprite.flip_h
		_ghosts[i].visible = true
		var sid: String = String(world.survivor.get("id", ""))
		var biome: String = ArenaBiome.from_stage(String(SimLoop.current_stage(world).get("id", "")))
		var tint := Color(1.0, 0.78, 0.47, 1.0) if sid == "penitent" or sid == "flagellant" else Color(1.0, 0.63, 0.38, 1.0)
		if sid == "astromancer":
			tint = Color(0.68, 0.52, 1.0, 1.0)
		elif sid != "penitent" and sid != "flagellant" and biome != "cinder":
			tint = Color(0.47, 0.8, 1.0, 1.0)
		_ghosts[i].modulate = Color(1, 1, 1, _ghost_init_a[i])
		if _ghosts[i].material is ShaderMaterial:
			var sm: ShaderMaterial = _ghosts[i].material as ShaderMaterial
			sm.set_shader_parameter("tint", Color(tint.r, tint.g, tint.b, _ghost_init_a[i]))
			sm.set_shader_parameter("u_progress", 1.0)
			sm.set_shader_parameter("u_dash", 1.0 if dashing else 0.35)
		return


func _spawn_impact(px: float, py: float, kind: float, radius: float, duration: float, is_crit: bool) -> void:
	var slot: int = -1
	var oldest: float = -1.0
	for i: int in IMPACT_CAP:
		if _impact_life[i] <= 0.0:
			slot = i
			break
		var spent: float = 1.0 - clampf(_impact_life[i] / maxf(_impact_max[i], 0.001), 0.0, 1.0)
		if spent > oldest:
			oldest = spent
			slot = i
	if slot < 0:
		return
	_impact_life[slot] = duration
	_impact_max[slot] = duration
	var spr: Sprite2D = _impact_sprites[slot]
	var rad: float = maxf(radius, 16.0)
	var size: float = rad * (2.6 if kind >= 0.5 else 2.8)
	spr.position = Vector2(px, py)
	spr.visible = true
	_fit_sprite(spr, size, size)
	var mat: ShaderMaterial = _impact_mats[slot]
	mat.set_shader_parameter("u_progress", 0.0)
	mat.set_shader_parameter("u_kind", kind)
	mat.set_shader_parameter("u_is_crit", 1.0 if is_crit else 0.0)
	mat.set_shader_parameter("u_seed", float(slot + 1) * 11.37)
	mat.set_shader_parameter("u_time", 0.0)


func _spawn_spark(px: float, py: float, kind: int, tint: int = 0) -> void:
	for i: int in SPARK_CAP:
		if _spark_life[i] > 0.0:
			continue
		_spark_life[i] = 0.14 if (kind == FxIds.GEM or kind == FxIds.ESSENCE_PICKUP) else 0.18
		if kind == FxIds.GEM or kind == FxIds.ESSENCE_PICKUP:
			_sparks[i].texture = _pickup_spark_tex if _pickup_spark_tex != null else _placeholder(Color(0.55, 0.9, 1.0), 6)
			_sparks[i].texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_sparks[i].position = Vector2(px, py)
			_sparks[i].visible = true
			if kind == FxIds.ESSENCE_PICKUP:
				_sparks[i].modulate = Color("e84a5f")
			elif tint != 0:
				_sparks[i].modulate = Color(
					float((tint >> 16) & 0xFF) / 255.0,
					float((tint >> 8) & 0xFF) / 255.0,
					float(tint & 0xFF) / 255.0,
					1.0,
				)
			else:
				_sparks[i].modulate = Color("8ce8ff")
			return
		var id: String = "hit"
		if kind == FxIds.MUZZLE:
			id = "muzzle"
		elif kind == FxIds.DEATH:
			id = "death"
		_sparks[i].texture = _fx_texture(id)
		if _sparks[i].texture == null:
			_sparks[i].texture = _placeholder(Color(1.0, 0.8, 0.3), 8)
		_sparks[i].position = Vector2(px, py)
		_sparks[i].visible = true
		_sparks[i].modulate = Color.WHITE
		return


func _spawn_arc(x0: float, y0: float, x1: float, y1: float, color: Color, dur: float) -> void:
	for i: int in ARC_CAP:
		if _arc_life[i] > 0.0:
			continue
		_arc_x0[i] = x0
		_arc_y0[i] = y0
		_arc_x1[i] = x1
		_arc_y1[i] = y1
		_arc_life[i] = dur
		_arc_max[i] = dur
		_arc_colors[i] = color
		return


func _clear_arcs() -> void:
	for i: int in ARC_CAP:
		_arc_life[i] = 0.0


func _step_arcs(dt: float) -> void:
	for i: int in ARC_CAP:
		if _arc_life[i] > 0.0:
			_arc_life[i] = maxf(0.0, _arc_life[i] - dt)


func _step_ghosts(dt: float) -> void:
	for i: int in GHOST_CAP:
		if _ghost_life[i] <= 0.0:
			_ghosts[i].visible = false
			continue
		_ghost_life[i] -= dt
		var t: float = clampf(_ghost_life[i] / maxf(_ghost_max[i], 0.001), 0.0, 1.0)
		_ghosts[i].modulate.a = t * _ghost_init_a[i]
		if _ghosts[i].material is ShaderMaterial:
			(_ghosts[i].material as ShaderMaterial).set_shader_parameter("u_progress", t)
		if _ghost_life[i] <= 0.0:
			_ghosts[i].visible = false


func _step_impacts(dt: float, run_time: float, reduce_vfx: bool) -> void:
	for i: int in IMPACT_CAP:
		if reduce_vfx or _impact_life[i] <= 0.0:
			_impact_sprites[i].visible = false
			if reduce_vfx:
				_impact_life[i] = 0.0
			continue
		_impact_life[i] -= dt
		var progress: float = 1.0 - clampf(_impact_life[i] / maxf(_impact_max[i], 0.001), 0.0, 1.0)
		var mat: ShaderMaterial = _impact_mats[i]
		mat.set_shader_parameter("u_progress", progress)
		mat.set_shader_parameter("u_time", run_time)
		if _impact_life[i] <= 0.0:
			_impact_sprites[i].visible = false


func _step_sparks(dt: float) -> void:
	for i: int in SPARK_CAP:
		if _spark_life[i] <= 0.0:
			_sparks[i].visible = false
			continue
		_spark_life[i] -= dt
		_sparks[i].modulate.a = clampf(_spark_life[i] / 0.18, 0.0, 1.0)


func _sync_music(app: Node) -> void:
	var bus := get_node_or_null("/root/GameAudio")
	if bus == null or app.world == null:
		return
	if app.overlay_mode != _last_overlay:
		_last_overlay = app.overlay_mode
		if app.overlay_mode == &"menu":
			bus.play_menu()
			return
	if app.world.boss_spawned != _last_boss:
		_last_boss = app.world.boss_spawned
		if app.world.boss_spawned:
			bus.play_boss(String(SimLoop.current_stage(app.world).get("boss", "")))
			return
	if app.world.stage_index != _last_stage:
		_last_stage = app.world.stage_index
		_last_boss = app.world.boss_spawned
		bus.play_stage(String(SimLoop.current_stage(app.world).get("id", "")))


func _stage_shader_style(stage_id: String, biome: String) -> float:
	if stage_id == "aether-vault":
		return 3.0
	if stage_id == "putrid-conservatory":
		return 2.0
	if biome == "rime":
		return 1.0
	return 0.0


func _slot_mat(
	store: Array[Dictionary],
	slot: int,
	key: String,
	shader_path: String,
	use_lut: bool,
) -> ShaderMaterial:
	var d: Dictionary = store[slot]
	if d.has(key):
		return d[key] as ShaderMaterial
	var mat: ShaderMaterial = _mat_lut(shader_path) if use_lut else _mat(shader_path)
	d[key] = mat
	return mat


func _fx_texture(id: String) -> Texture2D:
	return _cached_tex("res://assets/sprites/fx/%s.png" % id)


func _cached_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var loaded: Variant = load(path)
		if loaded is Texture2D:
			tex = loaded as Texture2D
	if tex == null:
		var abs_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path) or FileAccess.file_exists(abs_path):
			var img: Image = Image.load_from_file(abs_path)
			if img == null or img.is_empty():
				img = Image.load_from_file(path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex


func _load_pickup_tex(rel_path: String, fallback_size: int, fallback_color: Color) -> Texture2D:
	var tex: Texture2D = _cached_tex("res://assets/sprites/generated/%s" % rel_path)
	if tex != null:
		return tex
	return UiAtlas.generated_tex(rel_path, fallback_size, fallback_color)


func _apply_pillar_origin(spr: Sprite2D, radius: float, frame_h: float) -> void:
	var th: float = maxf(1.0, frame_h)
	if th <= radius * 2.0:
		spr.offset = Vector2.ZERO
		return
	var origin_y: float = (th - radius) / th
	spr.offset = Vector2(0.0, (0.5 - origin_y) * th)


func _fit_sprite(spr: Sprite2D, world_w: float, world_h: float) -> void:
	if spr.texture == null:
		return
	var tw: float = maxf(1.0, float(spr.texture.get_width()))
	var th: float = maxf(1.0, float(spr.texture.get_height()))
	spr.scale = Vector2(world_w / tw, world_h / th)


func _ensure_debug_actions() -> void:
	if not OS.is_debug_build():
		return
	if not InputMap.has_action("debug_spawn_gems"):
		InputMap.add_action("debug_spawn_gems")
	if not InputMap.has_action("debug_force_levelup"):
		InputMap.add_action("debug_force_levelup")


func _debug_editor_cheats(app: Node) -> void:
	if not OS.is_debug_build() or app.world == null:
		return
	if Input.is_action_just_pressed("debug_spawn_gems"):
		app.world.player.iframe_remain = 30.0
		var px: float = app.world.player.x
		var py: float = app.world.player.y
		for n: int in 8:
			var ang: float = TAU * float(n) / 8.0
			app.world.gems.spawn_gem(px + cos(ang) * 160.0, py + sin(ang) * 160.0, 8.0)
	if Input.is_action_just_pressed("debug_force_levelup"):
		app.world.player.iframe_remain = 30.0
		if app.overlay_mode == &"pause":
			app.resume_run()
		SimLevel.grant_xp(app.world, app.world.xp_need)


func _mat(path: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	return mat


func _mat_lut(path: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	if _lut_tex == null:
		_lut_tex = UiAtlas.lut_tex()
	if _lut_tex != null:
		mat.set_shader_parameter("u_lut_tex", _lut_tex)
		mat.set_shader_parameter("u_use_lut", 1.0)
	return mat


func _placeholder(color: Color, size: int) -> Texture2D:
	var img := Image.create(maxi(1, size), maxi(1, size), false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _radial(color: Color, size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: Vector2 = Vector2(float(size) * 0.5, float(size) * 0.5)
	for y: int in size:
		for x: int in size:
			var d: float = Vector2(float(x), float(y)).distance_to(c) / c.x
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * a * a))
	return ImageTexture.create_from_image(img)


func _make_pickup_spark_texture() -> Texture2D:
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bright := Color(1.0, 1.0, 1.0, 1.0)
	var mid := Color(1.0, 1.0, 1.0, 0.72)
	for o: int in range(-2, 3):
		img.set_pixel(3 + o, 3, bright if abs(o) <= 1 else mid)
		img.set_pixel(3, 3 + o, bright if abs(o) <= 1 else mid)
	img.set_pixel(2, 2, mid)
	img.set_pixel(4, 2, mid)
	img.set_pixel(2, 4, mid)
	img.set_pixel(4, 4, mid)
	return ImageTexture.create_from_image(img)


func _make_prism_texture() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = 16.0
	var cy: float = 16.0
	for y: int in 32:
		for x: int in 32:
			var dx: float = absf(float(x) + 0.5 - cx)
			var dy: float = absf(float(y) + 0.5 - cy)
			var d: float = dx / 10.0 + dy / 14.0
			if d <= 1.05 and d > 0.85:
				img.set_pixel(x, y, Color("1a1026"))
			elif d <= 0.85:
				var c: Color = Color("f0e8ff") if (float(x) < cx and float(y) < cy and d < 0.55) else (Color("a884f3") if float(x) < cx else Color("5ad4ff"))
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _make_crosshair(survivor_id: String) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if survivor_id == "penitent":
		var c := Color("e5c878")
		for a: int in 16:
			var ang: float = float(a) / 16.0 * TAU
			var x: int = int(round(7.5 + cos(ang) * 6.0))
			var y: int = int(round(7.5 + sin(ang) * 6.0))
			img.set_pixel(x, y, c)
	elif survivor_id == "flagellant":
		var c := Color("ffb366")
		for i: int in 5:
			img.set_pixel(2 + i, 2 + i, c)
			img.set_pixel(13 - i, 2 + i, c)
			img.set_pixel(2 + i, 13 - i, c)
			img.set_pixel(13 - i, 13 - i, c)
	elif survivor_id == "astromancer":
		var c := Color("d6b8ff")
		for i: int in 4:
			img.set_pixel(7, i, c)
			img.set_pixel(8, i, c)
			img.set_pixel(7, 12 + i, c)
			img.set_pixel(8, 12 + i, c)
			img.set_pixel(i, 7, c)
			img.set_pixel(i, 8, c)
			img.set_pixel(12 + i, 7, c)
			img.set_pixel(12 + i, 8, c)
		img.set_pixel(7, 7, Color.WHITE)
		img.set_pixel(8, 8, Color.WHITE)
	else:
		var c := Color("c4e4ff")
		for i: int in 4:
			img.set_pixel(7, i, c)
			img.set_pixel(8, i, c)
			img.set_pixel(7, 12 + i, c)
			img.set_pixel(8, 12 + i, c)
			img.set_pixel(i, 7, c)
			img.set_pixel(i, 8, c)
			img.set_pixel(12 + i, 7, c)
			img.set_pixel(12 + i, 8, c)
	return ImageTexture.create_from_image(img)
