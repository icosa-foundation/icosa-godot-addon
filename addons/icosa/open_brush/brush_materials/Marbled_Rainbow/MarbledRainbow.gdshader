shader_type spatial;
render_mode blend_mix, cull_disabled;

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"
#include "res://addons/icosa/open_brush/brush_materials/_includes/normal_map.gdshaderinc"
#include "res://addons/icosa/open_brush/brush_materials/_includes/surface_shader.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform sampler2D u_SpecTex : source_color, filter_linear_mipmap;
uniform vec3 u_SpecColor : source_color = vec3(0.235);
uniform float u_Shininess : hint_range(0.0, 1.0) = 0.4;
uniform float u_Cutoff : hint_range(0.0, 1.0) = 0.5;

uniform vec4 u_ambient_light_color;
uniform vec4 u_SceneLight_0_color;
uniform vec4 u_SceneLight_1_color;
uniform vec3 u_SceneLight_0_direction;
uniform vec3 u_SceneLight_1_direction;

varying vec3 v_view_position;
varying vec3 v_view_normal;
varying float v_fog_coord;

void vertex() {
  v_view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
  v_view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
  v_fog_coord = v_view_position.z;
}

void fragment() {
  vec4 mainTex = texture(u_MainTex, UV);
  vec4 specTex = texture(u_SpecTex, UV);

  // Sample bump map and perturb normal
  vec3 bumpNormal = perturb_normal(v_view_position, v_view_normal, UV, 0.0025, FRONT_FACING);

  if (!FRONT_FACING) {
    bumpNormal *= -1.0;
  }

  // Surface properties
  vec3 albedo = mainTex.rgb * COLOR.rgb;
  vec3 specularColor = u_SpecColor * specTex.rgb;
  float alpha = mainTex.a * COLOR.a;

  if (alpha <= u_Cutoff) {
    discard;
  }

  // Lighting
  vec3 eye_dir = -normalize(v_view_position);
  vec3 light_dir_0 = normalize(u_SceneLight_0_direction);
  vec3 light_dir_1 = normalize(u_SceneLight_1_direction);

  vec3 light_0 = surface_shader_specular_gloss(
    bumpNormal, light_dir_0, eye_dir,
    u_SceneLight_0_color.rgb, albedo, specularColor, u_Shininess);

  vec3 light_1 = sh_shader_with_spec(
    bumpNormal, light_dir_1,
    u_SceneLight_1_color.rgb, albedo, specularColor);

  vec3 ambient = albedo * u_ambient_light_color.rgb;

  vec3 color = light_0 + light_1 + ambient;
  vec3 final_color = apply_fog(color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = alpha;
}
