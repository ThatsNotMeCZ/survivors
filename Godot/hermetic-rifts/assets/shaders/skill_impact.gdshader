shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "fx_pixel.gdshaderinc"

uniform float u_time = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_kind : hint_range(0.0, 2.0) = 0.0;
uniform float u_is_crit : hint_range(0.0, 1.0) = 0.0;
uniform float u_seed = 1.0;

vec3 sample_impact_ramp(float base_style, float heat) {
	if (u_is_crit > 0.5) {
		return lut_sample(fx_ramp_crit(heat), u_lut_tex);
	}
	return fx_ramp(base_style, heat);
}

void fragment() {
	vec2 grid = fx_grid_dim();
	vec2 uv = quantize_uv(UV, grid);
	vec2 cell = floor(uv * grid);
	float bayer = px_bayer4(cell);

	vec2 p = (uv - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x + 0.00001);
	vec4 outc = vec4(0.0);

	if (r <= 1.05) {
		float erode = smoothstep(0.68, 1.0, u_progress);

		if (u_kind < 0.5) {
			// Kind 0: Explosive Censer / Strike burst — pixel fireball puffs, shock ring, 8 ember shards, stepped ash cloud
			float wave_r = clamp(u_progress / 0.85, 0.08, 1.0) * 0.84;
			float hw = mix(0.12, 0.055, u_progress);
			float ring = 1.0 - smoothstep(hw * 0.35, hw, abs(r - wave_r));
			float puff_n = px_fbm(p * 3.6 + u_seed * 2.7);
			float fireball = (1.0 - smoothstep(0.0, wave_r * (0.65 + 0.25 * puff_n), r)) * (1.0 - u_progress * 0.82);
			float shards = fx_debris_burst(p, u_progress, u_seed, 8);
			float smoke_n = px_fbm(p * 3.8 + u_seed * 3.3);
			float smoke = step(0.46, smoke_n) * step(r, wave_r + 0.10) * (0.45 + 0.35 * step(0.66, smoke_n)) * (1.0 - u_progress * 0.65);

			float mask = max(max(ring, fireball), max(shards, smoke * 0.72));
			if (mask > bayer * 0.40 + 0.04 + erode * 0.50) {
				if (smoke > max(ring, max(fireball, shards))) {
					vec3 ash = mix(vec3(0.180, 0.133, 0.184), vec3(0.322, 0.271, 0.345), step(0.66, smoke_n));
					outc = vec4(lut_sample(ash, u_lut_tex), 0.84);
				} else {
					float heat = clamp(0.24 + ring * 0.48 + fireball * 0.55 + step(0.55, puff_n) * 0.20 + shards * 0.65, 0.0, 1.0);
					outc = vec4(sample_impact_ramp(0.0, heat), 0.94);
				}
			}
		} else if (u_kind < 1.5) {
			// Kind 1: Crucible Cull / Rupture — vertical strike pillar, concentric alchemical rings, hexagonal seal & embers (no cracks)
			float beam_t = clamp(u_progress / 0.30, 0.0, 1.0);
			float beam = (1.0 - smoothstep(mix(0.12, 0.02, beam_t), mix(0.20, 0.05, beam_t), abs(p.x)))
				* (1.0 - beam_t) * step(u_progress, 0.32) * step(p.y, 0.25);
			float wave_r = clamp(u_progress / 0.86, 0.08, 1.0) * 0.90;
			float hw = mix(0.12, 0.055, u_progress);
			float ring1 = 1.0 - smoothstep(hw * 0.32, hw, abs(r - wave_r));
			float ring2 = (1.0 - smoothstep(0.03, 0.08, abs(r - wave_r * 0.58))) * (1.0 - u_progress * 0.60);
			float hex_r = (wave_r * 0.76) / max(cos(mod(ang + 0.5235988, 1.0471976) - 0.5235988), 0.5);
			float hex = (1.0 - smoothstep(0.03, 0.085, abs(r - hex_r))) * 0.90;
			float boil_n = px_fbm(p * 4.2 + u_seed * 1.9);
			float melt = (1.0 - smoothstep(0.0, wave_r * 0.50, r)) * (0.65 + 0.35 * step(0.50, boil_n)) * (1.0 - u_progress * 0.82);
			float sparks = fx_debris_burst(p, u_progress, u_seed + 5.3, 6);

			float mask = max(max(ring1, ring2), max(max(hex, sparks * 0.85), max(melt, beam)));
			if (mask > bayer * 0.38 + 0.04 + erode * 0.48) {
				float heat = clamp(
					0.20
					+ ring1 * 0.48
					+ hex * 0.44
					+ ring2 * 0.36
					+ melt * 0.52
					+ beam * 0.65
					+ sparks * 0.55,
					0.0,
					1.0
				);
				outc = vec4(sample_impact_ramp(0.0, heat), 0.95);
			}
		} else {
			// Kind 2: Tether Latch / Conduit / Ritual / Frost shock — toothed voltaic-solar ring + star burst + sparks
			float wave_r = clamp(u_progress / 0.82, 0.08, 1.0) * 0.82;
			float ring = 1.0 - smoothstep(0.035, 0.095, abs(r - wave_r));
			float teeth = step(0.48, fract(ang * 6.0 / 6.2831853 + u_progress * 0.45))
				* (1.0 - smoothstep(0.03, 0.085, abs(r - wave_r * 0.90)));
			float core = (1.0 - smoothstep(0.0, 0.38, r)) * (1.0 - u_progress * 0.82);
			float sparks = fx_debris_burst(p, u_progress, u_seed + 3.1, 6);

			float mask = max(max(ring, teeth), max(core, sparks));
			if (mask > bayer * 0.40 + 0.04 + erode * 0.50) {
				float heat = clamp(0.26 + ring * 0.44 + teeth * 0.42 + core * 0.50 + sparks * 0.55, 0.0, 1.0);
				outc = vec4(sample_impact_ramp(5.0, heat), 0.94);
			}
		}
	}
	COLOR = outc;
}
