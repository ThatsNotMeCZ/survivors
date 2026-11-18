uniform sampler2D u_lut_tex : filter_nearest, repeat_disable;
uniform float u_use_lut : hint_range(0.0, 1.0) = 0.0;

vec2 quantize_uv(vec2 uv, vec2 grid_px) {
	vec2 g = max(grid_px, vec2(1.0));
	return (floor(uv * g) + 0.5) / g;
}

vec2 quantize_uv_tex(vec2 uv, vec2 tex_pixel_size) {
	vec2 safe_px = max(tex_pixel_size, vec2(0.0001));
	vec2 res = max(vec2(1.0) / safe_px, vec2(1.0));
	return (floor(uv * res) + 0.5) / res;
}

vec3 lut_posterize(vec3 col, sampler2D lut) {
	vec3 c = clamp(col, vec3(0.0), vec3(1.0));
	float r = clamp(floor(c.r * 31.0 + 0.5), 0.0, 31.0);
	float g = clamp(floor(c.g * 31.0 + 0.5), 0.0, 31.0);
	float b = clamp(floor(c.b * 31.0 + 0.5), 0.0, 31.0);
	float x = b * 32.0 + r;
	float y = g;
	vec2 lut_uv = vec2((x + 0.5) / 1024.0, (y + 0.5) / 32.0);
	return texture(lut, lut_uv).rgb;
}

vec3 lut_sample(vec3 col, sampler2D lut_tex) {
	if (u_use_lut < 0.5) {
		return col;
	}
	return lut_posterize(col, lut_tex);
}

float px_hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

float px_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = px_hash21(i);
	float b = px_hash21(i + vec2(1.0, 0.0));
	float c = px_hash21(i + vec2(0.0, 1.0));
	float d = px_hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float px_fbm(vec2 p) {
	return 0.55 * px_vnoise(p) + 0.30 * px_vnoise(p * 2.07 + vec2(11.3, 7.1)) + 0.15 * px_vnoise(p * 4.19 + vec2(23.7, 17.9));
}

float px_bayer4(vec2 p) {
	vec2 f = floor(mod(p, 4.0));
	float x = f.x;
	float y = f.y;
	float v = 0.0;
	if (y < 0.5) {
		v = x < 0.5 ? 0.0 : (x < 1.5 ? 8.0 : (x < 2.5 ? 2.0 : 10.0));
	} else if (y < 1.5) {
		v = x < 0.5 ? 12.0 : (x < 1.5 ? 4.0 : (x < 2.5 ? 14.0 : 6.0));
	} else if (y < 2.5) {
		v = x < 0.5 ? 3.0 : (x < 1.5 ? 11.0 : (x < 2.5 ? 1.0 : 9.0));
	} else {
		v = x < 0.5 ? 15.0 : (x < 1.5 ? 7.0 : (x < 2.5 ? 13.0 : 5.0));
	}
	return v / 16.0;
}
