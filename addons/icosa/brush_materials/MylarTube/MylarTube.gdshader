shader_type spatial;
render_mode blend_mix, cull_back;

#include "res://addons/icosa/brush_materials/_includes/fog_functions.gdshaderinc"
#include "res://addons/icosa/brush_materials/_includes/surface_shader.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform vec3 u_SpecColor : source_color = vec3(0.5, 0.5, 0.5);
uniform float u_Shininess : hint_range(0.0, 1.0) = 0.078125;
uniform float u_SqueezeAmount : hint_range(0.0, 1.0) = 0.825;

global uniform vec4 u_ambient_light_color;
global uniform vec4 u_SceneLight_0_color;
global uniform vec4 u_SceneLight_1_color;
global uniform vec3 u_SceneLight_0_direction;
global uniform vec3 u_SceneLight_1_direction;

varying vec3 v_view_position;
varying vec3 v_view_normal;
varying vec3 v_world_normal;
varying float v_fog_coord;

void vertex() {
  // Radius stored in texcoord0.z (vec4)
  // GLTF importer maps _TEXCOORD_0 -> _CUSTOM0, accessible as CUSTOM0
  float radius = CUSTOM0.z;

  // Squeeze displacement
  float squeeze = sin(UV.x * 3.14159);
  vec3 squeeze_displacement = radius * NORMAL * squeeze;
  vec3 displaced_vertex = VERTEX - squeeze_displacement * u_SqueezeAmount;

  // Perturb normal
  vec3 perturbed_normal = normalize(NORMAL + squeeze_displacement * 2.5);

  v_view_position = (MODELVIEW_MATRIX * vec4(displaced_vertex, 1.0)).xyz;
  v_view_normal = normalize((MODELVIEW_MATRIX * vec4(perturbed_normal, 0.0)).xyz);
  v_world_normal = normalize((MODEL_MATRIX * vec4(perturbed_normal, 0.0)).xyz);
  v_fog_coord = v_view_position.z;

  VERTEX = displaced_vertex;
  NORMAL = perturbed_normal;
}

void fragment() {
  // Rim term in world space
  vec3 world_pos = (INV_VIEW_MATRIX * vec4(v_view_position, 1.0)).xyz;
  vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
  vec3 N = normalize(v_world_normal);
  float rim = 1.0 - abs(dot(view_dir, N));
  rim *= (1.0 - pow(rim, 5.0));

  // Thin-slit diffraction ramp lookup
  // Unity's GetTime().x = _Time.x = time/20
  float time_x = TIME / 20.0;
  vec2 diffUV = vec2(rim + time_x + N.y, rim + N.y);
  vec3 diffraction = texture(u_MainTex, diffUV).rgb;

  // Emission from rim and diffraction
  vec3 emission = rim * (0.25 * diffraction * rim + 0.75 * diffraction * COLOR.rgb);

  // Lighting
  vec3 normal = normalize(v_view_normal);
  if (!FRONT_FACING) {
    normal *= -1.0;
  }

  vec3 eye_dir = -normalize(v_view_position);
  vec3 light_dir_0 = normalize(u_SceneLight_0_direction);
  vec3 light_dir_1 = normalize(u_SceneLight_1_direction);

  vec3 specular_color = u_SpecColor * COLOR.rgb;

  vec3 light_0 = surface_shader_specular_gloss(
    normal, light_dir_0, eye_dir,
    u_SceneLight_0_color.rgb, COLOR.rgb, specular_color, u_Shininess);

  vec3 light_1 = sh_shader_with_spec(
    normal, light_dir_1,
    u_SceneLight_1_color.rgb, COLOR.rgb, specular_color);

  vec3 ambient = COLOR.rgb * u_ambient_light_color.rgb;

  vec3 final_color = light_0 + light_1 + ambient + emission;
  final_color = apply_fog(final_color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
