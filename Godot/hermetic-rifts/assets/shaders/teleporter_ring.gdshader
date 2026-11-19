shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "palette_utils.gdshaderinc"

uniform float u_time = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_tier : hint_range(0.0, 3.0) = 0.0;
uniform float u_active : hint_range(0.0, 1.0) = 1.0;
uniform float u_style : hint_range(0.0, 3.0) = 0.0;
uniform float u_grid_px : hint_range(32.0, 256.0) = 128.0;
uniform float u_tier_pulse : hint_range(0.0, 1.0) = 0.0;

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

	// Smooth tier crossfades (u_tier is smoothed in arena_view over ~0.85s per tier).
	float t1 = smoothstep(0.15, 0.95, u_tier);
	float t2 = smoothstep(1.15, 1.95, u_tier);
	float t3 = smoothstep(2.15, 2.95, u_tier);

	// Outer circumference rune band (always present when active).
	float outer_band = 1.0 - smoothstep(0.016, 0.042, abs(r - 0.94));
	float rot_ang = fract(ang / 6.2831853 + u_time * (0.04 + u_tier * 0.02));
	float rune_slot = step(0.18, fract(rot_ang * 16.0));
	float lit_arc = step(clock_ang, max(u_progress, 0.02));
	float outer_runes = outer_band * rune_slot;

	// Tier 1: rotating inner-mid pip ring at r = 0.78.
	float tier1_ring = (1.0 - smoothstep(0.014, 0.034, abs(r - 0.78))) * t1;
	float tier1_pips = tier1_ring * step(0.35, fract(fract(ang / 6.2831853 - u_time * 0.08) * 12.0));

	// Tier 2: middle containment ring at r = 0.60 + radial spokes strictly between rings (never across center).
	float tier2_ring = (1.0 - smoothstep(0.013, 0.032, abs(r - 0.60))) * t2;
	float spoke_ang = abs(sin(ang * 4.0 + u_time * 0.7));
	float tier2_spokes = step(0.95, spoke_ang) * smoothstep(0.46, 0.52, r) * (1.0 - smoothstep(0.88, 0.92, r)) * t2 * 0.42;

	// Tier 3: crisp inner seal ring at r = 0.42 with 8 seal glyphs (NO solid center disc — interior stays transparent).
	float tier3_ring = (1.0 - smoothstep(0.012, 0.030, abs(r - 0.42))) * t3;
	float tier3_pips = tier3_ring * step(0.28, fract(fract(ang / 6.2831853 + u_time * 0.11) * 8.0));

	// Subtle tier-up circumference pulse wave (replaces full-disc flash).
	float pulse_r = mix(0.62, 0.97, 1.0 - u_tier_pulse);
	float tier_wave = (1.0 - smoothstep(0.012, 0.040, abs(r - pulse_r))) * u_tier_pulse * 0.65;

	float tier_pulse = 0.72 + 0.28 * sin(u_time * (2.6 + u_tier * 1.4) - r * 6.0);
	float prog_head = exp(-abs(clock_ang - u_progress) * 28.0) * outer_band * step(0.01, u_progress);
	float base_idle = outer_band * 0.32;

	float intensity = clamp(
		base_idle
		+ outer_runes * mix(0.24, 0.84, lit_arc)
		+ prog_head * 0.65
		+ tier1_pips * 0.70 * tier_pulse
		+ tier2_ring * 0.58 * tier_pulse
		+ tier2_spokes * tier_pulse
		+ tier3_pips * 0.76 * tier_pulse
		+ tier_wave,
		0.0,
		1.0
	);

	// Keep the inner well (r < 0.36) strictly clear so {theme}-circle art reads cleanly.
	float inner_clear = smoothstep(0.34, 0.40, r);
	float mask = step(r, 1.0) * step(0.04, intensity) * inner_clear * u_active;

	vec3 col = mix(c_dim, c_mid, clamp(lit_arc * 0.80 + tier_pulse * 0.25, 0.0, 1.0));
	// Cap mix toward c_hot so LUT quantization never blows out to flat white.
	float hot_amt = clamp(prog_head * 0.55 + tier3_pips * 0.32 + tier_wave * 0.45 + t2 * 0.14, 0.0, 0.62);
	col = mix(col, c_hot, hot_amt);
	col = lut_sample(col, u_lut_tex);

	float alpha = clamp(intensity * mask, 0.0, 0.88);
	COLOR = vec4(col, alpha);
}
