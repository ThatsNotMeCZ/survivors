shader_type canvas_item;
render_mode unshaded;

uniform vec2 u_res = vec2(1920.0, 1080.0);
uniform vec2 u_center = vec2(0.5, 0.52);
uniform float u_locked = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	vec2 shift = vec2(100.0);
	mat2 rot = mat2(vec2(cos(0.5), sin(0.5)), vec2(-sin(0.5), cos(0.5)));
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = rot * p * 2.02 + shift;
		a *= 0.5;
	}
	return v;
}

float sigil_rings(vec2 p, float t) {
	float r = length(p);
	if (r > 1.25 || r < 0.02) {
		return 0.0;
	}
	float ring1 = smoothstep(0.025, 0.002, abs(r - 0.98));
	float ring2 = smoothstep(0.020, 0.002, abs(r - 0.90));
	float ring3 = smoothstep(0.016, 0.002, abs(r - 0.68));
	float ring4 = smoothstep(0.014, 0.002, abs(r - 0.44));
	float ring5 = smoothstep(0.016, 0.002, abs(r - 0.16));
	float angle = atan(p.y, p.x);
	float ticks1 = smoothstep(0.65, 0.95, cos((angle + t * 0.06) * 36.0)) * smoothstep(0.08, 0.0, abs(r - 0.94));
	float ticks2 = smoothstep(0.80, 0.98, cos((angle - t * 0.09) * 12.0)) * smoothstep(0.14, 0.0, abs(r - 0.56));
	float tri_angle = angle + t * 0.04;
	float geom = smoothstep(0.85, 0.99, cos(tri_angle * 3.0)) * smoothstep(0.20, 0.0, abs(r - 0.44));
	float glow_base = ring1 * 1.0 + ring2 * 0.75 + ring3 * 0.85 + ring4 * 0.70 + ring5 * 0.55;
	return glow_base + ticks1 * 0.85 + ticks2 * 0.70 + geom * 0.60;
}

float embers(vec2 uv, float t) {
	float acc = 0.0;
	for (int i = 0; i < 24; i++) {
		float fi = float(i);
		float speed = 0.10 + fract(fi * 0.317) * 0.16;
		float seed_x = fract(fi * 0.618);
		float x = (seed_x - 0.5) * 0.85 + sin(t * 1.4 + fi * 2.3) * 0.05;
		float y = fract(0.95 - (t * speed + fract(fi * 0.733))) * 1.15 - 0.1;
		vec2 pos = vec2(x, y);
		float dist = length(uv - pos);
		float spark = smoothstep(0.035, 0.002, dist);
		float flicker = 0.55 + 0.45 * sin(t * 8.5 + fi * 4.7);
		float life = smoothstep(0.95, 0.45, y) * smoothstep(-0.05, 0.2, y);
		acc += spark * flicker * life;
	}
	return acc;
}

void fragment() {
	vec2 res = max(u_res, vec2(1.0, 1.0));
	vec2 frag = vec2(UV.x, 1.0 - UV.y) * res;
	vec2 p = (frag - res * 0.5) / min(res.x, res.y);
	vec2 center_px = u_center * res;
	center_px.y = res.y - center_px.y;
	vec2 center_norm = (center_px - res * 0.5) / min(res.x, res.y);
	vec2 stage_coord = p - center_norm;

	vec3 bg_deep = vec3(0.065, 0.048, 0.080);
	vec3 bg_void = vec3(0.020, 0.015, 0.025);
	vec3 col = mix(bg_deep, bg_void, length(p) * 0.9);

	vec2 fog_uv = p * 1.5;
	fog_uv.y += TIME * 0.03;
	vec2 warp = vec2(
		fbm(fog_uv + vec2(0.0, TIME * 0.035)),
		fbm(fog_uv + vec2(5.2, TIME * 0.025))
	);
	float smoke = fbm(fog_uv + warp * 1.3);
	float center_falloff = smoothstep(1.3, 0.1, length(stage_coord));
	smoke *= (0.4 + 0.6 * center_falloff);
	vec3 smoke_cold = vec3(0.18, 0.13, 0.25);
	vec3 smoke_warm = mix(vec3(0.36, 0.18, 0.08), vec3(0.10, 0.14, 0.20), u_locked);
	col += mix(smoke_cold, smoke_warm, smoke * 0.7) * smoke * 0.55;

	vec2 ray_uv = stage_coord;
	float cone_width = 0.32 + (1.0 - ray_uv.y) * 0.26;
	float in_cone = smoothstep(cone_width, 0.0, abs(ray_uv.x));
	float ray_vertical = smoothstep(-0.65, 0.85, ray_uv.y);
	float ray_noise = noise(vec2(ray_uv.x * 5.0, ray_uv.y * 2.0 - TIME * 0.18));
	float beam = in_cone * ray_vertical * (0.60 + 0.40 * ray_noise);
	vec3 beam_color = mix(vec3(0.32, 0.25, 0.16), vec3(0.14, 0.16, 0.24), u_locked);
	col += beam_color * beam * 0.38;

	vec2 floor_coord = stage_coord;
	floor_coord.y += 0.24;
	floor_coord.y *= 2.8;
	float sigil_time = TIME * (1.0 - u_locked * 0.7);
	float sigil_mask = sigil_rings(floor_coord * 2.3, sigil_time);
	float seal_dist = length(floor_coord * 2.3);
	float seal_glow = smoothstep(1.4, 0.1, seal_dist) * 0.35;
	vec3 brass_col = vec3(0.86, 0.72, 0.38);
	vec3 ember_col = vec3(0.92, 0.42, 0.12);
	vec3 locked_sigil = vec3(0.28, 0.34, 0.44);
	float sigil_blink = 0.80 + 0.20 * sin(TIME * 1.2);
	vec3 active_sigil = mix(ember_col, brass_col, 0.65) * sigil_blink;
	vec3 sigil_color = mix(active_sigil, locked_sigil, u_locked);
	col += sigil_color * sigil_mask * (0.95 - u_locked * 0.45);
	col += mix(ember_col * 0.4, locked_sigil * 0.20, u_locked) * seal_glow;

	if (u_locked < 0.95) {
		vec2 ember_coord = stage_coord;
		ember_coord.y += 0.18;
		float emb = embers(ember_coord, TIME);
		col += vec3(0.98, 0.52, 0.14) * emb * 0.95;
	}

	float vignette = smoothstep(1.5, 0.4, length(p));
	col *= vignette;
	float grain = (hash(frag + fract(TIME)) - 0.5) * 0.025;
	col += grain;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
