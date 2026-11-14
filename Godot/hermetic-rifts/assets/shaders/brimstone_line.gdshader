shader_type canvas_item;

uniform float u_time = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_seed = 0.13;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7) + u_seed * 13.37);
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
	return 0.54 * vnoise(p) + 0.30 * vnoise(p * 2.15 + vec2(7.3, 11.1)) + 0.16 * vnoise(p * 4.35 + vec2(13.7, 29.3));
}

void fragment() {
	vec4 outc = vec4(0.0);
	float ignite = clamp(u_progress / 0.12, 0.0, 1.0);
	if (abs(UV.x - 0.5) <= ignite * 0.52) {
		float fade = 1.0 - smoothstep(0.78, 1.0, u_progress);
		float along = (UV.x - 0.5) * 2.0;
		float seam = (fbm(vec2(along * 6.0, u_seed * 3.1)) - 0.5) * 0.18;
		float dist = abs((UV.y - 0.5) - seam);
		float core = smoothstep(0.42, 0.04, dist);
		float tongue = fbm(vec2(along * 8.0 + u_time * 2.4, UV.y * 10.0 - u_time * 4.5));
		float flame = core * (0.55 + 0.45 * tongue) * fade;
		vec3 ember = vec3(0.62, 0.12, 0.06);
		vec3 amber = vec3(0.97, 0.45, 0.08);
		vec3 gold = vec3(1.0, 0.86, 0.38);
		vec3 col = mix(ember, amber, clamp(flame, 0.0, 1.0));
		col = mix(col, gold, pow(core, 3.0) * fade);
		float alpha = clamp(flame * 0.92, 0.0, 0.95);
		outc = vec4(col * alpha, alpha);
	}
	COLOR = outc;
}
