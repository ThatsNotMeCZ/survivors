shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "palette_utils.gdshaderinc"

uniform float u_kind : hint_range(0.0, 5.0) = 0.0;
uniform float u_hold : hint_range(0.0, 1.0) = 0.0;
uniform float u_time = 0.0;
uniform float u_grid_px : hint_range(32.0, 128.0) = 64.0;

void fragment() {
	vec2 uv = quantize_uv(UV, vec2(u_grid_px));
	vec2 p = (uv - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x + 0.00001);
	float clock_ang = fract((ang + 1.5707963) / 6.2831853);

	vec3 c_deep = vec3(0.58, 0.16, 0.10);
	vec3 c_mid = vec3(0.98, 0.62, 0.16);
	vec3 c_hot = vec3(1.0, 0.92, 0.62);
	if (u_kind >= 4.5) {
		c_deep = vec3(0.45, 0.08, 0.14);
		c_mid = vec3(0.91, 0.23, 0.25);
		c_hot = vec3(1.0, 0.82, 0.42);
	} else if (u_kind >= 3.5) {
		c_deep = vec3(0.62, 0.42, 0.12);
		c_mid = vec3(0.96, 0.78, 0.22);
		c_hot = vec3(1.0, 0.97, 0.78);
	} else if (u_kind >= 2.5) {
		c_deep = vec3(0.22, 0.42, 0.68);
		c_mid = vec3(0.56, 0.84, 0.96);
		c_hot = vec3(0.96, 0.99, 1.0);
	} else if (u_kind >= 1.5) {
		c_deep = vec3(0.28, 0.16, 0.52);
		c_mid = vec3(0.66, 0.52, 0.95);
		c_hot = vec3(0.92, 0.85, 1.0);
	} else if (u_kind >= 0.5) {
		c_deep = vec3(0.11, 0.36, 0.22);
		c_mid = vec3(0.42, 0.85, 0.41);
		c_hot = vec3(0.84, 0.98, 0.68);
	}

	float spin = u_time * 0.75;
	float arm = 0.5 + 0.5 * sin(ang * 3.0 - r * 7.5 + spin);
	float swirl_band = smoothstep(0.88, 0.18, r) * (0.45 + 0.55 * step(0.42, arm));
	float core = 1.0 - smoothstep(0.10, 0.38 + u_hold * 0.18, r);
	float rim = 1.0 - smoothstep(0.02, 0.08, abs(r - 0.82));
	float hold_ring = (1.0 - smoothstep(0.02, 0.06, abs(r - 0.94))) * step(clock_ang, u_hold) * step(0.01, u_hold);

	float total = clamp(swirl_band + core * 0.9 + rim * 0.75 + hold_ring, 0.0, 1.0);
	float mask = step(r, 1.0) * step(0.04, total);

	vec3 col = mix(c_deep, c_mid, clamp(swirl_band * 0.85 + rim * 0.5, 0.0, 1.0));
	col = mix(col, c_hot, clamp(core * 0.95 + hold_ring * 0.85, 0.0, 1.0));
	col = lut_sample(col, u_lut_tex);

	float alpha = clamp(total * mask * (0.78 + 0.20 * u_hold), 0.0, 0.96);
	COLOR = vec4(col, alpha);
}
