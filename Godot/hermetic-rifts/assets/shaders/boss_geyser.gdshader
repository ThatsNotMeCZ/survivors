shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "fx_pixel.gdshaderinc"

uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_style : hint_range(0.0, 2.0) = 0.0;
uniform float u_time = 0.0;
uniform float u_seed = 1.0;
uniform float u_layer : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 outc = vec4(0.0);
	vec2 grid = fx_grid_dim();
	vec2 uv = quantize_uv(UV, grid);
	vec2 cell = floor(uv * grid);
	float bayer = px_bayer4(cell);

	vec2 p_world = vec2((uv.x - 0.5) * u_quad_px.x, (uv.y - 0.6875) * u_quad_px.y);
	float base_r = max(u_quad_px.x * 0.404, 16.0);
	vec2 p_norm = p_world / base_r;
	float r_norm = length(p_norm);

	float env = sin(clamp(u_progress, 0.0, 1.0) * 3.14159265);
	float erode = smoothstep(0.58, 1.0, u_progress);

	if (u_layer < 0.5) {
		// Layer 0 (Ground): splashing liquid crown + concentric ripple rings (no cracks)
		if (r_norm <= 1.06) {
			float splash_n = px_fbm(p_norm * 3.5 + u_seed);
			float pool_base = (1.0 - smoothstep(0.25, 0.68 + (splash_n - 0.5) * 0.22, r_norm)) * (0.90 - u_progress * 0.30);
			float ring1_r = mix(0.20, 0.94, clamp(u_progress * 1.25, 0.0, 1.0));
			float ring2_r = mix(0.10, 0.64, clamp(u_progress * 1.15, 0.0, 1.0));
			float ring1 = (1.0 - smoothstep(0.035, 0.11, abs(r_norm - ring1_r))) * (1.0 - smoothstep(0.65, 1.0, u_progress));
			float ring2 = (1.0 - smoothstep(0.030, 0.09, abs(r_norm - ring2_r))) * (1.0 - smoothstep(0.75, 1.0, u_progress));
			float splash_mask = clamp(max(pool_base, max(ring1 * 0.92, ring2 * 0.85)), 0.0, 1.0);
			if (splash_mask > bayer * 0.42 + 0.04 + erode * 0.42) {
				float heat = clamp(
					0.25
					+ pool_base * 0.45
					+ step(0.54, splash_n) * 0.22
					+ ring1 * 0.48
					+ ring2 * 0.38,
					0.0,
					1.0
				) * (1.0 - u_progress * 0.25);
				vec3 col = fx_ramp(u_style, heat);
				outc = vec4(col, 0.94);
			}
		}
	} else if (u_reduce < 0.5 && p_world.y <= base_r * 0.30) {
		// Layer 1 (Overlay): vertical pixel geyser fountain + parabolic liquid droplets
		float col_h = clamp((base_r * 0.18 - p_world.y) / max(base_r * 2.35, 24.0), 0.0, 1.0);
		float swirl = (px_fbm(vec2(p_world.x * 0.055, col_h * 4.2 + u_time * 7.5 + u_seed)) - 0.5) * (base_r * 0.42) * (0.30 + col_h);
		float half_w = mix(base_r * 0.56, base_r * 0.22, col_h) * (0.60 + 0.48 * env);
		float x_norm = abs(p_world.x + swirl) / max(half_w, 1.0);
		float base_cut = smoothstep(base_r * 0.24, -base_r * 0.06, p_world.y);
		float top_cut = 1.0 - smoothstep(0.45, 0.98, col_h);
		float plume_noise = px_fbm(vec2((p_world.x + swirl) * 0.07, col_h * 5.0 + u_time * 9.5 + u_seed * 2.3));
		float jet = (1.0 - smoothstep(0.28, 1.02, x_norm)) * base_cut * top_cut * env;
		float col_mask = clamp(jet * (0.74 + 0.54 * plume_noise), 0.0, 1.0);
		float col_heat = clamp((1.0 - col_h * 0.72) * (1.0 - x_norm * 0.58) + step(0.52, plume_noise) * 0.28, 0.0, 1.0);

		float debris = fx_debris_burst(p_norm, u_progress, u_seed, 7);
		float plume_mask = max(col_mask, debris);

		if (plume_mask > bayer * 0.42 + 0.04 + erode * 0.30) {
			float heat = col_heat * step(0.05, col_mask);
			if (debris > col_mask) {
				heat = 0.72 + 0.22 * sin(u_time * 14.0 + cell.x);
			}
			vec3 col = fx_ramp(u_style, heat);
			outc = vec4(col, 0.96);
		}
	}
	COLOR = outc;
}
