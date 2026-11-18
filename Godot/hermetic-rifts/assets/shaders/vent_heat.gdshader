shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "palette_utils.gdshaderinc"

uniform float u_state : hint_range(0.0, 2.0) = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_time = 0.0;

void fragment() {
	vec2 uv = quantize_uv_tex(UV, TEXTURE_PIXEL_SIZE);
	vec4 base = texture(TEXTURE, uv);
	vec4 outc = base;
	if (base.a >= 0.05) {
		vec2 p = (uv - 0.5) * 2.0;
		float r = length(p);
		float luma = (base.r + base.g + base.b) / 3.0;
		float inner_slot = step(r, 0.66) * (1.0 - smoothstep(0.14, 0.34, luma));
		float rim_ring = step(0.45, r) * step(r, 0.84) * step(0.28, base.r - base.b * 0.6);
		float n = px_fbm(uv * 18.0 + vec2(0.0, -u_time * 3.5));

		if (u_state < 0.5) {
			float simmer = 0.35 + 0.30 * sin(u_time * 2.2 + r * 4.0);
			vec3 glow = lut_sample(vec3(0.78, 0.25, 0.10), u_lut_tex);
			outc.rgb = mix(base.rgb, glow, inner_slot * simmer * 0.55);
		} else if (u_state < 1.5) {
			float freq = mix(6.0, 24.0, u_progress);
			float flash = 0.5 + 0.5 * sin(u_time * freq);
			float heat_mask = clamp(inner_slot * (0.55 + 0.45 * u_progress) + rim_ring * 0.45 * flash, 0.0, 1.0);
			vec3 fissure = mix(vec3(0.95, 0.42, 0.10), vec3(1.0, 0.92, 0.48), clamp(u_progress * 0.75 + n * 0.45, 0.0, 1.0));
			fissure = lut_sample(fissure, u_lut_tex);
			outc.rgb = mix(base.rgb, fissure, heat_mask * 0.85);
		} else {
			float steam = step(0.38, n) * step(r, 0.85);
			vec3 blast = mix(vec3(0.98, 0.62, 0.14), vec3(1.0, 0.96, 0.82), clamp(inner_slot + steam * 0.65, 0.0, 1.0));
			blast = lut_sample(blast, u_lut_tex);
			float intensity = clamp(inner_slot * 0.95 + steam * 0.65 + rim_ring * 0.55, 0.0, 1.0);
			outc.rgb = mix(base.rgb, blast, intensity);
		}
	}
	COLOR = outc;
}
