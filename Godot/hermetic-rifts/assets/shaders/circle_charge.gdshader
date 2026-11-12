shader_type canvas_item;

uniform vec4 brass : source_color = vec4(0.77, 0.64, 0.35, 0.8);
uniform float charge : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float d = distance(UV, vec2(0.5));
	float ring = smoothstep(0.48, 0.42, d) * smoothstep(0.32, 0.38, d);
	float fill = step(d, mix(0.2, 0.45, charge));
	COLOR = brass * (ring + fill * 0.35);
	COLOR.a *= 0.85;
}
