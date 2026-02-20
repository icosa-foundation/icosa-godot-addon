shader_type spatial;
render_mode blend_add, cull_back;

#include "res://addons/icosa/open_brush/brush_materials/_includes/surface_shader.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform vec3 u_SpecColor : source_color = vec3(0.05);
uniform float u_Shininess : hint_range(0.0, 1.0) = 0.8;
uniform float u_EmissionGain : hint_range(0.0, 1.0) = 0.5;

uniform vec4 u_ambient_light_color;
uniform vec4 u_SceneLight_0_color;
uniform vec4 u_SceneLight_1_color;
uniform vec3 u_SceneLight_0_direction;
uniform vec3 u_SceneLight_1_direction;

varying vec3 v_view_position;
varying vec3 v_view_normal;

void vertex() {
  v_view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
  v_view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 bloom_color(vec4 color, float gain) {
  color = pow(color, vec4(2.2));
  color.rgb *= 80.0 * exp(gain * 10.0);
  return color;
}

void fragment() {
  vec3 normal = normalize(v_view_normal);
  if (!FRONT_FACING) {
    normal *= -1.0;
  }

  vec3 eye_dir = -normalize(v_view_position);
  vec3 light_dir_0 = normalize(u_SceneLight_0_direction);
  vec3 light_dir_1 = normalize(u_SceneLight_1_direction);

  // Specular lighting only (no diffuse)
  vec3 diffuse = vec3(0.0);
  vec3 spec = u_SpecColor;

  vec3 light_0 = surface_shader_specular_gloss(
    normal, light_dir_0, eye_dir,
    u_SceneLight_0_color.rgb, diffuse, spec, u_Shininess);

  vec3 light_1 = sh_shader_with_spec(
    normal, light_dir_1,
    u_SceneLight_1_color.rgb, diffuse, spec);

  // Neon pulse animation
  // Unity's _Time.x = time/20, so we need TIME/20.0 in Godot
  float time_x = TIME / 20.0;

  vec2 uv = UV;
  uv.x -= time_x * 15.0;
  uv.x = mod(abs(uv.x), 1.0);
  float neon = pow(10.0 * clamp(0.2 - uv.x, 0.0, 1.0), 5.0);
  neon = clamp(neon, 0.0, 1.0);

  vec4 bloom = bloom_color(COLOR, u_EmissionGain);

  // Fresnel-like term
  float NdotV = abs(dot(normal, eye_dir));
  bloom *= pow(NdotV, 2.0);
  bloom *= NdotV;

  vec3 final_color = light_0 + light_1 + neon * bloom.rgb;

  ALBEDO = final_color;
  ALPHA = 1.0;
}
