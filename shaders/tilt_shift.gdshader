shader_type canvas_item;
// Tilt-shift: sharp band in the middle, blur towards the top and bottom,
// boosted colours so the city looks like a miniature model.
// `drunk` adds blur everywhere and a slight wobble.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float focus_center = 0.58;
uniform float focus_half = 0.13;
uniform float falloff = 0.3;
uniform float max_blur = 7.0;
uniform float saturation = 1.25;
uniform float contrast = 1.12;
uniform float drunk = 0.0;
// Sun glare without sunglasses (0..1), strongest towards the top.
uniform float glare = 0.0;
// Double vision when very drunk (0..1): a second, shifted image.
uniform float double_vision = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 9.0 + TIME * 1.7) * 0.004 * drunk;
	float d = abs(uv.y - focus_center);
	float amount = smoothstep(focus_half, focus_half + falloff, d);
	amount = clamp(amount + drunk * 0.6, 0.0, 1.0);
	vec2 step_px = SCREEN_PIXEL_SIZE * max_blur * amount;
	vec3 col = vec3(0.0);
	float wsum = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 o = vec2(float(x), float(y));
			float w = exp(-dot(o, o) / 3.0);
			col += texture(screen_tex, uv + o * step_px).rgb * w;
			wsum += w;
		}
	}
	col /= wsum;
	if (double_vision > 0.0) {
		vec2 shift = vec2(0.025 + 0.01 * sin(TIME * 0.7), 0.006) * double_vision;
		vec3 ghost = texture(screen_tex, uv + shift).rgb;
		col = mix(col, ghost, 0.45 * double_vision);
	}
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	col = mix(col, vec3(1.0, 0.97, 0.88), glare * (0.45 + 0.55 * (1.0 - SCREEN_UV.y)));
	COLOR = vec4(col, 1.0);
}
