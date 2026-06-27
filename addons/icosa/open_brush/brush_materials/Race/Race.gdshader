shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform float u_EmissionGain : hint_range(0.0, 1.0) = 0.5;
uniform float u_Opacity : hint_range(0.0, 1.0) = 1.0;

const float BRUSHES_DIGITAL_ROWS = 5.0;

varying vec2 v_uv;
varying vec4 v_color;

float random(vec2 p) {
  const vec2 r = vec2(23.14079263, 2.7651234);
  return fract(cos(mod(123432189.0, 1e-7 + 256.0 * dot(p, r))));
}

vec3 bloom_color(vec3 color, float gain) {
  float cmin = length(color) * 0.05;
  color = max(color, vec3(cmin));
  color = pow(color, vec3(2.2));
  return color * 2.0 * exp(gain * 10.0);
}

void vertex() {
  v_uv = UV;
  v_color = COLOR;
}

float race_luminance(vec2 st) {
  vec2 st_per_px = fwidth(st);
  vec2 rc = floor(st);
  vec2 tile_st = fract(st);
  tile_st = (tile_st - vec2(0.5)) * 2.0;

  float lum = 0.0;
  float stroke_width = 0.1;
  float antialias_feather_px = 4.0;

  for (int ii = -1; ii <= 1; ii++) {
    if (rc.x + float(ii) < 0.0) {
      continue;
    }
    for (int jj = -1; jj <= 1; jj++) {
      if (abs(ii) == abs(jj)) {
        continue;
      }
      if (rc.y + float(jj) < 0.0 || rc.y + float(jj) >= BRUSHES_DIGITAL_ROWS) {
        continue;
      }

      float threshold = ii == 0 ? 1.5 : 0.5;
      if (random(rc) + random(rc + vec2(float(ii), float(jj))) < threshold) {
        continue;
      }

      vec2 ij = vec2(float(ii), float(jj));
      vec2 ij_perp = vec2(-float(jj), float(ii));
      vec2 bound1 = stroke_width * -ij_perp + stroke_width * -ij;
      vec2 bound2 = ij + stroke_width * ij_perp;
      vec2 min_bound = min(bound1, bound2);
      vec2 max_bound = max(bound1, bound2);
      vec2 aa = st_per_px * antialias_feather_px;

      vec2 lower = smoothstep(min_bound - aa, min_bound, tile_st);
      vec2 upper = vec2(1.0) - smoothstep(max_bound, max_bound + aa, tile_st);
      lum = max(lum, lower.x * upper.x * lower.y * upper.y);
    }
  }
  return lum;
}

void fragment() {
  vec2 st = v_uv;
  st.x *= 5.0;
  st *= BRUSHES_DIGITAL_ROWS;

  float lum = race_luminance(st);
  vec3 rgb = lum * bloom_color(v_color.rgb, lum * u_EmissionGain);

  ALBEDO = rgb;
  ALPHA = u_Opacity;
}
