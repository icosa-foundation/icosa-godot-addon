shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

#include "res://addons/icosa/brush_materials/_includes/fog_functions.gdshaderinc"

uniform float u_SparkleRate = 2.0;

varying vec4 v_color;
uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;

varying float v_fog_coord;

const float kRecipSquareRootOfTwo = 0.70710678;

// Given a centerpoint and vertex corner, create a camera-facing quad
vec3 recreate_corner(vec3 center, float corner, float rotation, float size) {
  float c = cos(rotation);
  float s = sin(rotation);

  // Basis in camera/view space
  vec3 up = vec3(s, c, 0.0);
  vec3 right = vec3(c, -s, 0.0);

  // Corner layout: 0=bottom-left, 1=bottom-right, 2=top-left, 3=top-right
  float f_up = (corner == 0.0 || corner == 1.0) ? -1.0 : 1.0;
  float f_right = (corner == 0.0 || corner == 2.0) ? -1.0 : 1.0;

  vec3 result = center;
  result += f_right * right * size;
  result += f_up * up * size;
  return result;
}

void vertex() {
  // Extract particle data from remapped attributes
  // GLTF attribute mapping (remapped in gltf_import.gd):
  // _TB_UNITY_NORMAL  packed into CUSTOM0.yzw (particle center, VEC3)
  // _TB_UNITY_TEXCOORD_0  TANGENT (rotation in .z, VEC4)
  // _TB_TIMESTAMP  TEXCOORD_1/UV2 (birth time)
  // CUSTOM0.x  vertex ID (added by importer)

  float rotation = TANGENT.z;

  vec4 custom0 = CUSTOM0;
  float vertex_id = custom0.x;
  vec3 center_OS = custom0.yzw;

  float corner = mod(vertex_id, 4.0);
  float halfSize_OS = length(VERTEX - center_OS) * kRecipSquareRootOfTwo;

  vec3 basis_y = MODEL_MATRIX[1].xyz;
  float scale = max(length(basis_y), 0.0001);

  mat4 modelview_mat = VIEW_MATRIX * MODEL_MATRIX;
  mat4 inv_modelview_mat = inverse(modelview_mat);

  vec3 center_view = (modelview_mat * vec4(center_OS, 1.0)).xyz;
  vec3 vertex_view = recreate_corner(center_view, corner, rotation, halfSize_OS * scale);

  VERTEX = (inv_modelview_mat * vec4(vertex_view, 1.0)).xyz;
  v_fog_coord = vertex_view.z;

  // Twinkle: phase from COLOR.a, brightness from time
  float phase = COLOR.a * (2.0 * PI);
  float brightness = 800.0 * pow(abs(sin(TIME * u_SparkleRate + phase)), 20.0);
  v_color.rgb = COLOR.rgb * brightness;
  v_color.a = 1.0;
}

void fragment() {
  vec4 tex = texture(u_MainTex, UV);
  vec3 rgb = (v_color * tex).rgb;
  rgb = apply_fog(rgb, v_fog_coord);
  ALBEDO = rgb;
  ALPHA = 1.0;
}
