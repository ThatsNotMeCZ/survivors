shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 hurt : source_color = vec4(1.0, 0.25, 0.2, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	COLOR = mix(base, hurt, flash * base.a);
}
