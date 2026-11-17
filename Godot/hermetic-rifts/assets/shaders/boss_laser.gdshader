shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float u_time = 0.0;
uniform float u_channeling = 0.0;
uniform float u_progress = 0.0;

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float along = uv.x;
	float across = (uv.y - 0.5) * 2.0;

	vec3 col = vec3(0.0);
	float alpha = 0.0;

	if (u_channeling < 0.5) {
		float width = mix(0.18, 0.06, u_progress);
		float line = smoothstep(width, 0.0, abs(across));
		float dash = step(0.35, fract(along * 14.0 - u_time * 6.0));
		float flash = u_progress > 0.7 ? (0.5 + 0.5 * sin(u_time * 34.0)) : 0.0;
		col = mix(vec3(0.45, 0.85, 1.0), vec3(1.0, 0.96, 1.0), flash);
		alpha = line * (0.45 + 0.45 * dash);
	} else {
		float wave1 = sin(along * 22.0 - u_time * 24.0) * 0.22;
		float wave2 = cos(along * 17.0 + u_time * 19.0) * 0.18;
		float core = smoothstep(0.28, 0.03, abs(across));
		float outer_glow = smoothstep(0.88, 0.12, abs(across)) * 0.55;
		float arc1 = smoothstep(0.11, 0.0, abs(across - wave1)) * 0.75;
		float arc2 = smoothstep(0.10, 0.0, abs(across - wave2)) * 0.65;

		float end_dist = length(vec2((along - 0.96) * 6.5, across));
		float end_flare = smoothstep(0.85, 0.05, end_dist);

		float intensity = clamp(core + outer_glow + arc1 + arc2 + end_flare, 0.0, 1.0);
		col = mix(vec3(0.28, 0.72, 1.0), vec3(0.95, 0.99, 1.0), clamp(core + end_flare * 0.7, 0.0, 1.0));
		alpha = clamp(intensity * 0.92, 0.0, 0.95);
	}

	COLOR = vec4(col * alpha, alpha);
}
