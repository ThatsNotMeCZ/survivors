shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "palette_utils.gdshaderinc"

uniform float u_time = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_tier : hint_range(0.0, 3.0) = 0.0;
uniform float u_active : hint_range(0.0, 1.0) = 1.0;
uniform float u_style : hint_range(0.0, 3.0) = 0.0;
uniform float u_grid_px : hint_range(32.0, 256.0) = 128.0;

void fragment() {
	vec2 uv = quantize_uv(UV, vec2(u_grid_px));
	vec2 p = (uv - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x + 0.00001);
	float clock_ang = fract((ang + 1.5707963) / 6.2831853);

	vec3 c_dim = vec3(0.45, 0.22, 0.14);
	vec3 c_mid = vec3(0.95, 0.56, 0.14);
	vec3 c_hot = vec3(1.0, 0.92, 0.56);
	if (u_style >= 2.5) {
		c_dim = vec3(0.28, 0.18, 0.48);
		c_mid = vec3(0.66, 0.52, 0.95);
		c_hot = vec3(0.92, 0.85, 1.0);
	} else if (u_style >= 1.5) {
		c_dim = vec3(0.14, 0.36, 0.22);
		c_mid = vec3(0.32, 0.82, 0.45);
		c_hot = vec3(0.82, 0.98, 0.65);
	} else if (u_style >= 0.5) {
		c_dim = vec3(0.14, 0.34, 0.52);
		c_mid = vec3(0.34, 0.82, 1.0);
		c_hot = vec3(0.90, 0.97, 1.0);
	}

	float outer_band = 1.0 - smoothstep(0.018, 0.045, abs(r - 0.94));
	float rot_ang = fract(ang / 6.2831853 + u_time * (0.04 + u_tier * 0.025));
	float rune_slot = step(0.18, fract(rot_ang * 16.0));
	float lit_arc = step(clock_ang, max(u_progress, 0.02));
	float outer_runes = outer_band * rune_slot;

	float tier1_ring = (1.0 - smoothstep(0.015, 0.036, abs(r - 0.76))) * step(0.8, u_tier);
	float tier1_pips = tier1_ring * step(0.35, fract(fract(ang / 6.2831853 - u_time * 0.08) * 12.0));

	float tier2_ring = (1.0 - smoothstep(0.014, 0.034, abs(r - 0.56))) * step(1.8, u_tier);
	float spoke_ang = abs(sin(ang * 4.0 + u_time * 0.9));
	float tier2_spokes = step(0.94, spoke_ang) * step(0.45, r) * step(r, 0.90) * step(1.8, u_tier) * 0.55;

	float tier3_crown = (1.0 - smoothstep(0.08, 0.36, r)) * step(2.8, u_tier);
	float tier_pulse = 0.65 + 0.35 * sin(u_time * (3.0 + u_tier * 2.2) - r * 8.0);

	float prog_head = exp(-abs(clock_ang - u_progress) * 28.0) * outer_band * step(0.01, u_progress);
	float base_idle = outer_band * 0.35;
	float intensity = clamp(
		base_idle
		+ outer_runes * mix(0.25, 0.92, lit_arc)
		+ prog_head * 0.85
		+ tier1_pips * 0.78 * tier_pulse
		+ tier2_ring * 0.65 * tier_pulse
		+ tier2_spokes * tier_pulse
		+ tier3_crown * 0.85 * tier_pulse,
		0.0,
		1.0
	);

	float mask = step(r, 1.0) * step(0.04, intensity) * u_active;
	vec3 col = mix(c_dim, c_mid, clamp(lit_arc * 0.85 + tier_pulse * 0.35, 0.0, 1.0));
	col = mix(col, c_hot, clamp(prog_head + tier3_crown * 0.8 + step(1.8, u_tier) * 0.25, 0.0, 1.0));
	col = lut_sample(col, u_lut_tex);

	float alpha = clamp(intensity * mask, 0.0, 0.95);
	COLOR = vec4(col, alpha);
}
