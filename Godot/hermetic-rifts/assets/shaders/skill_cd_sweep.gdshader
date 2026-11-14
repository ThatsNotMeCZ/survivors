shader_type canvas_item;

uniform float cd : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float ang = atan(p.x, -p.y);
	float t = (ang + 3.14159265) / 6.2831853;
	float mask = step(t, cd);
	COLOR = vec4(0.04, 0.03, 0.05, 0.78 * mask * step(0.01, cd));
}
