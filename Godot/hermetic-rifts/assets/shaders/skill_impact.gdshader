shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 0.75, 0.3, 0.8);
uniform float age : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float d = distance(UV, vec2(0.5));
	float ring = smoothstep(0.15 + age * 0.35, 0.05 + age * 0.3, d);
	COLOR = tint * ring * (1.0 - age);
}
