shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_size : hint_range(1.0, 4.0, 1.0) = 1.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.15;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / pixel_size);
	vec2 uv = (cell + 0.5) * pixel_size * SCREEN_PIXEL_SIZE;
	vec3 source = texture(screen_texture, uv).rgb;
	float light = dot(source, vec3(0.2126, 0.7152, 0.0722));
	light = clamp((light - 0.5) * contrast + 0.5, 0.0, 1.0);
	ivec2 tile = ivec2(mod(cell, 4.0));
	float threshold = (BAYER[tile.y * 4 + tile.x] + 0.5) / 16.0;
	float ink = step(threshold, light);
	COLOR = vec4(vec3(ink), 1.0);
}
