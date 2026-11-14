shader_type canvas_item;

uniform float u_time = 0.0;
uniform float u_style : hint_range(0.0, 1.0) = 0.0;
uniform float u_player_in : hint_range(0.0, 1.0) = 0.0;
uniform float u_seed = 0.2;

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

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	const float GRID = 64.0;
	vec2 uv = (floor(UV * GRID) + 0.5) / GRID;
	vec2 p = (uv - 0.5) * 2.0;
	float r = length(p);
	float n = vnoise(uv * 6.0 + vec2(u_time * 0.35, u_time * 0.22));
	float bubble = step(0.82, vnoise(uv * 9.0 - vec2(0.0, u_time * 0.8)));
	vec3 lava = vec3(0.72, 0.18, 0.06);
	vec3 brine = vec3(0.12, 0.42, 0.48);
	vec3 fluid = mix(lava, brine, u_style);
	vec3 hot = mix(fluid, vec3(1.0, 0.72, 0.22), n * (1.0 - u_style));
	hot = mix(hot, vec3(0.55, 0.92, 0.95), n * u_style);
	float mask = max(base.a, smoothstep(0.92, 0.35, r));
	vec3 rgb = mix(base.rgb, hot, 0.55 + 0.25 * u_player_in);
	rgb += vec3(1.0, 0.85, 0.4) * bubble * 0.35 * (1.0 - u_style);
	rgb += vec3(0.7, 0.95, 1.0) * bubble * 0.28 * u_style;
	COLOR = vec4(rgb, mask * mix(0.72, 0.92, u_player_in));
}
