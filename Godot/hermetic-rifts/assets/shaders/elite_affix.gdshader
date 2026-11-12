shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.35, 0.72, 1.0, 1.0);
uniform float width : hint_range(0.0, 4.0) = 1.5;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float a = base.a;
	a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	COLOR = mix(outline_color, base, base.a);
	COLOR.a = max(base.a, a * outline_color.a);
}
