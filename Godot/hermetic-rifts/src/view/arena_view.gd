extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var world_root: Node2D = $WorldRoot
@onready var player_sprite: Sprite2D = $WorldRoot/Player
@onready var crosshair: Sprite2D = $WorldRoot/Crosshair

var _fodder_layers: Dictionary = {}
var _elite_sprites: Array[Sprite2D] = []
var _proj_sprites: Array[Sprite2D] = []
var _hazard_sprites: Array[Sprite2D] = []
var _shake: float = 0.0
var _hurt_flash: float = 0.0
var _hurt_mat: ShaderMaterial
var _mat_tether: ShaderMaterial
var _mat_impact: ShaderMaterial
var _mat_brim: ShaderMaterial
var _ambient: Sprite2D
var _charge: Sprite2D
var _tex_cache: Dictionary = {}
var _manifest: Dictionary = {}
var _atlas: Dictionary = {}
var _last_px: float = 0.0
var _last_py: float = 0.0
var _last_stage: int = -1
var _last_boss: bool = false
var _last_overlay: StringName = &""


func _ready() -> void:
	if camera == null:
		camera = Camera2D.new()
		add_child(camera)
	camera.make_current()
	if world_root == null:
		world_root = Node2D.new()
		world_root.name = "WorldRoot"
		add_child(world_root)
	if player_sprite == null:
		player_sprite = Sprite2D.new()
		player_sprite.name = "Player"
		world_root.add_child(player_sprite)
	if crosshair == null:
		crosshair = Sprite2D.new()
		crosshair.name = "Crosshair"
		world_root.add_child(crosshair)
	_ambient = Sprite2D.new()
	_ambient.centered = false
	_ambient.z_index = -20
	_ambient.texture = _placeholder(Color(0.14, 0.08, 0.07, 1.0), 64)
	_ambient.material = _mat("res://assets/shaders/ambient_biome.gdshader")
	add_child(_ambient)
	_charge = Sprite2D.new()
	_charge.z_index = -5
	_charge.texture = _placeholder(Color(1, 1, 1, 1), 64)
	_charge.material = _mat("res://assets/shaders/circle_charge.gdshader")
	_charge.visible = false
	world_root.add_child(_charge)
	_hurt_mat = _mat("res://assets/shaders/player_hurt.gdshader")
	_mat_tether = _mat("res://assets/shaders/tether.gdshader")
	_mat_impact = _mat("res://assets/shaders/skill_impact.gdshader")
	_mat_brim = _mat("res://assets/shaders/brimstone_line.gdshader")
	_load_manifest()
	player_sprite.material = _hurt_mat
	player_sprite.texture = _entity_frame("runner", "idle", 0.0)
	if player_sprite.texture == null:
		player_sprite.texture = _placeholder(Color(0.85, 0.95, 1.0), 32)
	crosshair.texture = _fx_texture("bolt")
	if crosshair.texture == null:
		crosshair.texture = _placeholder(Color(0.9, 0.8, 0.4), 8)


func _process(dt: float) -> void:
	var app := get_node_or_null("/root/App")
	if app == null:
		return
	if app.world == null:
		_sync_menu_camera()
		return
	if Input.is_action_just_pressed("pause"):
		if app.overlay_mode == &"hidden":
			app.pause_run()
		elif app.overlay_mode == &"pause":
			app.resume_run()
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
		var frames: Array[InputFrame] = [frame]
		app.world.step(frames, dt)
		_consume_fx(app)
	_sync_music(app)
	_sync(app.world, dt, bool(app.settings.reduce_vfx), bool(app.settings.screenshake))


func _sync_menu_camera() -> void:
	camera.position = Vector2.ZERO
	camera.zoom = Vector2(0.92, 0.92)
	_ambient.visible = false
	if world_root != null:
		world_root.visible = false
	queue_redraw()


func _sync(world: SimWorld, dt: float, reduce_vfx: bool, screenshake: bool) -> void:
	if world_root != null:
		world_root.visible = true
	_ambient.visible = true
	var sid: String = String(world.survivor.get("id", "runner"))
	var moving: bool = absf(world.player.x - _last_px) + absf(world.player.y - _last_py) > 0.4
	_last_px = world.player.x
	_last_py = world.player.y
	var ptex: Texture2D = _entity_frame(sid, "walk" if moving else "idle", world.run_time)
	if ptex != null:
		player_sprite.texture = ptex
	player_sprite.position = Vector2(world.player.x, world.player.y)
	player_sprite.flip_h = world.aim_x < world.player.x
	crosshair.position = Vector2(world.aim_x, world.aim_y)
	var zoom: float = float(world.catalog.world.get("viewZoom", 0.92))
	camera.position = player_sprite.position
	camera.zoom = Vector2(zoom, zoom)
	if _hurt_flash > 0.0:
		_hurt_flash = maxf(0.0, _hurt_flash - dt * 4.0)
	if _hurt_mat != null:
		_hurt_mat.set_shader_parameter("flash", 0.0 if reduce_vfx else _hurt_flash)
	if screenshake and _shake > 0.0 and not reduce_vfx:
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = maxf(0.0, _shake - dt * 18.0)
	else:
		camera.offset = Vector2.ZERO
		_shake = maxf(0.0, _shake - dt * 18.0)
	var width: float = float(world.catalog.world.get("width", 2560))
	var height: float = float(world.catalog.world.get("height", 2560))
	_ambient.position = Vector2.ZERO
	_ambient.scale = Vector2(width / 64.0, height / 64.0)
	_ambient.visible = true
	if _ambient.material is ShaderMaterial:
		(_ambient.material as ShaderMaterial).set_shader_parameter("tint", Color(0.55, 0.22, 0.12, 0.0 if reduce_vfx else 0.08))
	if world.teleporter_state == &"charging":
		_charge.visible = not reduce_vfx
		_charge.position = Vector2(world.teleporter_x, world.teleporter_y)
		var charge: float = clampf(world.teleporter_charge / maxf(world.teleporter_hold, 0.001), 0.0, 1.0)
		var span: float = world.teleporter_radius * 2.0 / 64.0
		_charge.scale = Vector2(span, span)
		if _charge.material is ShaderMaterial:
			(_charge.material as ShaderMaterial).set_shader_parameter("charge", charge)
	else:
		_charge.visible = false
	_sync_fodder(world)
	_sync_elites(world, reduce_vfx)
	_sync_projectiles(world, reduce_vfx)
	_sync_hazards(world, reduce_vfx)
	queue_redraw()


func _draw() -> void:
	var app := get_node_or_null("/root/App")
	if app == null or app.world == null:
		draw_rect(Rect2(-2000, -1200, 4000, 2400), Color(0.07, 0.05, 0.06), true)
		return
	var world: SimWorld = app.world
	var width: float = float(world.catalog.world.get("width", 2560))
	var height: float = float(world.catalog.world.get("height", 2560))
	draw_rect(Rect2(0, 0, width, height), Color(0.07, 0.05, 0.06), true)
	draw_rect(Rect2(0, 0, width, height), Color(0.35, 0.22, 0.16), false, 4.0)
	if world.teleporter_state != &"hidden":
		draw_circle(Vector2(world.teleporter_x, world.teleporter_y), world.teleporter_radius, Color(0.77, 0.64, 0.35, 0.18))
	if world.portal_open:
		draw_circle(Vector2(world.portal_x, world.portal_y), float(world.catalog.loop.get("portalRadius", 70.0)), Color(0.9, 0.75, 0.2, 0.45))
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		var c := Color(0.35, 0.28, 0.22)
		if obs.type == &"hazard":
			c = Color(0.45, 0.12, 0.1, 0.55)
		elif obs.type == &"volatile":
			c = Color(0.7, 0.35, 0.15)
		draw_circle(Vector2(obs.x, obs.y), obs.radius, c)
	for i: int in world.gems.cap:
		if world.gems.alive[i] == 0:
			continue
		draw_circle(Vector2(world.gems.x[i], world.gems.y[i]), 4.0, Color(0.53, 0.78, 0.83))


func _sync_fodder(world: SimWorld) -> void:
	var by_id: Dictionary = {}
	for i: int in world.enemies.cap:
		if world.enemies.alive[i] == 0 or world.enemies.role[i] != EnemyPool.ROLE_FODDER:
			continue
		var id: String = world.enemies.def_id[i]
		if not by_id.has(id):
			by_id[id] = []
		(by_id[id] as Array).append(i)
	for id: Variant in _fodder_layers.keys():
		if not by_id.has(id):
			(_fodder_layers[id] as MultiMeshInstance2D).multimesh.instance_count = 0
	for id: Variant in by_id.keys():
		var mm: MultiMeshInstance2D = _fodder_layer(String(id))
		var sheet: Texture2D = _entity_frame(String(id), "walk", world.run_time)
		if sheet != null:
			mm.texture = sheet
		var indices: Array = by_id[id]
		mm.multimesh.instance_count = indices.size()
		for n: int in indices.size():
			var idx: int = int(indices[n])
			var xf := Transform2D(0.0, Vector2(world.enemies.x[idx], world.enemies.y[idx]))
			if world.enemies.facing[idx] == 255:
				xf = xf.scaled(Vector2(-1, 1))
			mm.multimesh.set_instance_transform_2d(n, xf)


func _fodder_layer(id: String) -> MultiMeshInstance2D:
	if _fodder_layers.has(id):
		return _fodder_layers[id]
	var mm := MultiMeshInstance2D.new()
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_2D
	var tex: Texture2D = _entity_frame(id, "idle", 0.0)
	var fw: float = 24.0
	var fh: float = 24.0
	if tex != null:
		fw = float(tex.get_width())
		fh = float(tex.get_height())
	var quad := QuadMesh.new()
	quad.size = Vector2(fw, fh)
	mesh.mesh = quad
	mesh.instance_count = 24
	mm.multimesh = mesh
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
		var anim: String = world.enemies.anim_name[i]
		if anim == "":
			anim = "walk"
		var tex: Texture2D = _entity_frame(world.enemies.def_id[i], anim, world.run_time)
		if tex != null:
			spr.texture = tex
		var outline := Color(0.35, 0.72, 1.0, 0.0 if reduce_vfx else 1.0)
		if world.enemies.shielder[i] != 0:
			spr.modulate = Color(0.55, 0.75, 1.0)
			outline = Color(0.45, 0.8, 1.0, 0.0 if reduce_vfx else 1.0)
		elif world.enemies.noxious[i] != 0:
			spr.modulate = Color(0.45, 1.0, 0.55)
			outline = Color(0.35, 1.0, 0.45, 0.0 if reduce_vfx else 1.0)
		else:
			spr.modulate = Color.WHITE
		if spr.material is ShaderMaterial:
			(spr.material as ShaderMaterial).set_shader_parameter("outline_color", outline)
		n += 1
	for i: int in range(n, _elite_sprites.size()):
		_elite_sprites[i].visible = false


func _sync_projectiles(world: SimWorld, reduce_vfx: bool) -> void:
	var needed: int = 0
	for i: int in world.projectiles.alive.size():
		if world.projectiles.alive[i] != 0:
			needed += 1
	while _proj_sprites.size() < needed:
		var spr := Sprite2D.new()
		spr.texture = _placeholder(Color(1.0, 0.85, 0.4), 8)
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
		if reduce_vfx:
			spr.material = null
			spr.texture = _placeholder(Color(1.0, 0.85, 0.4), 8)
		elif flags & ProjectilePool.FLAG_TETHER != 0:
			spr.material = _mat_tether
			spr.texture = _fx_texture("skill-condemn-tether")
		elif flags & ProjectilePool.FLAG_IMPACT != 0:
			spr.material = _mat_impact
			spr.texture = _fx_texture("skill-censer-lob")
		else:
			spr.material = _mat_brim
			spr.texture = _fx_texture("bolt")
		if spr.texture == null:
			spr.texture = _placeholder(Color(1.0, 0.85, 0.4), 8)
		n += 1
	for i: int in range(n, _proj_sprites.size()):
		_proj_sprites[i].visible = false


func _sync_hazards(world: SimWorld, reduce_vfx: bool) -> void:
	var needed: int = 0
	for i: int in world.boss_hazards.cap:
		if world.boss_hazards.alive[i] != 0:
			needed += 1
	while _hazard_sprites.size() < needed:
		var spr := Sprite2D.new()
		spr.texture = _placeholder(Color(1, 1, 1, 1), 64)
		spr.material = _mat("res://assets/shaders/hazard_pool.gdshader")
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
		var tint := Color(0.48, 0.83, 1.0, 0.45)
		if world.boss_hazards.style[i] == BossHazardPool.STYLE_LAVA:
			tint = Color(1.0, 0.42, 0.15, 0.5)
		if spr.material is ShaderMaterial:
			(spr.material as ShaderMaterial).set_shader_parameter("tint", tint)
		n += 1
	for i: int in range(n, _hazard_sprites.size()):
		_hazard_sprites[i].visible = false


func _consume_fx(app: Node) -> void:
	var world: SimWorld = app.world
	if app.settings.screenshake:
		for i: int in world.fx.count:
			if world.fx.kind[i] == FxIds.HURT or world.fx.kind[i] == FxIds.DEATH:
				_shake = maxf(_shake, 6.0)
	for i: int in world.fx.count:
		if world.fx.kind[i] == FxIds.HURT:
			_hurt_flash = 1.0
	var bus := get_node_or_null("/root/GameAudio")
	if bus != null:
		for i: int in world.fx.count:
			bus.play_fx(int(world.fx.kind[i]))


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


func _load_manifest() -> void:
	var file := FileAccess.open("res://assets/sprites/manifest.json", FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_manifest = parsed


func _entity_frame(id: String, anim: String, t: float) -> Texture2D:
	var entities: Dictionary = _manifest.get("entities", {})
	var def: Dictionary = entities.get(id, {})
	var full: Texture2D = _cached_tex("res://assets/sprites/entities/%s.png" % id)
	if full == null:
		return null
	var fw: int = int(def.get("frameWidth", full.get_width()))
	var fh: int = int(def.get("frameHeight", full.get_height()))
	if fw <= 0:
		fw = full.get_width()
	if fh <= 0:
		fh = full.get_height()
	var anims: Dictionary = def.get("anims", {})
	var spec: Dictionary = anims.get(anim, anims.get("idle", {}))
	var frames: Array = spec.get("frames", [0])
	if frames.is_empty():
		frames = [0]
	var rate: float = float(spec.get("frameRate", 8.0))
	var frame_i: int = int(frames[int(floor(t * rate)) % frames.size()])
	var key: String = "%s:%d:%d:%d" % [id, fw, fh, frame_i]
	if _atlas.has(key):
		return _atlas[key]
	var cols: int = maxi(1, int(full.get_width() / fw))
	var atlas := AtlasTexture.new()
	atlas.atlas = full
	atlas.region = Rect2(float((frame_i % cols) * fw), float(int(frame_i / cols) * fh), float(fw), float(fh))
	_atlas[key] = atlas
	return atlas


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


func _mat(path: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	return mat


func _placeholder(color: Color, size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
