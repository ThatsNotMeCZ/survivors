shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 tint : source_color = vec4(0.55, 0.22, 0.12, 0.08);
uniform float u_time = 0.0;
uniform float density : hint_range(0.0, 1.0) = 0.35;
uniform float u_biome = 0.0;
uniform vec2 u_world_size = vec2(2560.0, 2560.0);

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	float n = hash21(p);
	return vec2(n, hash21(p + n + 19.19));
}

float particle(vec2 world_pos, float cell, vec2 vel, float radius, float seed_v, float pulse) {
	vec2 p = (world_pos + vel * u_time) / cell;
	vec2 cell_id = floor(p);
	vec2 local = fract(p) - vec2(0.5);
	vec2 rnd = hash22(cell_id + vec2(seed_v));
	float gate = step(0.68, rnd.x);
	vec2 offset = (rnd - vec2(0.5)) * 0.62;
	offset.x += sin(u_time * pulse + rnd.y * 6.2831) * 0.12;
	float d = length(local - offset);
	float core = smoothstep(radius, radius * 0.15, d);
	float twinkle = 0.65 + 0.35 * sin(u_time * pulse * 1.4 + rnd.x * 12.0);
	return core * twinkle * gate;
}

void fragment() {
	vec2 world_pos = UV * u_world_size;
	float mist_n = hash21(floor(world_pos * 0.018 + u_time * 0.05));
	float mist = smoothstep(0.52, 0.82, mist_n);
	float ash = particle(world_pos, 42.0, vec2(-14.0, -9.0), 0.07, 11.0, 1.6);
	float ember = particle(world_pos, 64.0, vec2(6.0, -22.0), 0.045, 29.0, 2.4);
	vec3 col = tint.rgb;
	float alpha = mist * tint.a * 1.6;
	if (u_biome < 0.5) {
		alpha += ash * 0.16 * density;
		float ember_a = ember * 0.5 * density;
		col = mix(col, vec3(1.0, 0.55, 0.18), clamp(ember_a * 2.2, 0.0, 1.0));
		alpha += ember_a;
	} else {
		float snow = particle(world_pos, 52.0, vec2(18.0, 11.0), 0.06, 7.0, 1.15);
		alpha += snow * 0.14 * density;
		col = mix(col, vec3(0.78, 0.90, 1.0), 0.35);
	}
	COLOR = vec4(col, clamp(alpha, 0.0, 0.28));
}
