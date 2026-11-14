shader_type canvas_item;
// Draws the ink grid. The texture is one texel per cell (R = ink, G = smudge),
// sampled with linear filtering, wobbled with noise, and thresholded so cells
// become organic blobs with a darker wet rim. Swap this shader to restyle the
// ground.

uniform vec4 ink_color : source_color = vec4(0.20, 0.42, 0.95, 0.86);
uniform vec4 ink_rim : source_color = vec4(0.05, 0.13, 0.45, 0.95);
uniform vec4 locked_color : source_color = vec4(0.10, 0.16, 0.55, 0.95);
uniform vec4 smudge_color : source_color = vec4(0.36, 0.34, 0.33, 0.62);
uniform vec2 grid_size = vec2(480.0, 270.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 cell = UV * grid_size;
	vec2 wobble = vec2(noise(cell * 0.9), noise(cell * 0.9 + 37.0)) - 0.5;
	vec4 t = texture(TEXTURE, UV + wobble * 0.7 / grid_size);
	float grain = noise(cell * 3.0);

	float ink = smoothstep(0.40, 0.47, t.r);
	float core = smoothstep(0.62, 0.86, t.r);
	float smudge = smoothstep(0.34, 0.46, t.g + (grain - 0.5) * 0.3) * (1.0 - ink);

	vec3 ink_rgb = mix(ink_rim.rgb, ink_color.rgb, core) * (0.93 + 0.14 * grain);
	float ink_a = mix(ink_rim.a, ink_color.a, core);
	float locked = smoothstep(0.4, 0.6, t.b) * core;
	ink_rgb = mix(ink_rgb, locked_color.rgb * (0.9 + 0.2 * grain), locked);
	ink_a = mix(ink_a, locked_color.a, locked);
	vec3 smudge_rgb = smudge_color.rgb * (0.8 + 0.4 * grain);
	COLOR = vec4(mix(smudge_rgb, ink_rgb, ink), max(ink * ink_a, smudge * smudge_color.a));
}
