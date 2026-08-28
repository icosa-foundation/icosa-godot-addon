shader_type spatial;
render_mode unshaded, blend_mix, cull_back;

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"
#include "res://addons/icosa/open_brush/brush_materials/_includes/surface_shader.gdshaderinc"
#include "res://addons/icosa/open_brush/brush_materials/_includes/tangent_bump_lit.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform sampler2D u_BumpMap : hint_normal, filter_linear_mipmap;
uniform vec4 u_MainTex_ST = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec3 u_SpecColor : source_color = vec3(0.235294);
uniform float u_Shininess : hint_range(0.0, 1.0) = 0.4;
uniform float u_Cutoff : hint_range(0.0, 1.0) = 0.3;

uniform vec4 u_ambient_light_color;
uniform vec4 u_SceneLight_0_color;
uniform vec4 u_SceneLight_1_color;
uniform vec3 u_SceneLight_0_direction;
uniform vec3 u_SceneLight_1_direction;

varying vec3 v_view_position;
varying vec3 v_view_normal;
varying vec3 v_view_tangent;
varying vec3 v_view_bitangent;
varying vec2 v_uv;
varying float v_fog_coord;

void vertex() {
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v_view_position = view_position.xyz;
	v_view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_view_tangent = normalize((MODELVIEW_MATRIX * vec4(TANGENT, 0.0)).xyz);
	v_view_bitangent = normalize((MODELVIEW_MATRIX * vec4(BINORMAL, 0.0)).xyz);
	v_uv = UV * u_MainTex_ST.xy + u_MainTex_ST.zw;
	v_fog_coord = view_position.z;
}

void fragment() {
	float brush_mask = texture(u_MainTex, v_uv).a * COLOR.a;
	if (brush_mask <= u_Cutoff) {
		discard;
	}

	vec3 normal = perturb_tangent_normal(
		v_view_tangent,
		v_view_bitangent,
		v_view_normal,
		v_uv,
		u_BumpMap,
		FRONT_FACING
	);
	vec3 eye_dir = -normalize(v_view_position);
	vec3 light_dir_0 = normalize(u_SceneLight_0_direction);
	vec3 light_dir_1 = normalize(u_SceneLight_1_direction);

	vec3 light_0 = surface_shader_specular_gloss(
		normal,
		light_dir_0,
		eye_dir,
		u_SceneLight_0_color.rgb,
		COLOR.rgb,
		u_SpecColor,
		u_Shininess
	);
	vec3 light_1 = sh_shader_with_spec(
		normal,
		light_dir_1,
		u_SceneLight_1_color.rgb,
		COLOR.rgb,
		u_SpecColor
	);
	vec3 ambient = COLOR.rgb * u_ambient_light_color.rgb;

	ALBEDO = apply_fog(light_0 + light_1 + ambient, v_fog_coord);
	ALPHA = 1.0;
}
