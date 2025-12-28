shader_type spatial;
render_mode blend_mix, cull_disabled;

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"
#include "res://addons/icosa/open_brush/brush_materials/_includes/normal_map.gdshaderinc"
#include "res://addons/icosa/open_brush/brush_materials/_includes/surface_shader.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
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
  vec3 pos = VERTEX;

  // Wave animation - requires CUSTOM0.z for radius
  // GLTF importer maps _TEXCOORD_0 -> _CUSTOM0, accessible as CUSTOM0
  float radius = CUSTOM0.z;
  // Unity's _Time.z = time*2, so we need TIME*2.0 in Godot
  float wave = sin(UV.x - TIME * 2.0);
  float pulse = smoothstep(0.45, 0.5, clamp(wave, 0.0, 1.0));
  pos -= pulse * radius * NORMAL;

  v_view_position = (MODELVIEW_MATRIX * vec4(pos, 1.0)).xyz;
  v_view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
  v_fog_coord = v_view_position.z;

  VERTEX = pos;
}

void fragment() {
  float brush_mask = texture(u_MainTex, UV).a;
  brush_mask *= COLOR.a;

  if (brush_mask <= u_Cutoff) {
    discard;
  }

  // Use perturbed normal from bump map
  vec3 perturbed_normal = perturb_normal(v_view_position, v_view_normal, UV, 0.0025, FRONT_FACING);

  if (!FRONT_FACING) {
    perturbed_normal *= -1.0;
  }

  vec3 eye_dir = -normalize(v_view_position);
  vec3 light_dir_0 = normalize(u_SceneLight_0_direction);
  vec3 light_dir_1 = normalize(u_SceneLight_1_direction);

  vec3 light_0 = surface_shader_specular_gloss(
    perturbed_normal, light_dir_0, eye_dir,
    u_SceneLight_0_color.rgb, COLOR.rgb, u_SpecColor, u_Shininess);

  vec3 light_1 = sh_shader_with_spec(
    perturbed_normal, light_dir_1,
    u_SceneLight_1_color.rgb, COLOR.rgb, u_SpecColor);

  vec3 ambient = COLOR.rgb * u_ambient_light_color.rgb;

  vec3 final_color = light_0 + light_1 + ambient;
  final_color = apply_fog(final_color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
