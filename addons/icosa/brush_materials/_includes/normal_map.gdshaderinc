// normal_map.gdshaderinc
// Tangent-less normal mapping (Morten Mikkelsen's method)

uniform sampler2D u_BumpMap : hint_normal;
uniform vec4 u_BumpMap_TexelSize = vec4(1.0, 1.0, 512.0, 512.0);

// Derivative workarounds for compatibility
vec3 dFdx3(vec3 v) {
  return vec3(dFdx(v.x), dFdx(v.y), dFdx(v.z));
}

vec3 dFdy3(vec3 v) {
  return vec3(dFdy(v.x), dFdy(v.y), dFdy(v.z));
}

vec2 dFdx2(vec2 v) {
  return vec2(dFdx(v.x), dFdx(v.y));
}

vec2 dFdy2(vec2 v) {
  return vec2(dFdy(v.x), dFdy(v.y));
}

vec3 perturb_normal(vec3 position, vec3 normal, vec2 uv, float disp_amount) {
  // Mikkelsen tangent-less normal mapping
  vec3 vSigmaS = dFdx3(position);
  vec3 vSigmaT = dFdy3(position);
  vec3 vN = normal;
  vec3 vR1 = cross(vSigmaT, vN);
  vec3 vR2 = cross(vN, vSigmaS);
  float fDet = dot(vSigmaS, vR1);

  vec2 texDx = dFdx2(uv);
  vec2 texDy = dFdy2(uv);

  float resolution = max(u_BumpMap_TexelSize.z, u_BumpMap_TexelSize.w);
  float d = min(1.0, (0.5 / resolution) / max(length(texDx), length(texDy)));

  vec2 STll = uv;
  vec2 STlr = uv + d * texDx;
  vec2 STul = uv + d * texDy;

  float Hll = texture(u_BumpMap, STll).x;
  float Hlr = texture(u_BumpMap, STlr).x;
  float Hul = texture(u_BumpMap, STul).x;

  // Front-facing flip for double-sided materials
  Hll = mix(Hll, 1.0 - Hll, float(!FRONT_FACING)) * disp_amount;
  Hlr = mix(Hlr, 1.0 - Hlr, float(!FRONT_FACING)) * disp_amount;
  Hul = mix(Hul, 1.0 - Hul, float(!FRONT_FACING)) * disp_amount;

  float dBs = (Hlr - Hll) / d;
  float dBt = (Hul - Hll) / d;

  vec3 vSurfGrad = sign(fDet) * (dBs * vR1 + dBt * vR2);
  return normalize(abs(fDet) * vN - vSurfGrad);
}
