shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 u_Color : source_color = vec4(1.0);
uniform float u_Cutoff = 0.5;

void fragment() {
	vec4 color = u_Color * COLOR;
	if (color.a < u_Cutoff) {
		discard;
	}

	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	ALBEDO = color.rgb;
	ROUGHNESS = 1.0;
}
