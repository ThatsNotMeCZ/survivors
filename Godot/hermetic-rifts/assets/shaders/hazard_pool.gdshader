shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.2, 0.85, 0.35, 0.45);
uniform float pulse : hint_range(0.0, 4.0) = 1.2;

void fragment() {
	float d = distance(UV, vec2(0.5));
	float ring = smoothstep(0.5, 0.35, d);
	float wobble = 0.5 + 0.5 * sin(TIME * pulse + d * 12.0);
	COLOR = tint * ring * wobble;
}
