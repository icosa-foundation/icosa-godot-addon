shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform vec4 u_TintColor : source_color = vec4(0.5, 0.5, 0.5, 0.5);
uniform float u_ScrollRate = 0.0;
uniform float u_ScrollJitterIntensity = 0.0;
uniform float u_ScrollJitterFrequency = 0.0;
uniform float u_SmokeDisplacementParticleScale = 1.0;

varying vec4 v_color;
varying float v_fog_coord;
varying vec2 v_uv;
varying vec2 v_uv_base;

const float kRecipSquareRootOfTwo = 0.70710678;
const float kDecimetersToWorldUnits = 10.0;

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

vec3 compute_smoke_displacement_ws(vec3 seed_decimeters, float time_offset) {
  float t = TIME * u_ScrollRate + time_offset;
  vec3 jitter = vec3(
    sin(t + TIME + seed_decimeters.z * u_ScrollJitterFrequency),
    cos(t * 1.2 + TIME + seed_decimeters.x * u_ScrollJitterFrequency),
    cos(t + TIME + seed_decimeters.x * u_ScrollJitterFrequency)
  ) * u_ScrollJitterIntensity;

  // WebGL uses Unity _Time.x * 2.0. Godot TIME is equivalent to _Time.y,
  // so TIME * 0.1 matches elapsedTime / 20 * 2.
  vec3 noise_coord = (seed_decimeters + jitter) * 0.05 + vec3(TIME * 0.1);
  float curl_divisor = 30.0;
  vec3 curl_sample = vec3(
    curlX(noise_coord, curl_divisor),
    curlY(noise_coord, curl_divisor),
    curlZ(noise_coord, curl_divisor)
  ) * 15.0;

  // The web shader samples in decimeters and scales the displacement back to world units.
  return (jitter + curl_sample) * 0.1;
}

// Billboard particle recreation (matching Three.js recreateCorner)
// Takes center in OBJECT SPACE, transforms internally to view space, returns OBJECT SPACE
vec3 recreate_corner(vec3 center_os, float corner, float rotation, float size, mat4 modelview_mat, mat4 inv_modelview_mat) {
  float c = cos(rotation);
  float s = sin(rotation);

  // Basis in view/camera space
  vec3 up = vec3(s, c, 0.0);
  vec3 right = vec3(c, -s, 0.0);

  // Corner positions (matching Three.js exactly)
  float f_up = float(corner == 0.0 || corner == 1.0) * 2.0 - 1.0;     // 0,1 → -1 (bottom)
  float f_right = float(corner == 0.0 || corner == 2.0) * 2.0 - 1.0; // 0,2 → -1 (left)

  // Transform center to view space (matching Three.js line 83)
  vec3 center_vs = (modelview_mat * vec4(center_os, 1.0)).xyz;

  // Apply billboard offset in view space (matching Three.js lines 84-85)
  center_vs += f_right * right * size;
  center_vs += f_up * up * size;

  // Transform back to object space (matching Three.js line 86)
  return (inv_modelview_mat * vec4(center_vs, 1.0)).xyz;
}

void vertex() {
  // Extract particle data from vertex attributes
  // GLTF attribute mapping for Smoke brush (remapped to standard attributes):
  // _TB_UNITY_NORMAL → packed into CUSTOM0.yzw (particle center, VEC3)
  // _TB_UNITY_TEXCOORD_0 → TANGENT (rotation in .z, VEC4)
  // _TB_TIMESTAMP → TEXCOORD_1/UV2 (birth time)
  // CUSTOM0.x → vertex ID (added by importer)
  // CUSTOM0.yzw → particle center (object space)

  float rotation = TANGENT.z;   // Rotation angle
  vec4 custom0 = CUSTOM0;
  float vertex_id = custom0.x;
  vec3 center_OS = custom0.yzw; // Particle center

  // Get corner ID from vertex ID (matching GLSL gl_VertexID % 4)
  float corner = mod(vertex_id, 4.0);

  // Three.js passes through a_texcoord0.xy unchanged (line 123)
  // In Godot, UV = TEXCOORD_0 and already contains the atlas offset for each particle
  v_uv_base = UV;

  float halfSize_OS = length(VERTEX - center_OS) * kRecipSquareRootOfTwo;

  // Precompute basis vectors for scaling and curl strength
  vec3 basis_x = MODEL_MATRIX[0].xyz;
  vec3 basis_y = MODEL_MATRIX[1].xyz;
  vec3 basis_z = MODEL_MATRIX[2].xyz;
  float raw_scale = (length(basis_x) + length(basis_y) + length(basis_z)) / 3.0;
  float scale = max(raw_scale, 0.0001);

  vec3 center_final_OS = center_OS;
  mat4 inv_model_mat = inverse(MODEL_MATRIX);

  // Apply curl-noise displacement in world space, then convert back to object space.
  vec3 center_WS = (MODEL_MATRIX * vec4(center_OS, 1.0)).xyz;
  vec3 seed_decimeters = center_WS * kDecimetersToWorldUnits;
  // Legacy and UnityGLTF files can arrive at very different coordinate scales.
  // Scale world-space curl by the rendered particle size so Smoke motion stays
  // visually comparable without branching on exporter type.
  float halfSize_WS = max(halfSize_OS * scale, 0.0001);
  center_WS += compute_smoke_displacement_ws(seed_decimeters, 1.0) * halfSize_WS * u_SmokeDisplacementParticleScale;
  center_final_OS = (inv_model_mat * vec4(center_WS, 1.0)).xyz;

  // Calculate modelview matrix (Godot doesn't provide MODELVIEW_MATRIX)
  mat4 modelview_mat = VIEW_MATRIX * MODEL_MATRIX;
  mat4 inv_modelview_mat = inverse(modelview_mat);

  // Create camera-facing billboard (matching Three.js PositionParticle)
  // Three.js: newCorner = recreateCorner(center, corner, rotation, size * scale)
  // recreateCorner does the view space transform internally

  // Apply billboarding
  VERTEX = recreate_corner(center_final_OS, corner, rotation, halfSize_OS * scale, modelview_mat, inv_modelview_mat);

  // Calculate fog coordinate for fragment shader
  vec3 vertex_VS = (modelview_mat * vec4(VERTEX, 1.0)).xyz;

  // Pass color through
  v_color = COLOR;
  v_fog_coord = vertex_VS.z;
}

void fragment() {
  vec4 tex = texture(u_MainTex, v_uv_base);
  tex = pow(tex, vec4(2.2));
  vec3 color = tex.rgb * v_color.rgb * u_TintColor.rgb;
  float alpha = tex.a * v_color.a * u_TintColor.a;

  // Apply fog
  color = apply_fog(color, v_fog_coord);

  ALBEDO = color * 5.0;
  ALPHA = alpha;
}
