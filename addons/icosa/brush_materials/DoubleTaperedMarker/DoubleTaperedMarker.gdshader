shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

#include "res://addons/icosa/brush_materials/_includes/fog_functions.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_Cutoff : hint_range(0.0, 1.0) = 0.5;

varying float v_fog_coord;

void vertex() {
	v_fog_coord = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	float envelope = sin(UV.x * 3.14159);
	float widthMultiplier = 1.0 - envelope;
	VERTEX.xyz += vec3(-UV2.x, -UV2.y, 0) * widthMultiplier;
}

void fragment() {
	vec3 linear_color = pow(COLOR.rgb, vec3(2.2)); // Convert sRGB to linear
	vec3 final_color = apply_fog(linear_color, v_fog_coord);
	ALBEDO = final_color;
	ALPHA = 1.0;
}
