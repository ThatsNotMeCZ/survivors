shader_type canvas_item;

uniform float u_time = 0.0;
uniform float u_progress : hint_range(0.0, 1.0) = 0.0;
uniform float u_kind : hint_range(0.0, 2.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.75, 0.3, 0.85);

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 outc = vec4(0.0);
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	if (r <= 1.05) {
		float ring_r = mix(0.12, 0.92, u_progress);
		float ring = smoothstep(ring_r + 0.12, ring_r, r) * smoothstep(ring_r - 0.18, ring_r, r);
		float core = smoothstep(0.55, 0.0, r) * (1.0 - u_progress);
		float n = hash21(floor(UV * 28.0) + u_time);
		vec3 col = tint.rgb;
		col = mix(col, mix(vec3(0.72, 0.12, 0.08), vec3(0.98, 0.55, 0.12), core), step(0.5, u_kind) * (1.0 - step(1.5, u_kind)));
		col = mix(col, mix(vec3(0.97, 0.59, 0.09), vec3(0.98, 0.88, 0.42), ring), step(1.5, u_kind));
		float alpha = clamp((ring * 0.85 + core * 0.65 + n * 0.08 * (1.0 - u_progress)) * tint.a, 0.0, 1.0);
		outc = vec4(col * alpha, alpha);
	}
	COLOR = outc;
}
