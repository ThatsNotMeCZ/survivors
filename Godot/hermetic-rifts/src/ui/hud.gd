class_name HudView
extends Control

const DIFF_SEG_W: float = 72.0
const DIFF_MARKER_X: float = 43.0
const SKILL_SLOTS: Array[StringName] = [&"primary", &"secondary", &"utility", &"special"]
const SKILL_GLYPHS: Array[String] = ["I", "II", "III", "IV"]
const SKILL_KEYS: Array[String] = ["ui.hud.key.primary", "ui.hud.key.secondary", "ui.hud.key.utility", "ui.hud.key.special"]
const DIFF_KEYS: Array[String] = [
	"ui.diff.dormant",
	"ui.diff.stirring",
	"ui.diff.tempered",
	"ui.diff.calcined",
	"ui.diff.volatile",
	"ui.diff.cataclysm",
]
const DIFF_MIN: Array[float] = [1.0, 1.3, 1.65, 2.05, 2.55, 3.15]
const DIFF_MAX: Array[float] = [1.3, 1.65, 2.05, 2.55, 3.15, INF]
const DIFF_COLORS: Array[Color] = [
	Color("91db69"),
	Color("d5e04b"),
	Color("f9c22b"),
	Color("fb6b1d"),
	Color("f04f78"),
	Color("a884f3"),
]

var _vignette: ColorRect
var _vignette_mat: ShaderMaterial
var _draw_layer: Control
var _corner: TextureRect
var _obj_root: VBoxContainer
var _kicker: Label
var _objective: Label
var _obj_fill: ColorRect
var _obj_detail: Label
var _obj_sub: Label
var _ritual_lab: Label
var _alert_lab: Label
var _essence_panel: PanelContainer
var _essence_lab: Label
var _interact_panel: PanelContainer
var _interact_lab: Label
var _time: Label
var _stage: Label
var _diff_tier: Label
var _diff_coeff: Label
var _diff_tape: Control
var _hp_fill: ColorRect
var _hp_mat: ShaderMaterial
var _hp: Label
var _level: Label
var _xp_fill: ColorRect
var _skill_icons: Array[TextureRect] = []
var _skill_glyphs: Array[Label] = []
var _skill_cds: Array[Label] = []
var _skill_keys: Array[Label] = []
var _skill_sweeps: Array[ColorRect] = []
var _skill_slots: Array[Control] = []
var _item_list: GridContainer
var _last_item_key: String = ""
var _last_skill_bind: String = ""
var _built: bool = false
var _world: SimWorld
var _cached_world_vp: Viewport


func _ready() -> void:
	_build()


func sync(world: SimWorld) -> void:
	if not _built:
		_build()
	_world = world
	if world == null:
		visible = false
		return
	visible = true
	var stage: Dictionary = SimLoop.current_stage(world)
	var stage_id: String = String(stage.get("id", ""))
	var biome: String = ArenaBiome.from_stage(stage_id)
	var objective: Dictionary = SimLoop.current_objective(world)
	var tel_in: bool = (
		world.teleporter_state == &"charging"
		and Vector2(world.player.x, world.player.y).distance_to(Vector2(world.teleporter_x, world.teleporter_y))
		<= SimLoop.effective_teleporter_radius(world)
	)
	var portal_r: float = float(world.catalog.loop.get("portalRadius", 70.0))
	var portal_in: bool = (
		world.portal_open
		and Vector2(world.player.x, world.player.y).distance_to(Vector2(world.portal_x, world.portal_y)) <= portal_r
	)
	var ouroboros: bool = SimLoop.can_seal(world)
	var outside: bool = (world.teleporter_state == &"charging" and not tel_in) or (world.portal_open and not portal_in)
	var obj_kind: StringName = objective.get("kind", &"wait")
	if _obj_root != null:
		_obj_root.visible = obj_kind != &"wait"
	var copy: Dictionary = _objective_copy(world, objective, outside, ouroboros, tel_in)
	_kicker.text = String(copy.get("kicker", ""))
	_kicker.visible = _kicker.text != ""
	_objective.text = String(copy.get("label", ""))
	_obj_detail.text = String(copy.get("detail", ""))
	_obj_sub.text = String(copy.get("sub", ""))
	_obj_sub.visible = _obj_sub.text != ""
	var pct: float = clampf(float(objective.get("pct", 0.0)), 0.0, 1.0)
	_obj_fill.anchor_right = pct
	_obj_fill.offset_right = 0.0
	if tel_in:
		_obj_fill.color = Color("e5c878")
	elif outside:
		_obj_fill.color = Color("b81d24")
	else:
		_obj_fill.color = Color("c4a35a")
	var stage_label: String = Loc.stage_name(stage_id)
	if world.cycle_index > 0:
		stage_label = "%s · %s" % [stage_label, tr("ui.hud.cycle").replace("{n}", SimRng.cycle_numeral(world.cycle_index))]
	_stage.text = stage_label
	_time.text = Loc.format_time(world.run_time)
	_hp.text = "%d / %d" % [maxi(0, int(round(world.player.hp))), int(round(world.player.max_hp))]
	var hp_pct: float = clampf(world.player.hp / maxf(world.player.max_hp, 1.0), 0.0, 1.0)
	if _hp_mat != null:
		_hp_mat.set_shader_parameter("fill", hp_pct)
		if hp_pct < 0.35:
			_hp_mat.set_shader_parameter("fill_mid", Color("ff5252"))
			_hp_mat.set_shader_parameter("fill_top", Color("ff8a8a"))
		else:
			_hp_mat.set_shader_parameter("fill_mid", Color("9e1b24"))
			_hp_mat.set_shader_parameter("fill_top", Color("e03c44"))
	_level.text = tr("ui.hud.level").replace("{n}", str(world.level))
	var xp_pct: float = clampf(world.xp / maxf(world.xp_need, 1.0), 0.0, 1.0)
	_xp_fill.anchor_right = xp_pct
	_xp_fill.offset_right = 0.0
	_sync_essence(world)
	_sync_ritual_and_alerts(world)
	_sync_interact_prompt(world)
	_sync_difficulty(world.coefficient)
	_sync_skills(world)
	_sync_items(world)
	_sync_vignette(biome)
	if _draw_layer != null:
		_draw_layer.queue_redraw()
	queue_redraw()


func _build() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = load("res://assets/shaders/vignette.gdshader")
	_vignette.material = _vignette_mat
	add_child(_vignette)
	_draw_layer = Control.new()
	_draw_layer.name = "GaugeAndRingsLayer"
	_draw_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.draw.connect(_on_draw_layer)
	add_child(_draw_layer)
	_corner = TextureRect.new()
	_corner.texture = UiAtlas.frame("hud-corner")
	_corner.stretch_mode = TextureRect.STRETCH_KEEP
	_corner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corner.custom_minimum_size = Vector2(96, 96)
	_corner.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_corner.offset_right = 96.0
	_corner.offset_bottom = 96.0
	add_child(_corner)
	_build_objective()
	_build_run_panel()
	_build_vitals()
	_build_skills()
	_build_items()
	_build_interact_prompt()


func _build_objective() -> void:
	var root := VBoxContainer.new()
	_obj_root = root
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	root.offset_left = -220.0
	root.offset_right = 220.0
	root.offset_top = 8.0
	root.offset_bottom = 96.0
	add_child(root)
	_kicker = _label(10, UiAtlas.GOLD_MOLTEN, UiAtlas.TYPE_MICRO)
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_kicker)
	_objective = _label(16, UiAtlas.PARCHMENT, UiAtlas.TYPE_DISPLAY)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_objective)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(340, 62)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var bar_tex := NinePatchRect.new()
	bar_tex.texture = UiAtlas.frame("hud-objective")
	bar_tex.patch_margin_left = 50
	bar_tex.patch_margin_right = 50
	bar_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(bar_tex)
	var track := Control.new()
	track.clip_contents = true
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.offset_left = 45.0
	track.offset_right = -40.0
	track.offset_top = 22.0
	track.offset_bottom = -22.0
	bar.add_child(track)
	var track_bg := ColorRect.new()
	track_bg.color = Color(0.055, 0.043, 0.055, 0.92)
	track_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.add_child(track_bg)
	_obj_fill = ColorRect.new()
	_obj_fill.color = Color("c4a35a")
	_obj_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_fill.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_obj_fill.anchor_right = 0.0
	track.add_child(_obj_fill)
	_obj_detail = _label(11, UiAtlas.PARCHMENT, UiAtlas.TYPE_MICRO)
	_obj_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obj_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_obj_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.add_child(_obj_detail)
	_obj_sub = _label(11, Color("e8dcc8"), UiAtlas.TYPE_MICRO)
	_obj_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obj_sub.visible = false
	root.add_child(_obj_sub)
	_ritual_lab = _label(11, UiAtlas.GOLD_MOLTEN, UiAtlas.TYPE_MICRO)
	_ritual_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ritual_lab.visible = false
	root.add_child(_ritual_lab)
	_alert_lab = _label(11, Color("ff7a6e"), UiAtlas.TYPE_MICRO)
	_alert_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_lab.visible = false
	root.add_child(_alert_lab)


func _build_run_panel() -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(243, 158)
	root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	root.anchor_left = 1.0
	root.anchor_right = 1.0
	root.offset_left = -255.0
	root.offset_right = -12.0
	root.offset_top = 4.0
	root.offset_bottom = 162.0
	add_child(root)
	var bg := TextureRect.new()
	bg.texture = UiAtlas.frame("hud-timer")
	bg.stretch_mode = TextureRect.STRETCH_KEEP
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var col := VBoxContainer.new()
	col.offset_left = 57.0
	col.offset_top = 34.0
	col.offset_right = 228.0
	col.offset_bottom = 70.0
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	var timer_row := HBoxContainer.new()
	timer_row.alignment = BoxContainer.ALIGNMENT_END
	timer_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(timer_row)
	var timer_lab := _label(11, UiAtlas.PARCHMENT, UiAtlas.TYPE_MICRO)
	timer_lab.text = tr("ui.hud.timer")
	timer_row.add_child(timer_lab)
	_time = _label(13, UiAtlas.GOLD_MOLTEN, UiAtlas.TYPE_META)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_row.add_child(_time)
	_stage = _label(11, UiAtlas.ASH, UiAtlas.TYPE_MICRO)
	_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_stage)
	var header := HBoxContainer.new()
	header.offset_left = 57.0
	header.offset_top = 75.0
	header.offset_right = 228.0
	header.offset_bottom = 92.0
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	_diff_tier = _label(10, DIFF_COLORS[0], UiAtlas.TYPE_MICRO)
	_diff_tier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_diff_tier)
	_diff_coeff = _label(11, Color("c7dcd0"), UiAtlas.TYPE_MICRO)
	_diff_coeff.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_diff_coeff)
	var viewport := Control.new()
	viewport.name = "DiffViewport"
	viewport.offset_left = 57.0
	viewport.offset_top = 98.0
	viewport.offset_right = 228.0
	viewport.offset_bottom = 117.0
	viewport.custom_minimum_size = Vector2(171, 19)
	viewport.clip_contents = true
	viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(viewport)
	_diff_tape = HBoxContainer.new()
	_diff_tape.add_theme_constant_override("separation", 0)
	_diff_tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_diff_tape.position = Vector2(DIFF_MARKER_X, 0.0)
	viewport.add_child(_diff_tape)
	var roman: Array[String] = ["I", "II", "III", "IV", "V", "VI"]
	var has_tape_art: bool = UiAtlas.has_frame("hud-diff-tape")
	if has_tape_art:
		var tape_wrap := Control.new()
		tape_wrap.custom_minimum_size = Vector2(DIFF_SEG_W * 6.0, 19.0)
		tape_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_diff_tape.add_child(tape_wrap)
		var tape_tex := TextureRect.new()
		tape_tex.texture = UiAtlas.frame("hud-diff-tape")
		tape_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tape_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tape_tex.stretch_mode = TextureRect.STRETCH_SCALE
		tape_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tape_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tape_wrap.add_child(tape_tex)
		for i: int in 6:
			var lab := _label(9, Color.WHITE, UiAtlas.TYPE_MICRO)
			lab.text = roman[i]
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lab.position = Vector2(float(i) * DIFF_SEG_W, 0.0)
			lab.size = Vector2(DIFF_SEG_W, 19.0)
			tape_wrap.add_child(lab)
	else:
		for i: int in 6:
			var seg := ColorRect.new()
			seg.custom_minimum_size = Vector2(DIFF_SEG_W, 19)
			seg.color = DIFF_COLORS[i].darkened(0.45)
			seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_diff_tape.add_child(seg)
			var lab := _label(9, Color.WHITE, UiAtlas.TYPE_MICRO)
			lab.text = roman[i]
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			seg.add_child(lab)
	if UiAtlas.has_frame("hud-diff-pointer"):
		var ptr := TextureRect.new()
		ptr.name = "DiffPointer"
		ptr.texture = UiAtlas.frame("hud-diff-pointer")
		ptr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ptr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ptr.stretch_mode = TextureRect.STRETCH_SCALE
		ptr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ptr.position = Vector2(viewport.offset_left + DIFF_MARKER_X - 5.0, viewport.offset_top - 2.0)
		ptr.size = Vector2(11.0, 23.0)
		root.add_child(ptr)
	_essence_panel = PanelContainer.new()
	_essence_panel.name = "EssenceBadge"
	_essence_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_essence_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_essence_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_essence_panel.anchor_left = 1.0
	_essence_panel.anchor_right = 1.0
	_essence_panel.offset_left = -196.0
	_essence_panel.offset_right = -12.0
	_essence_panel.offset_top = 166.0
	_essence_panel.offset_bottom = 198.0
	if UiAtlas.has_frame("hud-essence"):
		_essence_panel.add_theme_stylebox_override("panel", UiAtlas.nine_slice("hud-essence", "idle", Vector4(16, 4, 16, 4)))
	else:
		var ess_sb := StyleBoxFlat.new()
		ess_sb.bg_color = Color("140d14d9")
		ess_sb.border_color = UiAtlas.BRASS_DIM
		ess_sb.set_border_width_all(1)
		ess_sb.content_margin_left = 10.0
		ess_sb.content_margin_right = 10.0
		ess_sb.content_margin_top = 3.0
		ess_sb.content_margin_bottom = 3.0
		_essence_panel.add_theme_stylebox_override("panel", ess_sb)
	add_child(_essence_panel)
	_essence_lab = _label(12, Color("ff809a"), UiAtlas.TYPE_META)
	_essence_lab.text = tr("ui.hud.essence").replace("{n}", "0")
	_essence_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_essence_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_essence_panel.add_child(_essence_lab)


func _build_vitals() -> void:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.alignment = BoxContainer.ALIGNMENT_END
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	root.anchor_top = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 12.0
	root.offset_right = 280.0
	root.offset_top = -116.0
	root.offset_bottom = -12.0
	add_child(root)
	var flask := Control.new()
	flask.custom_minimum_size = Vector2(90, 104)
	flask.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	flask.size_flags_vertical = Control.SIZE_SHRINK_END
	flask.clip_contents = false
	flask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flask)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color("9e1b24")
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hp_fill.anchor_right = 0.0
	_hp_fill.anchor_bottom = 0.0
	_hp_fill.offset_left = 6.0
	_hp_fill.offset_right = 70.0
	_hp_fill.offset_top = 35.0
	_hp_fill.offset_bottom = 99.0
	_hp_mat = ShaderMaterial.new()
	_hp_mat.shader = load("res://assets/shaders/flask_hp.gdshader")
	_hp_mat.set_shader_parameter("fill", 1.0)
	_hp_fill.material = _hp_mat
	flask.add_child(_hp_fill)
	var flask_tex := TextureRect.new()
	flask_tex.texture = UiAtlas.frame("hud-flask")
	flask_tex.stretch_mode = TextureRect.STRETCH_SCALE
	flask_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flask_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flask_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flask_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flask.add_child(flask_tex)
	_hp = _label(11, UiAtlas.PARCHMENT, UiAtlas.TYPE_MICRO)
	_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp.position = Vector2(6, 38)
	_hp.size = Vector2(64, 64)
	flask.add_child(_hp)
	var copy := VBoxContainer.new()
	copy.alignment = BoxContainer.ALIGNMENT_END
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(copy)
	_level = _label(12, UiAtlas.PARCHMENT, UiAtlas.TYPE_MICRO)
	copy.add_child(_level)
	var xp := Control.new()
	xp.custom_minimum_size = Vector2(0, 9)
	xp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(xp)
	var xp_bg := ColorRect.new()
	xp_bg.color = Color("141218")
	xp_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp.add_child(xp_bg)
	_xp_fill = ColorRect.new()
	_xp_fill.color = Color("d8dee9")
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_xp_fill.anchor_right = 0.0
	xp.add_child(_xp_fill)


func _build_skills() -> void:
	var dock := TextureRect.new()
	dock.texture = UiAtlas.frame("hud-skill-dock")
	dock.stretch_mode = TextureRect.STRETCH_KEEP
	dock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dock.custom_minimum_size = Vector2(315, 96)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dock.anchor_left = 1.0
	dock.anchor_top = 1.0
	dock.offset_left = -485.0
	dock.offset_right = -170.0
	dock.offset_top = -106.0
	dock.offset_bottom = -10.0
	add_child(dock)
	var sweep_mat_shader: Shader = load("res://assets/shaders/skill_cd_sweep.gdshader")
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 45.0
	inner.offset_right = -45.0
	inner.offset_top = 28.0
	inner.offset_bottom = -28.0
	dock.add_child(inner)
	for i: int in 4:
		if i > 0:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(spacer)
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(40, 40)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(slot)
		var frame := TextureRect.new()
		frame.texture = UiAtlas.frame("skill-slot-frame")
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(frame)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 8.0
		icon.offset_top = 8.0
		icon.offset_right = -8.0
		icon.offset_bottom = -8.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		var sweep := ColorRect.new()
		sweep.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sm := ShaderMaterial.new()
		sm.shader = sweep_mat_shader
		sweep.material = sm
		slot.add_child(sweep)
		var glyph := _label(14, UiAtlas.PARCHMENT, UiAtlas.TYPE_META)
		glyph.text = SKILL_GLYPHS[i]
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(glyph)
		var cd := _label(13, Color.WHITE, UiAtlas.TYPE_META)
		cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(cd)
		var key := _label(9, UiAtlas.PARCHMENT, UiAtlas.TYPE_MICRO)
		key.text = tr(SKILL_KEYS[i])
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		key.offset_left = -20.0
		key.offset_right = 20.0
		key.offset_top = 1.0
		key.offset_bottom = 17.0
		slot.add_child(key)
		_skill_slots.append(slot)
		_skill_icons.append(icon)
		_skill_glyphs.append(glyph)
		_skill_cds.append(cd)
		_skill_keys.append(key)
		_skill_sweeps.append(sweep)


func _build_interact_prompt() -> void:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center.anchor_top = 1.0
	center.anchor_bottom = 1.0
	center.offset_top = -168.0
	center.offset_bottom = -124.0
	add_child(center)
	_interact_panel = PanelContainer.new()
	_interact_panel.name = "InteractPrompt"
	_interact_panel.visible = false
	_interact_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("140e14e8")
	sb.border_color = UiAtlas.GOLD_MOLTEN
	sb.set_border_width_all(1)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	_interact_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_interact_panel)
	_interact_lab = _label(13, UiAtlas.GOLD_MOLTEN, UiAtlas.TYPE_META)
	_interact_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_panel.add_child(_interact_lab)


func _build_items() -> void:
	var box := TextureRect.new()
	box.texture = UiAtlas.frame("hud-inventory")
	box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.custom_minimum_size = Vector2(132, 132)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.anchor_left = 1.0
	box.anchor_top = 1.0
	box.offset_left = -144.0
	box.offset_right = -12.0
	box.offset_top = -142.0
	box.offset_bottom = -10.0
	add_child(box)
	_item_list = GridContainer.new()
	_item_list.columns = 6
	_item_list.add_theme_constant_override("h_separation", 4)
	_item_list.add_theme_constant_override("v_separation", 4)
	_item_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_item_list.offset_left = 16.0
	_item_list.offset_right = -16.0
	_item_list.offset_top = 16.0
	_item_list.offset_bottom = -16.0
	_item_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_item_list)


func _sync_difficulty(coefficient: float) -> void:
	var coeff: float = maxf(1.0, coefficient)
	var tier_i: int = 0
	for i: int in DIFF_MIN.size():
		if coeff >= DIFF_MIN[i]:
			tier_i = i
	_diff_tier.text = tr(DIFF_KEYS[tier_i])
	_diff_tier.add_theme_color_override("font_color", DIFF_COLORS[tier_i])
	_diff_coeff.text = "×%.2f" % coeff
	var offset: float = 0.0
	if tier_i < DIFF_MIN.size() - 1:
		var span: float = DIFF_MAX[tier_i] - DIFF_MIN[tier_i]
		var progress: float = clampf((coeff - DIFF_MIN[tier_i]) / maxf(span, 0.001), 0.0, 1.0)
		offset = float(tier_i) * DIFF_SEG_W + progress * DIFF_SEG_W
	else:
		var extra: float = maxf(0.0, coeff - DIFF_MIN[tier_i])
		offset = float(DIFF_MIN.size() - 1) * DIFF_SEG_W + (extra / 0.6) * DIFF_SEG_W
	_diff_tape.position.x = DIFF_MARKER_X - offset


func _sync_skills(world: SimWorld) -> void:
	var slot_ids: Array[String] = []
	var bind: String = ""
	for i: int in SKILL_SLOTS.size():
		var slot_id: String = SimSkills.slot_skill_id(world, SKILL_SLOTS[i])
		slot_ids.append(slot_id)
		bind += "%s:%s|" % [String(SKILL_SLOTS[i]), slot_id]
	var rebind: bool = bind != _last_skill_bind
	if rebind:
		_last_skill_bind = bind
	var action_names: Array[String] = ["fire_primary", "fire_secondary", "utility", "special"]
	for i: int in SKILL_SLOTS.size():
		var slot: StringName = SKILL_SLOTS[i]
		var id: String = slot_ids[i]
		var empty: bool = id == ""
		var cd: float = float(world.player.skill_cd.get(slot, 0.0))
		var max_cd: float = 0.0
		if not empty:
			var def: Dictionary = world.catalog.skill(id)
			max_cd = float(def.get("cooldown", 1.0)) * world.stats.cooldown_mul
		if rebind:
			_skill_icons[i].texture = null if empty else UiAtlas.skill_tex(id)
		if i < _skill_keys.size() and i < action_names.size():
			_skill_keys[i].text = _short_action_key(action_names[i], tr(SKILL_KEYS[i]))
		_skill_glyphs[i].visible = empty or _skill_icons[i].texture == null
		_skill_glyphs[i].modulate = Color(1, 1, 1, 0.35 if empty or cd > 0.0 else 1.0)
		_skill_icons[i].modulate = Color(1, 1, 1, 0.42 if cd > 0.05 else 1.0)
		_skill_slots[i].modulate = Color(1, 1, 1, 0.35 if empty else 1.0)
		var cd_pct: float = 0.0 if empty or max_cd <= 0.0 or cd <= 0.0 else clampf(cd / max_cd, 0.0, 1.0)
		if _skill_sweeps[i].material is ShaderMaterial:
			(_skill_sweeps[i].material as ShaderMaterial).set_shader_parameter("cd", cd_pct)
		if not empty and cd > 0.05:
			_skill_cds[i].text = "%ds" % int(ceil(cd)) if cd >= 1.0 else "%.1fs" % cd
		else:
			_skill_cds[i].text = ""
		if slot == InputFrame.SLOT_UTILITY and world.player.iframe_remain > 0.0:
			_skill_slots[i].modulate = Color(1.4, 1.4, 1.4, 1.0)


func _sync_items(world: SimWorld) -> void:
	var key: String = ""
	for inst: ItemInstance in world.inventory:
		var rarity_key: String = "common"
		if world.catalog != null and world.catalog.has_item(inst.id):
			rarity_key = String(world.catalog.item(inst.id).get("rarity", "common"))
		key += "%s:%d:%s|" % [inst.id, inst.stacks, rarity_key]
	if key == _last_item_key:
		return
	_last_item_key = key
	for child: Node in _item_list.get_children():
		_item_list.remove_child(child)
		child.free()
	var n: int = world.inventory.size()
	var cols: int = maxi(3, int(ceil(sqrt(float(maxi(1, n))))))
	_item_list.columns = mini(6, cols)
	for inst: ItemInstance in world.inventory:
		var rarity: String = "common"
		if world.catalog != null and world.catalog.has_item(inst.id):
			rarity = String(world.catalog.item(inst.id).get("rarity", "common"))
		var chip := Control.new()
		chip.custom_minimum_size = Vector2(32, 32)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiAtlas.attach_rarity_splash(chip, rarity)
		var icon := TextureRect.new()
		icon.texture = UiAtlas.item_tex(inst.id)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(icon)
		var count := _label(10, UiAtlas.PARCHMENT, UiAtlas.TYPE_MICRO)
		count.text = str(inst.stacks)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		chip.add_child(count)
		_item_list.add_child(chip)


func _sync_vignette(biome: String) -> void:
	if _vignette_mat == null:
		return
	var tint := Color(0.157, 0.039, 0.031, 0.46)
	if biome == "rime":
		tint = Color(0.031, 0.071, 0.11, 0.5)
	_vignette_mat.set_shader_parameter("tint", tint)


func _objective_copy(world: SimWorld, objective: Dictionary, outside: bool, ouroboros: bool, _holding: bool) -> Dictionary:
	var kind: StringName = objective.get("kind", &"wait")
	var pct: int = int(round(float(objective.get("pct", 0.0)) * 100.0))
	var sub: String = ""
	if kind == &"hold" and outside:
		sub = tr("ui.hud.sub.return")
	elif kind == &"portal":
		if ouroboros:
			sub = tr("ui.hud.sub.cycle").replace("{n}", SimRng.cycle_numeral(world.cycle_index + 1)) if outside else tr("ui.hud.sub.seal")
		elif outside:
			sub = tr("ui.hud.sub.stand")
	if kind == &"wait":
		return {"kicker": "", "label": tr("ui.hud.seal"), "detail": "%d%%" % pct, "sub": ""}
	if kind == &"hold":
		return {"kicker": "", "label": tr("ui.hud.channel"), "detail": "%d%%" % pct, "sub": sub}
	if kind == &"boss":
		return {
			"kicker": tr("ui.hud.kicker.guardian"),
			"label": tr("ui.hud.slay").replace("{name}", Loc.entity_name(String(objective.get("name", "")))),
			"detail": "%d%%" % pct,
			"sub": "",
		}
	return {
		"kicker": tr("ui.hud.kicker.ouroboros") if ouroboros else "",
		"label": tr("ui.hud.ouroboros") if ouroboros else tr("ui.hud.descend"),
		"detail": "%d%%" % pct,
		"sub": sub,
	}


func _label(px: int, color: Color, role: StringName = UiAtlas.TYPE_META) -> Label:
	var lab := Label.new()
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiAtlas.apply_label(lab, role, color, px, true)
	return lab


func _sync_essence(world: SimWorld) -> void:
	if _essence_lab != null:
		_essence_lab.text = tr("ui.hud.essence").replace("{n}", str(world.run_essence))


func _sync_ritual_and_alerts(world: SimWorld) -> void:
	if _ritual_lab != null:
		if world.teleporter_state == &"charging" and world.ritual_tier > 0:
			_ritual_lab.text = tr("ui.hud.ritual.tier").replace("{n}", str(world.ritual_tier))
			_ritual_lab.visible = true
		else:
			_ritual_lab.visible = false
	if _alert_lab == null:
		return
	var alerts: Array[String] = []
	var reliquary_time: float = -1.0
	var geode_time: float = INF
	if world.obstacles != null:
		for i: int in world.obstacles.cap:
			if world.obstacles.alive[i] == 0:
				continue
			var obs: SimObstacle = world.obstacles.items[i]
			if obs.type == &"obelisk" and obs.state == &"trial_active" and obs.sub_kind == "obelisk-reliquary":
				reliquary_time = maxf(reliquary_time, maxf(0.0, obs.trial_timer))
			elif obs.type == &"geode" and obs.state == &"intact" and obs.collapse_timer >= 0.0:
				geode_time = minf(geode_time, maxf(0.0, obs.collapse_timer))
	if reliquary_time >= 0.0 or world.obelisk_armor_debuff < -0.001:
		var t_val: float = maxf(0.0, reliquary_time)
		var txt: String = tr("ui.hud.reliquary.trial").replace("{s}", "%.1f" % t_val)
		if world.obelisk_armor_debuff < -0.001:
			txt += " (%d%% Armor)" % int(round(world.obelisk_armor_debuff * 100.0))
		alerts.append(txt)
	if geode_time < INF:
		alerts.append(tr("ui.hud.geode").replace("{s}", "%.1f" % geode_time))
	_alert_lab.text = "   |   ".join(alerts)
	_alert_lab.visible = not alerts.is_empty()


func _sync_interact_prompt(world: SimWorld) -> void:
	if _interact_panel == null or _interact_lab == null:
		return
	var key_txt: String = _action_key_label("interact", "E")
	var prompt: String = ""
	var px: float = world.player.x
	var py: float = world.player.y
	if world.teleporter_state == &"ready":
		var tel_dist: float = Vector2(px, py).distance_to(Vector2(world.teleporter_x, world.teleporter_y))
		if tel_dist <= world.teleporter_radius:
			prompt = "[%s] %s" % [key_txt, tr("ui.hud.channel")]
	if prompt == "" and not world.portals.is_empty():
		var default_pr: float = float(world.catalog.loop.get("portalRadius", 70.0))
		var best_dist: float = INF
		var best_portal: Dictionary = {}
		for portal: Dictionary in world.portals:
			var pr: float = float(portal.get("radius", default_pr))
			var d: float = Vector2(px, py).distance_to(Vector2(float(portal.get("x", 0.0)), float(portal.get("y", 0.0))))
			if d <= pr and d < best_dist:
				best_dist = d
				best_portal = portal
		if not best_portal.is_empty():
			var kind: String = String(best_portal.get("kind", "next"))
			var target_id: String = String(best_portal.get("target_stage_id", ""))
			if kind == "demo-seal":
				prompt = "[%s] Complete Demo Seal" % key_txt
			elif kind == "true-ending":
				prompt = "[%s] Claim the True Seal" % key_txt
			elif kind == "crimson" or target_id == "prima-materia-core":
				prompt = "[%s] %s" % [key_txt, tr("ui.hud.portal.core")]
			elif kind == "secret" or target_id == "aether-vault":
				prompt = "[%s] %s" % [key_txt, tr("ui.hud.portal.vault")]
			elif kind == "gold":
				prompt = "[%s] %s" % [key_txt, tr("ui.hud.ouroboros")]
			elif kind == "branch" or (target_id != "" and kind == "next"):
				prompt = "[%s] %s" % [key_txt, tr("ui.hud.portal.branch").replace("{stage}", Loc.stage_name(target_id))]
			else:
				prompt = "[%s] %s" % [key_txt, tr("ui.hud.descend")]
	if prompt == "" and world.obstacles != null:
		var blocked: bool = world.teleporter_state == &"charging" or (world.boss_spawned and not world.boss_defeated)
		if not blocked:
			var ob_cfg: Dictionary = DictUtil.d(world.catalog.obstacles, "siphonObelisk")
			var interact_r: float = float(ob_cfg.get("interactRadius", 64.0))
			var channel_dur: float = maxf(0.01, float(ob_cfg.get("channelDuration", 2.0)))
			var best_ob_dist: float = INF
			var best_ob: SimObstacle = null
			for i: int in world.obstacles.cap:
				if world.obstacles.alive[i] == 0:
					continue
				var obs: SimObstacle = world.obstacles.items[i]
				if obs.type != &"obelisk":
					continue
				if obs.state != &"idle" and obs.state != &"channeling":
					continue
				var d_ob: float = Vector2(px, py).distance_to(Vector2(obs.x, obs.y))
				if d_ob <= interact_r and d_ob < best_ob_dist:
					best_ob_dist = d_ob
					best_ob = obs
			if best_ob != null:
				if best_ob.state == &"channeling":
					var pct: int = clampi(int(round((best_ob.progress / channel_dur) * 100.0)), 0, 100)
					prompt = "%s (%d%%)" % [tr("ui.hud.obelisk.channel"), pct]
				else:
					var ob_key: String = "obstacle.%s.name" % best_ob.sub_kind
					var ob_name: String = tr(ob_key)
					if ob_name == ob_key or ob_name == "":
						ob_name = tr("ui.hud.obelisk.channel")
					prompt = "[%s] %s" % [key_txt, ob_name]
	_interact_lab.text = prompt
	_interact_panel.visible = prompt != ""


func _on_draw_layer() -> void:
	if _draw_layer == null or _world == null or not visible:
		return
	_draw_world_rings(_world)
	_draw_overheat_arc(_world)


func _draw_overheat_arc(world: SimWorld) -> void:
	var oh_cfg: Dictionary = DictUtil.d(world.catalog.loop, "overheat")
	if not bool(oh_cfg.get("enabled", true)):
		return
	var heat: float = clampf(world.player.heat, 0.0, 1.0)
	var lockout: float = world.player.overheat_lockout_remain
	if heat <= 0.01 and lockout <= 0.0:
		return
	var center: Vector2 = _draw_layer.get_local_mouse_position()
	var vp_rect: Rect2 = _draw_layer.get_rect()
	if center == Vector2.ZERO or not vp_rect.has_point(center):
		center = _world_to_hud(world.player.x, world.player.y) + Vector2(0.0, -34.0)
	var radius: float = 26.0
	var start_ang: float = deg_to_rad(-225.0)
	var end_ang: float = deg_to_rad(45.0)
	var span_ang: float = end_ang - start_ang
	var sweet_lo: float = clampf(float(oh_cfg.get("sweetSpotMin", 0.80)), 0.0, 0.99)
	var sweet_hi: float = clampf(float(oh_cfg.get("sweetSpotMax", 0.99)), sweet_lo, 1.0)
	var font: Font = ThemeDB.fallback_font
	_draw_layer.draw_arc(center, radius, start_ang, end_ang, 28, Color(0.08, 0.06, 0.08, 0.72), 5.0, true)
	if lockout > 0.0:
		var pulse: float = 0.55 + 0.45 * absf(sin(world.run_time * 14.0))
		_draw_layer.draw_arc(center, radius, start_ang, end_ang, 28, Color(0.95, 0.22, 0.20, 0.85 * pulse), 5.0, true)
		var bf_txt: String = tr("ui.hud.overheat.backfire")
		if font != null:
			_draw_layer.draw_string(font, center + Vector2(-46.0, radius + 16.0), bf_txt, HORIZONTAL_ALIGNMENT_CENTER, 92.0, 10, Color(1.0, 0.42, 0.36, 0.95))
		return
	var s_start: float = start_ang + span_ang * sweet_lo
	var s_end: float = start_ang + span_ang * sweet_hi
	_draw_layer.draw_arc(center, radius, s_start, s_end, 12, Color(0.32, 0.90, 0.96, 0.65), 6.0, true)
	var in_sweet: bool = heat >= sweet_lo and heat <= sweet_hi
	var fill_col: Color = Color(0.95, 0.68, 0.22, 0.95)
	if in_sweet:
		fill_col = Color(0.45, 0.96, 0.98, 0.98)
	elif heat >= 0.55:
		fill_col = Color(0.96, 0.40, 0.16, 0.95)
	_draw_layer.draw_arc(center, radius, start_ang, start_ang + span_ang * heat, 28, fill_col, 4.5, true)
	if in_sweet and font != null:
		var vent_txt: String = tr("ui.hud.overheat.vent")
		_draw_layer.draw_string(font, center + Vector2(-56.0, radius + 16.0), vent_txt, HORIZONTAL_ALIGNMENT_CENTER, 112.0, 10, Color(0.55, 0.98, 1.0, 0.98))


func _draw_world_rings(world: SimWorld) -> void:
	var font: Font = ThemeDB.fallback_font
	if world.teleporter_state == &"charging":
		var eff_r: float = SimLoop.effective_teleporter_radius(world)
		var tp_pos: Vector2 = _world_to_hud(world.teleporter_x, world.teleporter_y)
		var edge_pos: Vector2 = _world_to_hud(world.teleporter_x + eff_r, world.teleporter_y)
		var scr_r: float = tp_pos.distance_to(edge_pos)
		if scr_r >= 8.0 and scr_r <= 1000.0:
			var tel_pct: float = clampf(world.teleporter_charge / maxf(world.teleporter_hold, 0.001), 0.0, 1.0)
			_draw_layer.draw_arc(tp_pos, scr_r, 0.0, TAU, 48, Color(0.10, 0.08, 0.10, 0.35), 2.5, true)
			_draw_layer.draw_arc(tp_pos, scr_r, -PI * 0.5, -PI * 0.5 + TAU * tel_pct, 48, Color(0.90, 0.78, 0.47, 0.72), 3.0, true)
			var tel_cfg: Dictionary = DictUtil.d(world.catalog.loop, "teleporter")
			var tiers: Array = DictUtil.a(tel_cfg, "ritualTiers")
			var thresholds: Array[float] = [
				float(tiers[0]) if tiers.size() > 0 else 0.33,
				float(tiers[1]) if tiers.size() > 1 else 0.66,
				float(tiers[2]) if tiers.size() > 2 else 1.0,
			]
			for t_frac: float in thresholds:
				var ang: float = -PI * 0.5 + TAU * clampf(t_frac, 0.0, 1.0)
				var p0: Vector2 = tp_pos + Vector2(cos(ang), sin(ang)) * (scr_r - 5.0)
				var p1: Vector2 = tp_pos + Vector2(cos(ang), sin(ang)) * (scr_r + 5.0)
				var hit_col: Color = UiAtlas.GOLD_MOLTEN if tel_pct >= t_frac else UiAtlas.ASH
				_draw_layer.draw_line(p0, p1, hit_col, 2.0, true)
	if world.obstacles == null:
		return
	var ob_cfg: Dictionary = DictUtil.d(world.catalog.obstacles, "siphonObelisk")
	var channel_dur: float = maxf(0.01, float(ob_cfg.get("channelDuration", 2.0)))
	var rel_dur: float = maxf(0.01, float(DictUtil.d(ob_cfg, "reliquary").get("trialDuration", 20.0)))
	var geo_cfg: Dictionary = DictUtil.d(world.catalog.loop, "mercuryGeode")
	var geo_dur: float = maxf(0.01, float(geo_cfg.get("collapseDuration", 12.0)))
	var hud_bounds: Rect2 = _draw_layer.get_rect().grow(64.0)
	for i: int in world.obstacles.cap:
		if world.obstacles.alive[i] == 0:
			continue
		var obs: SimObstacle = world.obstacles.items[i]
		if obs.type == &"obelisk":
			if obs.state != &"channeling" and obs.state != &"trial_active":
				continue
			var spos: Vector2 = _world_to_hud(obs.x, obs.y)
			if not hud_bounds.has_point(spos):
				continue
			if obs.state == &"channeling":
				var pct: float = clampf(obs.progress / channel_dur, 0.0, 1.0)
				_draw_obelisk_dual_meter(spos, pct, 0.0, _obelisk_outer_color(obs.sub_kind))
			elif obs.sub_kind == "obelisk-reliquary":
				var pct_r: float = clampf(obs.trial_timer / rel_dur, 0.0, 1.0)
				_draw_obelisk_dual_meter(spos, 1.0, pct_r, _obelisk_outer_color(obs.sub_kind))
				if font != null:
					_draw_layer.draw_string(font, spos + Vector2(-28.0, -36.0), "%.1fs" % maxf(0.0, obs.trial_timer), HORIZONTAL_ALIGNMENT_CENTER, 56.0, 10, UiAtlas.BRASS_BRIGHT)
			else:
				var outer_pct: float = 1.0 if obs.trial_remaining > 0 else 0.0
				_draw_obelisk_dual_meter(spos, 1.0, outer_pct, _obelisk_outer_color(obs.sub_kind))
				if font != null and obs.trial_remaining > 0:
					_draw_layer.draw_string(font, spos + Vector2(-24.0, -36.0), "%d left" % obs.trial_remaining, HORIZONTAL_ALIGNMENT_CENTER, 48.0, 10, UiAtlas.PARCHMENT)
		elif obs.type == &"geode" and obs.state == &"intact" and obs.collapse_timer >= 0.0:
			var gpos: Vector2 = _world_to_hud(obs.x, obs.y)
			if not hud_bounds.has_point(gpos):
				continue
			var pct_g: float = clampf(obs.collapse_timer / geo_dur, 0.0, 1.0)
			_draw_ring_meter(gpos, 24.0, pct_g, Color("7ee8fa"))
			if font != null:
				_draw_layer.draw_string(font, gpos + Vector2(-28.0, -30.0), "%.1fs" % maxf(0.0, obs.collapse_timer), HORIZONTAL_ALIGNMENT_CENTER, 56.0, 10, Color("a8f5ff"))


func _obelisk_outer_color(sub_kind: String) -> Color:
	if sub_kind == "obelisk-blood":
		return Color("e83b3b")
	if sub_kind == "obelisk-reliquary":
		return Color("e5c878")
	return Color("5ad4ff")


func _draw_obelisk_dual_meter(center: Vector2, inner_pct: float, outer_pct: float, outer_col: Color) -> void:
	if UiAtlas.has_frame("hud-obelisk-meter"):
		var tex: Texture2D = UiAtlas.frame("hud-obelisk-meter")
		if tex != null:
			_draw_layer.draw_texture_rect(tex, Rect2(center - Vector2(32.0, 32.0), Vector2(64.0, 64.0)), false)
			if inner_pct > 0.005:
				_draw_layer.draw_arc(center, 17.75, -PI * 0.5, -PI * 0.5 + TAU * clampf(inner_pct, 0.0, 1.0), 28, UiAtlas.BRASS_BRIGHT, 2.5, true)
			if outer_pct > 0.005:
				_draw_layer.draw_arc(center, 27.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(outer_pct, 0.0, 1.0), 32, outer_col, 2.5, true)
			return
	_draw_ring_meter(center, 26.0, outer_pct if outer_pct > 0.005 else inner_pct, outer_col if outer_pct > 0.005 else UiAtlas.GOLD_MOLTEN)


func _draw_ring_meter(center: Vector2, radius: float, pct: float, color: Color) -> void:
	_draw_layer.draw_arc(center, radius, 0.0, TAU, 28, Color(0.06, 0.04, 0.06, 0.72), 4.0, true)
	if pct > 0.005:
		_draw_layer.draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(pct, 0.0, 1.0), 28, color, 3.5, true)


func _world_to_hud(wx: float, wy: float) -> Vector2:
	if _cached_world_vp == null or not is_instance_valid(_cached_world_vp):
		var tree: SceneTree = get_tree()
		if tree != null and tree.root != null:
			var arena: Node = tree.root.find_child("Arena", true, false)
			if arena != null:
				_cached_world_vp = arena.get_viewport()
	if _cached_world_vp != null and is_instance_valid(_cached_world_vp):
		var vp_pt: Vector2 = _cached_world_vp.get_canvas_transform() * Vector2(wx, wy)
		if _cached_world_vp is SubViewport:
			var vp_parent: Node = _cached_world_vp.get_parent()
			if vp_parent is Control:
				var ctrl: Control = vp_parent as Control
				var sv: SubViewport = _cached_world_vp as SubViewport
				var sx: float = ctrl.size.x / float(maxi(1, sv.size.x)) if sv.size.x > 0 else 1.0
				var sy: float = ctrl.size.y / float(maxi(1, sv.size.y)) if sv.size.y > 0 else 1.0
				var global_pt: Vector2 = ctrl.get_global_transform_with_canvas() * Vector2(vp_pt.x * sx, vp_pt.y * sy)
				if _draw_layer != null:
					return _draw_layer.get_global_transform_with_canvas().affine_inverse() * global_pt
				return global_pt
		return vp_pt
	return get_viewport().get_canvas_transform() * Vector2(wx, wy)


func _short_action_key(action: String, fallback: String) -> String:
	var label: String = _action_key_label(action, fallback)
	if label.length() > 5:
		if label.begins_with("Left "):
			return "LMB"
		if label.begins_with("Right "):
			return "RMB"
		if label.begins_with("Middle "):
			return "MMB"
		return label.substr(0, 5)
	return label


func _action_key_label(action: String, fallback: String) -> String:
	if not InputMap.has_action(action):
		return fallback
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	for ev: InputEvent in events:
		if ev is InputEventKey:
			var ek: InputEventKey = ev as InputEventKey
			var k: int = ek.physical_keycode if ek.physical_keycode != KEY_NONE else ek.keycode
			if k != KEY_NONE:
				var k_txt: String = OS.get_keycode_string(k)
				if k_txt != "":
					return k_txt.to_upper()
		elif ev is InputEventMouseButton:
			var emb: InputEventMouseButton = ev as InputEventMouseButton
			match emb.button_index:
				MOUSE_BUTTON_LEFT:
					return "LMB"
				MOUSE_BUTTON_RIGHT:
					return "RMB"
				MOUSE_BUTTON_MIDDLE:
					return "MMB"
				_:
					return "M%d" % emb.button_index
	return fallback
