shader_type sky;
render_mode use_debanding;

// Tilt Brush two-color gradient sky.
// sky_color_a = horizon/bottom color, sky_color_b = zenith/top color.
// gradient_direction is a world-space unit vector pointing toward sky_color_b.

uniform vec4 sky_color_a : source_color = vec4(0.5, 0.6, 1.0, 1.0);
uniform vec4 sky_color_b : source_color = vec4(0.7, 0.8, 0.6, 1.0);
uniform vec3 gradient_direction = vec3(0.0, 1.0, 0.0);

void sky() {
	float t = dot(normalize(EYEDIR), normalize(gradient_direction));
	t = clamp(t * 0.5 + 0.5, 0.0, 1.0);
	COLOR = mix(sky_color_a.rgb, sky_color_b.rgb, t);
}
