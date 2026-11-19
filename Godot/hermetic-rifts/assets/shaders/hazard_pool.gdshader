shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "fx_pixel.gdshaderinc"

uniform float u_time = 0.0;
uniform float u_kind : hint_range(0.0, 4.0) = 1.0;
uniform float u_style : hint_range(0.0, 2.0) = 0.0;
uniform float u_state : hint_range(0.0, 1.0) = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_angle = 0.8;
uniform vec2 u_dir = vec2(1.0, 0.0);
uniform float u_radius = 620.0;
uniform float u_seed = 1.0;
uniform mat4 u_pillars0;
uniform mat4 u_pillars1;
uniform mat4 u_pillars2;
uniform mat4 u_pillars3;

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

float hazard_bubble_ring(vec2 p, float speed, float scale, float seed) {
	vec2 sp = p * scale;
	vec2 cell = floor(sp);
	vec2 local = fract(sp) - vec2(0.5);
	float rx = px_hash21(cell + vec2(seed * 3.1, 7.7));
	float ry = px_hash21(cell + vec2(19.3, seed * 5.3));
	float life_t = fract(u_time * speed + rx * 6.2831853);
	float rad = sin(clamp(life_t / 0.88, 0.0, 1.0) * 3.14159265) * (0.18 + ry * 0.14);
	vec2 offset = (vec2(rx, ry) - vec2(0.5)) * 0.32;
	float d = length(local - offset);
	float disk = step(d, rad) * step(life_t, 0.72);
	float pop_ring = step(abs(d - rad), 0.055) * step(0.62, life_t) * step(life_t, 0.94);
	return max(disk * 0.75, pop_ring) * step(0.045, rad);
}

void fragment() {
	vec2 grid = fx_grid_dim();
	vec2 uv = quantize_uv(UV, grid);
	vec2 cell = floor(uv * grid);
	float bayer = px_bayer4(cell);

	vec2 p = (uv - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x + 0.00001);
	vec4 outc = vec4(0.0);

	if (u_kind < 0.5) {
		// HAZ_METEOR / GEYSER TELEGRAPH: Bubbling molten well + concentric pressure rings (no cracks)
		if (r <= 1.02) {
			float cell_w = 2.0 / max(grid.x, 24.0);
			float march = step(0.24, fract(ang * 12.0 / 6.2831853 + u_time * 1.2));
			float outer_ring = (1.0 - smoothstep(cell_w * 0.65, cell_w * 1.55, abs(r - 0.96))) * (0.68 + 0.32 * march);

			float fill_r = clamp(u_progress, 0.10, 1.0) * 0.96;
			float fill_ring = (1.0 - smoothstep(cell_w * 0.6, cell_w * 1.5, abs(r - fill_r))) * 0.92;

			// Bubbling liquid core welling up from below
			float boil_t = u_reduce > 0.5 ? 0.0 : u_time * mix(2.0, 5.5, u_progress);
			float boil_n = px_fbm(p * 3.4 + vec2(0.0, -boil_t * 0.35) + u_seed);
			float bubbles = u_reduce > 0.5 ? 0.0 : hazard_bubble_ring(p, mix(0.35, 0.85, u_progress), 5.5, u_seed);
			float core_well = (1.0 - smoothstep(0.0, fill_r * 0.55, r)) * (0.55 + 0.45 * step(0.48, boil_n));
			float inner_pool = step(r, fill_r) * (0.20 + 0.28 * u_progress + 0.22 * step(0.55, boil_n) + bubbles * 0.45);

			float pulse = u_reduce > 0.5 ? 0.88 : (0.72 + 0.28 * sin(u_time * mix(7.0, 22.0, u_progress)));
			float urgent = (u_reduce < 0.5 && u_progress > 0.72) ? (0.5 + 0.5 * sin(u_time * 28.0)) : 0.0;

			float mask = max(max(outer_ring, fill_ring), max(core_well * 0.82, inner_pool));
			if (fx_cut(mask, bayer, 0.38)) {
				float heat = clamp(
					0.18
					+ inner_pool * 0.42
					+ core_well * 0.40
					+ bubbles * 0.45
					+ outer_ring * (0.55 + 0.40 * urgent)
					+ fill_ring * (0.62 + 0.35 * u_progress),
					0.0,
					1.0
				) * pulse;
				vec3 col = fx_ramp(u_style, heat);
				float alpha = clamp(mask * mix(0.68, 0.95, u_progress), 0.0, 0.95);
				outc = vec4(col, alpha);
			}
		}
	} else if (u_kind < 1.5) {
		// HAZ_POOL: Pixel puddle with splash-in, dark meniscus, stepped surface bands, and dither erosion
		float splash = smoothstep(0.0, 0.08, u_progress);
		float evaporate = smoothstep(0.74, 1.0, u_progress);
		float anim_t = u_time * (u_reduce > 0.5 ? 0.0 : 0.22);
		float edge_noise = px_fbm(p * 2.5 + vec2(u_seed * 1.7 + anim_t * 0.6, -u_seed * 1.3 - anim_t * 0.5));
		float pool_r = (0.88 + (edge_noise - 0.5) * 0.20) * mix(0.55, 1.0, splash) * (1.0 - evaporate * 0.16);
		float rim_band = clamp((pool_r - r) / 0.18, 0.0, 1.0);
		float erosion_thresh = bayer * 0.58 + evaporate * 0.78;

		if (r <= 1.02 && rim_band > erosion_thresh) {
			vec2 flow = vec2(
				px_fbm(p * 1.8 + vec2(anim_t, -anim_t * 0.8) + u_seed),
				px_fbm(p * 1.8 + vec2(-anim_t * 0.8, anim_t) - u_seed)
			);
			float surface = px_fbm(p * 2.6 + flow * 0.85);
			float bubbles = u_reduce > 0.5 ? 0.0 : clamp(
				hazard_bubble_ring(p + flow * 0.12, 0.30, 6.5, u_seed)
				+ hazard_bubble_ring(p - flow * 0.12 + 9.3, 0.38, 8.5, u_seed + 4.1),
				0.0,
				1.0
			);
			float meniscus = 1.0 - smoothstep(0.08, 0.24, rim_band);
			float band1 = step(0.40, surface);
			float band2 = step(0.62, surface);
			float heat = clamp(0.18 + band1 * 0.30 + band2 * 0.26 + bubbles * 0.42 - meniscus * 0.55, 0.02, 0.98);
			if (u_style >= 0.5 && u_style < 1.5) {
				float ridge = step(0.64, 1.0 - abs(surface - 0.5) * 3.8);
				heat = clamp(0.24 + band1 * 0.28 + ridge * 0.44 - meniscus * 0.45, 0.05, 0.98);
			}
			vec3 col = fx_ramp(u_style, heat);
			outc = vec4(col, 0.92);
		}
	} else if (u_kind < 2.5) {
		// HAZ_PRISON: Frost crystalline jaw ring (no cracks)
		if (r <= 1.04) {
			float spike_wave = abs(fract(ang * 10.0 / 6.2831853 + 0.25) - 0.5) * 2.0;
			float teeth = (spike_wave - 0.5) * 0.085;
			float cell_w = 2.2 / max(grid.x, 32.0);
			if (u_state < 0.5) {
				float outer_ring = 1.0 - smoothstep(cell_w * 0.6, cell_w * 1.5, abs(r - (0.94 + teeth * 0.5)));
				float close_r = max(0.16, (1.0 - u_progress * 0.80) * 0.92 + teeth);
				float closing_ring = 1.0 - smoothstep(cell_w * 0.7, cell_w * 1.7, abs(r - close_r));
				float rime_band = step(close_r, r) * step(r, 0.94) * (0.20 + 0.18 * step(0.55, px_fbm(p * 4.5 + u_seed)));
				float urgent = (u_reduce < 0.5 && u_progress > 0.74) ? (0.5 + 0.5 * sin(u_time * 30.0)) : 0.0;
				float mask = max(max(outer_ring * 0.88, closing_ring), rime_band);
				if (fx_cut(mask, bayer, 0.36)) {
					float heat = clamp(0.32 + closing_ring * 0.52 + outer_ring * 0.28 + urgent * 0.35, 0.0, 1.0);
					outc = vec4(fx_ramp(1.0, heat), 0.94);
				}
			} else {
				float erode = smoothstep(0.35, 1.0, u_progress);
				float cage_r = 0.40 + teeth * 1.35;
				float cage_wall = 1.0 - smoothstep(cell_w * 0.8, cell_w * 2.2, abs(r - cage_r));
				float inner_shards = step(r, cage_r) * step(0.52, px_fbm(p * 6.0 + u_seed)) * 0.75;
				float mask = max(cage_wall, inner_shards) * (1.0 - erode * 0.65);
				if (mask > bayer * 0.45 + erode * 0.48) {
					float heat = clamp(0.45 + cage_wall * 0.48, 0.0, 1.0);
					outc = vec4(fx_ramp(1.0, heat), 0.92);
				}
			}
		}
	} else if (u_kind < 3.5) {
		// HAZ_CONE: Frost breath cone telegraph + blizzard blast (no cracks)
		vec2 dir = normalize(u_dir);
		float cos_half = cos(u_angle * 0.5);
		float safe_r = max(r, 0.001);
		float dot_dir = dot(p / safe_r, dir);
		if (r >= 0.04 && r <= 1.02 && dot_dir >= cos_half - 0.02) {
			float ang_factor = clamp((dot_dir - cos_half) / max(0.001, 1.0 - cos_half), 0.0, 1.0);
			float cell_w = 2.2 / max(grid.x, 32.0);
			float edge_side = 1.0 - smoothstep(0.02, 0.09, ang_factor);
			float edge_arc = 1.0 - smoothstep(cell_w * 0.6, cell_w * 1.6, abs(r - 0.97));
			float border = max(edge_side, edge_arc) * step(cos_half, dot_dir);
			float radial_flow = px_fbm(vec2(r * 5.5 - u_time * (u_reduce > 0.5 ? 0.0 : 3.8), ang * 4.0 + u_seed));

			if (u_state < 0.5) {
				float reach = clamp(u_progress, 0.12, 1.0);
				float sweep_front = (1.0 - smoothstep(cell_w * 0.7, cell_w * 1.8, abs(r - reach))) * step(cos_half, dot_dir);
				float fill = step(r, reach) * (0.22 + 0.32 * step(0.48, radial_flow)) * step(cos_half, dot_dir);
				float mask = max(max(border * 0.88, sweep_front * 0.92), fill);
				if (fx_cut(mask, bayer, 0.38)) {
					float heat = clamp(0.26 + border * 0.45 + sweep_front * 0.55 + fill * 0.30, 0.0, 1.0);
					outc = vec4(fx_ramp(1.0, heat), 0.90);
				}
			} else {
				float erode = smoothstep(0.40, 1.0, u_progress);
				float radial_fade = (1.0 - smoothstep(0.75, 1.0, r)) * smoothstep(0.0, 0.14, ang_factor);
				vec2 shard_cell = floor(vec2(r * 16.0 - u_time * 12.0, ang * 11.0));
				float shard = step(0.84, px_hash21(shard_cell + u_seed)) * radial_fade;
				float cloud = step(0.36, radial_flow) * (0.55 + 0.45 * step(0.62, radial_flow)) * radial_fade;
				float mask = max(cloud, shard);
				if (mask > bayer * 0.42 + erode * 0.52) {
					float heat = clamp(0.35 + step(0.62, radial_flow) * 0.35 + shard * 0.55, 0.0, 1.0);
					outc = vec4(fx_ramp(1.0, heat), 0.92);
				}
			}
		}
	} else {
		// HAZ_PULSE: Arena-wide shockwave with pillar cover shadows
		if (r <= 1.0) {
			vec2 world_offset = p * u_radius;
			bool shadowed = is_shadowed(world_offset);
			float cell_w = 2.5 / max(grid.x, 64.0);
			if (u_state < 0.5) {
				float outer_ring = 1.0 - smoothstep(cell_w * 0.6, cell_w * 1.5, abs(r - 0.985));
				float wave_r = clamp(u_progress, 0.05, 1.0) * 0.985;
				float wave_edge = 1.0 - smoothstep(cell_w * 0.7, cell_w * 1.8, abs(r - wave_r));
				if (shadowed) {
					float safe_rim = 1.0 - smoothstep(0.86, 1.0, r);
					float mask = (0.28 + 0.14 * u_progress) * safe_rim;
					if (fx_cut(mask, bayer, 0.48)) {
						vec3 safe_col = lut_sample(vec3(0.118, 0.737, 0.451), u_lut_tex);
						outc = vec4(safe_col, 0.78);
					}
				} else {
					float ripples = step(0.55, 0.5 + 0.5 * sin(r * 26.0 - u_time * (u_reduce > 0.5 ? 0.0 : 9.0)));
					float danger_fill = (0.20 + 0.22 * u_progress + 0.14 * ripples) * (1.0 - smoothstep(0.92, 1.0, r));
					float urgent = (u_reduce < 0.5 && u_progress > 0.78) ? (0.5 + 0.5 * sin(u_time * 32.0)) : 0.0;
					float mask = max(max(outer_ring * 0.92, wave_edge * 0.90), danger_fill);
					if (fx_cut(mask, bayer, 0.42)) {
						float heat = clamp(0.28 + outer_ring * 0.52 + wave_edge * 0.55 + urgent * 0.35, 0.0, 1.0);
						outc = vec4(fx_ramp(1.0, heat), 0.88);
					}
				}
			} else if (!shadowed) {
				float erode = smoothstep(0.25, 1.0, u_progress);
				float shock_r = 0.20 + u_progress * 0.80;
				float ring = 1.0 - smoothstep(cell_w * 1.2, cell_w * 3.2, abs(r - shock_r));
				float wake = step(r, shock_r) * (0.35 + 0.35 * step(0.55, px_fbm(p * 5.0 + u_seed)));
				float mask = max(ring, wake);
				if (mask > bayer * 0.44 + erode * 0.52) {
					float heat = clamp(0.42 + ring * 0.55, 0.0, 1.0);
					outc = vec4(fx_ramp(1.0, heat), 0.92);
				}
			}
		}
	}
	COLOR = outc;
}
