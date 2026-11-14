shader_type canvas_item;

uniform float affix : hint_range(0.0, 2.0) = 0.0;
uniform float shield_active : hint_range(0.0, 1.0) = 1.0;
uniform float corpse : hint_range(0.0, 1.0) = 0.0;
uniform float u_time = 0.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec4 outc = base;
	if (affix >= 0.5 && affix < 1.5) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float a_l = texture(TEXTURE, UV + vec2(-px.x, 0.0)).a;
		float a_r = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
		float a_d = texture(TEXTURE, UV + vec2(0.0, -px.y)).a;
		float a_u = texture(TEXTURE, UV + vec2(0.0, px.y)).a;
		float neighbor = max(max(a_l, a_r), max(a_d, a_u));
		if (base.a > 0.35) {
			outc = base;
		} else if (neighbor <= 0.35) {
			outc = vec4(0.0);
		} else {
			vec3 bright = vec3(0.302, 0.608, 0.902);
			vec3 light = vec3(0.561, 0.828, 1.0);
			vec3 broken = vec3(0.282, 0.290, 0.467);
			float wave = 0.5 + 0.5 * sin(u_time * 5.0 + UV.y * 14.0);
			vec3 col = mix(broken, mix(bright, light, wave * 0.6), step(0.5, shield_active));
			float alpha = mix(0.45, 0.95, step(0.5, shield_active));
			outc = vec4(col, alpha);
		}
	} else if (affix >= 1.5) {
		float pulse = 0.5 + 0.5 * sin(u_time * 4.2 + UV.x * 8.0);
		vec3 viridian = vec3(0.118, 0.737, 0.451);
		vec3 lime = vec3(0.569, 0.859, 0.412);
		vec3 overlay = mix(viridian, lime, pulse);
		float amount = mix(0.38, 0.62, pulse);
		outc = vec4(mix(base.rgb, overlay, amount * base.a), base.a);
		outc.rgb = mix(outc.rgb, vec3(0.137, 0.565, 0.388), 0.45 * step(0.5, corpse));
	}
	COLOR = outc;
}
