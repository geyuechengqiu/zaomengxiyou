shader_type canvas_item;
render_mode unshaded;

varying vec2 map_position;

void vertex() {
    map_position = VERTEX;
}

void fragment() {
    // Repeat an opaque stone patch from the original atlas beneath the grass.
    vec2 tile = fract((map_position - vec2(0.0, 1031.3)) / vec2(128.0, 64.0));
    vec2 atlas_uv = (vec2(100.5, 120.5) + tile * vec2(63.0, 31.0)) / vec2(textureSize(TEXTURE, 0));
    COLOR = texture(TEXTURE, atlas_uv);
}
