class_name FloorStamp
extends RefCounted

const TILE: int = 64
static var _cache: Dictionary = {}


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
			_blit_tile(img, atlas_img, id, tx * TILE, ty * TILE)
	_blit_borders(img, atlas_img, theme, width, height)
	var tex := ImageTexture.create_from_image(img)
	_cache[theme] = tex
	return tex


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
