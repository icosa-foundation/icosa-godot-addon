shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_Cutoff : hint_range(0.0, 1.0) = 0.5;
uniform float u_DebugSizeMultiplier : hint_range(1.0, 100.0) = 1.25; // A bit arbitrary but 1.0 seems to be too small compared to unity rendering

varying float v_fog_coord;
varying float t;
varying lowp float t2; // t modulo 1.0
const float kRecipSquareRootOfTwo = 0.70710678;
varying lowp float normalized_position_hash;

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

  float vertex_id = CUSTOM0.x;
  vec3 center_OS = CUSTOM0.yzw;

  float corner = mod(vertex_id, 4.0);
  float halfSize_OS = length(VERTEX - center_OS) * kRecipSquareRootOfTwo;

  vec3 basis_y = MODEL_MATRIX[1].xyz;
  float scale = max(length(basis_y), 0.0001);

  // normalized_position_hash is used to break up unnutural clumping of animation cycles
  // try setting this to 0.0 and see what the difference is
  normalized_position_hash = mod(CUSTOM0.y * 123.582872 + CUSTOM0.z * 10119.98128722 + CUSTOM0.w * 23.029220, 1.0);
  // the per-snowflake variance in COLOR.a is magnified before modulo, which effectively turns it into a pseudo-random hash
  t = normalized_position_hash * 7.54 + TIME * 0.3 + COLOR.a * 4292.8170029;
  t2 = mod(t, 1.0);

  // Displacement in LOCAL/object space (scales with mesh automatically)
  vec3 dispVec = (t2 - 0.5) * vec3(0.0, -0.03, 0.0);
  dispVec.x += sin(t2 * 3.0 + TIME) * 0.005;
  dispVec.z += cos(t2 * 3.0 * 0.5 + TIME) * 0.005;

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
  ///// CYCLES
  // every snowflake will be active for one period in CYCLES;
  // setting this to 1 will make all snowflakes visible all the time
  // setting it to 2 will make each snow flake actiove for 1 cycle, then off for 1 cycle, repeat.
  int cycles = 2; 
  bool active = mod(t, float(cycles)) <= 1.0; // (t + position_hash * 4.0) <= 1.0;
  if ( !active ){
     discard;
  }
	
  vec4 tex_color = texture(u_MainTex, UV);
  float brush_mask = tex_color.a * COLOR.a;

  if (brush_mask <= u_Cutoff) {
    discard;
  }

  vec3 final_color = tex_color.rgb * COLOR.rgb;
  final_color = apply_fog(final_color, v_fog_coord);

  ALBEDO = final_color;
  
  // debug visualization of animation time
  // ALBEDO = mix(mix(vec3(1,0,0), vec3(0,1,0), clamp(t2 * 2.0, 0.0, 1.0)), vec3(0,0,1), clamp(t2 * 2.0 - 1.0, 0.0, 1.0));
  
  // smoothly fade in and out
  ALPHA *= clamp(pow(sin(t * PI), 2.0), 0.0, 1.0);
}
