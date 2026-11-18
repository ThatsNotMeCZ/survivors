shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "palette_utils.gdshaderinc"

uniform sampler2D u_mask_tex : filter_nearest, repeat_disable;
uniform float u_charges : hint_range(0.0, 3.0) = 0.0;
uniform float u_depleted : hint_range(0.0, 1.0) = 0.0;
uniform float u_time = 0.0;

void fragment() {
	vec2 uv = quantize_uv_tex(UV, TEXTURE_PIXEL_SIZE);
	vec4 base = texture(TEXTURE, uv);
	vec4 outc = base;
	if (base.a >= 0.05) {
		vec4 mask = texture(u_mask_tex, uv);
		float m_val = max(mask.r, max(mask.g, mask.b)) * mask.a;
		if (u_depleted > 0.5) {
			float gray = dot(base.rgb, vec3(0.299, 0.587, 0.114));
			vec3 cold = vec3(gray * 0.58, gray * 0.60, gray * 0.72);
			float dim_pulse = 0.15 + 0.10 * sin(u_time * 2.5);
			outc.rgb = mix(cold, vec3(0.18, 0.24, 0.34), step(0.08, m_val) * (0.75 - dim_pulse));
		} else if (m_val > 0.08) {
			vec3 c_dim = lut_sample(vec3(0.12, 0.34, 0.42), u_lut_tex);
			vec3 c_lit = lut_sample(vec3(0.32, 0.92, 0.96), u_lut_tex);
			vec3 c_hot = lut_sample(vec3(0.92, 0.98, 1.0), u_lut_tex);
			if (uv.y > 0.70) {
				float rune_lit = 0.0;
				if (uv.x < 0.44) {
					rune_lit = step(0.5, u_charges);
				} else if (uv.x <= 0.56) {
					rune_lit = step(1.5, u_charges);
				} else {
					rune_lit = step(2.5, u_charges);
				}
				float pulse = 0.78 + 0.22 * sin(u_time * 6.0);
				outc.rgb = mix(c_dim, mix(c_lit, c_hot, 0.45 * pulse), rune_lit);
			} else {
				float rise = clamp((0.63 - uv.y) / 0.50, 0.0, 1.0);
				float charge_frac = clamp(u_charges / 3.0, 0.0, 1.0);
				float lit = step(rise, charge_frac + 0.06) * step(0.5, u_charges);
				float idle_shimmer = 0.25 + 0.18 * sin(u_time * 3.0 - uv.y * 12.0);
				float active_pulse = 0.65 + 0.35 * sin(u_time * 7.5 - uv.y * 16.0);
				vec3 unlit_col = mix(base.rgb * 0.68, c_dim, 0.45 + idle_shimmer * 0.3);
				vec3 lit_col = mix(c_lit, c_hot, clamp(m_val * 0.65 + active_pulse * 0.35, 0.0, 1.0));
				outc.rgb = mix(unlit_col, lit_col, lit);
			}
		}
	}
	COLOR = outc;
}
