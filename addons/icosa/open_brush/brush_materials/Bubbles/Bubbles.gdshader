shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_ScrollRate = 0.5;
uniform float u_ScrollJitterIntensity = 0.02;
uniform float u_ScrollJitterFrequency = 0.2;
uniform float u_BubblesDisplacementParticleScale = 1.0;

varying float v_fog_coord;

const float kRecipSquareRootOfTwo = 0.70710678;
const float kDecimetersToWorldUnits = 10.0;

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

vec3 mod289_v3(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec2 mod289_v2(vec2 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 permute_v3(vec3 x) {
  return mod289_v3(((x * 34.0) + 1.0) * x);
}

float snoise2D(vec2 v) {
  const vec4 C = vec4(0.211324865405187,
                      0.366025403784439,
                     -0.577350269189626,
                      0.024390243902439);

  vec2 i = floor(v + dot(v, C.yy));
  vec2 x0 = v - i + dot(i, C.xx);

  vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;

  i = mod289_v2(i);
  vec3 p = permute_v3(permute_v3(i.y + vec3(0.0, i1.y, 1.0))
                                + i.x + vec3(0.0, i1.x, 1.0));

  vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
  m = m * m;
  m = m * m;

  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;

  m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);

  vec3 g;
  g.x = a0.x * x0.x + h.x * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

vec3 snoise3D(vec3 v) {
  return vec3(
    snoise2D(vec2(v.x, v.y)),
    snoise2D(vec2(v.y, v.z)),
    snoise2D(vec2(v.z, v.x))
  );
}

float curlX(vec3 v, float d) {
  return (
    (snoise3D(vec3(v.x, v.y + d, v.z)).z - snoise3D(vec3(v.x, v.y - d, v.z)).z)
   -(snoise3D(vec3(v.x, v.y, v.z + d)).y - snoise3D(vec3(v.x, v.y, v.z - d)).y)
  ) / 2.0 / d;
}

float curlY(vec3 v, float d) {
  return (
    (snoise3D(vec3(v.x, v.y, v.z + d)).x - snoise3D(vec3(v.x, v.y, v.z - d)).x)
   -(snoise3D(vec3(v.x + d, v.y, v.z)).z - snoise3D(vec3(v.x - d, v.y, v.z)).z)
  ) / 2.0 / d;
}

float curlZ(vec3 v, float d) {
  return (
    (snoise3D(vec3(v.x + d, v.y, v.z)).y - snoise3D(vec3(v.x - d, v.y, v.z)).y)
   -(snoise3D(vec3(v.x, v.y + d, v.z)).x - snoise3D(vec3(v.x, v.y - d, v.z)).x)
  ) / 2.0 / d;
}

vec3 compute_bubbles_displacement_ws(vec3 seed_decimeters, float time_offset) {
  float t = TIME * u_ScrollRate + time_offset;
  vec3 jitter = vec3(
    sin(t + TIME + seed_decimeters.z * u_ScrollJitterFrequency),
    cos(t * 1.2 + TIME + seed_decimeters.x * u_ScrollJitterFrequency),
    cos(t + TIME + seed_decimeters.x * u_ScrollJitterFrequency)
  ) * u_ScrollJitterIntensity;

  // WebGL uses Unity _Time.x * 5.0. Godot TIME is equivalent to _Time.y,
  // so TIME * 0.25 matches elapsedTime / 20 * 5.
  vec3 noise_coord = (seed_decimeters + jitter) * 0.1 + vec3(TIME * 0.25);
  float curl_divisor = 30.0;
  vec3 curl_sample = vec3(
    curlX(noise_coord, curl_divisor),
    curlY(noise_coord, curl_divisor),
    curlZ(noise_coord, curl_divisor)
  ) * 10.0;

  return (jitter + curl_sample) * 0.1;
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
  vec3 center_final_OS = center_OS;

  vec3 center_WS = (MODEL_MATRIX * vec4(center_OS, 1.0)).xyz;
  vec3 seed_decimeters = center_WS * kDecimetersToWorldUnits;
  // Match WebGL's world-space displacement, then normalize by particle size
  // so legacy and UnityGLTF coordinate scales animate with comparable visual weight.
  float halfSize_WS = max(halfSize_OS * scale, 0.0001);
  center_WS += compute_bubbles_displacement_ws(seed_decimeters, 1.0) * halfSize_WS * u_BubblesDisplacementParticleScale;
  center_final_OS = (inverse(MODEL_MATRIX) * vec4(center_WS, 1.0)).xyz;

  mat4 modelview_mat = VIEW_MATRIX * MODEL_MATRIX;
  mat4 inv_modelview_mat = inverse(modelview_mat);

  vec3 center_view = (modelview_mat * vec4(center_final_OS, 1.0)).xyz;
  vec3 vertex_view = recreate_corner(center_view, corner, rotation, halfSize_OS * scale);

  VERTEX = (inv_modelview_mat * vec4(vertex_view, 1.0)).xyz;
  v_fog_coord = vertex_view.z;
}

void fragment() {
  vec4 tex_color = texture(u_MainTex, UV);
  vec3 basecolor = COLOR.rgb * tex_color.rgb;
  vec3 highlight = vec3(tex_color.a);
  vec3 final_color = basecolor + highlight;
  final_color = apply_fog(final_color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
