shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

#include "res://addons/icosa/brush_materials/_includes/fog_functions.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_Cutoff : hint_range(0.0, 1.0) = 0.5;
uniform float u_DebugSizeMultiplier : hint_range(1.0, 100.0) = 10.0;

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

  // Calculate scroll animation params
  float scrollAmount = TIME;
  float t = mod(scrollAmount * 0.3 + COLOR.a, 1.0);

  // Displacement in LOCAL/object space (scales with mesh automatically)
  vec3 dispVec = (t - 0.5) * vec3(0.0, -0.03, 0.0);
  dispVec.x += sin(t * 3.0 + TIME) * 0.005;
  dispVec.z += cos(t * 3.0 * 0.5 + TIME) * 0.005;

  // Apply displacement to center in object space BEFORE any transforms
  vec3 animated_center_OS = center_OS + dispVec;

  mat4 modelview_mat = VIEW_MATRIX * MODEL_MATRIX;
  mat4 inv_modelview_mat = inverse(modelview_mat);

  // Transform animated center to view space
  vec3 center_view = (modelview_mat * vec4(animated_center_OS, 1.0)).xyz;
  vec3 vertex_view = recreate_corner(center_view, corner, rotation, halfSize_OS * scale * u_DebugSizeMultiplier);

  VERTEX = (inv_modelview_mat * vec4(vertex_view, 1.0)).xyz;
  v_fog_coord = vertex_view.z;
}

void fragment() {
  vec4 tex_color = texture(u_MainTex, UV);
  float brush_mask = tex_color.a * COLOR.a;

  if (brush_mask <= u_Cutoff) {
    discard;
  }

  vec3 final_color = tex_color.rgb * COLOR.rgb;
  final_color = apply_fog(final_color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
