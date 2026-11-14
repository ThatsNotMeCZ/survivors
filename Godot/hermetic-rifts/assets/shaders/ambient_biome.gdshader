shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float u_time = 0.0;
uniform float u_biome : hint_range(0.0, 1.0) = 0.0;
uniform vec2 u_view_origin = vec2(0.0, 0.0);
uniform vec2 u_view_size = vec2(800.0, 450.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	float n = hash21(p);
	return vec2(n, hash21(p + n + 19.19));
}

float value_noise(vec2 p) {
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
	float v = 0.0;
	v += 0.55 * value_noise(p);
	v += 0.30 * value_noise(p * 2.07 + vec2(13.1, 7.7));
	v += 0.15 * value_noise(p * 4.13 + vec2(3.7, 29.3));
	return v;
}

float particle_layer(vec2 world_pos, float cell_size, vec2 vel, float radius, float seed_v, float pulse_speed) {
	vec2 p = (world_pos + vel * u_time) / cell_size;
	vec2 cell = floor(p);
	vec2 local = fract(p) - vec2(0.5);
	vec2 rnd = hash22(cell + vec2(seed_v));
	if (rnd.x < 0.68) {
		return 0.0;
	}
	vec2 offset = (rnd - vec2(0.5)) * 0.62;
	offset.x += sin(u_time * pulse_speed + rnd.y * 6.2831) * 0.12;
	float d = length(local - offset);
	float core = smoothstep(radius, radius * 0.15, d);
	float twinkle = 0.65 + 0.35 * sin(u_time * (pulse_speed * 1.4) + rnd.x * 12.0);
	return core * twinkle;
}

void fragment() {
	vec2 world_pos = u_view_origin + UV * u_view_size;
	vec2 mist_drift = u_biome < 0.5 ? vec2(-14.0, -9.0) : vec2(18.0, 11.0);
	float mist1 = fbm((world_pos + mist_drift * u_time) * 0.0045);
	float mist2 = fbm((world_pos - mist_drift * 0.6 * u_time + vec2(91.0, 43.0)) * 0.008);
	float mist = smoothstep(0.46, 0.78, mist1 * 0.65 + mist2 * 0.35);

	vec3 col = vec3(0.0);
	float alpha = 0.0;
	if (u_biome < 0.5) {
		vec3 smoke_col = vec3(0.24, 0.11, 0.08);
		float smoke_a = mist * 0.14;
		col += smoke_col * smoke_a;
		alpha += smoke_a;
		float ash = particle_layer(world_pos, 115.0, vec2(13.0, -11.0), 0.052, 11.3, 1.6)
			+ particle_layer(world_pos, 165.0, vec2(9.0, -7.0), 0.042, 37.9, 1.2) * 0.65;
		vec3 ash_col = vec3(0.58, 0.49, 0.44);
		float ash_a = clamp(ash, 0.0, 1.0) * 0.34;
		col += ash_col * ash_a;
		alpha += ash_a;
		float ember = particle_layer(world_pos, 140.0, vec2(5.0, 24.0), 0.060, 73.1, 3.2)
			+ particle_layer(world_pos, 200.0, vec2(-7.0, 31.0), 0.050, 109.7, 2.7);
		float ember_clamped = clamp(ember, 0.0, 1.0);
		vec3 ember_col = mix(vec3(1.0, 0.38, 0.12), vec3(1.0, 0.88, 0.45), ember_clamped);
		float ember_a = ember_clamped * 0.62;
		col += ember_col * ember_a;
		alpha += ember_a;
	} else {
		vec3 fog_col = vec3(0.32, 0.62, 0.84);
		float fog_a = mist * 0.16;
		col += fog_col * fog_a;
		alpha += fog_a;
		float snow1 = particle_layer(world_pos, 110.0, vec2(-22.0, -18.0), 0.052, 19.7, 1.8);
		float snow2 = particle_layer(world_pos, 160.0, vec2(-15.0, -13.0), 0.045, 53.4, 1.3);
		float snow = clamp(snow1 + snow2 * 0.8, 0.0, 1.0);
		vec3 snow_col = vec3(0.86, 0.95, 1.0);
		float snow_a = snow * 0.42;
		col += snow_col * snow_a;
		alpha += snow_a;
		float glint = particle_layer(world_pos, 185.0, vec2(-9.0, -6.0), 0.040, 141.2, 4.0);
		vec3 glint_col = vec3(0.55, 0.92, 1.0);
		float glint_a = clamp(glint, 0.0, 1.0) * 0.50;
		col += glint_col * glint_a;
		alpha += glint_a;
	}
	alpha = clamp(alpha, 0.0, 0.78);
	COLOR = vec4(col, alpha);
}
