shader_type canvas_item;

uniform vec4 ember : source_color = vec4(0.84, 0.22, 0.12, 0.9);

void fragment() {
	float along = abs(UV.y - 0.5);
	float core = smoothstep(0.5, 0.05, along);
	COLOR = ember * core;
	COLOR.rgb += vec3(1.0, 0.5, 0.1) * pow(core, 3.0);
}
