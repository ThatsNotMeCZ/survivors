class_name FloorStamp
extends RefCounted

const TILE: int = 64
const CHUNK_SIZE: int = 1024
const VOID_COLOR: Color = Color("0d0a0e")
const RIM_OBSIDIAN: Color = Color("0a080c")
const RIM_DITHER: Color = Color("18141c")
const RIM_ROT_STEPS: int = 32

static var _cache: Dictionary = {}
static var _chunk_cache: Dictionary = {}
static var _tile_stamps: Dictionary = {}
static var _rim_stamps: Dictionary = {}


static func build_chunks(
	theme: String,
	width: int,
	height: int,
	circular: bool = true,
	arena_radius: float = 3000.0,
) -> Array[Dictionary]:
	var w: int = width if width > 0 else int(ceil(arena_radius * 2.0))
	var h: int = height if height > 0 else int(ceil(arena_radius * 2.0))
	var key: String = "%s:%dx%d:%s:%.1f" % [theme, w, h, "c" if circular else "r", arena_radius]
	if _chunk_cache.has(key):
		return _chunk_cache[key] as Array[Dictionary]

	var atlas_tex: Texture2D = UiAtlas.env_atlas_tex()
	var atlas_img: Image = atlas_tex.get_image() if atlas_tex != null else null
	var stamp_seed: int = _seed_for_theme(theme)
	var chunks: Array[Dictionary] = []

	if circular:
		var outer_r: float = arena_radius + 32.0
		var half_tiles: int = int(ceil(outer_r / float(TILE)))
		var min_wx: int = -half_tiles * TILE
		var min_wy: int = -half_tiles * TILE
		var span: int = half_tiles * 2 * TILE
		var max_t_idx: int = half_tiles * 2
		var rim_inner_r: float = maxf(0.0, arena_radius - 28.0)
		var rim_inner_r2: float = rim_inner_r * rim_inner_r
		var outer_r2: float = outer_r * outer_r
		var cy0: int = min_wy
		while cy0 < min_wy + span:
			var ch: int = mini(CHUNK_SIZE, min_wy + span - cy0)
			var cx0: int = min_wx
			while cx0 < min_wx + span:
				var cw: int = mini(CHUNK_SIZE, min_wx + span - cx0)
				var near_x: float = clampf(0.0, float(cx0), float(cx0 + cw))
				var near_y: float = clampf(0.0, float(cy0), float(cy0 + ch))
				if near_x * near_x + near_y * near_y <= outer_r2:
					var far_x: float = maxf(absf(float(cx0)), absf(float(cx0 + cw)))
					var far_y: float = maxf(absf(float(cy0)), absf(float(cy0 + ch)))
					var is_boundary: bool = (far_x * far_x + far_y * far_y) >= rim_inner_r2
					var img: Image = Image.create(cw, ch, false, Image.FORMAT_RGBA8)
					img.fill(VOID_COLOR)
					_blit_chunk_tiles(img, atlas_img, theme, stamp_seed, cx0, cy0, cw, ch, true, 0.0, 0.0, outer_r2, half_tiles, max_t_idx)
					if is_boundary:
						_mask_circular_void_chunk(img, cx0, cy0, cw, ch, 0.0, 0.0, arena_radius)
						_stamp_circular_rim_chunk(img, theme, cx0, cy0, cw, ch, 0.0, 0.0, arena_radius)
					chunks.append({
						"rect": Rect2(float(cx0), float(cy0), float(cw), float(ch)),
						"texture": ImageTexture.create_from_image(img),
					})
				cx0 += CHUNK_SIZE
			cy0 += CHUNK_SIZE
	else:
		var max_tx: int = int(ceil(float(w) / float(TILE)))
		var max_ty: int = int(ceil(float(h) / float(TILE)))
		var cy0_r: int = 0
		while cy0_r < h:
			var ch_r: int = mini(CHUNK_SIZE, h - cy0_r)
			var cx0_r: int = 0
			while cx0_r < w:
				var cw_r: int = mini(CHUNK_SIZE, w - cx0_r)
				var img_r: Image = Image.create(cw_r, ch_r, false, Image.FORMAT_RGBA8)
				img_r.fill(VOID_COLOR)
				_blit_chunk_tiles(img_r, atlas_img, theme, stamp_seed, cx0_r, cy0_r, cw_r, ch_r, false, 0.0, 0.0, 0.0, 0, maxi(max_tx, max_ty))
				_blit_borders_chunk(img_r, atlas_img, theme, cx0_r, cy0_r, cw_r, ch_r, w, h)
				chunks.append({
					"rect": Rect2(float(cx0_r), float(cy0_r), float(cw_r), float(ch_r)),
					"texture": ImageTexture.create_from_image(img_r),
				})
				cx0_r += CHUNK_SIZE
			cy0_r += CHUNK_SIZE

	_chunk_cache[key] = chunks
	return chunks


static func texture_for(
	theme: String,
	width: int,
	height: int,
	circular: bool = true,
	arena_radius: float = 3000.0,
) -> Texture2D:
	var w: int = width if width > 0 else int(ceil(arena_radius * 2.0))
	var h: int = height if height > 0 else int(ceil(arena_radius * 2.0))
	var key: String = "%s:%dx%d:%s:%.1f" % [theme, w, h, "c" if circular else "r", arena_radius]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(VOID_COLOR)
	var atlas_tex: Texture2D = UiAtlas.env_atlas_tex()
	var atlas_img: Image = atlas_tex.get_image() if atlas_tex != null else null
	var stamp_seed: int = _seed_for_theme(theme)
	var cx: float = float(w) * 0.5
	var cy: float = float(h) * 0.5
	var max_tx: int = int(ceil(float(w) / float(TILE)))
	var max_ty: int = int(ceil(float(h) / float(TILE)))
	var outer_r2: float = (arena_radius + 32.0) * (arena_radius + 32.0)
	for ty: int in max_ty:
		for tx: int in max_tx:
			var dx_px: int = tx * TILE
			var dy_px: int = ty * TILE
			if circular:
				var near_x: float = clampf(cx, float(dx_px), float(dx_px + TILE)) - cx
				var near_y: float = clampf(cy, float(dy_px), float(dy_px + TILE)) - cy
				if near_x * near_x + near_y * near_y > outer_r2:
					continue
			var id: String = _tile_id(theme, tx, ty, max_tx, max_ty, stamp_seed)
			_blit_floor_tile(img, atlas_img, theme, id, dx_px, dy_px)
	if circular:
		_mask_circular_void_chunk(img, 0, 0, w, h, cx, cy, arena_radius)
		_stamp_circular_rim_chunk(img, theme, 0, 0, w, h, cx, cy, arena_radius)
	else:
		_blit_borders_chunk(img, atlas_img, theme, 0, 0, w, h, w, h)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _blit_chunk_tiles(
	dest: Image,
	atlas: Image,
	theme: String,
	stamp_seed: int,
	chunk_x: int,
	chunk_y: int,
	cw: int,
	ch: int,
	circular: bool,
	cx: float,
	cy: float,
	outer_r2: float,
	tile_offset: int,
	max_tiles: int,
) -> void:
	var tx0: int = int(floor(float(chunk_x) / float(TILE)))
	var tx1: int = int(ceil(float(chunk_x + cw) / float(TILE)))
	var ty0: int = int(floor(float(chunk_y) / float(TILE)))
	var ty1: int = int(ceil(float(chunk_y + ch) / float(TILE)))
	for ty: int in range(ty0, ty1):
		var wy: int = ty * TILE
		for tx: int in range(tx0, tx1):
			var wx: int = tx * TILE
			if circular:
				var near_x: float = clampf(cx, float(wx), float(wx + TILE)) - cx
				var near_y: float = clampf(cy, float(wy), float(wy + TILE)) - cy
				if near_x * near_x + near_y * near_y > outer_r2:
					continue
			var id: String = _tile_id(theme, tx + tile_offset, ty + tile_offset, max_tiles, max_tiles, stamp_seed)
			var stamp: Image = _floor_tile_stamp(atlas, theme, id)
			if stamp != null:
				_blit_clipped(dest, stamp, wx - chunk_x, wy - chunk_y)


static func _tile_id(theme: String, tx: int, ty: int, max_tx: int, max_ty: int, stamp_seed: int) -> String:
	var cell: int = (tx * 73856093) ^ (ty * 19349663) ^ stamp_seed
	var rune: bool = (cell & 7) == 0 and tx > 1 and ty > 1 and tx < max_tx - 2 and ty < max_ty - 2
	var variant: int = (cell >> 3) & 3
	var suffix: String = "tile-rune-%d" % variant if rune else "tile-%d" % variant
	var id: String = ArenaBiome.env_id(theme, suffix)
	if not UiAtlas.env_has(id):
		id = ArenaBiome.env_id(theme, "tile-0")
	return id


static func _seed_for_theme(theme: String) -> int:
	match theme:
		"cinder":
			return 1013
		"rime":
			return 2027
		"putrid":
			return 4057
		"foundry":
			return 5077
		"aether":
			return 6089
		"prima":
			return 7103
		_:
			return 3049


static func _mask_circular_void_chunk(
	img: Image,
	chunk_x: int,
	chunk_y: int,
	cw: int,
	ch: int,
	cx: float,
	cy: float,
	arena_radius: float,
) -> void:
	var outer_r: float = arena_radius + 32.0
	var inner_r: float = maxf(0.0, arena_radius - 2.0)
	var outer_r2: float = outer_r * outer_r
	var inner_r2: float = inner_r * inner_r
	for ly: int in ch:
		var wy: int = chunk_y + ly
		var dy: float = float(wy) + 0.5 - cy
		var dy2: float = dy * dy
		if dy2 >= outer_r2:
			img.fill_rect(Rect2i(0, ly, cw, 1), VOID_COLOR)
			continue
		var outer_dx: float = sqrt(outer_r2 - dy2)
		var ox0: int = clampi(int(floor(cx - outer_dx)) - chunk_x, 0, cw)
		var ox1: int = clampi(int(ceil(cx + outer_dx)) - chunk_x, 0, cw)
		if ox0 > 0:
			img.fill_rect(Rect2i(0, ly, ox0, 1), VOID_COLOR)
		if ox1 < cw:
			img.fill_rect(Rect2i(ox1, ly, cw - ox1, 1), VOID_COLOR)
		if dy2 >= inner_r2:
			_dither_rim_span(img, ly, wy, ox0, ox1, chunk_x, cx, dy, arena_radius)
		else:
			var in_dx: float = sqrt(inner_r2 - dy2)
			var ix0: int = clampi(int(ceil(cx - in_dx)) - chunk_x, ox0, ox1)
			var ix1: int = clampi(int(floor(cx + in_dx)) - chunk_x, ox0, ox1)
			_dither_rim_span(img, ly, wy, ox0, ix0, chunk_x, cx, dy, arena_radius)
			_dither_rim_span(img, ly, wy, ix1, ox1, chunk_x, cx, dy, arena_radius)


static func _dither_rim_span(
	img: Image,
	ly: int,
	wy: int,
	x_start: int,
	x_end: int,
	chunk_x: int,
	cx: float,
	dy: float,
	arena_radius: float,
) -> void:
	for lx: int in range(x_start, x_end):
		var wx: int = chunk_x + lx
		var dx: float = float(wx) + 0.5 - cx
		var d: float = sqrt(dx * dx + dy * dy)
		if d < arena_radius:
			continue
		if d <= arena_radius + 4.0:
			img.set_pixel(lx, ly, RIM_OBSIDIAN)
			continue
		if d > arena_radius + 32.0:
			img.set_pixel(lx, ly, VOID_COLOR)
			continue
		var t: float = clampf((d - (arena_radius + 4.0)) / 28.0, 0.0, 1.0)
		var bayer: float = _bayer4(wx, wy)
		if t > bayer:
			img.set_pixel(lx, ly, VOID_COLOR)
		else:
			img.set_pixel(lx, ly, RIM_DITHER)


static func _bayer4(x: int, y: int) -> float:
	var bx: int = x & 3
	var by: int = y & 3
	var idx: int = by * 4 + bx
	const MATRIX: PackedInt32Array = [
		0, 8, 2, 10,
		12, 4, 14, 6,
		3, 11, 1, 9,
		15, 7, 13, 5,
	]
	return float(MATRIX[idx]) / 16.0


static func _stamp_circular_rim_chunk(
	img: Image,
	theme: String,
	chunk_x: int,
	chunk_y: int,
	cw: int,
	ch: int,
	cx: float,
	cy: float,
	arena_radius: float,
) -> void:
	var rim_tex: Texture2D = UiAtlas.generated_tex("env/arena-rim-curved.png", 64, Color("3c3342"))
	if rim_tex == null:
		return
	var src: Image = rim_tex.get_image()
	if src == null or src.get_width() < 64 or src.get_height() < 32:
		return
	var steps: int = maxi(16, int(round((TAU * arena_radius) / 26.0)))
	for k: int in steps:
		var ang: float = (float(k) / float(steps)) * TAU
		var rot_rad: float = ang - PI * 0.5
		var rot_idx: int = posmod(int(round((rot_rad / TAU) * float(RIM_ROT_STEPS))), RIM_ROT_STEPS)
		var cell: int = 0 if k % 6 == 0 else 1
		var stamp: Image = _rim_stamp(src, theme, cell, rot_idx)
		if stamp == null:
			continue
		var sw: int = stamp.get_width()
		var sh: int = stamp.get_height()
		var lx: int = int(round(cx + cos(ang) * arena_radius)) - sw / 2 - chunk_x
		var ly: int = int(round(cy + sin(ang) * arena_radius)) - sh / 2 - chunk_y
		if lx + sw <= 0 or ly + sh <= 0 or lx >= cw or ly >= ch:
			continue
		_blend_clipped(img, stamp, lx, ly)


static func _blit_clipped(dest: Image, stamp: Image, dx: int, dy: int) -> void:
	var dw: int = dest.get_width()
	var dh: int = dest.get_height()
	var sw: int = stamp.get_width()
	var sh: int = stamp.get_height()
	var sx0: int = maxi(0, -dx)
	var sy0: int = maxi(0, -dy)
	var sx1: int = mini(sw, dw - dx)
	var sy1: int = mini(sh, dh - dy)
	if sx1 <= sx0 or sy1 <= sy0:
		return
	dest.blit_rect(stamp, Rect2i(sx0, sy0, sx1 - sx0, sy1 - sy0), Vector2i(dx + sx0, dy + sy0))


static func _blend_clipped(dest: Image, stamp: Image, dx: int, dy: int) -> void:
	var dw: int = dest.get_width()
	var dh: int = dest.get_height()
	var sw: int = stamp.get_width()
	var sh: int = stamp.get_height()
	var sx0: int = maxi(0, -dx)
	var sy0: int = maxi(0, -dy)
	var sx1: int = mini(sw, dw - dx)
	var sy1: int = mini(sh, dh - dy)
	if sx1 <= sx0 or sy1 <= sy0:
		return
	dest.blend_rect(stamp, Rect2i(sx0, sy0, sx1 - sx0, sy1 - sy0), Vector2i(dx + sx0, dy + sy0))


static func _rim_stamp(src: Image, theme: String, cell: int, rot_idx: int) -> Image:
	var key: String = "%s:%d:%d" % [theme, cell, rot_idx]
	if _rim_stamps.has(key):
		return _rim_stamps[key]
	var base := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	base.blit_rect(src, Rect2i(cell * 32, 0, 32, 32), Vector2i.ZERO)
	_tint_rim_block(base, theme)
	var out_size: int = 38
	var rotated := Image.create(out_size, out_size, false, Image.FORMAT_RGBA8)
	rotated.fill(Color(0, 0, 0, 0))
	var theta: float = (float(rot_idx) / float(RIM_ROT_STEPS)) * TAU
	var ca: float = cos(theta)
	var sa: float = sin(theta)
	var half_out: float = float(out_size) * 0.5
	var half_src: float = 16.0
	for y: int in out_size:
		var dy: float = float(y) + 0.5 - half_out
		for x: int in out_size:
			var dx: float = float(x) + 0.5 - half_out
			var sx: int = int(floor(dx * ca + dy * sa + half_src))
			var sy: int = int(floor(-dx * sa + dy * ca + half_src))
			if sx < 0 or sy < 0 or sx >= 32 or sy >= 32:
				continue
			var col: Color = base.get_pixel(sx, sy)
			if col.a > 0.05:
				rotated.set_pixel(x, y, col)
	_rim_stamps[key] = rotated
	return rotated


static func _tint_rim_block(img: Image, theme: String) -> void:
	if theme == "cinder" or theme == "foundry" or theme == "prima":
		return
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.05 or (c.r < 0.08 and c.g < 0.08 and c.b < 0.08):
				continue
			if theme == "rime" or theme == "glacial":
				img.set_pixel(x, y, Color(c.r * 0.72, c.g * 0.88, minf(1.0, c.b * 1.15), c.a))
			elif theme == "putrid":
				img.set_pixel(x, y, Color(c.r * 0.72, minf(1.0, c.g * 1.12), c.b * 0.78, c.a))
			elif theme == "aether":
				img.set_pixel(x, y, Color(c.r * 0.92, c.g * 0.76, minf(1.0, c.b * 1.18), c.a))


static func _blit_floor_tile(dest: Image, atlas: Image, theme: String, id: String, dx: int, dy: int) -> void:
	var stamp: Image = _floor_tile_stamp(atlas, theme, id)
	if stamp == null:
		return
	dest.blit_rect(stamp, Rect2i(0, 0, stamp.get_width(), stamp.get_height()), Vector2i(dx, dy))


static func _floor_tile_stamp(atlas: Image, theme: String, id: String) -> Image:
	var key: String = "%s:%s" % [theme, id]
	if _tile_stamps.has(key):
		return _tile_stamps[key]
	if atlas == null:
		return null
	var rect: Rect2 = UiAtlas.env_rect(id)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return null
	var w: int = int(rect.size.x)
	var h: int = int(rect.size.y)
	var stamp := Image.create(w, h, false, Image.FORMAT_RGBA8)
	stamp.blit_rect(atlas, Rect2i(int(rect.position.x), int(rect.position.y), w, h), Vector2i.ZERO)
	_darken_floor_stamp(stamp, theme)
	_tile_stamps[key] = stamp
	return stamp


static func _darken_floor_stamp(img: Image, theme: String) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y: int in h:
		for x: int in w:
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.06:
				continue
			img.set_pixel(x, y, _darken_floor_color(theme, c))


static func _darken_floor_color(theme: String, c: Color) -> Color:
	var r: int = int(round(c.r * 255.0))
	var g: int = int(round(c.g * 255.0))
	var b: int = int(round(c.b * 255.0))
	if theme == "cinder" or theme == "foundry" or theme == "prima":
		var is_ember: bool = r > 110 and float(r) > float(b) * 1.65
		if is_ember:
			r = int(round(58.0 + float(r - 58) * 0.68))
			g = int(round(42.0 + float(g - 42) * 0.65))
			b = int(round(40.0 + float(b - 40) * 0.75))
		else:
			r = mini(255, int(round(44.0 + float(r) * 0.72)))
			g = mini(255, int(round(35.0 + float(g) * 0.70)))
			b = mini(255, int(round(38.0 + float(b) * 0.70)))
		if theme == "foundry":
			r = mini(255, int(round(float(r) * 0.92)))
			b = mini(255, int(round(float(b) * 1.15)))
		elif theme == "prima":
			r = mini(255, int(round(float(r) * 1.08)))
			g = int(round(float(g) * 0.88))
			b = int(round(float(b) * 0.85))
	elif theme == "putrid":
		r = int(round(24.0 + float(r) * 0.46))
		g = mini(135, int(round(36.0 + float(g) * 0.66)))
		b = int(round(28.0 + float(b) * 0.50))
	elif theme == "aether":
		r = mini(140, int(round(28.0 + float(r) * 0.54)))
		g = int(round(24.0 + float(g) * 0.46))
		b = mini(160, int(round(42.0 + float(b) * 0.66)))
	elif theme == "rime":
		var is_ice: bool = b > 160 and (g > 130 or float(b) > float(r) * 1.5)
		if is_ice:
			r = int(round(float(r) * 0.45))
			g = mini(130, int(round(float(g) * 0.50)))
			b = mini(150, int(round(float(b) * 0.56)))
		else:
			r = int(round(float(r) * 0.48))
			g = int(round(float(g) * 0.52))
			b = int(round(float(b) * 0.58))
	else:
		var is_bright: bool = b > 190 and g > 150
		if is_bright:
			r = int(round(float(r) * 0.38))
			g = mini(125, int(round(float(g) * 0.44)))
			b = mini(145, int(round(float(b) * 0.50)))
		else:
			r = int(round(float(r) * 0.42))
			g = int(round(float(g) * 0.46))
			b = int(round(float(b) * 0.52))
	return Color(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0, c.a)


static func _blit_tile_clipped(dest: Image, atlas: Image, id: String, wx: int, wy: int, chunk_x: int, chunk_y: int) -> void:
	if atlas == null:
		return
	var rect: Rect2 = UiAtlas.env_rect(id)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var stamp := Image.create(int(rect.size.x), int(rect.size.y), false, Image.FORMAT_RGBA8)
	stamp.blit_rect(atlas, Rect2i(int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y)), Vector2i.ZERO)
	_blit_clipped(dest, stamp, wx - chunk_x, wy - chunk_y)


static func _blit_borders_chunk(
	dest: Image,
	atlas: Image,
	theme: String,
	chunk_x: int,
	chunk_y: int,
	cw: int,
	ch: int,
	width: int,
	height: int,
) -> void:
	if atlas == null:
		return
	var h0: String = ArenaBiome.env_id(theme, "border-h-0")
	var v0: String = ArenaBiome.env_id(theme, "border-v-0")
	if UiAtlas.env_has(h0):
		var hr: Rect2 = UiAtlas.env_rect(h0)
		var hw: int = maxi(1, int(hr.size.x))
		var hh: int = int(hr.size.y)
		if chunk_y < hh or chunk_y + ch > height - hh:
			var x: int = int(floor(float(chunk_x) / float(hw))) * hw
			while x < chunk_x + cw and x < width:
				if chunk_y < hh:
					_blit_tile_clipped(dest, atlas, h0, x, 0, chunk_x, chunk_y)
				if chunk_y + ch > height - hh:
					_blit_tile_clipped(dest, atlas, h0, x, height - hh, chunk_x, chunk_y)
				x += hw
	if UiAtlas.env_has(v0):
		var vr: Rect2 = UiAtlas.env_rect(v0)
		var vw: int = int(vr.size.x)
		var vh: int = maxi(1, int(vr.size.y))
		if chunk_x < vw or chunk_x + cw > width - vw:
			var y: int = int(floor(float(chunk_y) / float(vh))) * vh
			while y < chunk_y + ch and y < height:
				if chunk_x < vw:
					_blit_tile_clipped(dest, atlas, v0, 0, y, chunk_x, chunk_y)
				if chunk_x + cw > width - vw:
					_blit_tile_clipped(dest, atlas, v0, width - vw, y, chunk_x, chunk_y)
				y += vh
