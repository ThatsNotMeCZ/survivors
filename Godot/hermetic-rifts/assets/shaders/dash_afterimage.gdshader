shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.53, 0.80, 1.0, 0.55);
uniform float u_progress : hint_range(0.0, 1.0) = 1.0;
uniform float u_dash : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * (1.0 + 1.5 * u_dash);
	float r_a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	float b_a = texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
	vec3 col = mix(tex.rgb, tint.rgb, 0.62);
	col.r = mix(col.r, tint.r, r_a * 0.40 * u_dash);
	col.b = mix(col.b, tint.b, b_a * 0.40 * u_dash);
	float a = tex.a * tint.a * u_progress;
	COLOR = vec4(col * a, a);
}
