shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_ScrollRate = 0.1;
uniform vec3 u_ScrollDistance = vec3(0.5, 5.0, 0.0);
uniform float u_ScrollJitterIntensity = 0.2;
uniform float u_ScrollJitterFrequency = 5.0;
uniform float u_SpreadRate = 1.25;
uniform float u_Opacity = 1.0;
// UnityGLTF exporter v3+ has already baked the animated particle-center offset.
// Live strokes, .tilt imports, and legacy GLTF still need this shader path.
uniform bool u_IsUnityGltfExporterVersion3OrNewer = false;

varying vec3 v_color;
varying float v_fog_coord;
varying vec2 v_uv;

const float kRecipSquareRootOfTwo = 0.70710678;
const float kDecimetersToWorldUnits = 10.0;

vec3 recreate_corner(vec3 center, float corner, float rotation, float size) {
  float c = cos(rotation);
  float s = sin(rotation);

  vec3 up = vec3(s, c, 0.0);
  vec3 right = vec3(c, -s, 0.0);

  float f_up = (corner == 0.0 || corner == 1.0) ? -1.0 : 1.0;
  float f_right = (corner == 0.0 || corner == 2.0) ? -1.0 : 1.0;

  vec3 result = center;
  result += f_right * right * size;
  result += f_up * up * size;
  return result;
}

float spread_progress(float birth_time, float spread_rate) {
  float age = abs(TIME - birth_time);
  return clamp(age * spread_rate, 0.0, 1.0);
}

vec3 compute_displacement(vec3 pos, float seed, float t01) {
  float t2 = TIME * 0.3333333;
  vec3 disp = u_ScrollDistance * t01;
  disp.x += sin(t01 * u_ScrollJitterFrequency + seed * 10.0 + t2 + pos.z) * u_ScrollJitterIntensity;
  disp.y += (mod(seed * 100.0, 1.0) - 0.5) * u_ScrollDistance.y * t01;
  disp.z += cos(t01 * u_ScrollJitterFrequency + seed * 7.0 + t2 + pos.x) * u_ScrollJitterIntensity;
  return disp * kDecimetersToWorldUnits;
}

void vertex() {
  float rotation = TANGENT.z;
  float birth_time = UV2.x;
  float seed = clamp(COLOR.a, 0.0, 1.0);
  float t01 = mod(TIME * u_ScrollRate + seed * 10.0, 1.0);

  vec4 custom0 = CUSTOM0;
  float corner = mod(custom0.x, 4.0);
  vec3 center_OS = custom0.yzw;
  float half_size_OS = length(VERTEX - center_OS) * kRecipSquareRootOfTwo;

  float spread = spread_progress(birth_time, u_SpreadRate);
  if (!u_IsUnityGltfExporterVersion3OrNewer) {
    center_OS += compute_displacement(center_OS, seed, t01) * spread;
  }

  vec3 basis_y = MODEL_MATRIX[1].xyz;
  float scale = max(length(basis_y), 0.0001);

  mat4 modelview_mat = VIEW_MATRIX * MODEL_MATRIX;
  mat4 inv_modelview_mat = inverse(modelview_mat);

  vec3 center_view = (modelview_mat * vec4(center_OS, 1.0)).xyz;
  vec3 vertex_view = recreate_corner(center_view, corner, rotation, half_size_OS * scale);

  VERTEX = (inv_modelview_mat * vec4(vertex_view, 1.0)).xyz;
  v_color = COLOR.rgb * pow(1.0 - t01, 1.0) * 5.0;
  v_fog_coord = vertex_view.z;
  v_uv = UV;
}

void fragment() {
  vec4 tex_color = texture(u_MainTex, v_uv);
  vec3 base_color = v_color * tex_color.rgb;
  vec3 highlight_color = vec3(tex_color.a);
  vec3 final_color = (base_color + highlight_color) * u_Opacity;
  final_color = apply_fog(final_color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
