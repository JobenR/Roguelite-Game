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
// Reclaim mode: the player's ground is clean bright paper edged in their ink
// colour, the horde's ink glows and pulses, and walls are charcoal blocks.
uniform bool reclaim_look = false;
uniform bool wall_look = false;
uniform vec4 enemy_color : source_color = vec4(1.0, 0.24, 0.55, 0.95);
uniform vec4 enemy_light : source_color = vec4(1.0, 0.72, 0.84, 1.0);

// Paint by number (Masterpiece mode): each cell carries its own ink colour.
uniform bool paint_on = false;
uniform sampler2D paint_tex : filter_linear, repeat_disable;    // colour laid on each cell
uniform sampler2D target_tex : filter_nearest, repeat_disable;  // rgb = colour wanted, a = region id

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

	vec3 c_ink = ink_color.rgb;
	vec3 c_light = ink_light.rgb;
	vec3 c_glow = glow_color.rgb;
	vec3 c_glow_light = glow_light.rgb;
	vec3 c_locked = locked_color.rgb;
	float hint = 0.0;
	float outline = 0.0;
	vec3 want = vec3(0.0);
	if (paint_on) {
		c_ink = texture(paint_tex, uv).rgb;
		c_light = mix(c_ink, vec3(1.0), 0.3);
		// Flooded areas shine only a little, so the picture keeps its colours.
		c_glow = mix(c_ink, vec3(1.0), 0.12);
		c_glow_light = mix(c_ink, vec3(1.0), 0.38);
		c_locked = c_ink * 0.6;
		// Read through the same wobble as the ink, so the outlines look hand drawn.
		vec2 at = UV + wobble * 1.6 / grid_size;
		vec4 goal = texture(target_tex, at);
		vec2 one = 1.0 / grid_size;
		float differs = step(0.001, abs(goal.a - texture(target_tex, at + vec2(one.x, 0.0)).a))
				+ step(0.001, abs(goal.a - texture(target_tex, at + vec2(0.0, one.y)).a));
		outline = min(differs, 1.0);
		hint = step(0.001, goal.a);
		want = goal.rgb;
	}

	vec3 c_halo = c_ink;
	float enemy_body = 0.0;
	float enemy_core = 0.0;
	float enemy_halo = 0.0;
	float clean_edge = 0.0;
	if (reclaim_look) {
		c_halo = ink_color.rgb;
		c_ink = vec3(0.975, 0.955, 0.905);
		c_light = vec3(1.0, 0.99, 0.96);
		c_glow = vec3(0.92, 0.965, 1.0);
		c_glow_light = vec3(1.0);
		c_locked = vec3(0.84, 0.91, 1.0);
		// The horde's ink: smudge cells that are not walls (walls set both G and B).
		float sm_t = t.g * (1.0 - t.b);
		float sm_wide = (sm_t + east.g * (1.0 - east.b) + west.g * (1.0 - west.b) + south.g * (1.0 - south.b) + north.g * (1.0 - north.b)) * 0.2;
		vec2 far = 4.5 / grid_size;
		float sm_far = (texture(TEXTURE, uv + vec2(far.x, 0.0)).g * (1.0 - texture(TEXTURE, uv + vec2(far.x, 0.0)).b)
				+ texture(TEXTURE, uv - vec2(far.x, 0.0)).g * (1.0 - texture(TEXTURE, uv - vec2(far.x, 0.0)).b)
				+ texture(TEXTURE, uv + vec2(0.0, far.y)).g * (1.0 - texture(TEXTURE, uv + vec2(0.0, far.y)).b)
				+ texture(TEXTURE, uv - vec2(0.0, far.y)).g * (1.0 - texture(TEXTURE, uv - vec2(0.0, far.y)).b)) * 0.25;
		enemy_body = smoothstep(0.37, 0.46, sm_t + (dry - 0.5) * 0.2);
		enemy_core = smoothstep(0.6, 0.95, sm_wide);
		float pulse = 0.82 + 0.18 * sin(TIME * 2.2 + wash * 7.0);
		enemy_halo = smoothstep(0.02, 0.55, sm_wide * 0.6 + sm_far * 0.7) * (1.0 - enemy_body) * 0.62 * pulse;
		float wide_ink = (t.r + east.r + west.r + south.r + north.r) * 0.2;
		clean_edge = ink * (1.0 - smoothstep(0.72, 0.98, wide_ink));
	}

	// Bottom to top: smudge wash, bleed halo, glow halo, then the ink itself.
	vec3 col = smudge_color.rgb;
	float smudge = smoothstep(0.12, 0.7, wide_smudge + (wash - 0.5) * 0.18) * (1.0 - ink);
	if (reclaim_look) {
		smudge = 0.0;
	}
	float a = smudge * smudge_color.a * (0.7 + 0.5 * wash);

	float halo = smoothstep(0.03, 0.75, soak + (wash - 0.5) * 0.12) * (1.0 - ink) * bleed_strength;
	over(col, a, c_halo, halo);

	// Where the two inks meet they marble together instead of meeting at an edge.
	float meeting = smoothstep(0.05, 0.4, wide_smudge) * smoothstep(0.04, 0.5, soak) * (1.0 - ink);
	float swirl = noise(cell * 0.7 + vec2(wash * 4.0, bristle * 3.0));
	vec3 marble = mix(c_halo, vec3(0.16, 0.17, 0.24), smoothstep(0.3, 0.7, swirl));
	over(col, a, marble, meeting * 0.6);

	if (reclaim_look) {
		// The horde's glow bleeds into the paper around its ink.
		over(col, a, enemy_color.rgb, enemy_halo);
	}
	float shine = smoothstep(0.03, 0.42, wide_glow) * (1.0 - ink) * 0.5;
	over(col, a, c_glow, shine);

	// The picture to paint: a faint wash of the colour each area wants.
	over(col, a, want, hint * (1.0 - ink) * (0.13 + 0.05 * wash));

	vec3 black = mix(c_ink, c_light, core * 0.5) * (0.86 + 0.28 * bristle);
	vec3 blue = mix(c_glow, c_glow_light, core * 0.6) * (0.92 + 0.16 * bristle);
	blue = mix(blue, c_locked, smoothstep(0.4, 0.6, t.b) * core);
	vec3 ink_rgb = mix(black, blue, lit);
	float ink_a = ink * mix(ink_color.a * (0.86 + 0.14 * bristle), glow_color.a, lit);
	over(col, a, ink_rgb, ink_a);
	if (reclaim_look) {
		// A brushed line in the player's ink where clean ground meets the rest.
		over(col, a, ink_color.rgb * (0.85 + 0.3 * bristle), clean_edge * 0.8);
		// Enemy ink: luminous, brightest at the middle of a patch.
		vec3 glow_rgb = mix(enemy_color.rgb, enemy_light.rgb, enemy_core * 0.5) * (0.92 + 0.16 * bristle);
		over(col, a, glow_rgb, enemy_body * 0.96);
	}

	// Brushed outlines between the numbered areas, fainter once painted over.
	over(col, a, vec3(0.08, 0.07, 0.06), outline * mix(0.6, 0.3, ink) * (0.6 + 0.6 * dry));

	// Burnt paper (Burning Page mode): charred black with a glowing ember edge.
	float burnt_raw = min(t.g, t.b);
	float burnt = smoothstep(0.62, 0.82, burnt_raw + (dry - 0.5) * 0.25);
	float ember = smoothstep(0.25, 0.6, burnt_raw) * (1.0 - burnt);
	if (wall_look) {
		// Charcoal blocks with a lighter brushed rim, like stone drawn in ink.
		float grain = noise(cell * vec2(1.4, 0.5));
		over(col, a, vec3(0.28, 0.25, 0.22), ember * 0.7);
		over(col, a, vec3(0.105, 0.095, 0.09) * (0.75 + 0.5 * grain + 0.25 * bristle), burnt * 0.99);
	} else {
		over(col, a, mix(vec3(1.0, 0.45, 0.08), vec3(1.0, 0.85, 0.4), wash), ember * 0.9);
		over(col, a, vec3(0.07, 0.05, 0.045) * (0.7 + 0.6 * wash), burnt * 0.98);
	}

	COLOR = vec4(col, a);
}
