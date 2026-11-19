shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "palette_utils.gdshaderinc"

uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_time = 0.0;
uniform float u_style : hint_range(0.0, 3.0) = 0.0;
uniform float u_reduce : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 outc = vec4(0.0);
	const float GRID = 80.0;
	vec2 uv = quantize_uv(UV, vec2(GRID));
	vec2 cell = floor(uv * GRID);
	float bayer = px_bayer4(cell);

	// Ground plane centered around boss feet (slightly below visual center)
	vec2 p_ground = vec2((uv.x - 0.5) * 2.0, (uv.y - 0.66) * 2.5);
	float r = length(p_ground);
	float ang = atan(p_ground.y, p_ground.x + 0.00001);

	vec3 c_dark = vec3(0.180, 0.094, 0.082);
	vec3 c_mid  = vec3(0.918, 0.310, 0.212);
	vec3 c_hot  = vec3(0.976, 0.761, 0.169);
	if (u_style >= 2.5) {
		c_dark = vec3(0.24, 0.14, 0.44);
		c_mid  = vec3(0.66, 0.52, 0.95);
		c_hot  = vec3(0.98, 0.88, 0.45);
	} else if (u_style >= 1.5) {
		c_dark = vec3(0.10, 0.30, 0.18);
		c_mid  = vec3(0.35, 0.84, 0.45);
		c_hot  = vec3(0.84, 0.98, 0.68);
	} else if (u_style >= 0.5) {
		c_dark = vec3(0.12, 0.28, 0.55);
		c_mid  = vec3(0.35, 0.83, 1.0);
		c_hot  = vec3(0.90, 0.97, 1.0);
	}

	float env = sin(clamp(u_progress, 0.0, 1.0) * 3.14159265);
	const float SPOKES = 8.0;
	float sector = floor(((ang + 3.14159265) / 6.2831853) * SPOKES);
	float s_ang = ((sector + 0.5) / SPOKES) * 6.2831853 - 3.14159265;
	float wobble = (px_vnoise(vec2(r * 7.0, sector * 4.3)) - 0.5) * 0.32;
	float d_ang = abs(ang - (s_ang + wobble));
	d_ang = min(d_ang, 6.2831853 - d_ang);
	float crack = (1.0 - smoothstep(0.025, 0.075, d_ang * max(r, 0.15))) * (1.0 - smoothstep(0.55, 0.98, r));

	float ring_r = mix(0.25, 0.92, clamp(u_progress, 0.0, 1.0));
	float ring = (1.0 - smoothstep(0.02, 0.08, abs(r - ring_r))) * (1.0 - smoothstep(0.65, 1.0, u_progress));
	float pit = (1.0 - smoothstep(0.16, 0.42, r)) * env;

	float pillar_burst = 0.0;
	if (u_reduce < 0.5 && uv.y < 0.68) {
		float h = clamp((0.68 - uv.y) / 0.68, 0.0, 1.0);
		float x_dist = abs(uv.x - 0.5) * 2.0;
		float shard_n = px_fbm(vec2(uv.x * 18.0, h * 4.0 + u_time * 8.0));
		float w_lim = mix(0.45, 0.14, h);
		pillar_burst = (1.0 - smoothstep(w_lim * 0.3, w_lim, x_dist)) * (1.0 - smoothstep(0.4, 1.0, h)) * shard_n * env;
	}

	float intensity = clamp(max(max(crack * env, ring), max(pit * 0.9, pillar_burst)), 0.0, 1.0);
	if (intensity > bayer * 0.38 + 0.04) {
		vec3 col = mix(c_dark, c_mid, smoothstep(0.12, 0.55, intensity));
		col = mix(col, c_hot, smoothstep(0.55, 0.92, intensity));
		col = lut_sample(col, u_lut_tex);
		outc = vec4(col, clamp(intensity * 1.05, 0.0, 0.95));
	}
	COLOR = outc;
}
