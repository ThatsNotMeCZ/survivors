shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.55, 0.22, 0.12, 0.08);
uniform float drift : hint_range(0.0, 2.0) = 0.15;

void fragment() {
	vec2 uv = UV;
	uv.y += TIME * drift * 0.02;
	float n = fract(sin(dot(uv * 40.0, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = tint * n;
}
