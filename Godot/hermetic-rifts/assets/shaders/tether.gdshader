shader_type canvas_item;

uniform float u_time = 0.0;
uniform vec4 gold : source_color = vec4(0.97, 0.59, 0.09, 0.92);

void fragment() {
	float along = abs(UV.y - 0.5);
	float pulse = 0.55 + 0.45 * sin(u_time * 8.0 + UV.x * 18.0);
	float travel = fract(UV.x * 3.2 - u_time * 0.9);
	float bead = smoothstep(0.0, 0.25, travel) * smoothstep(1.0, 0.55, travel);
	float core = smoothstep(0.46, 0.04, along);
	float alpha = core * pulse * (0.55 + 0.45 * bead);
	vec3 hot = vec3(0.98, 0.88, 0.42);
	COLOR = vec4(mix(gold.rgb, hot, bead) * alpha, alpha * gold.a);
}
