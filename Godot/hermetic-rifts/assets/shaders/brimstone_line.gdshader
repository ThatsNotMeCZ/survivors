shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "fx_pixel.gdshaderinc"

uniform float u_time = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_seed = 0.13;

void fragment() {
	vec4 outc = vec4(0.0);
	vec2 grid = fx_grid_dim();
	vec2 uv = quantize_uv(UV, grid);
	vec2 cell = floor(uv * grid);
	float bayer = px_bayer4(cell);

	float ignite = clamp(u_progress / 0.14, 0.0, 1.0);
	float along_norm = (uv.x - 0.5) * 2.0; // -1..1 along flame wall length
	float across_norm = (uv.y - 0.5) * 2.0; // -1..1 across flame wall width

	if (abs(along_norm) <= ignite * 1.02) {
		float erode = smoothstep(0.74, 1.0, u_progress);
		float tip_taper = 1.0 - smoothstep(ignite * 0.84, ignite * 1.02, abs(along_norm));
		float world_x = along_norm * max(u_quad_px.x * 0.5, 32.0);
		float anim_t = u_reduce > 0.5 ? 0.0 : u_time;

		// Roaring pixel flame wall with billowing tongues and rising embers (no side cracks)
		float sway = (px_vnoise(vec2(world_x * 0.045 - anim_t * 1.8, u_seed * 7.3)) - 0.5) * 0.22;
		float dist = abs(across_norm - sway);

		float tongue = px_fbm(vec2(world_x * 0.085 + anim_t * 2.6, across_norm * 3.2 - anim_t * 5.8 + u_seed));
		float flame_reach = (0.48 + 0.46 * tongue) * tip_taper;
		float core_band = step(dist, 0.22 * tip_taper);
		float mid_band = step(dist, flame_reach * 0.72);
		float outer_flame = 1.0 - smoothstep(flame_reach * 0.58, flame_reach, dist);

		// Rising ember flecks along the flame edges
		vec2 spark_cell = floor(vec2(world_x * 0.15 + anim_t * 3.5, across_norm * 5.5 - anim_t * 6.0));
		float spark = (u_reduce < 0.5 && px_hash21(spark_cell + u_seed) > 0.89 && dist < 0.92 * tip_taper) ? 0.88 : 0.0;

		float mask = max(max(mid_band, outer_flame * 0.86), spark) * tip_taper;
		if (mask > bayer * 0.40 + 0.04 + erode * 0.52) {
			float heat = clamp(
				0.20
				+ outer_flame * 0.28
				+ mid_band * 0.28
				+ core_band * 0.36
				+ step(0.56, tongue) * 0.20
				+ spark * 0.50,
				0.0,
				1.0
			) * (1.0 - erode * 0.32);
			outc = vec4(fx_ramp(0.0, heat), 0.95);
		}
	}
	COLOR = outc;
}
