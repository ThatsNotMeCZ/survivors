shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "palette_utils.gdshaderinc"

uniform float u_kind : hint_range(0.0, 2.0) = 0.0;
uniform float u_time = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_seed = 1.0;
uniform float u_has_tex : hint_range(0.0, 1.0) = 0.0;
uniform float u_grid_px : hint_range(16.0, 128.0) = 64.0;

float pool_bubble(vec2 p, float speed, float scale) {
	vec2 sp = p * scale;
	vec2 cell = floor(sp);
	vec2 local = fract(sp) - vec2(0.5);
	float rx = px_hash21(cell + vec2(u_seed * 3.1, 7.7));
	float ry = px_hash21(cell + vec2(19.3, u_seed * 5.3));
	float life_t = fract(u_time * speed + rx * 6.28);
	float rad = sin(clamp(life_t / 0.85, 0.0, 1.0) * 3.14159) * (0.16 + ry * 0.12);
	vec2 offset = (vec2(rx, ry) - vec2(0.5)) * 0.35;
	return step(length(local - offset), rad) * step(0.04, rad) * step(life_t, 0.92);
}

void fragment() {
	vec2 uv = quantize_uv(UV, vec2(u_grid_px));
	vec2 p = (uv - 0.5) * 2.0;
	float r = length(p);
	float dither = px_bayer4(uv * u_grid_px + vec2(u_seed * 5.0, u_seed * 3.0));
	float fade = 1.0 - smoothstep(0.75, 1.0, u_progress);

	float edge_noise = px_fbm(p * 2.5 + vec2(u_seed * 2.1, -u_seed));
	float pool_r = 0.86 + (edge_noise - 0.5) * 0.22;
	float mask = smoothstep(pool_r, pool_r - 0.22, r);
	float rim = smoothstep(0.05, 0.42, mask);
	float keep = step(r, 1.0) * step(dither * 0.62, rim);
	if (u_has_tex > 0.5) {
		float ta = texture(TEXTURE, uv).a;
		keep *= step(0.08, ta);
	}

	vec2 flow = vec2(
		px_fbm(p * 1.9 + vec2(u_time * 0.18, -u_time * 0.14) + u_seed),
		px_fbm(p * 1.9 + vec2(-u_time * 0.14, u_time * 0.18) - u_seed)
	);
	float surface = px_fbm(p * 2.8 + flow * 0.8);
	float bubbles = clamp(pool_bubble(p + flow * 0.1, 0.28, 7.0) + pool_bubble(p - flow * 0.1 + 11.7, 0.34, 9.0), 0.0, 1.0);

	vec3 col = vec3(0.0);
	float alpha = 0.0;
	if (keep > 0.5 && mask > 0.02) {
		if (u_kind < 0.5) {
			vec3 deep_g = vec3(0.118, 0.282, 0.188);
			vec3 mid_g = vec3(0.137, 0.565, 0.388);
			vec3 bright_g = vec3(0.569, 0.859, 0.412);
			vec3 glint_g = vec3(0.835, 0.878, 0.294);
			col = mix(deep_g, mid_g, surface);
			col = mix(col, bright_g, step(0.54, surface) * 0.65);
			col = mix(col, glint_g, bubbles * 0.85);
			alpha = clamp((0.46 + surface * 0.34 + bubbles * 0.20) * mask * fade, 0.0, 0.88);
		} else if (u_kind < 1.5) {
			vec3 crust = vec3(0.180, 0.094, 0.082);
			vec3 magma = vec3(0.855, 0.255, 0.180);
			vec3 ember = vec3(0.969, 0.588, 0.090);
			vec3 glint = vec3(0.976, 0.840, 0.320);
			col = mix(crust, magma, surface);
			col = mix(col, ember, step(0.50, surface) * 0.70);
			col = mix(col, glint, bubbles * 0.90);
			alpha = clamp((0.48 + surface * 0.34 + bubbles * 0.22) * mask * fade, 0.0, 0.90);
		} else {
			float ridge = 1.0 - clamp(abs(surface - 0.5) * 4.2, 0.0, 1.0);
			vec3 deep_i = vec3(0.157, 0.361, 0.580);
			vec3 mid_i = vec3(0.310, 0.720, 0.940);
			vec3 shard_i = vec3(0.860, 0.960, 1.0);
			col = mix(deep_i, mid_i, surface);
			col = mix(col, shard_i, step(0.62, ridge) * 0.85);
			alpha = clamp((0.42 + surface * 0.28 + ridge * 0.28) * mask * fade, 0.0, 0.84);
		}
		col = lut_sample(col, u_lut_tex);
	}
	COLOR = vec4(col, alpha);
}
