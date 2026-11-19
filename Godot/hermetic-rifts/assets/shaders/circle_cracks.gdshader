shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "palette_utils.gdshaderinc"

uniform float u_time = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_tier : hint_range(0.0, 3.0) = 0.0;
uniform float u_active : hint_range(0.0, 1.0) = 0.0;
uniform float u_guide_active : hint_range(0.0, 1.0) = 1.0;
uniform vec2 u_circle_uv = vec2(0.5, 0.5);
uniform float u_circular : hint_range(0.0, 1.0) = 1.0;
uniform float u_grid_px : hint_range(256.0, 6000.0) = 3000.0;
uniform vec2 u_span_px = vec2(6000.0, 6000.0);
uniform float u_circle_r = 150.0;
uniform float u_seed = 1.0;
uniform float u_boss_active : hint_range(0.0, 1.0) = 0.0;
uniform float u_cooled : hint_range(0.0, 1.0) = 0.0;

// Returns vec2(all_fissure_strength, guide_leyline_strength)
// Evaluated in sector-local rotated coordinates (along_px, perp_px) so there is zero atan2 +-PI seam or cone artifact.
vec2 circle_vent_fissures(vec2 p_world, float r_px, float max_span, float circle_r, float seed) {
	if (r_px < circle_r * 0.82) {
		return vec2(0.0);
	}
	float ang = atan(p_world.y, p_world.x + 0.00001);
	float dist_out = max(0.0, r_px - circle_r * 0.85);
	float r_norm = clamp(r_px / max(max_span * 0.96, 1.0), 0.0, 1.0);

	const float BRANCHES = 20.0;
	float base_sector = floor(((ang + PI) / TAU) * BRANCHES);

	float main_w = mix(2.6, 1.5, clamp(dist_out / 1600.0, 0.0, 1.0));
	float best_all = 0.0;
	float best_guide = 0.0;

	for (int ds = -1; ds <= 1; ds++) {
		float sector = mod(base_sector + float(ds) + BRANCHES, BRANCHES);
		// 7 arena-wide guiding fissures spaced around the compass (sectors 0, 3, 6, 9, 12, 15, 18)
		bool is_guide = mod(sector, 3.0) < 0.5;
		float sector_center = ((sector + 0.5) / BRANCHES) * TAU - PI;
		float jitter_ang = (px_hash21(vec2(sector, seed * 3.1)) - 0.5) * 0.20;
		float ref_ang = sector_center + jitter_ang;

		vec2 dir_v = vec2(cos(ref_ang), sin(ref_ang));
		vec2 nrm_v = vec2(-dir_v.y, dir_v.x);
		float along_px = dot(p_world, dir_v);
		if (along_px <= 0.0) {
			continue;
		}
		float perp_px = dot(p_world, nrm_v);

		// Smoothly ramp meander from 0 near the circle center so trunks never flare into a cone
		float radial_grow = smoothstep(circle_r * 0.80, circle_r * 1.45, along_px);
		float meander_px = (
			(px_vnoise(vec2(along_px * 0.052, sector * 7.3 + seed)) - 0.5) * 18.0
			+ (px_vnoise(vec2(along_px * 0.015, sector * 3.7 + seed * 1.9)) - 0.5) * 42.0
		) * radial_grow;

		float arc_px = abs(perp_px - meander_px);
		float guide_w = mix(3.8, 2.45, clamp(dist_out / 1800.0, 0.0, 1.0));
		float trunk_w = is_guide ? guide_w : main_w;
		float main_crack = 1.0 - smoothstep(trunk_w * 0.48, trunk_w, arc_px);
		best_all = max(best_all, main_crack);
		if (is_guide) {
			best_guide = max(best_guide, main_crack);
		}

		// Attached forks along each trunk (5 tiers from near the circle to outer arena)
		for (int b = 0; b < 5; b++) {
			float bf = float(b);
			float h1 = px_hash21(vec2(sector * 5.3 + bf * 11.7, seed + 3.1));
			float h2 = px_hash21(vec2(sector * 9.1 + bf * 17.3, seed + 13.7));
			float h3 = px_hash21(vec2(sector * 13.7 + bf * 23.1, seed + 29.3));

			float split_base = circle_r * 1.02 + bf * bf * 82.0 + bf * 95.0;
			float split_r = split_base + h1 * (80.0 + bf * 120.0);
			float fork_len = 160.0 + bf * 140.0 + h2 * (140.0 + bf * 120.0);

			if (along_px >= split_r - 12.0 && along_px <= split_r + fork_len + 24.0) {
				float f_t = clamp((along_px - split_r) / max(fork_len, 1.0), 0.0, 1.0);
				float dir = (mod(bf + floor(h3 * 2.0), 2.0) < 0.5) ? 1.0 : -1.0;
				float slope = 0.42 + h3 * 0.32;
				float grow = smoothstep(split_r, split_r + 36.0, along_px);
				float f_wiggle = (px_vnoise(vec2(along_px * 0.06, sector * 11.3 + bf * 5.7 + seed)) - 0.5) * 16.0 * grow;

				float f_off_px = max(0.0, along_px - split_r) * slope * dir + f_wiggle;
				float f_arc_px = abs(perp_px - (meander_px + f_off_px));
				float f_w = is_guide ? mix(2.75, 1.85, f_t) : mix(1.95, 1.25, f_t);
				float f_env = smoothstep(split_r - 8.0, split_r + 14.0, along_px) * (1.0 - smoothstep(0.76, 1.0, f_t));
				float fork_crack = (1.0 - smoothstep(f_w * 0.45, f_w, f_arc_px)) * f_env * 0.92;
				best_all = max(best_all, fork_crack);
				if (is_guide) {
					best_guide = max(best_guide, fork_crack * 0.94);
				}

				// Secondary twig splitting off the fork past 34% of its length
				if (f_t > 0.34) {
					float sub_r = split_r + fork_len * (0.36 + h1 * 0.22);
					float sub_len = fork_len * 0.52;
					if (along_px >= sub_r - 8.0 && along_px <= sub_r + sub_len + 16.0) {
						float st = clamp((along_px - sub_r) / max(sub_len, 1.0), 0.0, 1.0);
						float s_off_px = max(0.0, along_px - sub_r) * (0.48 + h2 * 0.26) * (-dir);
						float s_arc_px = abs(perp_px - (meander_px + f_off_px + s_off_px));
						float s_w = mix(1.55, 1.15, st);
						float s_env = smoothstep(sub_r - 6.0, sub_r + 12.0, along_px) * (1.0 - smoothstep(0.70, 1.0, st));
						float sub_crack = (1.0 - smoothstep(s_w * 0.40, s_w, s_arc_px)) * s_env * 0.82;
						best_all = max(best_all, sub_crack);
					}
				}
			}
		}
	}

	float inner_cut = smoothstep(circle_r * 0.86, circle_r * 1.02, r_px);
	float tip_fade = (1.0 - smoothstep(0.88, 1.0, r_norm)) * inner_cut;
	return clamp(vec2(best_all, best_guide) * tip_fade, vec2(0.0), vec2(1.0));
}

void fragment() {
	vec4 outc = vec4(0.0);
	if (u_guide_active > 0.01 || (u_active > 0.01 && u_progress > 0.005)) {
		vec2 uv = quantize_uv(UV, vec2(u_grid_px));
		float arena_r = length(uv - vec2(0.5));
		if (u_circular < 0.5 || arena_r <= 0.494) {
			vec2 p_world = (uv - u_circle_uv) * u_span_px;
			float r_px = length(p_world);
			float max_span = max(u_span_px.x, u_span_px.y);
			float reach_px = mix(u_circle_r * 1.12, max_span * 0.96, pow(clamp(u_progress, 0.0, 1.0), 0.85));

			vec2 cell = floor(uv * u_grid_px);
			float bayer = px_bayer4(cell);

			// Resurrect 64 lava ramp from vent_erupt.gdshader
			vec3 c_crust = vec3(0.180, 0.094, 0.082); // #2e1815
			vec3 c_deep  = vec3(0.620, 0.157, 0.208); // #9e2835
			vec3 c_mid   = vec3(0.918, 0.310, 0.212); // #ea4f36
			vec3 c_hot   = vec3(0.969, 0.588, 0.090); // #f79617
			vec3 c_core  = vec3(0.976, 0.761, 0.169); // #f9c22b

			vec2 fis = circle_vent_fissures(p_world, r_px, max_span, u_circle_r, u_seed);
			float fissure = fis.x;
			float guide_fissure = fis.y * u_guide_active;

			float core_glow = (1.0 - smoothstep(u_circle_r * 0.92, u_circle_r * 1.06, r_px)) * 0.65 * (1.0 - u_cooled) * u_active;
			float reveal = (1.0 - smoothstep(reach_px - 65.0, reach_px + 18.0, r_px)) * step(0.005, u_progress) * u_active;

			float active_crust = smoothstep(0.06, 0.32, fissure) * reveal;
			float active_vein = smoothstep(0.36, 0.78, fissure) * reveal;

			// Arena-wide guiding fissures leading toward the portal/circle across the entire map
			float guide_crust = smoothstep(0.04, 0.24, guide_fissure);
			float guide_vein = smoothstep(0.28, 0.72, guide_fissure);
			// Pulse traveling INWARD (+r_px + u_time) toward the circle/portal center
			float inward_flow = pow(0.5 + 0.5 * sin(r_px * 0.015 + u_time * 2.6), 2.0);
			float guide_near_boost = 1.0 - smoothstep(u_circle_r * 1.2, max_span * 0.85, r_px) * 0.25;

			float crust = max(active_crust, guide_crust * 0.94);
			float vein = max(active_vein, guide_vein * 0.85);
			float mask = max(crust, core_glow * 0.50);

			if (mask > bayer * 0.35 + 0.05) {
				float chan_pulse = 0.72 + 0.28 * sin(u_time * mix(1.2, 2.8, u_progress) - r_px * 0.008);
				float boss_flicker = 0.86 + 0.14 * sin(u_time * 1.05 + px_hash21(floor(p_world * 0.015)) * TAU);
				float pulse = mix(chan_pulse, boss_flicker, u_boss_active);

				float active_heat = clamp(active_vein * (0.45 + 0.55 * u_progress + 0.10 * u_tier) + core_glow * 0.35, 0.0, 1.0) * pulse * (1.0 - u_cooled);
				float guide_heat = guide_vein * (0.28 + 0.44 * inward_flow) * guide_near_boost;
				float heat = max(active_heat, guide_heat);

				vec3 col = mix(c_crust, c_deep, smoothstep(0.10, 0.38, heat));
				col = mix(col, c_mid, smoothstep(0.38, 0.68, heat));
				col = mix(col, c_hot, smoothstep(0.68, 0.90, heat));
				col = mix(col, c_core, smoothstep(0.90, 1.0, heat));

				// When cooled after boss death, secondary cracks turn to dark scars while guiding fissures keep a gentle inward ember pulse to the open portal
				vec3 c_scar = mix(vec3(0.085, 0.055, 0.065), c_crust, smoothstep(0.20, 0.75, vein) * 0.65);
				float keep_guide_glow = clamp(guide_vein * (0.45 + 0.45 * inward_flow), 0.0, 0.85);
				col = mix(col, c_scar, u_cooled * (1.0 - keep_guide_glow));
				col = lut_sample(col, u_lut_tex);

				float live_alpha = clamp(max(active_crust * u_active * mix(0.65, 0.95, u_progress), guide_crust * 0.86), 0.0, 0.95);
				float scar_alpha = clamp(max(active_crust * 0.85, guide_crust * 0.88), 0.0, 0.90);
				outc = vec4(col, mix(live_alpha, scar_alpha, u_cooled));
			}
		}
	}
	COLOR = outc;
}
