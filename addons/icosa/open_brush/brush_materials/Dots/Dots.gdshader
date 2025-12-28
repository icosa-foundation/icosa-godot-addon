shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform vec4 u_TintColor : source_color = vec4(1.0);
uniform float u_EmissionGain = 1.0;
uniform float u_BaseGain = 1.0;

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
}

void fragment() {
  vec4 tex = texture(u_MainTex, UV);
  tex = pow(tex, vec4(2.2));
  vec4 c = COLOR * u_TintColor * u_BaseGain * tex;
  c.rgb += c.rgb * c.a * u_EmissionGain;
  vec3 final_color = apply_fog(c.rgb, v_fog_coord);
  ALBEDO = final_color * 5.0;
  ALPHA = 1.0;
}
