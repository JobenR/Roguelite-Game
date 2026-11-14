shader_type canvas_item;
// Draws the ink grid in the Sumi-e look. The texture is one texel per cell
// (R = the player's ink, G = smudge, B = permanent ink), sampled with linear
// filtering, wobbled with noise, and thresholded so cells become brushed
// shapes. The player's ink is luminous blue with a soft glow around it; the
// horde's smudge is a thin grey wash. Swap this shader to restyle the ground.

uniform vec4 ink_color : source_color = vec4(0.10, 0.29, 0.90, 0.93);
uniform vec4 ink_light : source_color = vec4(0.36, 0.62, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.16, 0.42, 1.0, 1.0);
uniform vec4 locked_color : source_color = vec4(0.04, 0.09, 0.42, 0.97);
uniform vec4 smudge_color : source_color = vec4(0.12, 0.11, 0.10, 0.40);
uniform float glow_strength = 0.42;
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
	vec2 uv = UV + wobble * 0.8 / grid_size;
	vec4 t = texture(TEXTURE, uv);
	// A wider average of the ink channel gives the glow its reach.
	vec2 px = 1.7 / grid_size;
	float wide = (t.r + texture(TEXTURE, uv + vec2(px.x, 0.0)).r + texture(TEXTURE, uv - vec2(px.x, 0.0)).r
			+ texture(TEXTURE, uv + vec2(0.0, px.y)).r + texture(TEXTURE, uv - vec2(0.0, px.y)).r) * 0.2;
	float grain = noise(cell * 3.0);
	float brush = noise(cell * vec2(0.4, 2.4));  // long streaks, like bristles

	float ink = smoothstep(0.40, 0.47, t.r);
	float core = smoothstep(0.60, 0.95, t.r);
	float halo = smoothstep(0.03, 0.42, wide) * (1.0 - ink) * glow_strength;
	// The smudge is a soft watery wash: wide blur, gentle edge, slow mottling.
	float wash = noise(cell * 0.35);
	float wide_g = (t.g + texture(TEXTURE, uv + vec2(px.x, 0.0)).g + texture(TEXTURE, uv - vec2(px.x, 0.0)).g
			+ texture(TEXTURE, uv + vec2(0.0, px.y)).g + texture(TEXTURE, uv - vec2(0.0, px.y)).g) * 0.2;
	float smudge = smoothstep(0.12, 0.7, wide_g + (wash - 0.5) * 0.18) * (1.0 - ink);

	vec3 ink_rgb = mix(ink_color.rgb, ink_light.rgb, core * 0.55) * (0.94 + 0.12 * brush);
	float locked = smoothstep(0.4, 0.6, t.b) * core;
	ink_rgb = mix(ink_rgb, locked_color.rgb * (0.9 + 0.2 * grain), locked);

	float ink_a = max(ink * ink_color.a, halo);
	vec3 rgb = mix(glow_color.rgb, ink_rgb, ink);
	float smudge_a = smudge * smudge_color.a * (0.7 + 0.5 * wash);
	rgb = mix(smudge_color.rgb, rgb, clamp(ink_a / (ink_a + smudge_a + 0.0001), 0.0, 1.0));
	COLOR = vec4(rgb, max(ink_a, smudge_a));
}
