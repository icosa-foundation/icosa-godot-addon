shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform float anti_aliasing_strength = 1.0;

void fragment() {
	float w = 0.0;
	float q = 0.0;
	vec2 f = fwidth(UV) * 4.0 * anti_aliasing_strength; // anti-aliasing edge
	w = smoothstep(0.5 - f.x, 0.5 + f.x, abs(UV.x - 0.5) * 4.0 - 1.3); // horizontal lines
	q = smoothstep(0.5 - f.y, 0.5 + f.y, abs(UV.y - 0.5) * 4.0 - 1.3); // vertical lines
	ALPHA = abs(q - w) * 2.0; // XOR effect
	ALPHA_ANTIALIASING_EDGE = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.0;
	ALBEDO = COLOR.rgb;
}