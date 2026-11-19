shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "fx_pixel.gdshaderinc"

uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_thickness : hint_range(0.02, 0.5) = 0.12;
uniform float u_style : hint_range(0.0, 4.0) = 0.0;
uniform float u_time = 0.0;
uniform float u_seed = 1.0;
uniform float u_grid_px : hint_range(32.0, 256.0) = 128.0;

void fragment() {
	vec2 grid = fx_grid_dim();
	vec2 uv = quantize_uv(UV, grid);
	vec2 cell = floor(uv * grid);
	float bayer = px_bayer4(cell);

	vec2 p = (uv - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x + 0.00001);
	vec4 outc = vec4(0.0);

	if (r <= 1.02) {
		float ring_r = clamp(u_progress, 0.04, 0.96);
		float hw = max(u_thickness * 0.5, 0.03);
		float erode = smoothstep(0.80, 1.0, u_progress);

		if (u_style >= 3.5) {
			// Style 4: Hex Sigil — pixel occult hexagon seal with inner ritual ring and glyphs
			float rot_ang = ang + (u_reduce > 0.5 ? 0.0 : u_time * 0.75);
			float hex_r = 0.88 / max(cos(mod(rot_ang + 0.5235988, 1.0471976) - 0.5235988), 0.5);
			float cell_w = 2.2 / max(grid.x, 32.0);
			float outer_ring = 1.0 - smoothstep(cell_w * 0.6, cell_w * 1.5, abs(r - 0.94));
			float hex_edge = 1.0 - smoothstep(cell_w * 0.7, cell_w * 1.8, abs(r - hex_r * 0.82));
			float pulse_r = ring_r * 0.92;
			float pulse_ring = 1.0 - smoothstep(cell_w * 0.7, cell_w * 1.8, abs(r - pulse_r));
			float spokes = (1.0 - smoothstep(0.03, 0.09, abs(sin(rot_ang * 3.0)) * max(r, 0.15))) * step(r, 0.82) * step(0.18, r);
			float sigil_fill = step(r, pulse_r) * (0.20 + 0.22 * step(0.54, px_fbm(p * 4.5 + u_seed)));
			float urgent = (u_reduce < 0.5 && u_progress > 0.75) ? (0.5 + 0.5 * sin(u_time * 28.0)) : 0.0;

			float mask = max(max(outer_ring * 0.92, hex_edge * 0.95), max(pulse_ring * 0.90, max(spokes * 0.78, sigil_fill)));
			if (mask > bayer * 0.40 + 0.04 + erode * 0.42) {
				float heat = clamp(
					0.24
					+ hex_edge * 0.48
					+ outer_ring * 0.42
					+ pulse_ring * 0.55
					+ spokes * 0.32
					+ urgent * 0.35,
					0.0,
					1.0
				);
				outc = vec4(fx_ramp(4.0, heat), 0.92);
			}
		} else {
			// Pure expanding shockwave ring with toothed crest, stepped wake, and trailing sparks (no cracks)
			float d = abs(r - ring_r);
			float band = 1.0 - smoothstep(hw * 0.28, hw, d);
			float crest = 1.0 - smoothstep(0.0, hw * 0.36, abs(r - (ring_r + hw * 0.18)));
			float teeth_freq = (u_style >= 2.5) ? 12.0 : 18.0;
			float teeth = 0.72 + 0.28 * step(0.0, sin(ang * teeth_freq + (u_reduce > 0.5 ? 0.0 : u_time * 8.0)));

			float wake_band = step(ring_r - hw * 2.2, r) * step(r, ring_r)
				* (1.0 - clamp((ring_r - r) / (hw * 2.2), 0.0, 1.0));
			float echo_ring = (u_style >= 2.5)
				? (1.0 - smoothstep(hw * 0.25, hw * 0.7, abs(r - ring_r * 0.62))) * 0.78
				: 0.0;
			vec2 spark_cell = floor(vec2(r * 14.0, ang * 10.0 + u_seed));
			float spark = (u_reduce < 0.5 && px_hash21(spark_cell) > 0.89 && wake_band > 0.25) ? 0.85 : 0.0;

			float mask = clamp(band * teeth + wake_band * 0.48 + echo_ring + spark, 0.0, 1.0);
			if (mask > bayer * 0.40 + 0.04 + erode * 0.48) {
				float ramp_id = u_style;
				if (u_style >= 2.5) {
					ramp_id = 5.0; // Solar / Censure Bell
				} else if (u_style >= 1.5) {
					ramp_id = 3.0; // Voltaic
				}
				float heat = clamp(0.24 + band * 0.46 + crest * 0.45 + echo_ring * 0.40 + spark * 0.50, 0.0, 1.0);
				outc = vec4(fx_ramp(ramp_id, heat), 0.93);
			}
		}
	}
	COLOR = outc;
}
