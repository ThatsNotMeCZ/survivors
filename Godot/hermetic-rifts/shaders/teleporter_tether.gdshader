shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "palette_utils.gdshaderinc"

uniform float u_time = 0.0;
uniform float u_charge : hint_range(0.0, 1.0) = 0.0;
uniform float u_active : hint_range(0.0, 1.0) = 1.0;
uniform vec2 u_player_offset = vec2(0.0);
uniform float u_style : hint_range(0.0, 3.0) = 0.0;
uniform float u_grid_px : hint_range(32.0, 256.0) = 128.0;

void fragment() {
	vec4 outc = vec4(0.0);
	if (u_active > 0.01) {
		vec2 uv = quantize_uv(UV, vec2(u_grid_px));
		vec2 p = (uv - 0.5) * 2.0;
		float r = length(p);
		vec2 p0 = u_player_offset;
		vec2 seg = -p0;
		float seg_len = length(seg);
		if (r <= 1.05 && seg_len > 0.06) {
			vec2 dir = seg / seg_len;
			vec2 normal = vec2(-dir.y, dir.x);
			vec2 to_p = p - p0;
			float t = dot(to_p, dir) / seg_len;
			if (t >= -0.02 && t <= 1.02) {
				float sway = sin(t * 14.0 - u_time * 4.5) * 0.025 * sin(clamp(t, 0.0, 1.0) * 3.14159);
				float dist_to_line = abs(dot(to_p, normal) - sway);
				float tether_width = mix(0.068, 0.036, clamp(t, 0.0, 1.0));
				float beam = smoothstep(tether_width, 0.0, dist_to_line);
				float end_fade = smoothstep(0.0, 0.08, t) * smoothstep(1.0, 0.92, t);
				float travel1 = fract(t * 2.6 - u_time * 0.60);
				float pulse1 = smoothstep(0.0, 0.35, travel1) * smoothstep(1.0, 0.50, travel1);
				float travel2 = fract(t * 4.0 - u_time * 0.85 + 0.5);
				float pulse2 = smoothstep(0.0, 0.32, travel2) * smoothstep(1.0, 0.52, travel2);
				float noise_wave = px_fbm(vec2(t * 6.0 - u_time * 1.1, dist_to_line * 14.0));
				float tether_mask = beam * end_fade * (0.38 + 0.45 * pulse1 + 0.25 * pulse2 + 0.15 * noise_wave);
				float center_pool = smoothstep(0.09, 0.0, length(p)) * 0.38;
				float total = tether_mask + center_pool * tether_mask;
				if (total > 0.02) {
					vec3 c_deep = vec3(0.62, 0.15, 0.08);
					vec3 c_mid = vec3(0.97, 0.59, 0.09);
					vec3 c_hot = vec3(0.98, 0.88, 0.42);
					if (u_style >= 2.5) {
						c_deep = vec3(0.28, 0.16, 0.52);
						c_mid = vec3(0.66, 0.52, 0.95);
						c_hot = vec3(0.92, 0.86, 1.0);
					} else if (u_style >= 1.5) {
						c_deep = vec3(0.12, 0.38, 0.22);
						c_mid = vec3(0.35, 0.84, 0.45);
						c_hot = vec3(0.84, 0.98, 0.68);
					} else if (u_style >= 0.5) {
						c_deep = vec3(0.12, 0.32, 0.65);
						c_mid = vec3(0.32, 0.82, 1.0);
						c_hot = vec3(0.88, 0.96, 1.0);
					}
					float stream = clamp(t, 0.0, 1.0);
					vec3 col = mix(c_deep, c_mid, clamp(stream * 0.7 + tether_mask * 0.4, 0.0, 1.0));
					col = mix(col, c_hot, clamp(center_pool * 0.9 + tether_mask * 0.35, 0.0, 1.0));
					col = lut_sample(col, u_lut_tex);
					float alpha = clamp(total * u_active * mix(0.82, 1.0, u_charge), 0.0, 0.90);
					outc = vec4(col, alpha);
				}
			}
		}
	}
	COLOR = outc;
}
