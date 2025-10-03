shader_type spatial;
render_mode blend_mix, cull_disabled;

// Include shared functions
#include "res://addons/icosa/brush_materials/_includes/fog_functions.gdshaderinc"
#include "res://addons/icosa/brush_materials/_includes/normal_map.gdshaderinc"
#include "res://addons/icosa/brush_materials/_includes/surface_shader.gdshaderinc"

// Material properties
uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform vec3 u_SpecColor : source_color = vec3(0.235);
uniform float u_Shininess : hint_range(0.0, 1.0) = 0.4;
uniform float u_Cutoff : hint_range(0.0, 1.0) = 0.5;

// Lighting
global uniform vec4 u_ambient_light_color;
global uniform vec4 u_SceneLight_0_color;
global uniform vec4 u_SceneLight_1_color;
global uniform vec3 u_SceneLight_0_direction;
global uniform vec3 u_SceneLight_1_direction;

// Varyings
varying vec3 v_view_position;
varying vec3 v_view_normal;
varying float v_fog_coord;

void vertex() {
  // Transform to view space for lighting calculations
  v_view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
  v_view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
  v_fog_coord = v_view_position.z;
}

void fragment() {
  // Sample textures
  vec4 tex_color = texture(u_MainTex, UV);

  // Compute perturbed normal (must be called before conditional discard)
  vec3 perturbed_normal = perturb_normal(v_view_position, v_view_normal, UV, 0.0005, FRONT_FACING);
  perturbed_normal.z *= mix(-1.0, 1.0, float(FRONT_FACING));

  // Hypercolor animation
  float scroll = TIME;
  vec3 animated_color = vec3(0.0);
  animated_color.r = (sin(tex_color.r * 2.0 + scroll * 0.5 - UV.x) + 1.0) * 2.0;
  animated_color.g = (sin(tex_color.r * 3.3 + scroll * 1.0 - UV.x) + 1.0) * 2.0;
  animated_color.b = (sin(tex_color.r * 4.66 + scroll * 0.25 - UV.x) + 1.0) * 2.0;

  float color_multiplier = 0.5;
  vec3 specular_color = u_SpecColor * animated_color * color_multiplier;
  vec3 diffuse_color = animated_color * COLOR.rgb * color_multiplier;

  // Lighting
  vec3 eye_dir = -normalize(v_view_position);
  vec3 light_dir_0 = normalize(u_SceneLight_0_direction);
  vec3 light_dir_1 = normalize(u_SceneLight_1_direction);

  vec3 light_0 = surface_shader_specular_gloss(
    perturbed_normal, light_dir_0, eye_dir,
    u_SceneLight_0_color.rgb, diffuse_color, specular_color, u_Shininess);

  vec3 light_1 = sh_shader_with_spec(
    perturbed_normal, light_dir_1,
    u_SceneLight_1_color.rgb, diffuse_color, specular_color);

  vec3 ambient = diffuse_color * u_ambient_light_color.rgb;

  vec3 final_color = light_0 + light_1 + ambient;
  final_color = apply_fog(final_color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = 1.0;

  // Alpha cutoff must come last to ensure perturb_normal is called uniformly
  if (tex_color.a <= u_Cutoff) {
    discard;
  }
}
