shader_type canvas_item;
render_mode unshaded;

// Authored AnimationPlayer advances this with the battle clock, including pause.
uniform float wind_phase = 0.0;
uniform float sway_pixels : hint_range(0.0, 5.0) = 2.0;
uniform float trunk_anchor_y = 460.0;
uniform float canopy_height = 380.0;
uniform float sharpness : hint_range(0.0, 0.4) = 0.16;
varying vec4 tint;

void vertex() {
    tint = COLOR;
}

void fragment() {
    vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
    float canopy = clamp((trunk_anchor_y - pixel.y) / canopy_height, 0.0, 1.0);
    // Independent tree groups, anchored trunks and a stable panorama boundary.
    float edge = smoothstep(0.0, 12.0, pixel.x)
        * smoothstep(0.0, 12.0, 1.0 / TEXTURE_PIXEL_SIZE.x - pixel.x);
    float wind = sin(wind_phase + pixel.x * 0.012)
        + 0.25 * sin(wind_phase * 2.0 - pixel.x * 0.021);
    vec2 uv = UV + vec2(wind * sway_pixels * canopy * canopy * edge, 0.0) * TEXTURE_PIXEL_SIZE;
    vec4 center = texture(TEXTURE, uv);
    vec4 left = texture(TEXTURE, uv - vec2(TEXTURE_PIXEL_SIZE.x, 0.0));
    vec4 right = texture(TEXTURE, uv + vec2(TEXTURE_PIXEL_SIZE.x, 0.0));
    vec4 up = texture(TEXTURE, uv - vec2(0.0, TEXTURE_PIXEL_SIZE.y));
    vec4 down = texture(TEXTURE, uv + vec2(0.0, TEXTURE_PIXEL_SIZE.y));
    // Sharpen opaque interiors only: transparent sprite edges retain their alpha.
    float interior = min(min(left.a, right.a), min(up.a, down.a)) * center.a;
    center.rgb = clamp(center.rgb + sharpness * interior
        * (center.rgb - (left.rgb + right.rgb + up.rgb + down.rgb) * 0.25), vec3(0.0), vec3(1.0));
    COLOR = center * tint;
}
