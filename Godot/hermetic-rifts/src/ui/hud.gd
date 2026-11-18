class_name HudView
extends Control

const DIFF_SEG_W: float = 72.0
const DIFF_MARKER_X: float = 44.0
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
var _corner: TextureRect
var _kicker: Label
var _objective: Label
var _obj_fill: ColorRect
var _obj_detail: Label
var _obj_sub: Label
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
var _skill_sweeps: Array[ColorRect] = []
var _skill_slots: Array[Control] = []
var _item_list: GridContainer
var _last_item_key: String = ""
var _last_skill_bind: String = ""
var _built: bool = false


func _ready() -> void:
	_build()


func sync(world: SimWorld) -> void:
	if not _built:
		_build()
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
		<= world.teleporter_radius
	)
	var portal_r: float = float(world.catalog.loop.get("portalRadius", 70.0))
	var portal_in: bool = (
		world.portal_open
		and Vector2(world.player.x, world.player.y).distance_to(Vector2(world.portal_x, world.portal_y)) <= portal_r
	)
	var ouroboros: bool = SimLoop.can_seal(world)
	var outside: bool = (world.teleporter_state == &"charging" and not tel_in) or (world.portal_open and not portal_in)
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
	_sync_difficulty(world.coefficient)
	_sync_skills(world)
	_sync_items(world)
	_sync_vignette(biome)


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


func _build_objective() -> void:
	var root := VBoxContainer.new()
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
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 56.0
	col.offset_top = 34.0
	col.offset_right = -12.0
	col.offset_bottom = -10.0
	col.add_theme_constant_override("separation", 6)
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
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(header)
	_diff_tier = _label(10, DIFF_COLORS[0], UiAtlas.TYPE_MICRO)
	_diff_tier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_diff_tier)
	_diff_coeff = _label(11, Color("c7dcd0"), UiAtlas.TYPE_MICRO)
	_diff_coeff.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_diff_coeff)
	var viewport := Control.new()
	viewport.custom_minimum_size = Vector2(0, 16)
	viewport.clip_contents = true
	viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(viewport)
	_diff_tape = HBoxContainer.new()
	_diff_tape.add_theme_constant_override("separation", 0)
	_diff_tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_diff_tape.position = Vector2(DIFF_MARKER_X, 0.0)
	viewport.add_child(_diff_tape)
	var roman: Array[String] = ["I", "II", "III", "IV", "V", "VI"]
	for i: int in 6:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(DIFF_SEG_W, 16)
		seg.color = DIFF_COLORS[i].darkened(0.45)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_diff_tape.add_child(seg)
		var lab := _label(9, Color.WHITE, UiAtlas.TYPE_MICRO)
		lab.text = roman[i]
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		seg.add_child(lab)


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
	var flask_tex := TextureRect.new()
	flask_tex.texture = UiAtlas.frame("hud-flask")
	flask_tex.stretch_mode = TextureRect.STRETCH_SCALE
	flask_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flask_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flask_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flask_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flask.add_child(flask_tex)
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
		_skill_sweeps.append(sweep)


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
	var skills: Dictionary = world.survivor.get("skills", {})
	var bind: String = ""
	for i: int in SKILL_SLOTS.size():
		bind += "%s:%s|" % [String(SKILL_SLOTS[i]), String(skills.get(String(SKILL_SLOTS[i]), ""))]
	var rebind: bool = bind != _last_skill_bind
	if rebind:
		_last_skill_bind = bind
	for i: int in SKILL_SLOTS.size():
		var slot: StringName = SKILL_SLOTS[i]
		var id: String = String(skills.get(String(slot), ""))
		var empty: bool = id == ""
		var cd: float = float(world.player.skill_cd.get(slot, 0.0))
		var max_cd: float = 0.0
		if not empty:
			var def: Dictionary = world.catalog.skill(id)
			max_cd = float(def.get("cooldown", 1.0)) * world.stats.cooldown_mul
		if rebind:
			_skill_icons[i].texture = null if empty else UiAtlas.skill_tex(id)
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
