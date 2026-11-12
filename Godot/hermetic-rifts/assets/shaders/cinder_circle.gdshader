shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

void fragment() {
	vec2 center = vec2(0.5);
	vec2 d = UV - center;
	float angle = TIME * 0.087;
	float ca = cos(angle);
	float sa = sin(angle);
	vec2 rot_uv = vec2(d.x * ca - d.y * sa, d.x * sa + d.y * ca) + center;
	vec4 out_col = vec4(0.0);
	if (rot_uv.x >= 0.0 && rot_uv.x <= 1.0 && rot_uv.y >= 0.0 && rot_uv.y <= 1.0) {
		vec4 base = texture(TEXTURE, rot_uv);
		if (base.a >= 0.03) {
			float warmth = max(base.r - base.b * 0.85, 0.0);
			float self_emissive = 0.0;
			if (base.a >= 0.05) {
				self_emissive = smoothstep(0.28, 0.68, warmth) * base.a;
			}
			float wave = sin(TIME * 1.2);
			float blink = smoothstep(-0.4, 0.85, wave);
			float pulse = 0.12 + 0.88 * blink;
			vec3 rune_color = mix(vec3(0.50, 0.08, 0.02), vec3(0.96, 0.56, 0.14), pulse);
			vec3 dark_stone = vec3(base.r * 0.72, base.g * 0.62, base.b * 0.68);
			vec3 final_rgb = mix(dark_stone, rune_color, self_emissive);
			final_rgb = clamp(final_rgb * base.a, vec3(0.0), vec3(base.a));
			out_col = vec4(final_rgb, base.a);
		}
	}
	COLOR = out_col;
}
