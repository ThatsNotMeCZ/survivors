shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "fx_pixel.gdshaderinc"

uniform float u_state : hint_range(0.0, 3.0) = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_time = 0.0;
uniform float u_kind : hint_range(0.0, 1.0) = 0.0;
uniform float u_arcDeg : hint_range(10.0, 360.0) = 120.0;
uniform float u_seed = 1.0;
uniform float u_layer : hint_range(0.0, 1.0) = 0.0;

// Parabolic chunks/sparks erupting forward from the fist slam point
float slam_debris(vec2 p_imp, float half_arc, float progress, float seed) {
	float t = clamp(progress, 0.0, 1.0);
	float best = 0.0;
	for (int i = 0; i < 9; i++) {
		float fi = float(i);
		float h0 = px_hash21(vec2(fi * 4.1 + 1.3, seed));
		float h1 = px_hash21(vec2(fi * 7.7 + 3.9, seed * 1.9));
		float ang = ((fi + 0.2 + h0 * 0.6) / 9.0 * 2.0 - 1.0) * (half_arc * 0.88);
		float dist = mix(0.08, 0.50 + h1 * 0.30, pow(t, 0.68));
		float lift = sin(t * 3.14159265) * (0.10 + h0 * 0.14);
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 pos = dir * dist + vec2(lift * 0.35, -lift * 0.55);
		float sz = mix(0.048, 0.022, t);
		vec2 d = abs(p_imp - pos);
		float chunk = step(max(d.x, d.y), sz);
		best = max(best, chunk * (1.0 - smoothstep(0.75, 1.0, t)));
	}
	return best;
}

vec3 sample_cleave_ramp(float heat) {
	return fx_ramp(u_kind < 0.5 ? 0.0 : 1.0, heat);
}

void fragment() {
	vec4 outc = vec4(0.0);
	if (u_state >= 0.5) {
		vec2 grid = fx_grid_dim();
		vec2 uv = quantize_uv(UV, grid);
		vec2 cell = floor(uv * grid);
		float bayer = px_bayer4(cell);

		vec2 p = (uv - 0.5) * 2.0;
		float r = length(p);
		float ang = atan(p.y, p.x + 0.00001);
		float half_arc = radians(u_arcDeg) * 0.5;
		float ang_abs = abs(ang);

		// Fist ground-slam origin sits forward along +X (direction of enemy aim/strike)
		vec2 impact_c = vec2(0.28, 0.0);
		vec2 p_imp = p - impact_c;
		float r_imp = length(p_imp);
		float max_imp_reach = 0.82;

		if (r <= 1.02 && ang_abs <= half_arc + 0.04) {
			float cone_ang = 1.0 - smoothstep(half_arc - 0.03, half_arc + 0.02, ang_abs);
			float cone_rad = (1.0 - smoothstep(0.95, 1.01, r)) * smoothstep(0.08, 0.18, r);
			float cone_mask = cone_ang * cone_rad;

			float cell_w = 2.0 / max(grid.x, 48.0);
			float edge_arc = (1.0 - smoothstep(cell_w * 0.6, cell_w * 1.5, abs(r - 0.96))) * cone_ang;
			float side_dist = abs(ang_abs - half_arc) * max(r, 0.14);
			float edge_side = (1.0 - smoothstep(cell_w * 0.55, cell_w * 1.4, side_dist)) * cone_rad;
			float rim = max(edge_arc, edge_side);

			float crater_core = 1.0 - smoothstep(0.05, 0.22, r_imp);
			float crater_ring = 1.0 - smoothstep(0.025, 0.065, abs(r_imp - 0.18));

			if (u_state < 1.5) {
				// State 1 (Windup): Fists raised (frame 4). Target impact zone and expanding pressure wave fill the cone
				if (u_layer < 0.5) {
					float reach = mix(0.16, max_imp_reach * 0.98, clamp(u_progress, 0.0, 1.0));
					float front_arc = (1.0 - smoothstep(cell_w * 0.7, cell_w * 1.8, abs(r_imp - reach))) * cone_mask;
					float fill_zone = step(r_imp, reach) * cone_mask * (0.22 + 0.24 * u_progress);
					float pulse = u_reduce > 0.5 ? 0.85 : (0.72 + 0.28 * sin(u_time * mix(8.0, 24.0, u_progress)));
					float urgent = (u_reduce < 0.5 && u_progress > 0.70) ? (0.5 + 0.5 * sin(u_time * 32.0)) : 0.0;

					float target_ring = crater_ring * (0.58 + 0.42 * u_progress);
					float target_core = crater_core * (0.42 + 0.50 * u_progress);
					float rim_lit = rim * mix(0.52, 0.95, u_progress);
					float mask = max(max(rim_lit, front_arc * 0.88), max(fill_zone, max(target_ring, target_core * 0.78)));

					if (fx_cut(mask, bayer, 0.38)) {
						float heat = clamp(
							0.18
							+ fill_zone * 0.35
							+ front_arc * 0.48
							+ target_core * 0.55
							+ target_ring * 0.65
							+ rim_lit * (0.58 + 0.40 * urgent),
							0.0,
							1.0
						) * pulse;
						vec3 col = sample_cleave_ramp(heat);
						outc = vec4(col, clamp(mask * mix(0.60, 0.94, u_progress), 0.0, 0.94));
					}
				}
			} else if (u_state < 2.5) {
				// State 2 (Strike): Fists slam the floor (frame 5). Scorched/frosted crater & concentric shockwave
				if (u_layer < 0.5) {
					float flash = 1.0 - smoothstep(0.0, 0.42, u_progress);
					float blast_n = px_fbm(p_imp * 3.8 + u_seed);
					float blast_r = mix(0.28, max_imp_reach * 0.95, clamp(u_progress * 1.45, 0.0, 1.0));
					float ground_blast = (1.0 - smoothstep(blast_r * 0.45, blast_r, r_imp)) * (0.55 + 0.45 * step(0.46, blast_n));
					float wake = clamp((ground_blast * 0.78 + crater_core * 0.95 + crater_ring * 0.82 + rim * 0.55) * cone_mask, 0.0, 1.0);
					if (fx_cut(wake, bayer, 0.40)) {
						float heat = clamp(0.18 + ground_blast * 0.42 + crater_ring * 0.38 + crater_core * 0.50 + flash * 0.25, 0.0, 1.0);
						outc = vec4(sample_cleave_ramp(heat), 0.93);
					}
				} else if (u_reduce < 0.5) {
					// Overlay: Concentric ground-slam shockwave arcs + dust/ember cloud + flying debris chunks
					float wave_t = clamp(u_progress * 1.32, 0.0, 1.0);
					float wave_r = mix(0.12, max_imp_reach * 0.98, pow(wave_t, 0.76));
					float wave_hw = mix(0.12, 0.055, wave_t);
					float wave_d = abs(r_imp - wave_r);
					float wave_band = (1.0 - smoothstep(wave_hw * 0.30, wave_hw, wave_d)) * cone_mask;
					float wave_crest = (1.0 - smoothstep(0.0, wave_hw * 0.42, abs(r_imp - (wave_r + wave_hw * 0.18)))) * cone_mask;
					float echo_band = (1.0 - smoothstep(0.025, 0.07, abs(r_imp - wave_r * 0.62))) * cone_mask * 0.78;
					float wave_noise = px_fbm(vec2(r_imp * 6.5 - u_time * 9.0, atan(p_imp.y, p_imp.x + 0.0001) * 4.0 + u_seed));

					float slam_plume = (1.0 - smoothstep(0.0, 0.26, r_imp)) * (1.0 - smoothstep(0.0, 0.50, u_progress)) * (0.68 + 0.42 * wave_noise);
					float debris = slam_debris(p_imp, half_arc, u_progress, u_seed) * cone_mask;

					float erode = smoothstep(0.62, 1.0, u_progress);
					float ov_mask = max(max(wave_band * (0.74 + 0.46 * wave_noise), echo_band), max(slam_plume, debris));
					if (ov_mask > bayer * 0.38 + 0.04 + erode * 0.42) {
						float heat = clamp(
							0.34
							+ echo_band * 0.35
							+ wave_crest * 0.58
							+ slam_plume * 0.55
							+ debris * 0.62
							+ step(0.55, wave_noise) * 0.18,
							0.0,
							1.0
						) * (1.0 - u_progress * 0.22);
						outc = vec4(sample_cleave_ramp(heat), 0.96);
					}
				}
			} else {
				// State 3 (Afterglow): Cooling impact crater & scorched/frosted ground eroding via Bayer dither
				if (u_layer < 0.5) {
					float erode = clamp(u_progress, 0.0, 1.0);
					float blast_n = px_fbm(p_imp * 3.8 + u_seed);
					float scorched = (1.0 - smoothstep(0.18, 0.62, r_imp)) * (0.45 + 0.45 * step(0.48, blast_n));
					float scar = clamp((scorched * 0.72 + crater_core * 0.85 + crater_ring * 0.75) * cone_mask, 0.0, 1.0);
					if (scar > bayer * 0.46 + 0.06 + erode * 0.58) {
						float heat = clamp(scar * mix(0.62, 0.12, erode), 0.02, 0.80);
						outc = vec4(sample_cleave_ramp(heat), 0.88);
					}
				}
			}
		}
	}
	COLOR = outc;
}
