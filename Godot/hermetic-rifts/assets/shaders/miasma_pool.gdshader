shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "fx_pixel.gdshaderinc"

uniform float u_kind : hint_range(0.0, 3.0) = 0.0;
uniform float u_time = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_seed = 1.0;
uniform float u_has_tex : hint_range(0.0, 1.0) = 0.0;
uniform float u_grid_px : hint_range(16.0, 256.0) = 64.0;

float pool_bubble_ring(vec2 p, float speed, float scale) {
	vec2 sp = p * scale;
	vec2 cell = floor(sp);
	vec2 local = fract(sp) - vec2(0.5);
	float rx = px_hash21(cell + vec2(u_seed * 3.1, 7.7));
	float ry = px_hash21(cell + vec2(19.3, u_seed * 5.3));
	float life_t = fract(u_time * speed + rx * 6.2831853);
	float rad = sin(clamp(life_t / 0.88, 0.0, 1.0) * 3.14159265) * (0.17 + ry * 0.13);
	vec2 offset = (vec2(rx, ry) - vec2(0.5)) * 0.34;
	float d = length(local - offset);
	float disk = step(d, rad) * step(life_t, 0.70);
	float pop_ring = step(abs(d - rad), 0.06) * step(0.60, life_t) * step(life_t, 0.94);
	return max(disk * 0.72, pop_ring) * step(0.045, rad);
}

vec3 ramp_smoke(float h) {
	return lut_sample(fx_ramp5(
		vec3(0.141, 0.133, 0.204), // #242234
		vec3(0.220, 0.278, 0.282), // #384748
		vec3(0.325, 0.459, 0.427), // #53756d
		vec3(0.533, 0.690, 0.616), // #88b09d
		vec3(0.776, 0.878, 0.812), // #c6e0cf
		h
	), u_lut_tex);
}

void fragment() {
	vec2 grid = fx_grid_dim();
	vec2 uv = quantize_uv(UV, grid);
	vec2 cell = floor(uv * grid);
	float bayer = px_bayer4(cell + vec2(u_seed * 5.0, u_seed * 3.0));

	vec2 p = (uv - 0.5) * 2.0;
	float r = length(p);
	vec4 outc = vec4(0.0);

	float splash = smoothstep(0.0, 0.09, u_progress);
	float evaporate = smoothstep(0.74, 1.0, u_progress);
	float anim_t = u_reduce > 0.5 ? 0.0 : u_time;

	if (u_kind >= 2.5) {
		// Kind 3: Smoke cloud — billowing stepped vapor puffs with dithered edges
		float drift_n = px_fbm(p * 2.4 + vec2(anim_t * 0.35 + u_seed, -anim_t * 0.28));
		float billow = px_fbm(p * 3.6 - vec2(anim_t * 0.45, anim_t * 0.32) + drift_n * 0.65);
		float cloud_r = (0.90 + (drift_n - 0.5) * 0.24) * mix(0.65, 1.0, splash);
		float density = clamp((cloud_r - r) / 0.32, 0.0, 1.0) * (0.55 + 0.55 * billow);
		if (r <= 1.02 && density > bayer * 0.55 + evaporate * 0.68 + 0.06) {
			float band = step(0.38, billow) * 0.32 + step(0.62, billow) * 0.34 + density * 0.28;
			outc = vec4(ramp_smoke(band), 0.78);
		}
	} else {
		float edge_noise = px_fbm(p * 2.6 + vec2(u_seed * 2.1 + anim_t * 0.14, -u_seed - anim_t * 0.11));
		float pool_r = (0.86 + (edge_noise - 0.5) * 0.22) * mix(0.54, 1.0, splash) * (1.0 - evaporate * 0.16);
		float rim_band = clamp((pool_r - r) / 0.20, 0.0, 1.0);
		float splash_drops = (u_progress < 0.22 && u_reduce < 0.5)
			? fx_debris_burst(p, u_progress / 0.22, u_seed, 5)
			: 0.0;

		bool in_pool = (r <= 1.02 && rim_band > bayer * 0.58 + evaporate * 0.78 + 0.04);
		if (u_has_tex > 0.5) {
			in_pool = in_pool && (texture(TEXTURE, uv).a >= 0.08);
		}

		if (in_pool || splash_drops > 0.5) {
			vec2 flow = vec2(
				px_fbm(p * 1.9 + vec2(anim_t * 0.20, -anim_t * 0.15) + u_seed),
				px_fbm(p * 1.9 + vec2(-anim_t * 0.15, anim_t * 0.20) - u_seed)
			);
			float surface = px_fbm(p * 2.8 + flow * 0.85);
			float bubbles = u_reduce > 0.5 ? 0.0 : clamp(
				pool_bubble_ring(p + flow * 0.10, 0.28, 6.8)
				+ pool_bubble_ring(p - flow * 0.10 + 11.7, 0.36, 8.8),
				0.0,
				1.0
			);
			float meniscus = in_pool ? (1.0 - smoothstep(0.08, 0.25, rim_band)) : 0.0;
			float band1 = step(0.40, surface);
			float band2 = step(0.62, surface);
			float glint = step(0.79, px_fbm(p * 6.4 - vec2(anim_t * 0.45, -anim_t * 0.35) + u_seed));

			if (u_kind < 0.5) {
				// Kind 0: Caustic Acid Pool (noxious elite death puddle)
				float heat = clamp(0.18 + band1 * 0.28 + band2 * 0.24 + bubbles * 0.42 + glint * 0.25 - meniscus * 0.52, 0.03, 0.98);
				if (splash_drops > 0.5 && !in_pool) {
					heat = 0.82;
				}
				outc = vec4(fx_ramp(2.0, heat), 0.92);
			} else if (u_kind < 1.5) {
				// Kind 1: Burn Trail (molten slag puddle with cooling crust rim)
				float crust_cool = smoothstep(0.45, 0.95, u_progress) * 0.26;
				float heat = clamp(0.16 + band1 * 0.32 + band2 * 0.28 + bubbles * 0.45 + glint * 0.24 - meniscus * 0.58 - crust_cool, 0.02, 0.98);
				if (splash_drops > 0.5 && !in_pool) {
					heat = 0.86;
				}
				outc = vec4(fx_ramp(0.0, heat), 0.93);
			} else {
				// Kind 2: Frozen Patch (faceted ice sheet with bright fracture ridges)
				float ridge = 1.0 - clamp(abs(surface - 0.50) * 4.4, 0.0, 1.0);
				float shard_edge = step(0.62, ridge);
				float heat = clamp(0.24 + band1 * 0.26 + shard_edge * 0.44 + glint * 0.22 - meniscus * 0.44, 0.05, 0.98);
				outc = vec4(fx_ramp(1.0, heat), 0.88);
			}
		}
	}
	COLOR = outc;
}
