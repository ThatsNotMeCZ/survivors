class_name FloorStamp
extends RefCounted

const TILE: int = 64
static var _cache: Dictionary = {}
static var _tile_stamps: Dictionary = {}


static func texture_for(theme: String, width: int, height: int) -> Texture2D:
	if _cache.has(theme):
		return _cache[theme]
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.07, 0.05, 0.06, 1.0))
	var atlas_tex: Texture2D = UiAtlas.env_atlas_tex()
	var atlas_img: Image = atlas_tex.get_image() if atlas_tex != null else null
	var stamp_seed: int = 1013 if theme == "cinder" else (2027 if theme == "rime" else 3049)
	var max_tx: int = int(floor(float(width) / float(TILE)))
	var max_ty: int = int(floor(float(height) / float(TILE)))
	for ty: int in max_ty:
		for tx: int in max_tx:
			var cell: int = (tx * 73856093) ^ (ty * 19349663) ^ stamp_seed
			var rune: bool = (cell & 7) == 0 and tx > 1 and ty > 1 and tx < max_tx - 2 and ty < max_ty - 2
			var variant: int = (cell >> 3) & 3
			var suffix: String = "tile-rune-%d" % variant if rune else "tile-%d" % variant
			var id: String = ArenaBiome.env_id(theme, suffix)
			if not UiAtlas.env_has(id):
				id = ArenaBiome.env_id(theme, "tile-0")
			_blit_floor_tile(img, atlas_img, theme, id, tx * TILE, ty * TILE)
	_blit_borders(img, atlas_img, theme, width, height)
	var tex := ImageTexture.create_from_image(img)
	_cache[theme] = tex
	return tex


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
	if theme == "cinder":
		var is_ember: bool = r > 110 and float(r) > float(b) * 1.65
		if is_ember:
			r = int(round(58.0 + float(r - 58) * 0.68))
			g = int(round(42.0 + float(g - 42) * 0.65))
			b = int(round(40.0 + float(b - 40) * 0.75))
		else:
			r = mini(255, int(round(44.0 + float(r) * 0.72)))
			g = mini(255, int(round(35.0 + float(g) * 0.70)))
			b = mini(255, int(round(38.0 + float(b) * 0.70)))
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


static func _blit_tile(dest: Image, atlas: Image, id: String, dx: int, dy: int) -> void:
	if atlas == null:
		return
	var rect: Rect2 = UiAtlas.env_rect(id)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var src := Rect2i(int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y))
	dest.blit_rect(atlas, src, Vector2i(dx, dy))


static func _blit_borders(dest: Image, atlas: Image, theme: String, width: int, height: int) -> void:
	if atlas == null:
		return
	var h0: String = ArenaBiome.env_id(theme, "border-h-0")
	var v0: String = ArenaBiome.env_id(theme, "border-v-0")
	if UiAtlas.env_has(h0):
		var hr: Rect2 = UiAtlas.env_rect(h0)
		var hw: int = maxi(1, int(hr.size.x))
		var x: int = 0
		while x < width:
			_blit_tile(dest, atlas, h0, x, 0)
			_blit_tile(dest, atlas, h0, x, height - int(hr.size.y))
			x += hw
	if UiAtlas.env_has(v0):
		var vr: Rect2 = UiAtlas.env_rect(v0)
		var vh: int = maxi(1, int(vr.size.y))
		var y: int = 0
		while y < height:
			_blit_tile(dest, atlas, v0, 0, y)
			_blit_tile(dest, atlas, v0, width - int(vr.size.x), y)
			y += vh
