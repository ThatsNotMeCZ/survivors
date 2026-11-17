shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float u_time = 0.0;
uniform float u_kind : hint_range(0.0, 4.0) = 1.0;
uniform float u_style : hint_range(0.0, 2.0) = 0.0;
uniform float u_state : hint_range(0.0, 1.0) = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_angle = 0.8;
uniform vec2 u_dir = vec2(1.0, 0.0);
uniform float u_radius = 620.0;
uniform mat4 u_pillars0;
uniform mat4 u_pillars1;
uniform mat4 u_pillars2;
uniform mat4 u_pillars3;

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
	return 0.55 * vnoise(p) + 0.30 * vnoise(p * 2.1 + 11.3) + 0.15 * vnoise(p * 4.3 + 27.1);
}

bool ray_blocked_by_pillar(vec2 target, vec4 pil) {
	if (pil.w < 0.5) {
		return false;
	}
	float len = length(target);
	if (len < 1.0) {
		return false;
	}
	vec2 dir = target / len;
	float proj = dot(pil.xy, dir);
	if (proj <= 0.0 || proj >= len) {
		return false;
	}
	vec2 closest = dir * proj;
	float dist_sq = dot(pil.xy - closest, pil.xy - closest);
	return dist_sq <= pil.z * pil.z;
}

bool is_shadowed(vec2 pos) {
	if (ray_blocked_by_pillar(pos, u_pillars0[0])) return true;
	if (ray_blocked_by_pillar(pos, u_pillars0[1])) return true;
	if (ray_blocked_by_pillar(pos, u_pillars0[2])) return true;
	if (ray_blocked_by_pillar(pos, u_pillars0[3])) return true;
	if (ray_blocked_by_pillar(pos, u_pillars1[0])) return true;
	if (ray_blocked_by_pillar(pos, u_pillars1[1])) return true;
	if (ray_blocked_by_pillar(pos, u_pillars1[2])) return true;
	if (ray_blocked_by_pillar(pos, u_pillars1[3])) return true;
	if (ray_blocked_by_pillar(pos, u_pillars2[0])) return true;
	if (ray_blocked_by_pillar(pos, u_pillars2[1])) return true;
	if (ray_blocked_by_pillar(pos, u_pillars2[2])) return true;
	if (ray_blocked_by_pillar(pos, u_pillars2[3])) return true;
	if (ray_blocked_by_pillar(pos, u_pillars3[0])) return true;
	if (ray_blocked_by_pillar(pos, u_pillars3[1])) return true;
	return false;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	vec3 col = vec3(0.0);
	float alpha = 0.0;
	float keep = 1.0;

	if (u_kind < 0.5) {
		keep = step(r, 1.02);
		float outer_ring = smoothstep(0.06, 0.0, abs(r - 0.96));
		float fill_r = clamp(u_progress, 0.08, 1.0) * 0.96;
		float fill_edge = smoothstep(0.04, 0.0, abs(r - fill_r));
		float cracks = fbm(p * 4.5 + vec2(u_time * 0.8, -u_time * 0.6));
		float inner_fill = step(r, fill_r) * (0.20 + 0.32 * u_progress + 0.25 * cracks);
		float urgent = u_progress > 0.72 ? (0.5 + 0.5 * sin(u_time * 28.0)) : 0.0;
		vec3 base_col = u_style < 0.5 ? vec3(1.0, 0.42, 0.12) : vec3(0.42, 0.82, 1.0);
		vec3 hot_col = u_style < 0.5 ? vec3(1.0, 0.92, 0.65) : vec3(0.92, 0.98, 1.0);
		alpha = clamp(outer_ring * 0.92 + fill_edge * 0.85 + inner_fill, 0.0, 0.95);
		col = mix(base_col, hot_col, clamp(outer_ring + fill_edge * 0.7 + urgent * 0.5, 0.0, 1.0));
	} else if (u_kind < 1.5) {
		float fade = 1.0 - smoothstep(0.75, 1.0, u_progress);
		if (u_style < 0.5) {
			const float GRID = 64.0;
			vec2 uv_grid = (floor(uv * GRID) + 0.5) / GRID;
			vec2 p_grid = (uv_grid - 0.5) * 2.0;
			float r_grid = length(p_grid);
			float boil_speed = 0.14;
			float anim_time = u_time * boil_speed;
			float edge_noise = fbm(p_grid * 2.5 + vec2(sin(anim_time * 0.8), cos(anim_time * 0.6)) * 0.35);
			float pool_r = 0.86 + (edge_noise - 0.5) * 0.14;
			float pool_mask = smoothstep(pool_r, pool_r - 0.14, r_grid);
			keep = step(r_grid, 1.0) * step(0.01, pool_mask);
			vec2 flow = vec2(
				fbm(p_grid * 1.6 + vec2(anim_time * 0.2, -anim_time * 0.16)),
				fbm(p_grid * 1.6 + vec2(-anim_time * 0.16, anim_time * 0.2))
			);
			float surface = fbm(p_grid * 2.4 + flow * 0.8);
			vec3 crust = vec3(0.180, 0.094, 0.082);
			vec3 deep_magma = vec3(0.620, 0.157, 0.208);
			vec3 magma_deep = vec3(0.918, 0.310, 0.212);
			vec3 lava_ember = vec3(0.969, 0.588, 0.090);
			vec3 lava_glint = vec3(0.976, 0.761, 0.169);
			float heat_veins = step(0.48, surface);
			vec3 fluid = mix(crust, magma_deep, surface);
			fluid = mix(fluid, deep_magma, (1.0 - surface) * 0.45);
			fluid = mix(fluid, lava_ember, heat_veins * 0.65);
			float spark_noise = fbm(p_grid * 7.0 - vec2(anim_time * 0.8, -anim_time * 0.6));
			float spark_glow = step(0.76, spark_noise);
			fluid = mix(fluid, lava_glint, spark_glow * 0.8);
			col = fluid;
			alpha = clamp((0.40 + surface * 0.38 + spark_glow * 0.2) * pool_mask * fade * 0.92, 0.0, 0.92);
		} else {
			float n = fbm(p * 3.8 + vec2(u_time * 0.65, -u_time * 0.45));
			float edge_r = 0.88 + (n - 0.5) * 0.18;
			keep = step(r, edge_r);
			float rim = smoothstep(edge_r, edge_r - 0.14, r);
			float veins = fbm(p * 7.2 - vec2(u_time * 1.1, u_time * 0.8));
			float shard = smoothstep(0.45, 0.75, veins);
			vec3 deep_ice = vec3(0.16, 0.42, 0.68);
			vec3 rime = mix(vec3(0.45, 0.84, 1.0), vec3(0.92, 0.98, 1.0), shard);
			col = mix(deep_ice, rime, shard);
			alpha = rim * fade * 0.68;
		}
	} else if (u_kind < 2.5) {
		keep = step(r, 1.04);
		float teeth = 0.045 * cos(ang * 12.0 + u_time * 3.0);
		if (u_state < 0.5) {
			float outer_ring = smoothstep(0.05, 0.0, abs(r - 0.95));
			float close_r = max(0.14, (1.0 - u_progress * 0.82) * 0.95 + teeth);
			float closing_ring = smoothstep(0.065, 0.0, abs(r - close_r));
			float frost_web = step(close_r, r) * step(r, 0.95) * 0.22;
			float flash = u_progress > 0.75 ? (0.5 + 0.5 * sin(u_time * 30.0)) : 0.0;
			vec3 ice_col = mix(vec3(0.35, 0.82, 1.0), vec3(0.95, 0.99, 1.0), clamp(closing_ring + flash * 0.5, 0.0, 1.0));
			alpha = clamp(outer_ring * 0.85 + closing_ring * 0.95 + frost_web, 0.0, 0.95);
			col = ice_col;
		} else {
			float fade = 1.0 - u_progress;
			float cage = smoothstep(0.08, 0.0, abs(r - (0.38 + teeth * 1.6))) + step(r, 0.38) * 0.45;
			col = vec3(0.82, 0.96, 1.0);
			alpha = clamp(cage * fade, 0.0, 0.9);
		}
	} else if (u_kind < 3.5) {
		vec2 dir = normalize(u_dir);
		float cos_half = cos(u_angle * 0.5);
		float safe_r = max(r, 0.001);
		float dot_dir = dot(p / safe_r, dir);
		keep = step(0.04, r) * step(r, 1.0) * step(cos_half, dot_dir);
		float ang_factor = clamp((dot_dir - cos_half) / max(0.001, 1.0 - cos_half), 0.0, 1.0);
		float edge_border = smoothstep(0.08, 0.0, ang_factor) + smoothstep(0.05, 0.0, abs(r - 0.97));
		float radial_flow = fbm(vec2(r * 5.0 - u_time * 3.6, ang * 3.5));
		if (u_state < 0.5) {
			float sweep = step(r, clamp(u_progress, 0.1, 1.0)) * (0.18 + 0.22 * radial_flow);
			col = mix(vec3(0.38, 0.82, 1.0), vec3(0.92, 0.98, 1.0), edge_border);
			alpha = clamp(edge_border * 0.78 + sweep, 0.0, 0.85);
		} else {
			float fade = 1.0 - smoothstep(0.4, 1.0, u_progress);
			float radial_fade = smoothstep(1.0, 0.72, r) * smoothstep(0.0, 0.18, ang_factor);
			float cloud = (0.45 + 0.55 * radial_flow) * radial_fade;
			col = mix(vec3(0.48, 0.86, 1.0), vec3(0.96, 0.99, 1.0), radial_flow);
			alpha = clamp(cloud * fade * 0.85, 0.0, 0.9);
		}
	} else {
		keep = step(r, 1.0);
		vec2 world_offset = p * u_radius;
		bool shadowed = is_shadowed(world_offset);
		if (u_state < 0.5) {
			float outer_ring = smoothstep(0.015, 0.0, abs(r - 0.985));
			float wave_r = clamp(u_progress, 0.05, 1.0) * 0.985;
			float wave_edge = smoothstep(0.025, 0.0, abs(r - wave_r));
			float ripples = 0.5 + 0.5 * sin(r * 28.0 - u_time * 10.0);
			if (shadowed) {
				col = vec3(0.25, 0.85, 0.62);
				alpha = (0.10 + 0.06 * u_progress) * smoothstep(1.0, 0.85, r);
			} else {
				float danger_fill = (0.10 + 0.16 * u_progress + 0.06 * ripples) * smoothstep(1.0, 0.92, r);
				float flash = u_progress > 0.78 ? (0.5 + 0.5 * sin(u_time * 32.0)) : 0.0;
				col = mix(vec3(0.32, 0.76, 1.0), vec3(0.92, 0.98, 1.0), clamp(outer_ring + wave_edge + flash * 0.45, 0.0, 1.0));
				alpha = clamp(outer_ring * 0.85 + wave_edge * 0.75 + danger_fill, 0.0, 0.82);
			}
		} else if (shadowed) {
			keep = 0.0;
			alpha = 0.0;
		} else {
			float fade = 1.0 - u_progress;
			float shock_r = 0.25 + u_progress * 0.75;
			float ring = smoothstep(0.08, 0.0, abs(r - shock_r));
			col = vec3(0.85, 0.97, 1.0);
			alpha = clamp((ring * 0.85 + 0.22) * fade, 0.0, 0.88);
		}
	}
	COLOR = vec4(col * alpha * keep, alpha * keep);
}
