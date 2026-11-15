shader_type canvas_item;
// Draws the ink grid in the Sumi-e look. The main texture is one texel per
// cell: R = the player's ink, G = smudge, B = permanent ink, A = pulse-filled
// ink. `bleed_tex` is a quarter-resolution blur of the ink.
//
//   Ink:    the player's luminous blue, with dry-brush edges and bristle streaks.
//   Bleed:  a soft blue halo where the ink soaked into the paper; it reads as glow.
//   Smudge: the horde's thin grey wash.
//   Glow:   ink filled by a pulse shines brighter, almost white.

uniform sampler2D bleed_tex : filter_linear, repeat_disable;
uniform vec2 bleed_scale = vec2(1.0, 1.0);
uniform vec4 ink_color : source_color = vec4(0.10, 0.30, 0.95, 0.94);
uniform vec4 ink_light : source_color = vec4(0.30, 0.56, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.42, 0.74, 1.0, 0.92);
uniform vec4 glow_light : source_color = vec4(0.88, 0.96, 1.0, 1.0);
uniform vec4 locked_color : source_color = vec4(0.05, 0.14, 0.62, 0.95);
uniform vec4 smudge_color : source_color = vec4(0.12, 0.11, 0.10, 0.36);
uniform float bleed_strength = 0.42;
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

// Lays colour c2 with alpha a2 over the running colour and alpha.
void over(inout vec3 c, inout float a, vec3 c2, float a2) {
	float o = a2 + a * (1.0 - a2);
	c = (c2 * a2 + c * a * (1.0 - a2)) / max(o, 0.0001);
	a = o;
}

void fragment() {
	vec2 cell = UV * grid_size;
	vec2 wobble = vec2(noise(cell * 0.9), noise(cell * 0.9 + 37.0)) - 0.5;
	vec2 uv = UV + wobble * 0.8 / grid_size;
	vec4 t = texture(TEXTURE, uv);
	vec2 px = 1.7 / grid_size;
	vec4 east = texture(TEXTURE, uv + vec2(px.x, 0.0));
	vec4 west = texture(TEXTURE, uv - vec2(px.x, 0.0));
	vec4 south = texture(TEXTURE, uv + vec2(0.0, px.y));
	vec4 north = texture(TEXTURE, uv - vec2(0.0, px.y));
	float wide_smudge = (t.g + east.g + west.g + south.g + north.g) * 0.2;
	float wide_glow = (t.a + east.a + west.a + south.a + north.a) * 0.2;
	float soak = texture(bleed_tex, (UV + wobble * 3.0 / grid_size) * bleed_scale).r;

	float bristle = noise(cell * vec2(0.4, 2.6));   // long streaks along the stroke
	float dry = noise(cell * vec2(2.2, 0.6));       // breaks up the edge
	float wash = noise(cell * 0.35);

	float ink = smoothstep(0.37, 0.45, t.r + (dry - 0.5) * 0.2);
	float core = smoothstep(0.6, 0.95, t.r);
	float lit = smoothstep(0.35, 0.6, t.a) * ink;

	// Bottom to top: smudge wash, bleed halo, glow halo, then the ink itself.
	vec3 col = smudge_color.rgb;
	float smudge = smoothstep(0.12, 0.7, wide_smudge + (wash - 0.5) * 0.18) * (1.0 - ink);
	float a = smudge * smudge_color.a * (0.7 + 0.5 * wash);

	float halo = smoothstep(0.03, 0.75, soak + (wash - 0.5) * 0.12) * (1.0 - ink) * bleed_strength;
	over(col, a, ink_color.rgb, halo);

	// Where the two inks meet they marble together instead of meeting at an edge.
	float meeting = smoothstep(0.05, 0.4, wide_smudge) * smoothstep(0.04, 0.5, soak) * (1.0 - ink);
	float swirl = noise(cell * 0.7 + vec2(wash * 4.0, bristle * 3.0));
	vec3 marble = mix(ink_color.rgb, vec3(0.16, 0.17, 0.24), smoothstep(0.3, 0.7, swirl));
	over(col, a, marble, meeting * 0.6);

	float shine = smoothstep(0.03, 0.42, wide_glow) * (1.0 - ink) * 0.5;
	over(col, a, glow_color.rgb, shine);

	vec3 black = mix(ink_color.rgb, ink_light.rgb, core * 0.5) * (0.86 + 0.28 * bristle);
	vec3 blue = mix(glow_color.rgb, glow_light.rgb, core * 0.6) * (0.92 + 0.16 * bristle);
	blue = mix(blue, locked_color.rgb, smoothstep(0.4, 0.6, t.b) * core);
	vec3 ink_rgb = mix(black, blue, lit);
	float ink_a = ink * mix(ink_color.a * (0.86 + 0.14 * bristle), glow_color.a, lit);
	over(col, a, ink_rgb, ink_a);

	// Burnt paper (Burning Page mode): charred black with a glowing ember edge.
	float burnt_raw = min(t.g, t.b);
	float burnt = smoothstep(0.62, 0.82, burnt_raw + (dry - 0.5) * 0.25);
	float ember = smoothstep(0.25, 0.6, burnt_raw) * (1.0 - burnt);
	over(col, a, mix(vec3(1.0, 0.45, 0.08), vec3(1.0, 0.85, 0.4), wash), ember * 0.9);
	over(col, a, vec3(0.07, 0.05, 0.045) * (0.7 + 0.6 * wash), burnt * 0.98);

	COLOR = vec4(col, a);
}
