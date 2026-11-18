shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "palette_utils.gdshaderinc"

uniform sampler2D u_mask_tex : filter_nearest, repeat_disable;
uniform float u_state : hint_range(0.0, 3.0) = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_variant : hint_range(0.0, 2.0) = 0.0;
uniform float u_time = 0.0;

void fragment() {
	vec2 uv = quantize_uv_tex(UV, TEXTURE_PIXEL_SIZE);
	vec4 base = texture(TEXTURE, uv);
	vec4 outc = base;
	if (base.a >= 0.05) {
		vec4 mask = texture(u_mask_tex, uv);
		float m_val = max(mask.r, max(mask.g, mask.b)) * mask.a;

		vec3 c_dim = vec3(0.14, 0.38, 0.44);
		vec3 c_lit = vec3(0.32, 0.90, 0.96);
		vec3 c_hot = vec3(0.92, 0.98, 1.0);
		if (u_variant >= 1.5) {
			c_dim = vec3(0.45, 0.10, 0.14);
			c_lit = vec3(0.92, 0.22, 0.26);
			c_hot = vec3(1.0, 0.78, 0.72);
		} else if (u_variant >= 0.5) {
			c_dim = vec3(0.48, 0.32, 0.12);
			c_lit = vec3(0.96, 0.74, 0.22);
			c_hot = vec3(1.0, 0.95, 0.72);
		}

		if (u_state >= 2.5) {
			float gray = dot(base.rgb, vec3(0.299, 0.587, 0.114));
			vec3 dull = vec3(gray * 0.72, gray * 0.70, gray * 0.75);
			outc.rgb = mix(dull, dull * 0.45, step(0.08, m_val));
		} else if (m_val > 0.08) {
			float is_crown = step(uv.y, 0.36);
			float glyph_thr = 0.82;
			if (uv.y >= 0.63) {
				glyph_thr = 0.12;
			} else if (uv.y >= 0.53) {
				glyph_thr = 0.46;
			}
			float rune_lit = step(glyph_thr, u_progress);
			vec3 dim_c = lut_sample(c_dim, u_lut_tex);
			vec3 lit_c = lut_sample(c_lit, u_lut_tex);
			vec3 hot_c = lut_sample(c_hot, u_lut_tex);

			if (u_state < 0.5) {
				float breath = 0.45 + 0.35 * sin(u_time * 2.6 - uv.y * 6.0);
				outc.rgb = mix(base.rgb, mix(dim_c, lit_c, breath), is_crown * 0.45 + (1.0 - is_crown) * 0.25);
			} else if (u_state < 1.5) {
				float wave = 0.65 + 0.35 * sin(u_time * 8.0 - uv.y * 14.0);
				float active_m = max(rune_lit, is_crown * clamp(u_progress, 0.2, 1.0));
				vec3 glow = mix(lit_c, hot_c, clamp(m_val * 0.6 + wave * 0.4, 0.0, 1.0));
				outc.rgb = mix(dim_c, glow, active_m);
			} else {
				float trial_pulse = 0.55 + 0.45 * sin(u_time * 10.5 - uv.y * 16.0);
				outc.rgb = mix(lit_c, hot_c, clamp(m_val * 0.65 + trial_pulse * 0.45, 0.0, 1.0));
			}
		}
	}
	COLOR = outc;
}
