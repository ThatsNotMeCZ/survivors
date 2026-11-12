shader_type canvas_item;

uniform vec4 smoke : source_color = vec4(0.12, 0.08, 0.07, 0.35);

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv);
	float wisp = smoothstep(0.5, 0.1, d) * (0.5 + 0.5 * sin(TIME + uv.x * 8.0));
	COLOR = smoke * wisp;
}
