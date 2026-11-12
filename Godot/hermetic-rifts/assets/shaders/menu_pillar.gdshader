shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec3 top = vec3(0.106, 0.090, 0.114);
	vec3 bot = vec3(0.078, 0.067, 0.086);
	COLOR = vec4(mix(top, bot, UV.y), 1.0);
}
