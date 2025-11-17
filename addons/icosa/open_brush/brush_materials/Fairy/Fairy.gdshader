shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

uniform float u_EmissionGain : hint_range(0.0, 1.0) = 0.5;
uniform float u_Dissolve : hint_range(0.0, 1.0) = 0.0;

// Random functions for procedural generation
float random(vec2 p) {
  const vec2 r = vec2(23.14079263, 2.7651234);
  return fract(cos(mod(123432189.0, 1e-7 + 256.0 * dot(p, r))));
}

vec2 random2(vec2 p) {
  return vec2(random(p), random(p + vec2(1.0)));
}

// Simple bloom color approximation
vec3 bloomColor(vec3 color, float intensity) {
  return color * (1.0 + intensity);
}

void fragment() {
  float scale1 = 3.0;
  float scale2 = 3.0;

  vec2 st = UV;
  vec2 uv = st;

  // Fix aspect ratio
  st.x *= 5.0;

  // Divide the space into tiles
  vec2 scaler = floor(st);
  scaler = vec2(random(scaler));
  scaler *= scale1;
  scaler = max(scaler, vec2(1.0));
  scaler = floor(scaler);
  st *= scaler;

  // And again
  scaler = floor(st);
  scaler = vec2(random(scaler + vec2(234.4)));
  scaler *= scale2;
  scaler = max(scaler, vec2(1.0));
  scaler = floor(scaler);
  st *= scaler;

  // Row,col (only used as random seed)
  vec2 rc = floor(st);

  // Get the tile UV
  st = fract(st);
  st -= vec2(0.5);
  st *= 2.0;

  // Scale it a bit
  float rscale = mix(0.2, 1.0, random(rc));
  st /= rscale;

  // Move it a little bit
  vec2 offset = random2(rc + vec2(5.0)) * 0.1;
  st += offset;

  float r = length(st);
  float lum = 1.0 - r;

  // Make sure the dot fully fades by the time we get to the edge
  // of the square, otherwise it will get chopped off
  lum -= max(offset.x, offset.y);
  lum = clamp(lum, 0.0, 1.0);

  // Vary the radial brightness falloff
  float powpow = random(rc);
  powpow = powpow * 2.0 - 1.0;
  powpow = max(0.3, powpow);
  if (powpow < 0.0) {
    powpow = 1.0 / abs(powpow);
  }
  lum *= 2.0;
  lum = pow(lum, powpow);

  // Fade the dots in and out with variety
  // Unity's _Time.z = time*2, so we need TIME*2.0 in Godot
  float time_z = TIME * 2.0;
  float fadespeed = mix(0.25, 1.25, random(rc));
  float fadephase = random(rc) * 2.0 * 3.14159;
  float time = sin(time_z * fadespeed + fadephase) / 2.0 + 0.5;
  lum *= mix(0.0, 1.0, time);

  vec3 final_color = lum * bloomColor(COLOR.rgb, lum * u_EmissionGain);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
