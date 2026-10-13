shader_type canvas_item;
render_mode unshaded;

uniform sampler2D clean_background : source_color, filter_linear, repeat_disable;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	// Only replace the publisher mark; retain the original artwork and disclaimer.
	vec2 pixel = UV * vec2(940.0, 590.0);
	float patch = smoothstep(712.0, 718.0, pixel.x)
		* (1.0 - smoothstep(927.0, 933.0, pixel.x))
		* smoothstep(477.0, 483.0, pixel.y)
		* (1.0 - smoothstep(532.0, 538.0, pixel.y));
	COLOR = tint * mix(texture(TEXTURE, UV), texture(clean_background, UV), patch);
}
