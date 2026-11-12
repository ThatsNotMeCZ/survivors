shader_type canvas_item;

uniform vec4 gold : source_color = vec4(0.97, 0.59, 0.09, 0.9);

void fragment() {
	float along = abs(UV.y - 0.5);
	float pulse = 0.6 + 0.4 * sin(TIME * 8.0 + UV.x * 20.0);
	COLOR = gold * smoothstep(0.45, 0.05, along) * pulse;
}
