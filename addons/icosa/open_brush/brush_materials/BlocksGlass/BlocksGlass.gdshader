shader_type spatial;
render_mode blend_add, cull_disabled;

#include "res://addons/icosa/open_brush/brush_materials/_includes/surface_shader.gdshaderinc"

uniform float u_Shininess : hint_range(0.0, 1.0) = 0.8;
uniform float u_RimIntensity : hint_range(0.0, 5.0) = 1.0;
uniform float u_RimPower : hint_range(0.0, 10.0) = 4.0;
uniform vec4 u_Color : source_color = vec4(1.0);

uniform vec4 u_SceneLight_0_color;
uniform vec3 u_SceneLight_0_direction;

varying vec3 v_view_position;
varying vec3 v_view_normal;

void vertex() {
  v_view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
  v_view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
  vec3 normal = normalize(v_view_normal);
  float backfaceDimming = 1.0;

  if (!FRONT_FACING) {
    normal *= -1.0;
    backfaceDimming = 0.25;
  }

  vec3 light_dir_0 = normalize(u_SceneLight_0_direction);
  vec3 eye_dir = -normalize(v_view_position);

  vec3 diffuseColor = vec3(0.0);
  vec3 specularColor = u_Color.rgb;

  vec3 light_0 = surface_shader_specular_gloss(
    normal, light_dir_0, eye_dir,
    u_SceneLight_0_color.rgb, diffuseColor, specularColor, u_Shininess);

  // Calculate rim lighting
  float viewAngle = clamp(dot(eye_dir, normal), 0.0, 1.0);
  float rim = pow(1.0 - viewAngle, u_RimPower) * u_RimIntensity;
  vec3 rimColor = vec3(rim);

  vec3 final_color = (light_0 + rimColor) * backfaceDimming;

  ALBEDO = final_color;
  ALPHA = 1.0;
}
