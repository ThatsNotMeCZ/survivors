shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "palette_utils.gdshaderinc"

uniform float u_affix : hint_range(0.0, 4.0) = 0.0;
uniform float u_shield_active : hint_range(0.0, 1.0) = 1.0;
uniform float u_corpse : hint_range(0.0, 1.0) = 0.0;
uniform float u_time = 0.0;

void fragment() {
	vec2 uv = quantize_uv_tex(UV, TEXTURE_PIXEL_SIZE);
	vec4 base = texture(TEXTURE, uv);
	vec4 outc = base;
	if (u_affix >= 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float a_l = texture(TEXTURE, uv + vec2(-px.x, 0.0)).a;
		float a_r = texture(TEXTURE, uv + vec2(px.x, 0.0)).a;
		float a_d = texture(TEXTURE, uv + vec2(0.0, -px.y)).a;
		float a_u = texture(TEXTURE, uv + vec2(0.0, px.y)).a;
		float neighbor = max(max(a_l, a_r), max(a_d, a_u));
		bool is_outline = base.a <= 0.35 && neighbor > 0.35;

		if (u_affix < 1.5) {
			if (is_outline) {
				float wave = 0.5 + 0.5 * sin(u_time * 5.0 + uv.y * 14.0);
				vec3 active_col = mix(vec3(0.302, 0.608, 0.902), vec3(0.561, 0.828, 1.0), wave * 0.6);
				vec3 broken_col = vec3(0.282, 0.290, 0.467);
				vec3 ol = lut_sample(mix(broken_col, active_col, step(0.5, u_shield_active)), u_lut_tex);
				outc = vec4(ol, mix(0.48, 0.96, step(0.5, u_shield_active)));
			} else if (base.a <= 0.35) {
				outc = vec4(0.0);
			}
		} else if (u_affix < 2.5) {
			float pulse = 0.5 + 0.5 * sin(u_time * 4.5 + uv.x * 8.0);
			vec3 viridian = lut_sample(vec3(0.118, 0.737, 0.451), u_lut_tex);
			vec3 lime = lut_sample(vec3(0.569, 0.859, 0.412), u_lut_tex);
			vec3 ol = mix(viridian, lime, pulse);
			if (is_outline) {
				outc = vec4(ol, mix(0.88, 1.0, step(0.5, u_corpse)));
			} else if (base.a > 0.35) {
				vec3 body_col = mix(base.rgb, ol, mix(0.28, 0.52, pulse));
				body_col = mix(body_col, lime, 0.48 * step(0.5, u_corpse));
				outc = vec4(body_col, base.a);
			} else {
				outc = vec4(0.0);
			}
		} else if (u_affix < 3.5) {
			vec2 cell = floor(uv / max(px, vec2(0.0001)));
			float ember_flick = px_hash21(cell + vec2(0.0, floor(u_time * 10.0)));
			vec3 crimson = lut_sample(vec3(0.910, 0.231, 0.231), u_lut_tex);
			vec3 amber = lut_sample(vec3(0.976, 0.680, 0.169), u_lut_tex);
			vec3 ol = mix(crimson, amber, step(0.45, ember_flick));
			if (is_outline) {
				outc = vec4(ol, 0.96);
			} else if (base.a > 0.35) {
				float pulse = 0.20 + 0.18 * sin(u_time * 6.5 - uv.y * 10.0);
				outc = vec4(mix(base.rgb, amber, pulse * step(0.4, uv.y)), base.a);
			} else {
				outc = vec4(0.0);
			}
		} else {
			vec2 cell = floor(uv / max(px, vec2(0.0001)));
			float arc_rnd = px_hash21(cell + vec2(floor(u_time * 16.0), 13.7));
			vec3 e_cyan = lut_sample(vec3(0.353, 0.831, 1.0), u_lut_tex);
			vec3 e_gold = lut_sample(vec3(0.980, 0.880, 0.380), u_lut_tex);
			vec3 ol = mix(e_cyan, e_gold, step(0.60, arc_rnd));
			if (is_outline) {
				float on = step(0.18, arc_rnd);
				outc = vec4(ol, mix(0.65, 1.0, on));
			} else if (base.a > 0.35) {
				float glint = step(0.92, arc_rnd) * 0.45;
				outc = vec4(mix(base.rgb, e_gold, glint), base.a);
			} else {
				outc = vec4(0.0);
			}
		}
	}
	COLOR = outc;
}
