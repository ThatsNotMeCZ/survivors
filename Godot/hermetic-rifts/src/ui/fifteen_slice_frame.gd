class_name FifteenSliceFrame
extends Control

var frame_id: String = ""
var frame_state: String = "idle"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func configure(p_id: String, p_state: String = "idle") -> void:
	frame_id = p_id
	frame_state = p_state
	queue_redraw()


func set_state(p_state: String) -> void:
	if frame_state == p_state:
		return
	frame_state = p_state
	queue_redraw()


func _draw() -> void:
	if frame_id == "" or size.x < 2.0 or size.y < 2.0:
		return
	var tex: Texture2D = UiAtlas.ui_atlas_tex()
	if tex == null:
		return
	var src: Rect2 = UiAtlas.frame_region(frame_id, frame_state)
	if src.size.x <= 0.0 or src.size.y <= 0.0:
		return
	var meta: Dictionary = UiAtlas.frame_meta(frame_id)
	var nine_v: Variant = meta.get("nineSlice", null)
	if typeof(nine_v) != TYPE_DICTIONARY:
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, size), src)
		return
	var nine: Dictionary = nine_v as Dictionary
	var margins: Dictionary = nine.get("margins", {})
	var ml: float = float(margins.get("left", 0.0))
	var mr: float = float(margins.get("right", 0.0))
	var mt: float = float(margins.get("top", 0.0))
	var mb: float = float(margins.get("bottom", 0.0))
	var tile_edges: bool = String(nine.get("repeat", "stretch")) == "tile"

	var sw: float = src.size.x
	var sh: float = src.size.y
	var dw: float = size.x
	var dh: float = size.y

	# Clamp margins if destination is smaller than corner sum
	var eff_l: float = minf(ml, dw * 0.5)
	var eff_r: float = minf(mr, dw - eff_l)
	var eff_t: float = minf(mt, dh * 0.5)
	var eff_b: float = minf(mb, dh - eff_t)

	var mid_h: float = maxf(0.0, dh - eff_t - eff_b)
	var src_mid_h: float = maxf(0.0, sh - mt - mb)
	var mid_w: float = maxf(0.0, dw - eff_l - eff_r)
	var src_mid_w: float = maxf(0.0, sw - ml - mr)

	# Check for horizontal center ornament (15-slice: 5 columns x 3 rows)
	var has_center: bool = false
	var cx: float = 0.0
	var cw: float = 0.0
	var center_v: Variant = nine.get("center", null)
	if typeof(center_v) == TYPE_DICTIONARY:
		var cd: Dictionary = center_v as Dictionary
		cx = float(cd.get("x", 0.0))
		cw = float(cd.get("w", 0.0))
		if cw > 0.0 and cx >= ml and (cx + cw) <= (sw - mr) and dw >= (eff_l + cw + eff_r):
			has_center = true

	# Center interior well (clean solid fill — stretch cleanly)
	if mid_w > 0.0 and mid_h > 0.0 and src_mid_w > 0.0 and src_mid_h > 0.0:
		var dst_well := Rect2(eff_l, eff_t, mid_w, mid_h)
		var src_well := Rect2(src.position.x + ml, src.position.y + mt, src_mid_w, src_mid_h)
		draw_texture_rect_region(tex, dst_well, src_well)

	# Left & right vertical rails (middle row)
	if mid_h > 0.0 and src_mid_h > 0.0:
		if eff_l > 0.0:
			_draw_vband(tex, Rect2(0.0, eff_t, eff_l, mid_h), Rect2(src.position.x, src.position.y + mt, eff_l, src_mid_h), tile_edges)
		if eff_r > 0.0:
			_draw_vband(tex, Rect2(dw - eff_r, eff_t, eff_r, mid_h), Rect2(src.position.x + sw - eff_r, src.position.y + mt, eff_r, src_mid_h), tile_edges)

	# Top & bottom rows (either 5-column 15-slice or 3-column 9-slice)
	if eff_t > 0.0:
		_draw_cap_row(tex, 0.0, eff_t, src.position.y, eff_t, src.position.x, sw, dw, eff_l, eff_r, ml, mr, has_center, cx, cw, tile_edges)
	if eff_b > 0.0:
		_draw_cap_row(tex, dh - eff_b, eff_b, src.position.y + sh - eff_b, eff_b, src.position.x, sw, dw, eff_l, eff_r, ml, mr, has_center, cx, cw, tile_edges)


func _draw_cap_row(
	tex: Texture2D,
	dst_y: float,
	dst_h: float,
	src_y: float,
	src_h: float,
	src_x0: float,
	sw: float,
	dw: float,
	eff_l: float,
	eff_r: float,
	ml: float,
	mr: float,
	has_center: bool,
	cx: float,
	cw: float,
	tile_edges: bool,
) -> void:
	# Left corner
	if eff_l > 0.0:
		draw_texture_rect_region(tex, Rect2(0.0, dst_y, eff_l, dst_h), Rect2(src_x0, src_y, eff_l, src_h))
	# Right corner
	if eff_r > 0.0:
		draw_texture_rect_region(tex, Rect2(dw - eff_r, dst_y, eff_r, dst_h), Rect2(src_x0 + sw - eff_r, src_y, eff_r, src_h))

	if not has_center:
		var mid_w: float = dw - eff_l - eff_r
		var src_mid_w: float = sw - ml - mr
		if mid_w > 0.0 and src_mid_w > 0.0:
			_draw_hband(tex, Rect2(eff_l, dst_y, mid_w, dst_h), Rect2(src_x0 + ml, src_y, src_mid_w, src_h), tile_edges)
		return

	# 15-slice: Left-mid band | Unstretched centered ornament | Right-mid band
	var dst_cx: float = floor((dw - cw) * 0.5)
	var left_span: float = maxf(0.0, dst_cx - eff_l)
	var right_start: float = dst_cx + cw
	var right_span: float = maxf(0.0, (dw - eff_r) - right_start)

	var src_lm_w: float = maxf(0.0, cx - ml)
	var src_rm_x: float = cx + cw
	var src_rm_w: float = maxf(0.0, (sw - mr) - src_rm_x)

	if left_span > 0.0 and src_lm_w > 0.0:
		_draw_hband(tex, Rect2(eff_l, dst_y, left_span, dst_h), Rect2(src_x0 + ml, src_y, src_lm_w, src_h), tile_edges)
	draw_texture_rect_region(tex, Rect2(dst_cx, dst_y, cw, dst_h), Rect2(src_x0 + cx, src_y, cw, src_h))
	if right_span > 0.0 and src_rm_w > 0.0:
		_draw_hband(tex, Rect2(right_start, dst_y, right_span, dst_h), Rect2(src_x0 + src_rm_x, src_y, src_rm_w, src_h), tile_edges)


func _draw_hband(tex: Texture2D, dst: Rect2, src: Rect2, tile: bool) -> void:
	if not tile or src.size.x <= 1.0:
		draw_texture_rect_region(tex, dst, src)
		return
	var x: float = 0.0
	var step: float = src.size.x
	while x < dst.size.x:
		var seg_w: float = minf(step, dst.size.x - x)
		draw_texture_rect_region(
			tex,
			Rect2(dst.position.x + x, dst.position.y, seg_w, dst.size.y),
			Rect2(src.position.x, src.position.y, seg_w, src.size.y)
		)
		x += seg_w


func _draw_vband(tex: Texture2D, dst: Rect2, src: Rect2, tile: bool) -> void:
	if not tile or src.size.y <= 1.0:
		draw_texture_rect_region(tex, dst, src)
		return
	var y: float = 0.0
	var step: float = src.size.y
	while y < dst.size.y:
		var seg_h: float = minf(step, dst.size.y - y)
		draw_texture_rect_region(
			tex,
			Rect2(dst.position.x, dst.position.y + y, dst.size.x, seg_h),
			Rect2(src.position.x, src.position.y, src.size.x, seg_h)
		)
		y += seg_h
