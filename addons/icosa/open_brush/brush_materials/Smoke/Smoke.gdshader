shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform vec4 u_TintColor : source_color = vec4(0.5, 0.5, 0.5, 0.5);
uniform float u_ScrollRate = 1.0;

varying vec4 v_color;
varying float v_fog_coord;
varying vec2 v_uv;
varying vec2 v_uv_base;

const float kRecipSquareRootOfTwo = 0.70710678;
const float kDecimetersToWorldUnits = 10.0;

// Simplex noise functions for curl noise
vec3 mod289_3(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289_4(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289_4(((x * 34.0) + 1.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float snoise(vec3 v) {
  const vec2 C = vec2(1.0/6.0, 1.0/3.0);
  const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

  vec3 i = floor(v + dot(v, C.yyy));
  vec3 x0 = v - i + dot(i, C.xxx);

  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min(g.xyz, l.zxy);
  vec3 i2 = max(g.xyz, l.zxy);

  vec3 x1 = x0 - i1 + C.xxx;
  vec3 x2 = x0 - i2 + C.yyy;
  vec3 x3 = x0 - D.yyy;

  i = mod289_3(i);
  vec4 p = permute(permute(permute(
    i.z + vec4(0.0, i1.z, i2.z, 1.0))
    + i.y + vec4(0.0, i1.y, i2.y, 1.0))
    + i.x + vec4(0.0, i1.x, i2.x, 1.0));

  float n_ = 0.142857142857;
  vec3 ns = n_ * D.wyz - D.xzx;

  vec4 j = p - 49.0 * floor(p * ns.z * ns.z);

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_);

  vec4 x = x_ * ns.x + ns.yyyy;
  vec4 y = y_ * ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4(x.xy, y.xy);
  vec4 b1 = vec4(x.zw, y.zw);

  vec4 s0 = floor(b0) * 2.0 + 1.0;
  vec4 s1 = floor(b1) * 2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
  vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

  vec3 p0 = vec3(a0.xy, h.x);
  vec3 p1 = vec3(a0.zw, h.y);
  vec3 p2 = vec3(a1.xy, h.z);
  vec3 p3 = vec3(a1.zw, h.w);

  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;

  vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
  m = m * m;
  return 42.0 * dot(m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}

// Curl noise components
float curlX(vec3 p, float d) {
  float eps = 0.0001;
  float n1 = snoise(p + vec3(0.0, eps, 0.0));
  float n2 = snoise(p - vec3(0.0, eps, 0.0));
  return (n1 - n2) / (2.0 * eps) / d;
}

float curlY(vec3 p, float d) {
  float eps = 0.0001;
  float n1 = snoise(p + vec3(eps, 0.0, 0.0));
  float n2 = snoise(p - vec3(eps, 0.0, 0.0));
  return (n1 - n2) / (2.0 * eps) / d;
}

float curlZ(vec3 p, float d) {
  float eps = 0.0001;
  float n1 = snoise(p + vec3(0.0, 0.0, eps));
  float n2 = snoise(p - vec3(0.0, 0.0, eps));
  return (n1 - n2) / (2.0 * eps) / d;
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
  float birthTime = UV2.x;      // Birth time

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

  // Apply subtle curl-noise displacement in world space, then convert back to object space
  {
    vec3 center_WS = (MODEL_MATRIX * vec4(center_OS, 1.0)).xyz;
    float noise_time = TIME * 0.05 + birthTime * 0.5;
    vec3 noise_coord = center_WS * 0.08 + vec3(noise_time);
    float curl_divisor = 30.0;
    vec3 curl_sample = vec3(
      curlX(noise_coord, curl_divisor),
      curlY(noise_coord, curl_divisor),
      curlZ(noise_coord, curl_divisor)
    );
    float curl_strength = max(raw_scale * 0.02, 0.02);
    vec3 disp = curl_sample * curl_strength;
    center_WS += disp;
    center_final_OS = (inv_model_mat * vec4(center_WS, 1.0)).xyz;
  }

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
