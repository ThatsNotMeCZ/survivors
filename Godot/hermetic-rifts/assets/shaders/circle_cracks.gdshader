shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "palette_utils.gdshaderinc"

uniform float u_time = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_tier : hint_range(0.0, 3.0) = 0.0;
uniform float u_active : hint_range(0.0, 1.0) = 0.0;
uniform vec2 u_circle_uv = vec2(0.5, 0.5);
uniform float u_circular : hint_range(0.0, 1.0) = 1.0;
uniform float u_grid_px : hint_range(256.0, 6000.0) = 3000.0;

void fragment() {
	vec4 outc = vec4(0.0);
	if (u_active > 0.01 && u_progress > 0.005) {
		vec2 uv = quantize_uv(UV, vec2(u_grid_px));
		float arena_r = length(uv - vec2(0.5));
		if (u_circular < 0.5 || arena_r <= 0.494) {
			vec2 rel = (uv - u_circle_uv) * 2.0;
			float d = length(rel);
			float ang = atan(rel.y, rel.x + 0.00001);

			// Primary radial cracks radiating from the Transmutation Circle across the floor
			const float TRUNKS = 12.0;
			float sector = floor(((ang + 3.14159265) / 6.2831853) * TRUNKS);
			float base_ang = ((sector + 0.5) / TRUNKS) * 6.2831853 - 3.14159265;
			float seed_off = (px_hash21(vec2(sector, 11.7)) - 0.5) * 0.24;
			float wiggle = (px_vnoise(vec2(d * 14.0, sector * 5.9)) - 0.5) * 0.26;
			float d_ang = abs(ang - (base_ang + seed_off + wiggle));
			d_ang = min(d_ang, 6.2831853 - d_ang);
			float arc_d = d_ang * max(d, 0.05);
			float trunk_w = mix(0.014, 0.0038, clamp(d * 0.55, 0.0, 1.0)) * (1.0 + u_tier * 0.14);
			float trunk = 1.0 - smoothstep(trunk_w * 0.40, trunk_w, arc_d);

			// Forked secondary branches along each trunk
			float seg = floor(d * 6.5 + px_hash21(vec2(sector, 3.1)));
			float branch_side = px_hash21(vec2(sector * 13.0 + seg, 7.3)) > 0.5 ? 1.0 : -1.0;
			float branch_start = (seg - px_hash21(vec2(sector, seg))) / 6.5;
			float branch_ang = base_ang + seed_off + wiggle * 0.5 + max(0.0, d - branch_start) * 0.95 * branch_side;
			float b_d_ang = abs(ang - branch_ang);
			b_d_ang = min(b_d_ang, 6.2831853 - b_d_ang);
			float b_arc_d = b_d_ang * max(d, 0.08);
			float branch_on = step(0.28, px_hash21(vec2(seg, sector + 29.0)) + u_tier * 0.18);
			float branch = (1.0 - smoothstep(0.0022, 0.0062, b_arc_d)) * smoothstep(branch_start, branch_start + 0.04, d) * branch_on;

			float crack = max(trunk, branch * 0.85);
			float max_reach = mix(0.08, 1.92, pow(clamp(u_progress, 0.0, 1.0), 0.85));
			float reach_fade = 1.0 - smoothstep(max_reach * 0.72, max_reach, d);
			float circle_cut = smoothstep(0.032, 0.052, d);

			float bayer = px_bayer4(floor(uv * u_grid_px));
			float intensity = crack * reach_fade * circle_cut;
			if (intensity > bayer * 0.40 + 0.04) {
				float pulse = 0.55 + 0.45 * sin(d * 18.0 - u_time * (3.2 + u_tier * 1.4));
				float heat = clamp(intensity * (0.45 + 0.35 * u_progress + 0.14 * u_tier) + pulse * 0.28 * intensity, 0.0, 1.0);

				// Resurrect 64 ember / brass colors
				vec3 c_crust = vec3(0.180, 0.094, 0.082); // #2e1815
				vec3 c_deep  = vec3(0.620, 0.157, 0.208); // #9e2835
				vec3 c_ember = vec3(0.918, 0.310, 0.212); // #ea4f36
				vec3 c_brass = vec3(0.769, 0.639, 0.353); // #c4a35a
				vec3 c_gold  = vec3(0.976, 0.761, 0.169); // #f9c22b

				vec3 col = mix(c_crust, c_deep, smoothstep(0.05, 0.30, heat));
				col = mix(col, c_ember, smoothstep(0.30, 0.58, heat));
				col = mix(col, mix(c_brass, vec3(0.969, 0.588, 0.090), 0.45), smoothstep(0.58, 0.82, heat));
				col = mix(col, c_gold, smoothstep(0.82, 0.98, heat));
				col = lut_sample(col, u_lut_tex);

				float alpha = clamp(intensity * u_active * mix(0.65, 0.96, u_progress), 0.0, 0.94);
				outc = vec4(col, alpha);
			}
		}
	}
	COLOR = outc;
}
