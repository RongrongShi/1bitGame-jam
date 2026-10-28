shader_type canvas_item;

uniform float top_width : hint_range(0.5, 1.0) = 0.82;
uniform float edge_roughness : hint_range(0.0, 0.03) = 0.0;

float edge_noise(float position, float seed) {
	return fract(sin(position * 127.1 + seed * 311.7) * 43758.5453);
}

float edge_cut(float position, float seed) {
	return edge_roughness * (0.2 + 0.55 * edge_noise(floor(position * 90.0), seed)
		+ 0.25 * edge_noise(floor(position * 450.0), seed + 1.0));
}

void fragment() {
	// Inverse projective mapping keeps the texture continuous across the paper.
	float width = mix(top_width, 1.0, UV.y);
	vec2 source_uv = vec2((UV.x - 0.5) / width + 0.5, UV.y / width);
	if (source_uv.x < 0.0 || source_uv.x > 1.0) {
		discard;
	}
	if (edge_roughness > 0.0) {
		if (source_uv.x < edge_cut(source_uv.y, 1.0)
			|| 1.0 - source_uv.x < edge_cut(source_uv.y, 3.0)
			|| source_uv.y < edge_cut(source_uv.x, 5.0)
			|| 1.0 - source_uv.y < edge_cut(source_uv.x, 7.0)) {
			discard;
		}
	}
	COLOR = texture(TEXTURE, source_uv);
}
