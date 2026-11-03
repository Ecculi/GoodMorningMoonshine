shader_type spatial;
// Moving cloud shadows on sunny days. Drawn on thin planes over the street
// and the facades; darkens what is behind it (multiply). Each point is
// projected along the sun direction onto a cloud layer, so the shadows line
// up with the sun like real ones.
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec3 to_sun = vec3(0.0, 1.0, 0.0);
uniform vec2 offset = vec2(0.0);
uniform float strength = 0.4;
uniform float scale = 0.018;
uniform float coverage = 0.55;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 s = normalize(to_sun);
	vec2 ground = world_pos.xz - s.xz * (world_pos.y / max(s.y, 0.1));
	float n = texture(noise_tex, (ground + offset) * scale).r;
	float cloud = smoothstep(coverage, coverage + 0.12, n);
	ALBEDO = vec3(1.0 - strength * cloud);
}
