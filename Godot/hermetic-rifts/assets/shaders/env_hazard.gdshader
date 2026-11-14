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

void fragment() {
	const float GRID = 64.0;
	vec4 base = texture(TEXTURE, UV);
	vec2 uv = (floor(UV * GRID) + 0.5) / GRID;
	vec2 p = (uv - 0.5) * 2.0;
	COLOR = vec4(0.0);
	if (base.a >= 0.2) {
		float liquid_mask = 0.0;
		if (u_style < 0.5) {
			float warmth = base.r - base.b;
			float brightness = max(base.r, base.g);
			liquid_mask = smoothstep(0.20, 0.42, warmth) * step(0.26, brightness);
		} else {
			float green_hue = base.g - base.r * 0.75;
			liquid_mask = smoothstep(0.08, 0.28, green_hue) * step(0.24, base.g);
		}
		if (liquid_mask <= 0.02) {
			COLOR = base;
		} else {
			float flow_speed = mix(0.12, 0.22, u_player_in);
			vec2 flow = vec2(
				fbm(p * 2.0 + vec2(u_time * flow_speed, -u_time * flow_speed * 0.8)),
				fbm(p * 2.0 + vec2(-u_time * flow_speed * 0.8, u_time * flow_speed))
			);
			float surface = fbm(p * 3.0 + flow * 0.8);
			float micro1 = micro_bubble(p + flow * 0.1, mix(0.18, 0.32, u_player_in), 7.0);
			float micro2 = micro_bubble(p - flow * 0.12 + vec2(13.7, 29.1), mix(0.22, 0.38, u_player_in), 9.0);
			float micro_total = clamp(micro1 + micro2, 0.0, 1.0);
			vec3 col = vec3(0.0);
			float alpha = 0.0;
			if (u_style > 1.5) {
				vec3 deep_cyan = vec3(0.12, 0.55, 0.85);
				vec3 bright_cyan = vec3(0.45, 0.92, 1.0);
				vec3 hot_glint = vec3(0.92, 0.98, 1.0);
				vec3 fluid = mix(deep_cyan, bright_cyan, surface);
				fluid = mix(fluid, hot_glint, micro_total * 0.85);
				col = fluid;
				alpha = clamp((0.35 + surface * 0.30 + micro_total * 0.35) * liquid_mask, 0.0, 0.65);
			} else if (u_style > 0.5) {
				vec3 caustic_green = vec3(0.118, 0.737, 0.451);
				vec3 neon_acid = vec3(0.569, 0.859, 0.412);
				vec3 acid_spec = vec3(0.804, 0.875, 0.424);
				vec3 fluid = mix(caustic_green, neon_acid, surface);
				fluid = mix(fluid, acid_spec, micro_total * 0.9);
				float sizzle = u_player_in * (0.5 + 0.5 * sin(u_time * 3.5)) * 0.20;
				col = fluid + acid_spec * sizzle;
				alpha = clamp((0.38 + surface * 0.30 + micro_total * 0.32 + sizzle) * liquid_mask, 0.0, 0.68);
			} else {
				vec3 magma_deep = vec3(0.918, 0.310, 0.212);
				vec3 lava_ember = vec3(0.969, 0.588, 0.090);
				vec3 lava_glint = vec3(0.976, 0.761, 0.169);
				vec3 fluid = mix(magma_deep, lava_ember, surface);
				fluid = mix(fluid, lava_glint, micro_total * 0.85);
				float simmer = u_player_in * (0.5 + 0.5 * sin(u_time * 3.2)) * 0.18;
				col = fluid + lava_glint * simmer;
				alpha = clamp((0.36 + surface * 0.32 + micro_total * 0.32 + simmer) * liquid_mask, 0.0, 0.68);
			}
			alpha *= clamp(u_fade, 0.0, 1.0);
			vec3 rgb = mix(base.rgb, col, clamp(alpha / max(base.a, 0.001), 0.0, 1.0));
			COLOR = vec4(rgb, max(base.a, alpha));
		}
	}
}
