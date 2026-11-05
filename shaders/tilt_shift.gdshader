shader_type canvas_item;
// Tilt-shift: sharp band in the middle, blur towards the top and bottom,
// boosted colours so the city looks like a miniature model.
// `drunk` adds a slight wobble and blurs everything outside a sharp
// circle around the player; the circle shrinks as the drinking goes on.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float focus_center = 0.58;
uniform float focus_half = 0.13;
uniform float falloff = 0.3;
uniform float max_blur = 7.0;
uniform float saturation = 1.25;
uniform float contrast = 1.12;
uniform float drunk = 0.0;
// Sharp circle around the player (screen UV, radius in screen heights).
uniform vec2 circle_center = vec2(0.5, 0.5);
uniform float circle_radius = 2.0;
uniform float aspect = 1.7778;
// Above 3 per mille (0..1): much stronger blur outside the circle.
uniform float heavy = 0.0;
// Drunk vignette (0..1): the edges of the view darken.
uniform float vignette = 0.0;
// Drunk eyelids (0 = open, 1 = shut): dark curved lids from top and bottom.
uniform float lids = 0.0;
// Sun glare without sunglasses (0..1), strongest towards the top.
uniform float glare = 0.0;
// Double vision when very drunk (0..1): a second, shifted image.
uniform float double_vision = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 9.0 + TIME * 1.7) * 0.004 * drunk;
	float d = abs(uv.y - focus_center);
	float amount = smoothstep(focus_half, focus_half + falloff, d);
	// Drunk blur only outside the circle, with a soft edge.
	float dc = length((SCREEN_UV - circle_center) * vec2(aspect, 1.0));
	float outside = smoothstep(circle_radius, circle_radius * 1.6, dc);
	// Some blur also inside the circle, stronger outside it.
	float drunk_blur = mix(0.3, 1.0, outside) * drunk + outside * heavy * 1.3;
	amount = clamp(max(amount, drunk_blur), 0.0, 2.3);
	vec2 step_px = SCREEN_PIXEL_SIZE * max_blur * amount;
	vec3 col = vec3(0.0);
	float wsum = 0.0;
	// Rotate the sample grid randomly per pixel so strong blur turns into
	// soft noise instead of visible copies.
	float ang = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831853;
	mat2 rot = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 o = vec2(float(x), float(y));
			float w = exp(-dot(o, o) / 3.0);
			col += texture(screen_tex, uv + (rot * o) * step_px).rgb * w;
			wsum += w;
		}
	}
	col /= wsum;
	if (double_vision > 0.0) {
		vec2 shift = vec2(0.025 + 0.01 * sin(TIME * 0.7), 0.006) * double_vision;
		vec3 ghost = texture(screen_tex, uv + shift).rgb;
		// Double vision is weaker near the player.
		col = mix(col, ghost, 0.45 * double_vision * mix(0.3, 1.0, outside));
	}
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	col = mix(col, vec3(1.0, 0.97, 0.88), glare * (0.45 + 0.55 * (1.0 - SCREEN_UV.y)));
	if (vignette > 0.0) {
		float r = length((SCREEN_UV - vec2(0.5)) * vec2(aspect, 1.0)) / (0.5 * length(vec2(aspect, 1.0)));
		float inner = mix(0.8, 0.3, vignette);
		col *= 1.0 - smoothstep(inner, inner + 0.55, r) * mix(0.35, 0.85, vignette);
	}
	if (lids > 0.0) {
		// Each lid covers up to half the screen; the edge curves like an eye.
		float x = (SCREEN_UV.x - 0.5) * 2.0;
		float reach = lids * 0.5 + 0.08 * lids * x * x;
		float top = smoothstep(reach + 0.03, reach - 0.01, SCREEN_UV.y);
		float bottom = smoothstep(reach + 0.03, reach - 0.01, 1.0 - SCREEN_UV.y);
		// Semi-transparent: the street still shows through the lids.
		col = mix(col, vec3(0.05, 0.03, 0.03), max(top, bottom) * 0.72);
	}
	COLOR = vec4(col, 1.0);
}
