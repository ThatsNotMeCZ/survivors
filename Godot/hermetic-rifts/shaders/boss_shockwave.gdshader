shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "palette_utils.gdshaderinc"

uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_thickness : hint_range(0.02, 0.5) = 0.12;
uniform float u_style : hint_range(0.0, 2.0) = 0.0;
uniform float u_time = 0.0;
uniform float u_grid_px : hint_range(32.0, 256.0) = 128.0;

void fragment() {
	vec2 uv = quantize_uv(UV, vec2(u_grid_px));
	vec2 p = (uv - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x + 0.00001);

	float ring_r = clamp(u_progress, 0.02, 0.98);
	float hw = max(u_thickness * 0.5, 0.025);
	float d = abs(r - ring_r);
	float band = 1.0 - smoothstep(hw * 0.28, hw, d);
	float crest = 1.0 - smoothstep(0.0, hw * 0.32, abs(r - (ring_r + hw * 0.2)));
	float teeth = 0.72 + 0.28 * step(0.0, sin(ang * 18.0 + u_time * 8.0));
	float wake = step(ring_r - hw * 2.2, r) * step(r, ring_r) * (1.0 - clamp((ring_r - r) / (hw * 2.2), 0.0, 1.0)) * 0.45;

	vec3 c_outer = vec3(0.88, 0.25, 0.16);
	vec3 c_mid = vec3(0.98, 0.62, 0.15);
	vec3 c_hot = vec3(1.0, 0.94, 0.70);
	if (u_style >= 1.5) {
		c_outer = vec3(0.28, 0.54, 0.92);
		c_mid = vec3(0.90, 0.76, 0.26);
		c_hot = vec3(0.96, 0.98, 1.0);
	} else if (u_style >= 0.5) {
		c_outer = vec3(0.18, 0.48, 0.82);
		c_mid = vec3(0.45, 0.85, 1.0);
		c_hot = vec3(0.94, 0.99, 1.0);
	}

	float intensity = clamp(band * teeth + wake, 0.0, 1.0);
	vec3 col = mix(c_outer, c_mid, clamp(band, 0.0, 1.0));
	col = mix(col, c_hot, clamp(crest * 0.9, 0.0, 1.0));
	col = lut_sample(col, u_lut_tex);

	float fade = 1.0 - smoothstep(0.86, 1.0, u_progress);
	float alpha = clamp(intensity * step(r, 1.0) * fade * 0.92, 0.0, 0.92);
	COLOR = vec4(col, alpha);
}
