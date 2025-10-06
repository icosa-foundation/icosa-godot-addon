shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

#include "res://addons/icosa/brush_materials/_includes/fog_functions.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_Cutoff : hint_range(0.0, 1.0) = 0.5;

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
  // _TB_UNITY_NORMAL → NORMAL (particle center, VEC3)
  // _TB_UNITY_TEXCOORD_0 → TANGENT (rotation in .z, VEC4)
  // _TB_TIMESTAMP → TEXCOORD_1/UV2 (birth time)

  vec3 center_OS = NORMAL;      // Particle center
  float rotation = TANGENT.z;   // Rotation angle
  float birthTime = UV2.x;      // Birth time

  // Calculate which corner this vertex represents
  // We can't use mod(VERTEX_ID, 4) because index buffer draws vertices out of order
  vec3 offset_OS = VERTEX - center_OS;

  float corner;
  if (offset_OS.x < 0.0 && offset_OS.y < 0.0) {
    corner = 0.0;  // bottom-left
  } else if (offset_OS.x >= 0.0 && offset_OS.y < 0.0) {
    corner = 1.0;  // bottom-right
  } else if (offset_OS.x < 0.0 && offset_OS.y >= 0.0) {
    corner = 2.0;  // top-left
  } else {
    corner = 3.0;  // top-right
  }

  float halfSize_OS = length(VERTEX - center_OS) * kRecipSquareRootOfTwo;

  // Get scale from model matrix
  float scale = MODEL_MATRIX[1][1];
  scale = 0.1; // Hardcoded scale adjustment

  // Calculate modelview matrix
  mat4 modelview_mat = VIEW_MATRIX * MODEL_MATRIX;
  mat4 inv_modelview_mat = inverse(modelview_mat);

  // Apply billboarding using recreate_corner in view space
  vec3 center_final_OS = center_OS;
  vec3 center_view = (modelview_mat * vec4(center_final_OS, 1.0)).xyz;
  vec3 vertex_view = recreate_corner(center_view, corner, rotation, halfSize_OS * scale);

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
