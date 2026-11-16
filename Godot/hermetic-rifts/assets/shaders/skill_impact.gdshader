shader_type canvas_item;

uniform float u_time = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_kind : hint_range(0.0, 2.0) = 0.0;
uniform float u_is_crit : hint_range(0.0, 1.0) = 0.0;
uniform float u_seed = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7) + u_seed * 17.31);
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
	return 0.55 * vnoise(p) + 0.30 * vnoise(p * 2.15 + vec2(7.3, 11.1)) + 0.15 * vnoise(p * 4.35 + vec2(13.7, 29.3));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	vec3 col = vec3(0.0);
	float alpha = 0.0;
	float inside = step(r, 1.05);

	if (u_kind < 0.5) {
		float fade = 1.0 - smoothstep(0.68, 1.0, u_progress);
		float wave_r = clamp(u_progress / 0.85, 0.05, 1.0) * 0.82;
		float ring = smoothstep(0.12 * (1.0 - u_progress * 0.45), 0.0, abs(r - wave_r));
		float core = smoothstep(wave_r * 0.72, 0.0, r) * (1.0 - u_progress * 0.88);
		float shard_idx = floor((ang + 3.14159) / (6.28318 / 8.0));
		float shard_rand = hash21(vec2(shard_idx, u_seed));
		vec2 shard_c = vec2(cos((shard_idx + 0.5) * 0.785398), sin((shard_idx + 0.5) * 0.785398)) * (u_progress * (0.45 + 0.50 * shard_rand));
		float shard = step(length(p - shard_c), 0.042 * (1.0 - u_progress * 0.55));
		float smoke_n = fbm(p * 4.2 + u_seed * 3.3);
		float smoke = smoothstep(0.42, 0.76, smoke_n) * step(r, wave_r + 0.12) * (1.0 - u_progress * 0.82);
		vec3 hot = mix(vec3(1.0, 0.957, 0.784), vec3(1.0, 0.88, 0.92), u_is_crit);
		vec3 mid = mix(vec3(0.969, 0.588, 0.090), vec3(1.0, 0.133, 0.32), u_is_crit);
		col = mix(vec3(0.918, 0.310, 0.212), mid, ring);
		col = mix(col, hot, clamp(core * 1.5 + ring * 0.8, 0.0, 1.0));
		col = mix(col, vec3(0.976, 0.761, 0.169), shard * 0.9);
		col = mix(col, vec3(0.243, 0.208, 0.275), smoke * 0.45);
		alpha = clamp((ring * 0.95 + core * 0.85 + shard * 0.98 + smoke * 0.42) * fade, 0.0, 0.95);
	} else if (u_kind < 1.5) {
		float fade = 1.0 - smoothstep(0.72, 1.0, u_progress);
		float beam = smoothstep(mix(0.16, 0.02, clamp(u_progress / 0.30, 0.0, 1.0)), 0.0, abs(p.x)) * (1.0 - clamp(u_progress / 0.30, 0.0, 1.0)) * step(u_progress, 0.30);
		float wave_r = clamp(u_progress / 0.86, 0.05, 1.0) * 0.90;
		float ring1 = smoothstep(0.13 * (1.0 - u_progress * 0.48), 0.0, abs(r - wave_r));
		float ring2 = smoothstep(0.08 * (1.0 - u_progress * 0.3), 0.0, abs(r - wave_r * 0.60)) * (1.0 - u_progress * 0.7);
		float hex = smoothstep(0.09, 0.0, abs(r - wave_r * (0.90 + 0.10 * cos(ang * 6.0)))) * 0.8;
		float crack = smoothstep(0.52, 0.78, fbm(p * 5.2 + vec2(u_seed * 4.3, -u_seed * 3.1))) * step(r, wave_r + 0.06) * (1.0 - u_progress * 0.65);
		float melt = smoothstep(wave_r * 0.50, 0.0, r) * (1.0 - u_progress * 0.92);
		vec3 core_hot = mix(vec3(1.0, 0.965, 0.86), vec3(1.0, 0.9, 0.95), u_is_crit);
		vec3 fire = mix(vec3(0.969, 0.588, 0.09), vec3(1.0, 0.18, 0.35), u_is_crit);
		col = mix(vec3(0.62, 0.157, 0.208), fire, ring1);
		col = mix(col, core_hot, clamp(melt * 1.4 + beam, 0.0, 1.0));
		col = mix(col, vec3(0.976, 0.761, 0.169), hex * 0.65 + ring2 * 0.5);
		col = mix(col, vec3(0.18, 0.094, 0.082), crack * 0.55);
		alpha = clamp((ring1 * 0.95 + ring2 * 0.7 + hex * 0.75 + melt * 0.9 + beam * 0.85 + crack * 0.4) * fade, 0.0, 0.95);
	} else {
		float fade = 1.0 - smoothstep(0.70, 1.0, u_progress);
		float wave_r = clamp(u_progress / 0.80, 0.05, 1.0) * 0.78;
		float ring = smoothstep(0.10, 0.0, abs(r - wave_r));
		float teeth = step(0.55, fract(ang * 5.0 / 6.28318 + u_progress * 0.4)) * smoothstep(0.08, 0.0, abs(r - wave_r * 0.92));
		float core = smoothstep(0.42, 0.0, r) * (1.0 - u_progress * 0.85);
		vec3 gold = mix(vec3(0.97, 0.59, 0.09), vec3(1.0, 0.15, 0.30), u_is_crit);
		col = mix(vec3(0.45, 0.22, 0.08), gold, ring);
		col = mix(col, vec3(0.98, 0.88, 0.42), core * 0.9 + teeth * 0.7);
		alpha = clamp((ring * 0.9 + teeth * 0.8 + core * 0.7) * fade, 0.0, 0.95);
	}

	alpha *= inside;
	COLOR = vec4(col * alpha, alpha);
}
