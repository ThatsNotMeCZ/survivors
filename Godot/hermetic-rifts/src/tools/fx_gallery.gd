extends SceneTree

const SHADERS: PackedStringArray = [
	"res://assets/shaders/vent_erupt.gdshader",
	"res://assets/shaders/hazard_pool.gdshader",
	"res://assets/shaders/boss_geyser.gdshader",
	"res://assets/shaders/miasma_pool.gdshader",
	"res://assets/shaders/cleave_slash.gdshader",
	"res://assets/shaders/boss_shockwave.gdshader",
	"res://assets/shaders/skill_impact.gdshader",
	"res://assets/shaders/brimstone_line.gdshader",
	"res://assets/shaders/boss_laser.gdshader",
	"res://assets/shaders/circle_cracks.gdshader",
]

var _frames: int = 0
var _out_path: String = ""
var _vp: SubViewport


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_path = arg.substr(6)
	var lut: Texture2D = UiAtlas.lut_tex()
	var ok_count: int = 0
	for path: String in SHADERS:
		var sh: Shader = load(path) as Shader
		if sh == null or sh.code.is_empty():
			push_error("fx_gallery: failed to load shader %s" % path)
			quit(1)
			return
		var mat := ShaderMaterial.new()
		mat.shader = sh
		if lut != null:
			mat.set_shader_parameter("u_lut_tex", lut)
			mat.set_shader_parameter("u_use_lut", 1.0)
		mat.set_shader_parameter("u_quad_px", Vector2(128.0, 128.0))
		mat.set_shader_parameter("u_progress", 0.5)
		mat.set_shader_parameter("u_time", 1.25)
		ok_count += 1
	var arena_packed: PackedScene = load("res://scenes/arena.tscn") as PackedScene
	if arena_packed == null:
		push_error("fx_gallery: failed to load res://scenes/arena.tscn")
		quit(1)
		return
	var arena_inst: Node = arena_packed.instantiate()
	arena_inst.free()
	print("fx_gallery: verified %d combat FX shaders and ArenaView scene." % ok_count)
	if _out_path == "" or DisplayServer.get_name() == "headless":
		quit(0)
		return
	_build_capture_viewport(lut)


func _build_capture_viewport(lut: Texture2D) -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(1420, 480)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.transparent_bg = false
	get_root().add_child(_vp)

	var bg := ColorRect.new()
	bg.color = Color("181216")
	bg.size = Vector2(1420, 480)
	_vp.add_child(bg)

	var chunks: Array[Dictionary] = FloorStamp.build_chunks("cinder", 1420, 480, false, 710.0)
	for cdict: Dictionary in chunks:
		var cspr := Sprite2D.new()
		cspr.centered = false
		cspr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cspr.texture = cdict.get("texture", null)
		cspr.position = (cdict.get("rect", Rect2()) as Rect2).position
		_vp.add_child(cspr)

	var gallery_packed: PackedScene = load("res://scenes/debug/fx_gallery.tscn") as PackedScene
	if gallery_packed != null:
		var gnode: Node = gallery_packed.instantiate()
		for child: Node in gnode.get_children():
			if child is CanvasItem and (child as CanvasItem).material is ShaderMaterial:
				var sm: ShaderMaterial = (child as CanvasItem).material as ShaderMaterial
				if lut != null:
					sm.set_shader_parameter("u_lut_tex", lut)
					sm.set_shader_parameter("u_use_lut", 1.0)
				sm.set_shader_parameter("u_time", 2.15)
		_vp.add_child(gnode)

	# Mount ember-chaser on strike frame 5 above CleaveSlam cell
	var chaser := Sprite2D.new()
	chaser.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chaser.texture = UiAtlas.entity_frame("ember-chaser", "attack", 0.30)
	chaser.position = Vector2(818.0, 136.0)
	_vp.add_child(chaser)


func _process(_dt: float) -> bool:
	if _out_path == "" or _vp == null:
		return true
	_frames += 1
	if _frames >= 4:
		var img: Image = _vp.get_texture().get_image()
		if img != null:
			img.save_png(_out_path)
			print("fx_gallery: saved snapshot to %s" % _out_path)
		quit(0)
		return true
	return false
