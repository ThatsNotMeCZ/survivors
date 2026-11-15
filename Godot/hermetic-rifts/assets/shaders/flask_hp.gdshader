shader_type canvas_item;

uniform vec4 well_color : source_color = vec4(0.051, 0.027, 0.035, 0.92);
uniform vec4 fill_top : source_color = vec4(0.878, 0.235, 0.267, 1.0);
uniform vec4 fill_mid : source_color = vec4(0.620, 0.106, 0.141, 1.0);
uniform vec4 fill_bot : source_color = vec4(0.361, 0.047, 0.071, 1.0);
uniform float fill : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float inside = 1.0 - step(1.0, d);
	float edge = smoothstep(1.0, 0.88, d);
	vec4 liquid_hi = mix(fill_top, fill_mid, clamp(UV.y / 0.35, 0.0, 1.0));
	vec4 liquid_lo = mix(fill_mid, fill_bot, clamp((UV.y - 0.35) / 0.65, 0.0, 1.0));
	vec4 liquid = mix(liquid_hi, liquid_lo, step(0.35, UV.y));
	float filled = step(1.0 - UV.y, fill + 0.001);
	vec4 col = mix(well_color, liquid, filled);
	col.a *= edge * inside;
	COLOR = col;
}
