shader_type spatial;
render_mode blend_mix, cull_back;

#include "res://addons/icosa/brush_materials/_includes/fog_functions.gdshaderinc"
#include "res://addons/icosa/brush_materials/_includes/surface_shader.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform vec3 u_SpecColor : source_color = vec3(0.235);
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
  vec3 baseColor = COLOR.rgb;

  // Rim term in world space
  vec3 N = normalize(-v_view_normal);
  vec3 V = normalize(CAMERA_POSITION_WORLD - (INV_VIEW_MATRIX * vec4(v_view_position, 1.0)).xyz);
  float rim = 1.0 - abs(dot(V, N));
  rim *= (1.0 - pow(rim, 5.0));

  // Thin-slit diffraction ramp lookup
  // Unity's _Time.y = time, so just use TIME
  vec2 diffUV = vec2(rim + TIME + N.y, rim + N.y);
  vec3 diffraction = texture(u_MainTex, diffUV).rgb;

  // Emission is currently disabled (set to 0 in original)
  vec3 emission = vec3(0.0);

  // Lighting
  vec3 normal = normalize(v_view_normal);
  if (!FRONT_FACING) {
    normal *= -1.0;
  }

  vec3 eye_dir = -normalize(v_view_position);
  vec3 light_dir_0 = normalize(u_SceneLight_0_direction);
  vec3 light_dir_1 = normalize(u_SceneLight_1_direction);

  vec3 light_0 = surface_shader_specular_gloss(
    normal, light_dir_0, eye_dir,
    u_SceneLight_0_color.rgb, COLOR.rgb, u_SpecColor, u_Shininess);

  vec3 light_1 = sh_shader_with_spec(
    normal, light_dir_1,
    u_SceneLight_1_color.rgb, COLOR.rgb, u_SpecColor);

  vec3 ambient = COLOR.rgb * u_ambient_light_color.rgb;

  vec3 final_color = light_0 + light_1 + ambient + emission;
  final_color = apply_fog(final_color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
