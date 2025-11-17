shader_type spatial;
render_mode blend_add, cull_back;

#include "res://addons/icosa/brush_materials/_includes/fog_functions.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform vec3 u_SpecColor : source_color = vec3(0.6);
uniform float u_Shininess : hint_range(0.0, 1.0) = 0.9;
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
  vec3 normal = normalize(v_view_normal);
  vec3 view_dir = normalize(-v_view_position);

  // Hardcode shiny specular values for bubble effect
  float smoothness = 0.9;
  vec3 specular_color = 0.6 * COLOR.rgb;

  // Calculate rim effect
  float rim = 1.0 - abs(dot(view_dir, normal));
  rim *= 1.0 - pow(rim, 5.0);

  // Unity's _Time.x = time/20, so we need TIME/20.0 in Godot
  float time_x = TIME / 20.0;

  // Thin slit diffraction texture ramp lookup
  vec3 diffraction = texture(u_MainTex, vec2(rim + time_x + normal.y, rim + normal.y)).xyz;
  vec3 emission = rim * (0.25 * diffraction * rim + 0.75 * diffraction * COLOR.rgb);

  // Apply specular lighting from main light
  vec3 light_dir_0 = normalize(u_SceneLight_0_direction);
  vec3 half_vector = normalize(light_dir_0 + view_dir);
  float NdotH = max(dot(normal, half_vector), 0.0);
  float specular = pow(NdotH, smoothness * 128.0);

  vec3 color = emission;
  color += specular_color * specular * u_SceneLight_0_color.rgb;
  color += COLOR.rgb * u_ambient_light_color.rgb * 0.1;

  vec3 final_color = apply_fog(color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = COLOR.a;
}
