shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float u_time = 0.0;
uniform float u_style : hint_range(0.0, 2.0) = 0.0;
uniform float u_player_in : hint_range(0.0, 1.0) = 0.0;
uniform float u_seed = 0.2;
uniform float u_fade : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7) + u_seed * 17.31);
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	float n = hash21(p);
	return vec2(n, hash21(p + n + 19.19));
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
	float v = 0.0;
	v += 0.52 * vnoise(p);
	v += 0.31 * vnoise(p * 2.08 + vec2(13.1, 7.7));
	v += 0.17 * vnoise(p * 4.15 + vec2(3.7, 29.3));
	return v;
}

float micro_bubble(vec2 p, float speed, float scale) {
	vec2 sp = p * scale;
	vec2 cell = floor(sp);
	vec2 local = fract(sp) - vec2(0.5);
	vec2 rnd = hash22(cell);
	float life_time = fract(u_time * speed + rnd.x * 6.28);
	float grow = sin(clamp(life_time / 0.85, 0.0, 1.0) * 3.14159);
	float radius = grow * (0.16 + rnd.y * 0.12);
	vec2 offset = (rnd - vec2(0.5)) * 0.35;
	float d = length(local - offset);
	return step(d, radius) * step(0.04, radius) * step(life_time, 0.92);
}

float bayer4(vec2 p) {
	vec2 f = floor(mod(p, 4.0));
	float x = f.x;
	float y = f.y;
	float v = 0.0;
	if (y < 0.5) {
		v = x < 0.5 ? 0.0 : (x < 1.5 ? 8.0 : (x < 2.5 ? 2.0 : 10.0));
	} else if (y < 1.5) {
		v = x < 0.5 ? 12.0 : (x < 1.5 ? 4.0 : (x < 2.5 ? 14.0 : 6.0));
	} else if (y < 2.5) {
		v = x < 0.5 ? 3.0 : (x < 1.5 ? 11.0 : (x < 2.5 ? 1.0 : 9.0));
	} else {
		v = x < 0.5 ? 15.0 : (x < 1.5 ? 7.0 : (x < 2.5 ? 13.0 : 5.0));
	}
	return v / 16.0;
}

vec3 pal_pick(vec3 c, vec3 a, vec3 b, vec3 d, vec3 e, vec3 f) {
	float da = dot(c - a, c - a);
	float db = dot(c - b, c - b);
	float dd = dot(c - d, c - d);
	float de = dot(c - e, c - e);
	float df = dot(c - f, c - f);
	float best = da;
	vec3 outc = a;
	if (db < best) {
		best = db;
		outc = b;
	}
	if (dd < best) {
		best = dd;
		outc = d;
	}
	if (de < best) {
		best = de;
		outc = e;
	}
	if (df < best) {
		outc = f;
	}
	return outc;
}

void fragment() {
	const float GRID = 64.0;
	vec2 uv = (floor(UV * GRID) + 0.5) / GRID;
	vec2 p = (uv - 0.5) * 2.0;
	float r = length(p);
	float edge_noise = fbm(p * 2.4 + vec2(u_seed * 2.1, -u_seed));
	float pool_r = 0.82 + (edge_noise - 0.5) * 0.28;
	float mask = smoothstep(pool_r, pool_r - 0.26, r);
	float dither = bayer4(uv * GRID + vec2(u_seed * 5.0, u_seed * 3.0));
	float rim = smoothstep(0.04, 0.42, mask);
	float keep = step(dither * 0.62, rim);
	vec3 col = vec3(0.0);
	float alpha = 0.0;
	if (mask >= 0.03 && keep >= 0.5) {
		float flow_speed = mix(0.12, 0.22, u_player_in);
		vec2 flow = vec2(
			fbm(p * 2.0 + vec2(u_time * flow_speed, -u_time * flow_speed * 0.8)),
			fbm(p * 2.0 + vec2(-u_time * flow_speed * 0.8, u_time * flow_speed))
		);
		float surface = fbm(p * 3.0 + flow * 0.8);
		float micro1 = micro_bubble(p + flow * 0.1, mix(0.18, 0.32, u_player_in), 7.0);
		float micro2 = micro_bubble(p - flow * 0.12 + vec2(13.7, 29.1), mix(0.22, 0.38, u_player_in), 9.0);
		float micro_total = clamp(micro1 + micro2, 0.0, 1.0);
		if (u_style > 1.5) {
			vec3 deep_cyan = vec3(0.118, 0.227, 0.373);
			vec3 mid_blue = vec3(0.302, 0.608, 0.902);
			vec3 bright_cyan = vec3(0.561, 0.827, 1.0);
			vec3 dusk = vec3(0.282, 0.290, 0.467);
			vec3 hot_glint = vec3(0.918, 0.969, 0.976);
			vec3 fluid = mix(deep_cyan, mid_blue, surface);
			fluid = mix(fluid, bright_cyan, micro_total * 0.85);
			col = pal_pick(fluid, deep_cyan, dusk, mid_blue, bright_cyan, hot_glint);
			alpha = clamp(0.42 + surface * 0.28 + micro_total * 0.22, 0.0, 0.78);
		} else if (u_style > 0.5) {
			vec3 deep_green = vec3(0.137, 0.565, 0.388);
			vec3 caustic_green = vec3(0.118, 0.737, 0.451);
			vec3 neon_acid = vec3(0.569, 0.859, 0.412);
			vec3 acid_spec = vec3(0.804, 0.875, 0.424);
			vec3 moss = vec3(0.133, 0.333, 0.125);
			vec3 fluid = mix(deep_green, caustic_green, surface);
			fluid = mix(fluid, neon_acid, micro_total * 0.9);
			float sizzle = u_player_in * (0.5 + 0.5 * sin(u_time * 3.5)) * 0.20;
			fluid += acid_spec * sizzle;
			col = pal_pick(fluid, moss, deep_green, caustic_green, neon_acid, acid_spec);
			alpha = clamp(0.44 + surface * 0.26 + micro_total * 0.20 + sizzle, 0.0, 0.80);
		} else {
			vec3 crust = vec3(0.180, 0.094, 0.082);
			vec3 deep_magma = vec3(0.620, 0.157, 0.208);
			vec3 magma_deep = vec3(0.918, 0.310, 0.212);
			vec3 lava_ember = vec3(0.969, 0.588, 0.090);
			vec3 lava_glint = vec3(0.976, 0.761, 0.169);
			vec3 fluid = mix(crust, magma_deep, surface);
			fluid = mix(fluid, deep_magma, (1.0 - surface) * 0.35);
			fluid = mix(fluid, lava_ember, step(0.48, surface) * 0.65);
			fluid = mix(fluid, lava_glint, micro_total * 0.85);
			float simmer = u_player_in * (0.5 + 0.5 * sin(u_time * 3.2)) * 0.18;
			fluid += lava_glint * simmer;
			col = pal_pick(fluid, crust, deep_magma, magma_deep, lava_ember, lava_glint);
			alpha = clamp(0.46 + surface * 0.28 + micro_total * 0.18 + simmer, 0.0, 0.86);
		}
		alpha *= clamp(u_fade, 0.0, 1.0);
		alpha *= mix(0.28, 1.0, smoothstep(0.12, 0.62, mask));
	}
	COLOR = vec4(col, alpha);
}
