shader_type spatial;
render_mode blend_mix, cull_disabled;

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"
#include "res://addons/icosa/open_brush/brush_materials/_includes/surface_shader.gdshaderinc"

uniform vec3 u_SpecColor : source_color = vec3(0.2);
uniform float u_Shininess : hint_range(0.0, 1.0) = 0.4;
uniform float u_Cutoff : hint_range(0.0, 1.0) = 0.5;

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
  // Fade from center outward (dark to light)
  vec4 darker_color = COLOR * 0.6;
  vec4 finalColor = mix(COLOR, darker_color, 1.0 - UV.x);

  // Ambient occlusion: front faces are brighter, back faces fade with UV.x
  float fAO = FRONT_FACING ? 1.0 : 0.5 * UV.x;

  vec3 normal = normalize(v_view_normal);
  if (!FRONT_FACING) {
    normal *= -1.0;
  }

  vec3 eye_dir = -normalize(v_view_position);
  vec3 light_dir_0 = normalize(u_SceneLight_0_direction);
  vec3 light_dir_1 = normalize(u_SceneLight_1_direction);

  vec3 light_0 = surface_shader_specular_gloss(
    normal, light_dir_0, eye_dir,
    u_SceneLight_0_color.rgb, finalColor.rgb, u_SpecColor, u_Shininess);

  vec3 light_1 = sh_shader_with_spec(
    normal, light_dir_1,
    u_SceneLight_1_color.rgb, finalColor.rgb, u_SpecColor);

  vec3 ambient = finalColor.rgb * u_ambient_light_color.rgb;

  vec3 color = (light_0 + light_1 + ambient) * fAO;
  vec3 final_color = apply_fog(color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
