shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "fx_pixel.gdshaderinc"

uniform float u_time = 0.0;
uniform float u_channeling : hint_range(0.0, 1.0) = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_style : hint_range(0.0, 5.0) = 1.0;

void fragment() {
	vec4 outc = vec4(0.0);
	vec2 grid = fx_grid_dim();
	vec2 uv = quantize_uv(UV, grid);
	vec2 cell = floor(uv * grid);
	float bayer = px_bayer4(cell);

	float along = uv.x;
	float across = (uv.y - 0.5) * 2.0; // -1..1
	float world_x = along * max(u_quad_px.x, 64.0);
	float abs_across = abs(across);

	if (u_channeling < 0.5) {
		// Telegraph: crisp pixel-snapped sightline with marching dashes & lock-on flash
		float width = mix(0.22, 0.08, u_progress);
		float core_line = 1.0 - smoothstep(width * 0.45, width, abs_across);
		float rail = (1.0 - smoothstep(0.02, 0.06, abs(abs_across - 0.36))) * 0.65;
		float dash = step(0.32, fract(world_x * 0.035 - u_time * 5.0));
		float urgent = (u_reduce < 0.5 && u_progress > 0.70) ? (0.5 + 0.5 * sin(u_time * 34.0)) : 0.0;

		float mask = max(core_line * (0.55 + 0.45 * dash), rail * dash);
		if (fx_cut(mask, bayer, 0.38)) {
			float heat = clamp(0.45 + core_line * 0.35 + urgent * 0.35, 0.0, 1.0);
			outc = vec4(fx_ramp(u_style, heat), 0.88);
		}
	} else {
		// Channeling beam: stepped core/mantle/crust bands + pixel-snapped crackling arcs + muzzle/end flare
		float anim_t = u_reduce > 0.5 ? 0.0 : u_time;
		float pulse = 0.88 + 0.12 * sin(anim_t * 26.0 - world_x * 0.04);

		float arc_cell1 = floor(world_x * 0.075 - anim_t * 18.0);
		float arc_cell2 = floor(world_x * 0.055 + anim_t * 14.0);
		float wave1 = (px_hash21(vec2(arc_cell1, 3.7)) - 0.5) * 0.62;
		float wave2 = (px_hash21(vec2(arc_cell2, 9.1)) - 0.5) * 0.54;
		float arc1 = 1.0 - smoothstep(0.04, 0.11, abs(across - wave1));
		float arc2 = 1.0 - smoothstep(0.04, 0.10, abs(across - wave2));

		float core_band = step(abs_across, 0.18 * pulse);
		float mid_band = step(abs_across, 0.38 * pulse);
		float outer_band = 1.0 - smoothstep(0.36 * pulse, 0.76, abs_across);

		// Origin & termination splash flares in world pixels
		float start_dist = length(vec2(world_x / 28.0, across * 1.1));
		float end_dist = length(vec2((u_quad_px.x - world_x) / 34.0, across * 0.95));
		float flare = max(1.0 - smoothstep(0.35, 1.0, start_dist), 1.0 - smoothstep(0.40, 1.05, end_dist));

		// Flying spark pixels along beam sheath
		vec2 spark_c = floor(vec2(world_x * 0.12 - anim_t * 22.0, across * 7.0));
		float spark = (u_reduce < 0.5 && px_hash21(spark_c) > 0.91 && abs_across < 0.88) ? 0.85 : 0.0;

		float mask = clamp(max(max(mid_band, outer_band * 0.82), max(max(arc1, arc2) * 0.88, max(flare, spark))), 0.0, 1.0);
		if (fx_cut(mask, bayer, 0.38)) {
			float heat = clamp(
				0.20
				+ outer_band * 0.25
				+ mid_band * 0.30
				+ core_band * 0.38
				+ max(arc1, arc2) * 0.35
				+ flare * 0.45
				+ spark * 0.40,
				0.0,
				1.0
			);
			outc = vec4(fx_ramp(u_style, heat), 0.95);
		}
	}
	COLOR = outc;
}
