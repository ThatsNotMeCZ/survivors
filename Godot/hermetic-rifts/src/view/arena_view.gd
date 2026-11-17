extends Node2D

const WAYPOINT_DIST: float = 80.0
const WAYPOINT_PAD: float = 52.0
const GHOST_CAP: int = 10
const SPARK_CAP: int = 24
const IMPACT_CAP: int = 12
const DASH_GHOST_CD: float = 0.04
const MOVE_GHOST_CD: float = 0.055
const TRAIL_SPEED: float = 18.0

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
var _obstacle_sprites: Array[Sprite2D] = []
var _volatile_glows: Array[Sprite2D] = []
var _zone_sprites: Array[Sprite2D] = []
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
var _mat_charge: ShaderMaterial
var _mat_laser: ShaderMaterial
var _laser: Sprite2D
var _ambient: Sprite2D
var _floor: Sprite2D
var _circle: Sprite2D
var _charge: Sprite2D
var _portal: Sprite2D
var _player_glow: Sprite2D
var _decoy: Sprite2D
var _waypoint: Sprite2D
var _gems: MultiMeshInstance2D
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
	_floor = Sprite2D.new()
	_floor.centered = false
	_floor.z_index = -30
	_floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_floor)
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
	_charge = Sprite2D.new()
	_charge.z_index = -6
	_charge.texture = _placeholder(Color(1, 1, 1, 1), 64)
	_mat_charge = _mat("res://assets/shaders/circle_charge.gdshader")
	_charge.material = _mat_charge
	_charge.visible = false
	world_root.add_child(_charge)
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
	_waypoint = Sprite2D.new()
	_waypoint.z_index = 20
	_waypoint.texture = UiAtlas.frame("nav-arrow")
	_waypoint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_waypoint.visible = false
	world_root.add_child(_waypoint)
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
	crosshair.texture = _make_crosshair(false)
	_ghost_life.resize(GHOST_CAP)
	_ghost_max.resize(GHOST_CAP)
	_ghost_init_a.resize(GHOST_CAP)
	_spark_life.resize(SPARK_CAP)
	_impact_life.resize(IMPACT_CAP)
	_impact_max.resize(IMPACT_CAP)
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
	_gems = MultiMeshInstance2D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	var gem_tex: Texture2D = _fx_texture("gem")
	if gem_tex == null:
		gem_tex = _placeholder(Color(0.53, 0.78, 0.83), 16)
	var gw: float = maxf(16.0, float(gem_tex.get_width()))
	var gh: float = maxf(16.0, float(gem_tex.get_height()))
	var quad := QuadMesh.new()
	quad.size = Vector2(gw, -gh)
	mm.mesh = quad
	mm.instance_count = 64
	_gems.multimesh = mm
	_gems.z_index = 2
	_gems.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_gems.texture = gem_tex
	world_root.add_child(_gems)


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
	if Input.is_action_just_pressed("confirm") and app.overlay_mode == &"hidden" and app.world.phase == &"play" and SimLoop.can_seal(app.world):
		SimLoop.complete_working(app.world)
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
	if _floor != null:
		_floor.visible = false
	if world_root != null:
		world_root.visible = false
	queue_redraw()


func _sync(world: SimWorld, dt: float, reduce_vfx: bool, screenshake: bool) -> void:
	if world_root != null:
		world_root.visible = true
	_ambient.visible = not reduce_vfx
	if _floor != null:
		_floor.visible = true
	var stage: Dictionary = SimLoop.current_stage(world)
	var stage_id: String = String(stage.get("id", ""))
	var biome: String = ArenaBiome.from_stage(stage_id)
	var theme: String = ArenaBiome.theme_from_stage(stage_id)
	if world.stage_gen != _last_stage_gen:
		_last_stage_gen = world.stage_gen
		_apply_stage_art(world, theme)
		crosshair.texture = _make_crosshair(String(world.survivor.get("id", "")) == "penitent")
		_trail_inited = false
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
	_sync_circle(world, biome, dt, reduce_vfx)
	_sync_portal(world, theme)
	_sync_obstacles(world, biome, theme, reduce_vfx)
	_sync_fodder(world)
	_sync_elites(world, reduce_vfx)
	_sync_projectiles(world, biome, reduce_vfx)
	_sync_zones(world, reduce_vfx)
	_sync_hazards(world, reduce_vfx)
	_sync_laser(world, reduce_vfx)
	_sync_gems(world)
	_sync_lores(world)
	_sync_waypoint(world)
	_step_ghosts(dt)
	_step_sparks(dt)
	_step_impacts(dt, world.run_time, reduce_vfx)
	queue_redraw()


func _apply_stage_art(world: SimWorld, theme: String) -> void:
	var width: int = int(world.catalog.world.get("width", 2560))
	var height: int = int(world.catalog.world.get("height", 2560))
	_floor.texture = FloorStamp.texture_for(theme, width, height)
	_floor.position = Vector2.ZERO
	_floor.scale = Vector2.ONE


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


func _sync_circle(world: SimWorld, biome: String, dt: float, reduce_vfx: bool) -> void:
	var tel_hidden: bool = world.teleporter_state == &"hidden"
	var charging: bool = world.teleporter_state == &"charging"
	var in_zone: bool = (
		charging
		and Vector2(world.player.x, world.player.y).distance_to(Vector2(world.teleporter_x, world.teleporter_y))
		<= world.teleporter_radius
	)
	var theme: String = ArenaBiome.theme_from_stage(String(SimLoop.current_stage(world).get("id", "")))
	var circle_id: String = ArenaBiome.env_id(theme, "circle")
	if not tel_hidden and UiAtlas.env_has(circle_id):
		_circle.texture = UiAtlas.env_frame(circle_id)
		_circle.visible = true
		_circle.position = Vector2(world.teleporter_x, world.teleporter_y)
		var span: float = world.teleporter_radius * 2.0
		_fit_sprite(_circle, span, span)
	else:
		_circle.visible = false
	if reduce_vfx or not charging:
		_charge_active = maxf(0.0, _charge_active - dt * 4.0)
	else:
		var target: float = 1.0 if in_zone else 0.0
		_charge_active += (target - _charge_active) * minf(1.0, dt * 5.0)
	_charge.visible = _charge_active > 0.01
	if _charge.visible:
		_charge.position = Vector2(world.teleporter_x, world.teleporter_y)
		var diam: float = world.teleporter_radius * 2.15
		_charge.scale = Vector2(diam / 64.0, diam / 64.0)
		if _mat_charge != null:
			var charge: float = clampf(world.teleporter_charge / maxf(world.teleporter_hold, 0.001), 0.0, 1.0)
			var r: float = maxf(1.0, world.teleporter_radius)
			var ox: float = clampf((world.player.x - world.teleporter_x) / r, -1.0, 1.0)
			var oy: float = clampf((world.player.y - world.teleporter_y) / r, -1.0, 1.0)
			_mat_charge.set_shader_parameter("u_time", world.run_time)
			_mat_charge.set_shader_parameter("u_charge", charge)
			_mat_charge.set_shader_parameter("u_active", _charge_active)
			_mat_charge.set_shader_parameter("u_player_offset", Vector2(ox, oy))
			_mat_charge.set_shader_parameter("u_style", 0.0 if biome == "cinder" else 1.0)


func _sync_portal(world: SimWorld, theme: String) -> void:
	var ouroboros: bool = SimLoop.can_seal(world)
	var portal_id: String = ArenaBiome.env_id(theme, "portal")
	if world.portal_open and not ouroboros and UiAtlas.env_has(portal_id):
		_portal.texture = UiAtlas.env_frame(portal_id)
		_portal.visible = true
		_portal.position = Vector2(world.portal_x, world.portal_y)
		var radius: float = float(world.catalog.loop.get("portalRadius", 70.0))
		var hold: float = float(world.catalog.loop.get("portalHold", 1.4))
		var pct: float = clampf(world.portal_hold / maxf(hold, 0.001), 0.0, 1.0)
		var pulse: float = 0.75 + 0.15 * sin(world.run_time * 7.0) + 0.1 * pct
		_fit_sprite(_portal, radius * 2.0, radius * 2.0)
		_portal.modulate = Color(1, 1, 1, pulse)
	else:
		_portal.visible = false


func _sync_obstacles(world: SimWorld, biome: String, theme: String, reduce_vfx: bool) -> void:
	while _obstacle_sprites.size() < world.obstacles.cap:
		var spr := Sprite2D.new()
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.z_index = 5
		world_root.add_child(spr)
		_obstacle_sprites.append(spr)
		var glow := Sprite2D.new()
		glow.texture = _radial(Color(1.0, 0.55, 0.15, 0.35), 32)
		glow.z_index = 1
		glow.visible = false
		world_root.add_child(glow)
		_volatile_glows.append(glow)
	var hazard_frame: int = 0 if int(floor(world.run_time / 0.45)) % 2 == 0 else 1
	for i: int in world.obstacles.cap:
		var spr: Sprite2D = _obstacle_sprites[i]
		var glow: Sprite2D = _volatile_glows[i]
		if world.obstacles.alive[i] == 0:
			spr.visible = false
			glow.visible = false
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		var suffix: String = "pillar"
		if obs.type == &"hazard":
			suffix = "hazard-%d" % hazard_frame
		elif obs.type == &"volatile":
			suffix = "volatile"
		var timed: bool = obs.type == &"hazard" and obs.timer > 0.0
		var use_theme: String = "rime" if timed else theme
		var env_id: String = ArenaBiome.env_id(use_theme, suffix)
		if obs.type == &"hazard" and not UiAtlas.env_has(env_id):
			env_id = ArenaBiome.env_id(use_theme, "hazard-0")
		var has_tex: bool = UiAtlas.env_has(env_id)
		if str(spr.get_meta("env_id", "")) != env_id:
			spr.set_meta("env_id", env_id)
			spr.remove_meta("hazard_quad")
			if has_tex:
				if obs.type == &"hazard":
					var img: ImageTexture = UiAtlas.env_image(env_id)
					if img != null:
						spr.texture = img
					else:
						spr.texture = UiAtlas.env_frame(env_id)
				else:
					spr.texture = UiAtlas.env_frame(env_id)
			else:
				var fallback_c := Color(0.35, 0.28, 0.22)
				if obs.type == &"volatile":
					fallback_c = Color(0.7, 0.35, 0.15)
				elif obs.type == &"hazard":
					fallback_c = Color(1.0, 1.0, 1.0, 1.0)
				var fallback_px: int = 64 if obs.type == &"hazard" else int(obs.radius * 2.0)
				spr.texture = _placeholder(fallback_c, fallback_px)
		spr.visible = true
		spr.position = Vector2(obs.x, obs.y)
		spr.centered = true
		if spr.texture != null:
			var env_size: Vector2 = UiAtlas.env_rect(env_id).size
			var th: float = maxf(1.0, env_size.y if env_size.y > 0.0 else float(spr.texture.get_height()))
			if obs.type == &"hazard":
				var diam: float = obs.radius * 2.0
				var tw: float = maxf(1.0, float(spr.texture.get_width()))
				var tex_h: float = maxf(1.0, float(spr.texture.get_height()))
				spr.scale = Vector2(diam / tw, diam / tex_h)
				spr.offset = Vector2.ZERO
				spr.z_index = 1
			elif obs.type == &"pillar":
				spr.scale = Vector2.ONE
				spr.z_index = 5
				_apply_pillar_origin(spr, obs.radius, th)
			else:
				spr.scale = Vector2.ONE
				spr.offset = Vector2.ZERO
				spr.z_index = 5
		if obs.type == &"pillar":
			var near: bool = Vector2(world.player.x, world.player.y).distance_to(Vector2(obs.x, obs.y)) < 170.0
			spr.modulate = Color("ffe8d0") if near else Color.WHITE
		if obs.type == &"hazard":
			if spr.material == null:
				spr.material = _mat("res://assets/shaders/env_hazard.gdshader")
			if spr.material is ShaderMaterial:
				var hm: ShaderMaterial = spr.material as ShaderMaterial
				var player_in: float = 1.0 if Vector2(world.player.x, world.player.y).distance_to(Vector2(obs.x, obs.y)) <= obs.radius + world.player.radius else 0.0
				var style: float = 2.0 if theme == "glacial" else (1.0 if biome == "rime" else 0.0)
				if timed:
					style = 1.0
				var fade: float = clampf(obs.timer, 0.0, 1.0) if timed else 1.0
				hm.set_shader_parameter("u_time", world.run_time)
				hm.set_shader_parameter("u_style", style)
				hm.set_shader_parameter("u_player_in", player_in)
				hm.set_shader_parameter("u_seed", float(i + 1) * 13.37)
				hm.set_shader_parameter("u_fade", fade)
				hm.set_shader_parameter("u_has_tex", 1.0 if has_tex else 0.0)
				hm.set_shader_parameter("u_reduce", 1.0 if reduce_vfx else 0.0)
		else:
			spr.material = null
		if obs.type == &"volatile":
			glow.visible = not reduce_vfx
			glow.position = Vector2(obs.x, obs.y)
			var primed: bool = obs.state == &"primed"
			glow.modulate = Color(1.0, 0.85, 0.3, 0.55 if primed else 0.22)
			glow.scale = Vector2(2.4, 2.4) if primed else Vector2(1.6, 1.6)
			if primed and int(floor(world.run_time * 16.0)) % 2 == 0:
				spr.modulate = Color(1.4, 1.1, 0.6)
			else:
				spr.modulate = Color.WHITE
		elif obs.type != &"pillar":
			glow.visible = false
			spr.modulate = Color.WHITE
		else:
			glow.visible = false


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


func _fodder_layer(id: String) -> MultiMeshInstance2D:
	if _fodder_layers.has(id):
		return _fodder_layers[id]
	var mm := MultiMeshInstance2D.new()
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_2D
	var tex: Texture2D = UiAtlas.entity_frame(id, "idle", 0.0)
	var fw: float = 24.0
	var fh: float = 24.0
	if tex != null:
		fw = float(tex.get_width())
		fh = float(tex.get_height())
	var quad := QuadMesh.new()
	quad.size = Vector2(fw, -fh)
	mesh.mesh = quad
	mesh.instance_count = 24
	mm.multimesh = mesh
	mm.z_index = 2
	mm.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mm.texture = tex if tex != null else _placeholder(Color(0.85, 0.4, 0.25), 24)
	world_root.add_child(mm)
	_fodder_layers[id] = mm
	return mm


func _sync_elites(world: SimWorld, reduce_vfx: bool) -> void:
	var needed: int = 0
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] != 0 and world.enemies.role[i] != EnemyPool.ROLE_FODDER:
			needed += 1
	while _elite_sprites.size() < needed:
		var spr := Sprite2D.new()
		spr.texture = _placeholder(Color(0.4, 0.7, 1.0), 40)
		spr.material = _mat("res://assets/shaders/elite_affix.gdshader")
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.z_index = 5
		world_root.add_child(spr)
		_elite_sprites.append(spr)
	var n: int = 0
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0 or world.enemies.role[i] == EnemyPool.ROLE_FODDER:
			continue
		var spr: Sprite2D = _elite_sprites[n]
		spr.visible = true
		spr.position = Vector2(world.enemies.x[i], world.enemies.y[i])
		spr.flip_h = world.enemies.facing[i] == 255
		if _enemy_last_x.size() < world.enemies.cap:
			_enemy_last_x.resize(world.enemies.cap)
			_enemy_last_y.resize(world.enemies.cap)
			_enemy_anim.resize(world.enemies.cap)
			_enemy_anim_t0.resize(world.enemies.cap)
			_enemy_windup.resize(world.enemies.cap)
		var moved: float = absf(world.enemies.x[i] - _enemy_last_x[i]) + absf(world.enemies.y[i] - _enemy_last_y[i])
		_enemy_last_x[i] = world.enemies.x[i]
		_enemy_last_y[i] = world.enemies.y[i]
		var attacking: bool = world.enemies.attack_remain[i] > 0.0 or world.enemies.windup[i] > 0.0
		var anim: String = world.enemies.anim_name[i]
		if not attacking or anim == "":
			anim = "walk" if moved > 0.35 else "idle"
		var clip: String = "%s:%s" % [world.enemies.def_id[i], anim]
		var wu: float = world.enemies.windup[i]
		if clip != _enemy_anim[i] or wu > _enemy_windup[i] + 0.001:
			_enemy_anim[i] = clip
			_enemy_anim_t0[i] = world.run_time
		_enemy_windup[i] = wu
		var anim_t: float = world.run_time if anim == "idle" or anim == "walk" else world.run_time - _enemy_anim_t0[i]
		var tex: Texture2D = UiAtlas.entity_frame(world.enemies.def_id[i], anim, anim_t)
		if tex != null:
			spr.texture = tex
		var affix: float = 0.0
		var shield_on: float = 0.0
		var corpse: float = 1.0 if world.enemies.corpse_remain[i] > 0.0 else 0.0
		if world.enemies.shielder[i] != 0:
			affix = 1.0
			shield_on = 1.0 if world.enemies.shield_hp[i] > 0.0 else 0.0
		elif world.enemies.noxious[i] != 0:
			affix = 2.0
		if reduce_vfx:
			affix = 0.0
		if spr.material is ShaderMaterial:
			var sm: ShaderMaterial = spr.material as ShaderMaterial
			sm.set_shader_parameter("affix", affix)
			sm.set_shader_parameter("shield_active", shield_on)
			sm.set_shader_parameter("corpse", corpse)
			sm.set_shader_parameter("u_time", world.run_time)
		n += 1
	for i: int in range(n, _elite_sprites.size()):
		_elite_sprites[i].visible = false


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
		var flags: int = int(world.projectiles.flags[i])
		var team: int = int(world.projectiles.team[i])
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
			elif flags & ProjectilePool.FLAG_PIERCE != 0:
				spr.texture = _fx_texture("skill-aether-pierce")
			else:
				spr.texture = _fx_texture("bolt")
		if spr.texture == null:
			spr.texture = _placeholder(Color(1.0, 0.85, 0.4), 8)
		n += 1
	for i: int in range(n, _proj_sprites.size()):
		_proj_sprites[i].visible = false


func _sync_zones(world: SimWorld, reduce_vfx: bool) -> void:
	while _zone_sprites.size() < world.zones.cap:
		var spr := Sprite2D.new()
		spr.z_index = 3
		spr.visible = false
		world_root.add_child(spr)
		_zone_sprites.append(spr)
	for i: int in world.zones.cap:
		var spr: Sprite2D = _zone_sprites[i]
		if world.zones.alive[i] == 0 or reduce_vfx:
			spr.visible = false
			continue
		spr.visible = true
		var progress: float = 1.0 - clampf(world.zones.remain[i] / maxf(world.zones.duration[i], 0.001), 0.0, 1.0)
		if world.zones.kind[i] == ZonePool.ZONE_LINE:
			spr.material = _mat_brim
			spr.texture = _fx_texture("skill-brimstone-line")
			if spr.texture == null:
				spr.texture = _placeholder(Color(0.9, 0.3, 0.1, 0.8), 16)
			var dx: float = world.zones.dir_x[i]
			var dy: float = world.zones.dir_y[i]
			var length: float = world.zones.length[i]
			var width: float = maxf(world.zones.width[i], 12.0)
			spr.position = Vector2(world.zones.x[i] + dx * length * 0.5, world.zones.y[i] + dy * length * 0.5)
			spr.rotation = atan2(dy, dx)
			var tw: float = float(spr.texture.get_width())
			var th: float = float(spr.texture.get_height())
			spr.scale = Vector2(length / maxf(tw, 1.0), width / maxf(th, 1.0))
			if _mat_brim != null:
				_mat_brim.set_shader_parameter("u_time", world.run_time)
				_mat_brim.set_shader_parameter("u_progress", progress)
				_mat_brim.set_shader_parameter("u_seed", float(i) * 0.37)
		else:
			spr.material = _mat_impact
			spr.texture = _fx_texture("skill-crucible-cull")
			if spr.texture == null:
				spr.texture = _placeholder(Color(1, 1, 1, 1), 64)
			spr.position = Vector2(world.zones.x[i], world.zones.y[i])
			spr.rotation = 0.0
			var rad: float = maxf(world.zones.radius[i] * 2.0, 24.0)
			var tw2: float = float(spr.texture.get_width())
			spr.scale = Vector2(rad / maxf(tw2, 1.0), rad / maxf(tw2, 1.0))
			if _mat_impact != null:
				_mat_impact.set_shader_parameter("u_time", world.run_time)
				_mat_impact.set_shader_parameter("u_progress", progress)
				_mat_impact.set_shader_parameter("u_kind", 1.0)


func _sync_hazards(world: SimWorld, reduce_vfx: bool) -> void:
	var needed: int = 0
	for i: int in world.boss_hazards.cap:
		if world.boss_hazards.alive[i] != 0:
			needed += 1
	while _hazard_sprites.size() < needed:
		var spr := Sprite2D.new()
		spr.texture = _placeholder(Color(1, 1, 1, 1), 64)
		spr.material = _mat("res://assets/shaders/hazard_pool.gdshader")
		spr.z_index = 1
		world_root.add_child(spr)
		_hazard_sprites.append(spr)
	var n: int = 0
	for i: int in world.boss_hazards.cap:
		if world.boss_hazards.alive[i] == 0:
			continue
		var spr: Sprite2D = _hazard_sprites[n]
		spr.visible = not reduce_vfx
		spr.position = Vector2(world.boss_hazards.x[i], world.boss_hazards.y[i])
		var span: float = maxf(world.boss_hazards.radius[i] * 2.0 / 64.0, 0.2)
		spr.scale = Vector2(span, span)
		if spr.material is ShaderMaterial:
			var hm: ShaderMaterial = spr.material as ShaderMaterial
			var dur: float = maxf(world.boss_hazards.duration[i], 0.001)
			var progress: float = clampf(world.boss_hazards.elapsed[i] / dur, 0.0, 1.0)
			hm.set_shader_parameter("u_time", world.run_time)
			hm.set_shader_parameter("u_kind", float(world.boss_hazards.kind[i]))
			hm.set_shader_parameter("u_style", float(world.boss_hazards.style[i]))
			hm.set_shader_parameter("u_state", float(world.boss_hazards.state[i]))
			hm.set_shader_parameter("u_progress", progress)
			hm.set_shader_parameter("u_angle", world.boss_hazards.angle[i])
			hm.set_shader_parameter("u_dir", Vector2(world.boss_hazards.dir_x[i], world.boss_hazards.dir_y[i]))
			hm.set_shader_parameter("u_radius", world.boss_hazards.radius[i])
			if world.boss_hazards.kind[i] == BossHazardPool.HAZ_PULSE:
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
	var n: int = 0
	for i: int in world.gems.cap:
		if world.gems.alive[i] != 0:
			n += 1
	_gems.multimesh.instance_count = n
	var k: int = 0
	for i: int in world.gems.cap:
		if world.gems.alive[i] == 0:
			continue
		_gems.multimesh.set_instance_transform_2d(k, Transform2D(0.0, Vector2(world.gems.x[i], world.gems.y[i])))
		k += 1


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


func _sync_waypoint(world: SimWorld) -> void:
	var objective: Dictionary = SimLoop.current_objective(world)
	if not bool(objective.get("has_target", false)):
		_waypoint.visible = false
		return
	var tx: float = float(objective.get("target_x", 0.0))
	var ty: float = float(objective.get("target_y", 0.0))
	var vis: Rect2 = _view_rect()
	var on_screen: bool = (
		tx > vis.position.x + WAYPOINT_PAD
		and tx < vis.position.x + vis.size.x - WAYPOINT_PAD
		and ty > vis.position.y + WAYPOINT_PAD
		and ty < vis.position.y + vis.size.y - WAYPOINT_PAD
	)
	if on_screen:
		_waypoint.visible = false
		return
	var dx: float = tx - world.player.x
	var dy: float = ty - world.player.y
	var dist: float = sqrt(dx * dx + dy * dy)
	if dist < 1.0:
		_waypoint.visible = false
		return
	_waypoint.visible = true
	_waypoint.position = Vector2(world.player.x + (dx / dist) * WAYPOINT_DIST, world.player.y + (dy / dist) * WAYPOINT_DIST)
	_waypoint.rotation = atan2(dy, dx) - PI * 0.5


func _clamp_arena_camera(world: SimWorld, focus: Vector2) -> Vector2:
	var bounds: Dictionary = world.catalog.world
	var arena := Rect2(0.0, 0.0, float(bounds.get("width", 2560.0)), float(bounds.get("height", 2560.0)))
	var zx: float = camera.zoom.x if absf(camera.zoom.x) > 0.0001 else 1.0
	var zy: float = camera.zoom.y if absf(camera.zoom.y) > 0.0001 else 1.0
	var view: Vector2 = get_viewport_rect().size
	var half := Vector2(view.x / zx, view.y / zy) * 0.5
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
		draw_circle(Vector2(world.teleporter_x, world.teleporter_y), world.teleporter_radius, Color(0.77, 0.64, 0.35, 0.18))
	if world.portal_open and not _portal.visible:
		var color := Color(0.9, 0.75, 0.2, 0.45) if SimLoop.can_seal(world) or biome == "cinder" else Color(0.87, 0.96, 1.0, 0.4)
		draw_circle(Vector2(world.portal_x, world.portal_y), float(world.catalog.loop.get("portalRadius", 70.0)), color)
	_draw_telegraphs(world, biome)


func _draw_telegraphs(world: SimWorld, biome: String) -> void:
	var flash: bool = int(floor(world.run_time * 12.0)) % 2 == 0
	var line: Color = Color.WHITE if flash else (Color("ff7a3a") if biome == "cinder" else Color("55ffff"))
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0:
			continue
		if world.enemies.corpse_remain[i] > 0.0:
			var pop: float = float(DictUtil.d(world.catalog.loop, "noxious").get("popRadius", 48.0))
			draw_arc(Vector2(world.enemies.x[i], world.enemies.y[i]), pop, 0.0, TAU, 24, Color("33cc66") if not flash else Color("ccffdd"), 2.0)
		if world.enemies.windup[i] <= 0.0:
			continue
		var def: Dictionary = world.catalog.entity(world.enemies.def_id[i])
		var ai: Dictionary = DictUtil.d(def, "ai")
		if String(ai.get("type", "")) == "sniper":
			var laser: Color = Color("ff2244") if flash else Color("4488ff")
			var dx: float = world.enemies.aim_x[i] - world.enemies.x[i]
			var dy: float = world.enemies.aim_y[i] - world.enemies.y[i]
			var aim_len: float = sqrt(dx * dx + dy * dy)
			if aim_len <= 0.001:
				continue
			var far := Vector2(world.enemies.x[i] + (dx / aim_len) * 980.0, world.enemies.y[i] + (dy / aim_len) * 980.0)
			draw_line(Vector2(world.enemies.x[i], world.enemies.y[i]), far, laser, 2.0)
		elif String(ai.get("type", "")) != "boss":
			draw_line(
				Vector2(world.enemies.x[i], world.enemies.y[i]),
				Vector2(world.enemies.aim_x[i], world.enemies.aim_y[i]),
				line,
				1.5,
			)


func _shake_for_fx(kind: int, tint: int) -> float:
	if kind == FxIds.HURT:
		return 6.0
	if kind == FxIds.CRUCIBLE_IMPACT:
		return 10.0 if tint == 0xFF4422 else 8.0
	if kind == FxIds.CENSER_IMPACT:
		return 7.0 if tint == 0xFF4422 else 5.0
	if kind == FxIds.TETHER_LATCH:
		return 5.0
	if kind == FxIds.STRIKE:
		return 6.0
	if kind != FxIds.DEATH:
		return 0.0
	# Enemy kill (0xFFD35A) and noxious pop (0x66FF88) do not shake.
	# Volatile break and boss enrage still do.
	if tint == 0xFFD35A or tint == 0x66FF88:
		return 0.0
	return 6.0


func _consume_fx(app: Node) -> void:
	var world: SimWorld = app.world
	var reduce_vfx: bool = bool(app.settings.reduce_vfx)
	for i: int in world.fx.count:
		var kind: int = int(world.fx.kind[i])
		var tint: int = int(world.fx.tint[i])
		if app.settings.screenshake and not reduce_vfx:
			_shake = maxf(_shake, _shake_for_fx(kind, tint))
		if kind == FxIds.HURT:
			_hurt_flash = 1.0
		elif kind == FxIds.DASH:
			_spawn_dash_ghost(world, true)
		elif kind == FxIds.CENSER_IMPACT:
			_spawn_impact(world.fx.x[i], world.fx.y[i], 0.0, world.fx.radius[i], 0.34, tint == 0xFF4422)
		elif kind == FxIds.CRUCIBLE_IMPACT:
			_spawn_impact(world.fx.x[i], world.fx.y[i], 1.0, world.fx.radius[i], 0.50, tint == 0xFF4422)
		elif kind == FxIds.TETHER_LATCH:
			_spawn_impact(world.fx.x[i], world.fx.y[i], 2.0, world.fx.radius[i], 0.38, tint == 0xFF4422)
		elif kind == FxIds.HIT or kind == FxIds.MUZZLE or kind == FxIds.DEATH:
			_spawn_spark(world.fx.x[i], world.fx.y[i], kind)
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
		var tint := Color(1.0, 0.78, 0.47, 1.0) if sid == "penitent" else Color(1.0, 0.63, 0.38, 1.0)
		if sid != "penitent" and biome != "cinder":
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


func _spawn_spark(px: float, py: float, kind: int) -> void:
	for i: int in SPARK_CAP:
		if _spark_life[i] > 0.0:
			continue
		_spark_life[i] = 0.18
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


func _fx_texture(id: String) -> Texture2D:
	return _cached_tex("res://assets/sprites/fx/%s.png" % id)


func _cached_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	if not ResourceLoader.exists(path):
		_tex_cache[path] = null
		return null
	var tex: Texture2D = load(path)
	_tex_cache[path] = tex
	return tex


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


func _make_crosshair(penitent: bool) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color("c4e4ff") if not penitent else Color("e5c878")
	if penitent:
		for a: int in 16:
			var ang: float = float(a) / 16.0 * TAU
			var x: int = int(round(7.5 + cos(ang) * 6.0))
			var y: int = int(round(7.5 + sin(ang) * 6.0))
			img.set_pixel(x, y, c)
	else:
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
