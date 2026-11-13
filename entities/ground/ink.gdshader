shader_type canvas_item;
// Draws the ink grid. The texture is one texel per cell (R = ink, G = smudge),
// sampled with linear filtering and thresholded so blocky cells become
// rounded blobs. Swap this shader to restyle the ground.

uniform vec4 ink_color : source_color = vec4(0.22, 0.45, 0.95, 0.80);
uniform vec4 smudge_color : source_color = vec4(0.42, 0.40, 0.38, 0.60);

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float ink = smoothstep(0.34, 0.42, t.r);
	float smudge = smoothstep(0.34, 0.42, t.g) * (1.0 - ink);
	vec3 rgb = mix(smudge_color.rgb, ink_color.rgb, ink);
	COLOR = vec4(rgb, max(ink * ink_color.a, smudge * smudge_color.a));
}
