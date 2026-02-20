shader_type spatial;
render_mode blend_mix, cull_back;

// LightWire shader - Emissive wire with animated colored lights
// Based on LightWire-4391aaaa-df81-4396-9e33-31e4e4930b27

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"
#include "res://addons/icosa/open_brush/brush_materials/_includes/surface_shader.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform vec3 u_SpecColor : source_color = vec3(0.3);
uniform float u_Shininess : hint_range(0.0, 1.0) = 0.81;

// Lighting
uniform vec4 u_ambient_light_color;
uniform vec4 u_SceneLight_0_color;
uniform vec4 u_SceneLight_1_color;
uniform vec3 u_SceneLight_0_direction;
uniform vec3 u_SceneLight_1_direction;

// Varyings
varying vec3 v_view_position;
varying vec3 v_view_normal;
varying float v_fog_coord;
varying vec2 v_texcoord0;
varying vec4 v_color;

vec4 bloom_color(vec4 color, float gain) {
  float cmin = length(color.rgb) * 0.05;
  color.rgb = max(color.rgb, vec3(cmin));
  color.r = pow(color.r, 2.2);
  color.g = pow(color.g, 2.2);
  color.b = pow(color.b, 2.2);
  color.a = pow(color.a, 2.2);
  color.rgb *= 2.0 * exp(gain * 10.0);
  return color;
}

void vertex() {
  // Calculate light envelope pattern along the wire
  float envelope = sin(mod(UV.x * 2.0, 1.0) * 3.14159);
  float lights = envelope < 0.15 ? 1.0 : 0.0;
  // Radius stored in texcoord0.z (vec4)
  // GLTF importer maps _TEXCOORD_0 -> _CUSTOM0, accessible as CUSTOM0
  float radius = CUSTOM0.z;

  // Displace vertices outward where lights appear
  vec3 displaced = VERTEX + NORMAL * lights * radius;

  // Transform to view space
  v_view_position = (MODELVIEW_MATRIX * vec4(displaced, 1.0)).xyz;
  v_view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
  v_fog_coord = v_view_position.z;
  v_texcoord0 = UV;
  v_color = COLOR;
}

void fragment() {
  // Calculate light pattern
  float envelope = sin(mod(v_texcoord0.x * 2.0, 1.0) * 3.14159);
  float lights = envelope < 0.1 ? 1.0 : 0.0;
  float border = abs(envelope - 0.1) < 0.01 ? 0.0 : 1.0;

  vec3 specular_color = vec3(0.3) - lights * vec3(0.15);
  float smoothness = 0.3 - lights * 0.3;

  // Animated colored lights
  vec4 color = v_color;
  if (lights > 0.0) {
    // Cycle through RGB colors
    float color_index = floor(mod(v_texcoord0.x * 2.0 + 0.5, 3.0));
    if (color_index < 0.5) {
      color.rgb *= vec3(0.2, 0.2, 1.0); // Blue
    } else if (color_index < 1.5) {
      color.rgb *= vec3(1.0, 0.2, 0.2); // Red
    } else {
      color.rgb *= vec3(0.2, 1.0, 0.2); // Green
    }

    // Sequential light animation
    // Unity's _Time.w = time*3, so we need TIME*3.0 in Godot
    float light_index = mod(v_texcoord0.x * 2.0 + 0.5, 7.0);
    float time_index = mod(TIME * 3.0, 7.0);
    float delta = abs(light_index - time_index);
    float on = 1.0 - clamp(delta * 1.5, 0.0, 1.0);
    color = bloom_color(color * on, 0.7);
  }

  // Compute diffuse color for the wire itself
  vec3 diffuse_color = (1.0 - lights) * color.rgb * 0.2;
  diffuse_color *= border;
  specular_color *= border;

  // Lighting calculation
  vec3 normal = normalize(v_view_normal);
  if (!FRONT_FACING) {
    normal *= -1.0;
  }

  vec3 eye_dir = -normalize(v_view_position);
  vec3 light_dir_0 = normalize(u_SceneLight_0_direction);
  vec3 light_dir_1 = normalize(u_SceneLight_1_direction);

  vec3 light_out_0 = surface_shader_specular_gloss(
    normal, light_dir_0, eye_dir,
    u_SceneLight_0_color.rgb, diffuse_color, specular_color, smoothness);

  vec3 light_out_1 = sh_shader_with_spec(
    normal, light_dir_1,
    u_SceneLight_1_color.rgb, diffuse_color, u_SpecColor);

  vec3 ambient_out = diffuse_color * u_ambient_light_color.rgb;

  vec3 final_color = light_out_0 + light_out_1 + ambient_out;

  // Add emission from lights
  final_color += lights * color.rgb;

  final_color = apply_fog(final_color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
