shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "palette_utils.gdshaderinc"

uniform float u_heat : hint_range(0.0, 1.0) = 0.0;
uniform float u_time = 0.0;
uniform float u_overheated : hint_range(0.0, 1.0) = 0.0;
uniform float u_grid_px : hint_range(16.0, 128.0) = 64.0;

void fragment() {
	vec2 uv = quantize_uv(UV, vec2(u_grid_px));
	vec2 p = (uv - 0.5) * 2.0;
	float r = length(p);
	float dither = px_bayer4(uv * u_grid_px);

	float wave = sin(uv.y * 28.0 - u_time * 9.0 + sin(uv.x * 18.0 + u_time * 5.0)) * 0.5 + 0.5;
	float spark_n = px_fbm(uv * 10.0 + vec2(0.0, u_time * 2.4));
	float sparks = step(0.68, spark_n) * step(r, 0.92);

	float ring = (1.0 - smoothstep(0.18, 0.52, abs(r - 0.64))) * (0.55 + 0.45 * wave);
	float core = (1.0 - smoothstep(0.20, 0.88, r)) * 0.45;
	float sweet = step(0.80, u_heat) * (1.0 - u_overheated);
	float pulse = 0.65 + 0.35 * sin(u_time * mix(7.0, 16.0, sweet + u_overheated));

	vec3 col = mix(vec3(0.92, 0.32, 0.12), vec3(0.98, 0.72, 0.22), clamp(ring * 0.6 + sparks * 0.6 + sweet * 0.35, 0.0, 1.0));
	vec3 hot = vec3(1.0, 0.94, 0.68);
	col = mix(col, hot, clamp(sparks * sweet + ring * sweet * 0.45, 0.0, 1.0));

	vec3 over_col = mix(vec3(0.28, 0.14, 0.16), vec3(0.91, 0.23, 0.23), clamp(wave * 0.65 + sparks * 0.5, 0.0, 1.0));
	col = mix(col, over_col, step(0.5, u_overheated));
	col = lut_sample(col, u_lut_tex);

	float strength = clamp(max(u_heat, u_overheated), 0.0, 1.0);
	float mask = step(r, 0.98) * step(dither * 0.55, ring + sparks * 0.75 + core);
	float alpha = clamp((ring * 0.55 + sparks * 0.70 + core * 0.30) * pulse * strength * mask * 0.78, 0.0, 0.85);
	COLOR = vec4(col, alpha);
}
