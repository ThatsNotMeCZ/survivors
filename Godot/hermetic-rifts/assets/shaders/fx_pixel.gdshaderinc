#include "palette_utils.gdshaderinc"

uniform vec2 u_quad_px = vec2(64.0, 64.0);
uniform float u_reduce : hint_range(0.0, 1.0) = 0.0;

const float FX_CELL_PX = 2.0;

vec2 fx_grid_dim() {
	return max(floor(u_quad_px / FX_CELL_PX + vec2(0.5)), vec2(8.0));
}

bool fx_cut(float mask, float bayer, float k) {
	return mask > bayer * k + 0.04;
}

vec3 fx_ramp5(vec3 c0, vec3 c1, vec3 c2, vec3 c3, vec3 c4, float heat) {
	float h = clamp(heat, 0.0, 1.0);
	vec3 col = mix(c0, c1, smoothstep(0.06, 0.30, h));
	col = mix(col, c2, smoothstep(0.30, 0.56, h));
	col = mix(col, c3, smoothstep(0.56, 0.80, h));
	col = mix(col, c4, smoothstep(0.80, 0.96, h));
	return col;
}

// Resurrect 64 ramps
vec3 fx_ramp_lava(float heat) {
	return fx_ramp5(
		vec3(0.180, 0.094, 0.082), // #2e1815
		vec3(0.620, 0.157, 0.208), // #9e2835
		vec3(0.918, 0.310, 0.212), // #ea4f36
		vec3(0.969, 0.588, 0.090), // #f79617
		vec3(0.976, 0.761, 0.169), // #f9c22b
		heat
	);
}

vec3 fx_ramp_frost(float heat) {
	return fx_ramp5(
		vec3(0.118, 0.227, 0.373), // #1e3a5f
		vec3(0.180, 0.353, 0.561), // #2e5a8f
		vec3(0.302, 0.608, 0.902), // #4d9be6
		vec3(0.561, 0.827, 1.000), // #8fd3ff
		vec3(0.910, 0.973, 1.000), // #e8f8ff
		heat
	);
}

vec3 fx_ramp_acid(float heat) {
	return fx_ramp5(
		vec3(0.118, 0.282, 0.188), // #1e4830
		vec3(0.137, 0.565, 0.388), // #239063
		vec3(0.118, 0.737, 0.451), // #1ebc73
		vec3(0.569, 0.859, 0.412), // #91db69
		vec3(0.804, 1.000, 0.510), // #cdff82
		heat
	);
}

vec3 fx_ramp_voltaic(float heat) {
	return fx_ramp5(
		vec3(0.169, 0.169, 0.271), // #2b2b45
		vec3(0.302, 0.396, 0.706), // #4d65b4
		vec3(0.302, 0.608, 0.902), // #4d9be6
		vec3(0.976, 0.761, 0.169), // #f9c22b
		vec3(1.000, 0.957, 0.659), // #fff4a8
		heat
	);
}

vec3 fx_ramp_hex(float heat) {
	return fx_ramp5(
		vec3(0.169, 0.106, 0.239), // #2b1b3d
		vec3(0.420, 0.243, 0.459), // #6b3e75
		vec3(0.627, 0.345, 0.816), // #a058d0
		vec3(0.788, 0.678, 1.000), // #c9adff
		vec3(0.941, 0.902, 1.000), // #f0e6ff
		heat
	);
}

vec3 fx_ramp_solar(float heat) {
	return fx_ramp5(
		vec3(0.353, 0.180, 0.122), // #5a2e1f
		vec3(0.769, 0.416, 0.122), // #c46a1f
		vec3(0.969, 0.588, 0.090), // #f79617
		vec3(0.976, 0.761, 0.169), // #f9c22b
		vec3(1.000, 0.957, 0.784), // #fff4c8
		heat
	);
}

vec3 fx_ramp_crit(float heat) {
	return fx_ramp5(
		vec3(0.243, 0.118, 0.161), // #3e1e29
		vec3(0.620, 0.157, 0.208), // #9e2835
		vec3(0.910, 0.231, 0.231), // #e83b3b
		vec3(0.984, 0.420, 0.114), // #fb6b1d
		vec3(1.000, 0.910, 0.840), // #ffe8d6
		heat
	);
}

// Style selector: 0 = lava, 1 = frost, 2 = acid, 3 = voltaic, 4 = hex, 5 = solar
vec3 fx_ramp(float style, float heat) {
	vec3 col;
	if (style < 0.5) {
		col = fx_ramp_lava(heat);
	} else if (style < 1.5) {
		col = fx_ramp_frost(heat);
	} else if (style < 2.5) {
		col = fx_ramp_acid(heat);
	} else if (style < 3.5) {
		col = fx_ramp_voltaic(heat);
	} else if (style < 4.5) {
		col = fx_ramp_hex(heat);
	} else {
		col = fx_ramp_solar(heat);
	}
	return lut_sample(col, u_lut_tex);
}

// Generalized radial fissure field evaluated in sector-local pixel coordinates (no +-PI seam)
float fx_fissure_field(vec2 p_norm, float seed, float branches) {
	float r = length(p_norm);
	if (r > 1.06) {
		return 0.0;
	}
	float ang = atan(p_norm.y, p_norm.x + 0.00001);
	float base_sector = floor(((ang + 3.14159265) / 6.2831853) * branches);
	float best = 0.0;
	for (int ds = -1; ds <= 1; ds++) {
		float sector = mod(base_sector + float(ds) + branches, branches);
		float sector_center = ((sector + 0.5) / branches) * 6.2831853 - 3.14159265;
		float jitter_ang = (px_hash21(vec2(sector, seed * 3.1)) - 0.5) * (2.2 / max(branches, 3.0));
		float ref_ang = sector_center + jitter_ang;
		vec2 dir = vec2(cos(ref_ang), sin(ref_ang));
		vec2 nrm = vec2(-dir.y, dir.x);
		float along = dot(p_norm, dir);
		if (along < -0.05) {
			continue;
		}
		float perp = dot(p_norm, nrm);
		float meander = (px_vnoise(vec2(r * 6.5, sector * 7.3 + seed)) - 0.5) * 0.14 * clamp(r + 0.15, 0.2, 1.0);
		float arc_dist = abs(perp - meander);
		float width = mix(0.068, 0.022, clamp(r, 0.0, 1.0));
		float main_crack = 1.0 - smoothstep(width * 0.45, width, arc_dist);

		float fork_dir = px_hash21(vec2(sector + 19.0, seed)) > 0.5 ? 1.0 : -1.0;
		float fork_off = max(0.0, r - 0.36) * 0.38 * fork_dir;
		float fork_dist = abs(perp - (meander * 0.65 + fork_off));
		float fork_crack = (1.0 - smoothstep(0.015, 0.038, fork_dist)) * smoothstep(0.33, 0.44, r);
		best = max(best, max(main_crack, fork_crack * 0.86));
	}
	float tip_fade = 1.0 - smoothstep(0.78, 1.02, r);
	return clamp(best * tip_fade, 0.0, 1.0);
}

// Parabolic 2x2-cell debris flecks flying outward from origin
float fx_debris_burst(vec2 p_norm, float progress, float seed, int count) {
	float t = clamp(progress, 0.0, 1.0);
	float best = 0.0;
	for (int i = 0; i < 10; i++) {
		if (i >= count) {
			break;
		}
		float fi = float(i);
		float h0 = px_hash21(vec2(fi * 3.7 + 1.1, seed));
		float h1 = px_hash21(vec2(fi * 7.3 + 5.9, seed * 1.7));
		float ang = (fi + 0.2 + h0 * 0.6) / float(max(count, 1)) * 6.2831853;
		float dist = mix(0.18, 0.84 + h1 * 0.24, pow(t, 0.72));
		float arc_y = -sin(t * 3.14159265) * (0.14 + h0 * 0.16);
		vec2 pos = vec2(cos(ang), sin(ang)) * dist + vec2(0.0, arc_y);
		float sz = mix(0.065, 0.028, t);
		vec2 d = abs(p_norm - pos);
		float box = step(max(d.x, d.y), sz);
		best = max(best, box * (1.0 - smoothstep(0.78, 1.0, t)));
	}
	return best;
}
