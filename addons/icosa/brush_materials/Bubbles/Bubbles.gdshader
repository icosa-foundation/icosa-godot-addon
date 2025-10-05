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
  // Extract particle data from vertex attributes
  vec3 center = NORMAL;  // Particle center stored in normal
  // Rotation stored in CUSTOM0.z (from _TEXCOORD_0.z)
  float rotation = CUSTOM0.z;

  // Calculate billboard size and corner
  float corner = mod(float(VERTEX_ID), 4.0);
  float size = length(VERTEX - center) * kRecipSquareRootOfTwo;

  // Get scale from model matrix
  float scale = MODEL_MATRIX[1][1];

  // Create camera-facing billboard in view space
  vec3 center_view = (MODELVIEW_MATRIX * vec4(center, 1.0)).xyz;
  vec3 vertex_view = recreate_corner(center_view, corner, rotation, size * scale);
  vec3 vertex_world = (inverse(MODELVIEW_MATRIX) * vec4(vertex_view, 1.0)).xyz;

  VERTEX = (inverse(MODEL_MATRIX) * vec4(vertex_world, 1.0)).xyz;
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
