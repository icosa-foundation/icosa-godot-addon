shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

#include "res://addons/icosa/brush_materials/_includes/fog_functions.gdshaderinc"

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
  // _TB_UNITY_NORMAL → NORMAL (particle center, VEC3)
  // _TB_UNITY_TEXCOORD_0 → TANGENT (rotation in .z, VEC4)
  // _TB_TIMESTAMP → TEXCOORD_1/UV2 (birth time)

  vec3 center_OS = NORMAL;      // Particle center
  float rotation = TANGENT.z;   // Rotation angle
  float birthTime = UV2.x;      // Birth time

  // Calculate which corner this vertex represents by examining its position relative to center
  // We can't use mod(VERTEX_ID, 4) because the index buffer draws vertices out of order
  vec3 offset_OS = VERTEX - center_OS;

  // Determine corner based on position in a 2x2 grid
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

  // Three.js passes through a_texcoord0.xy unchanged (line 123)
  // In Godot, UV = TEXCOORD_0, which should have the correct atlas coordinates
  // But we need to reconstruct UVs for the billboard quad

  // Generate corner-based UVs (0-1 range for the quad)
  vec2 corner_uv;
  if (corner == 0.0) corner_uv = vec2(0.0, 0.0);
  else if (corner == 1.0) corner_uv = vec2(1.0, 0.0);
  else if (corner == 2.0) corner_uv = vec2(0.0, 1.0);
  else corner_uv = vec2(1.0, 1.0);

  v_uv_base = corner_uv;

  float halfSize_OS = length(VERTEX - center_OS) * kRecipSquareRootOfTwo;

  // For curl noise displacement (currently disabled for debugging)
  vec3 center_final_OS = center_OS;

  // TODO: Enable curl noise displacement
  // vec3 center_WS = (MODEL_MATRIX * vec4(center_OS, 1.0)).xyz;
  // float time = TIME / 20.0 * 5.0;
  // float d = 30.0;
  // float freq = 0.1;
  // vec3 disp = vec3(1.0, 0.0, 0.0) * curlX(center_WS * freq + time, d);
  // disp += vec3(0.0, 1.0, 0.0) * curlY(center_WS * freq + time, d);
  // disp += vec3(0.0, 0.0, 1.0) * curlZ(center_WS * freq + time, d);
  // disp *= 5.0 * kDecimetersToWorldUnits;
  // center_WS += disp;
  // center_final_OS = (inverse(MODEL_MATRIX) * vec4(center_WS, 1.0)).xyz;

  // Get scale from model matrix (matching Three.js line 101)
  float scale = MODEL_MATRIX[1][1];

  // DEBUG: Show what scale value is
  // v_color = vec4(scale, scale, scale, 1.0);

  // The scale from MODEL_MATRIX is too large - maybe already applied to mesh?
  // Just use 1.0 / the scale factor that works
  scale = 0.1;

  // Filtering now done earlier by setting center_OS to zero

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
  vec3 color = tex.rgb * v_color.rgb * u_TintColor.rgb;
  float alpha = tex.a * v_color.a * u_TintColor.a;

  // Apply fog
  color = apply_fog(color, v_fog_coord);

  ALBEDO = color;
  ALPHA = alpha;
}
