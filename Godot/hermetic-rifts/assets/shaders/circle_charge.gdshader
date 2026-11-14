shader_type canvas_item;

uniform float u_time = 0.0;
uniform float u_charge : hint_range(0.0, 1.0) = 0.0;
uniform float u_active : hint_range(0.0, 1.0) = 0.0;
uniform vec2 u_player_offset = vec2(0.0);
uniform float u_style : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return 0.55 * vnoise(p) + 0.30 * vnoise(p * 2.08 + 7.3) + 0.15 * vnoise(p * 4.15 + 19.1);
}

void fragment() {
	vec4 outc = vec4(0.0);
	if (u_active > 0.01) {
		const float GRID = 128.0;
		vec2 uv = (floor(UV * GRID) + 0.5) / GRID;
		vec2 p = (uv - 0.5) * 2.0;
		float r = length(p);
		vec2 p0 = u_player_offset;
		vec2 seg = -p0;
		float seg_len = length(seg);
		if (r <= 1.05 && seg_len > 0.08) {
			vec2 dir = seg / seg_len;
			vec2 normal = vec2(-dir.y, dir.x);
			vec2 to_p = p - p0;
			float t = dot(to_p, dir) / seg_len;
			if (t >= -0.02 && t <= 1.02) {
				float sway = sin(t * 12.0 - u_time * 3.5) * 0.022 * sin(clamp(t, 0.0, 1.0) * 3.14159);
				float dist_to_line = abs(dot(to_p, normal) - sway);
				float tether_width = mix(0.065, 0.038, clamp(t, 0.0, 1.0));
				float beam = smoothstep(tether_width, 0.0, dist_to_line);
				float end_fade = smoothstep(0.0, 0.08, t) * smoothstep(1.0, 0.92, t);
				float travel1 = fract(t * 2.5 - u_time * 0.45);
				float pulse1 = smoothstep(0.0, 0.4, travel1) * smoothstep(1.0, 0.5, travel1);
				float travel2 = fract(t * 3.8 - u_time * 0.65 + 0.5);
				float pulse2 = smoothstep(0.0, 0.35, travel2) * smoothstep(1.0, 0.55, travel2);
				float noise_wave = fbm(vec2(t * 6.0 - u_time * 0.8, dist_to_line * 14.0));
				float tether_mask = beam * end_fade * (0.35 + 0.45 * pulse1 + 0.25 * pulse2 + 0.15 * noise_wave);
				float stream = clamp(t, 0.0, 1.0);
				float center_pool = smoothstep(0.08, 0.0, length(p)) * 0.35;
				float total = tether_mask + center_pool * tether_mask;
				if (total > 0.01) {
					vec3 ember_deep = vec3(0.62, 0.15, 0.08);
					vec3 amber_mid = vec3(0.97, 0.59, 0.09);
					vec3 gold_hot = vec3(0.98, 0.88, 0.42);
					vec3 azure_deep = vec3(0.12, 0.32, 0.65);
					vec3 cyan_mid = vec3(0.32, 0.82, 1.0);
					vec3 silver_hot = vec3(0.88, 0.96, 1.0);
					vec3 col = mix(ember_deep, amber_mid, clamp(stream * 0.7 + tether_mask * 0.4, 0.0, 1.0));
					col = mix(col, gold_hot, clamp(center_pool * 0.9 + tether_mask * 0.3, 0.0, 1.0));
					vec3 rime = mix(azure_deep, cyan_mid, clamp(stream * 0.7 + tether_mask * 0.4, 0.0, 1.0));
					rime = mix(rime, silver_hot, clamp(center_pool * 0.9 + tether_mask * 0.3, 0.0, 1.0));
					col = mix(col, rime, step(0.5, u_style));
					float alpha = clamp(total * u_active * 0.82, 0.0, 0.88);
					alpha *= mix(0.85, 1.0, u_charge);
					outc = vec4(col * alpha, alpha);
				}
			}
		}
	}
	COLOR = outc;
}
