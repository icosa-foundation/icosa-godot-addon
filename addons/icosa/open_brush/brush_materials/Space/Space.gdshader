shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

// Space shader - Additive with bloom (no texture)
// Based on Space-bdf65db2-1fb7-4202-b5e0-c6b5e3ea851e

uniform float u_EmissionGain : hint_range(0.0, 2.0) = 0.5;

varying vec4 v_color;

vec4 bloom_color(vec4 color, float gain) {
  float cmin = length(color.rgb) * 0.05;
  color.rgb = max(color.rgb, vec3(cmin));
  color.r = pow(color.r, 2.2);
  color.g = pow(color.g, 2.2);
  color.b = pow(color.b, 2.2);
  color.a = pow(color.a, 2.2);
  color.rgb *= 2.0 * exp(gain * 10.0);
  return color;
}

void vertex() {
  v_color = bloom_color(COLOR, u_EmissionGain);
}

void fragment() {
  ALBEDO = v_color.rgb;
  ALPHA = v_color.a;
}
