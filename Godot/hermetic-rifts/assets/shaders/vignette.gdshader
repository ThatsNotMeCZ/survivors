shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.16, 0.04, 0.03, 0.46);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p * vec2(1.0, 0.78));
	float a = smoothstep(0.42, 1.18, d);
	COLOR = vec4(tint.rgb, tint.a * a);
}
