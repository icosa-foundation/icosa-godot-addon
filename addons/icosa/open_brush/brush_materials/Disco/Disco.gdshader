shader_type spatial;
render_mode blend_mix, cull_back;

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"
#include "res://addons/icosa/open_brush/brush_materials/_includes/surface_shader.gdshaderinc"

uniform float u_Shininess : hint_range(0.0, 1.0) = 0.8;
uniform vec3 u_SpecColor : source_color = vec3(0.5);

global uniform vec4 u_ambient_light_color;
global uniform vec4 u_SceneLight_0_color;
global uniform vec4 u_SceneLight_1_color;
global uniform vec3 u_SceneLight_0_direction;
global uniform vec3 u_SceneLight_1_direction;

varying vec3 v_view_position;
varying vec3 v_view_normal;
varying float v_fog_coord;

void vertex() {
  v_view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
  v_view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
  v_fog_coord = v_view_position.z;
}

void fragment() {
  vec3 normal = normalize(v_view_normal);

  // Create faceted normal using derivatives for disco ball effect
  normal.x = dFdx(normal.x);
  vec3 faceted_normal = normalize(cross(dFdy(v_view_position), dFdx(v_view_position)));

  vec3 light_dir_0 = normalize(u_SceneLight_0_direction);
  vec3 light_dir_1 = normalize(u_SceneLight_1_direction);
  vec3 eye_dir = -normalize(v_view_position);

  vec3 diffuseColor = vec3(0.0);
  vec3 specularColor = COLOR.rgb * u_SpecColor;

  vec3 light_0 = surface_shader_specular_gloss(
    faceted_normal, light_dir_0, eye_dir,
    u_SceneLight_0_color.rgb, diffuseColor, specularColor, u_Shininess);

  vec3 light_1 = sh_shader_with_spec(
    normal, light_dir_1,
    u_SceneLight_1_color.rgb, diffuseColor, u_SpecColor);

  vec3 ambient = diffuseColor * u_ambient_light_color.rgb;

  // Fake "disco ball" hot spot
  float fakeLightIntensity = pow(abs(dot(faceted_normal, vec3(0.0, 1.0, 0.0))), 10.0) * 20.0;
  vec3 fakeLight = specularColor * fakeLightIntensity;

  vec3 final_color = light_0 + light_1 + ambient + fakeLight;
  final_color = apply_fog(final_color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
