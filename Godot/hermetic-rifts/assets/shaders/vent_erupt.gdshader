shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "palette_utils.gdshaderinc"

uniform float u_state : hint_range(0.0, 2.0) = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_time = 0.0;
uniform float u_seed = 1.0;
uniform float u_reduce : hint_range(0.0, 1.0) = 0.0;
uniform float u_layer : hint_range(0.0, 1.0) = 0.0;

float vent_fissure_field(vec2 p_norm, float seed) {
	float r = length(p_norm);
	if (r > 1.06) {
		return 0.0;
	}
	float ang = atan(p_norm.y, p_norm.x + 0.00001);
	const float BRANCHES = 7.0;
	float sector = floor(((ang + 3.14159265) / 6.2831853) * BRANCHES);
	float sector_center = ((sector + 0.5) / BRANCHES) * 6.2831853 - 3.14159265;
	float jitter_ang = (px_hash21(vec2(sector, seed * 3.1)) - 0.5) * 0.36;
	float meander = (px_vnoise(vec2(r * 6.5, sector * 7.3 + seed)) - 0.5) * 0.38;
	float d_ang = abs(ang - (sector_center + jitter_ang + meander));
	d_ang = min(d_ang, 6.2831853 - d_ang);
	float arc_dist = d_ang * max(r, 0.14);
	float width = mix(0.068, 0.022, clamp(r, 0.0, 1.0));
	float main_crack = 1.0 - smoothstep(width * 0.45, width, arc_dist);

	// Forked sub-branch splitting off past r > 0.38
	float fork_dir = px_hash21(vec2(sector + 19.0, seed)) > 0.5 ? 1.0 : -1.0;
	float fork_off = max(0.0, r - 0.38) * 0.65 * fork_dir;
	float fork_d = abs(ang - (sector_center + jitter_ang + meander * 0.6 + fork_off));
	fork_d = min(fork_d, 6.2831853 - fork_d);
	float fork_crack = (1.0 - smoothstep(0.014, 0.036, fork_d * max(r, 0.25))) * smoothstep(0.35, 0.45, r);

	float raw = max(main_crack, fork_crack * 0.85);
	float tip_fade = 1.0 - smoothstep(0.76, 1.02, r);
	return clamp(raw * tip_fade, 0.0, 1.0);
}

void fragment() {
	vec4 outc = vec4(0.0);
	if (u_state >= 0.5) {
		const vec2 GRID = vec2(68.0, 96.0);
		vec2 uv = quantize_uv(UV, GRID);
		vec2 cell = floor(uv * GRID);
		float bayer = px_bayer4(cell);

		// Grate center sits at UV (0.5, 0.6875) on a 136x192 quad -> +-55 world px hurtbox = r_norm 1.0.
		vec2 p_world = vec2((uv.x - 0.5) * 136.0, (uv.y - 0.6875) * 192.0);
		vec2 p_norm = p_world / 55.0;
		float r_norm = length(p_norm);

		// Resurrect 64 lava ramp
		vec3 c_crust = vec3(0.180, 0.094, 0.082); // #2e1815
		vec3 c_deep  = vec3(0.620, 0.157, 0.208); // #9e2835
		vec3 c_mid   = vec3(0.918, 0.310, 0.212); // #ea4f36
		vec3 c_hot   = vec3(0.969, 0.588, 0.090); // #f79617
		vec3 c_core  = vec3(0.976, 0.761, 0.169); // #f9c22b

		float fissure = vent_fissure_field(p_norm, u_seed);
		float core_glow = (1.0 - smoothstep(0.18, 0.46, r_norm)) * 0.75;

		if (u_state < 1.5) {
			// Telegraph: branching magma fissures ignite outward beneath/around the grate (fissure layer only)
			if (u_layer < 0.5) {
				float reach = mix(0.32, 1.04, clamp(u_progress, 0.0, 1.0));
				float reveal = 1.0 - smoothstep(reach - 0.12, reach + 0.04, r_norm);
				float pulse = u_reduce > 0.5 ? 0.85 : (0.68 + 0.32 * sin(u_time * mix(7.0, 22.0, u_progress)));
				float crust = smoothstep(0.06, 0.32, fissure) * reveal;
				float vein = smoothstep(0.36, 0.78, fissure) * reveal;
				float mask = max(crust, core_glow * 0.55);
				if (mask > bayer * 0.35 + 0.05) {
					float heat = clamp(vein * (0.45 + 0.55 * u_progress) + core_glow * 0.35, 0.0, 1.0) * pulse;
					vec3 col = mix(c_crust, c_deep, smoothstep(0.10, 0.38, heat));
					col = mix(col, c_mid, smoothstep(0.38, 0.68, heat));
					col = mix(col, c_hot, smoothstep(0.68, 0.90, heat));
					col = mix(col, c_core, smoothstep(0.90, 1.0, heat));
					col = lut_sample(col, u_lut_tex);
					outc = vec4(col, clamp(mask * mix(0.65, 0.95, u_progress), 0.0, 0.95));
				}
			}
		} else {
			// Erupting: split into ground fissures (u_layer < 0.5, under grate) and upward heat column (u_layer >= 0.5, above grate)
			float env = sin(clamp(u_progress, 0.0, 1.0) * 3.14159265);
			if (u_layer < 0.5) {
				float erupt_fissure = clamp(fissure * (0.85 + 0.25 * env) + core_glow * 0.9, 0.0, 1.0);
				if (erupt_fissure > bayer * 0.42 + 0.04) {
					float heat = erupt_fissure * 0.88;
					vec3 col = mix(c_crust, c_deep, smoothstep(0.05, 0.30, heat));
					col = mix(col, c_mid, smoothstep(0.30, 0.56, heat));
					col = mix(col, c_hot, smoothstep(0.56, 0.80, heat));
					col = mix(col, c_core, smoothstep(0.80, 0.96, heat));
					col = lut_sample(col, u_lut_tex);
					float alpha = clamp(erupt_fissure * 1.15, 0.0, 0.96);
					outc = vec4(col, alpha);
				}
			} else if (u_reduce < 0.5 && p_world.y <= 16.0) {
				float col_h = clamp((10.0 - p_world.y) / 136.0, 0.0, 1.0);
				float swirl = (px_fbm(vec2(p_world.x * 0.055, col_h * 4.2 + u_time * 7.0 + u_seed)) - 0.5) * 26.0 * (0.35 + col_h);
				float half_w = mix(32.0, 15.0, col_h) * (0.62 + 0.48 * env);
				float x_norm = abs(p_world.x + swirl) / max(half_w, 1.0);
				float base_cut = smoothstep(14.0, -4.0, p_world.y);
				float top_cut = 1.0 - smoothstep(0.45, 0.98, col_h);
				float plume_noise = px_fbm(vec2((p_world.x + swirl) * 0.07, col_h * 5.0 + u_time * 9.5 + u_seed * 2.3));
				float jet = (1.0 - smoothstep(0.28, 1.02, x_norm)) * base_cut * top_cut * env;
				float col_mask = clamp(jet * (0.72 + 0.55 * plume_noise), 0.0, 1.0);
				float col_heat = clamp((1.0 - col_h * 0.78) * (1.0 - x_norm * 0.65) + plume_noise * 0.28, 0.0, 1.0);

				// Rising ember & steam flecks
				float steam_mask = 0.0;
				vec2 puff_uv = vec2(p_world.x * 0.14, p_world.y * 0.14 + u_time * 16.0 + u_seed * 5.0);
				float puff_rnd = px_hash21(floor(puff_uv));
				float in_cone = step(abs(p_world.x), mix(36.0, 48.0, col_h)) * base_cut * (1.0 - smoothstep(0.75, 1.0, col_h));
				if (puff_rnd > 0.90 && in_cone > 0.5) {
					steam_mask = env * 0.85;
				}

				float plume_mask = max(col_mask, steam_mask);
				if (plume_mask > bayer * 0.42 + 0.04) {
					float heat = col_heat * step(0.05, col_mask);
					if (steam_mask > col_mask) {
						heat = 0.55 + 0.35 * sin(u_time * 14.0 + cell.x);
					}
					vec3 col = mix(c_crust, c_deep, smoothstep(0.05, 0.30, heat));
					col = mix(col, c_mid, smoothstep(0.30, 0.56, heat));
					col = mix(col, c_hot, smoothstep(0.56, 0.80, heat));
					col = mix(col, c_core, smoothstep(0.80, 0.96, heat));
					col = lut_sample(col, u_lut_tex);
					float alpha = clamp(plume_mask * 1.15, 0.0, 0.96);
					outc = vec4(col, alpha);
				}
			}
		}
	}
	COLOR = outc;
}
