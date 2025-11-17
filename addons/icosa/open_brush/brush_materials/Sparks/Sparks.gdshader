shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

// Sparks shader - Additive particles with bloom
// Based on Sparks-50e99447-3861-05f4-697d-a1b96e771b98

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_EmissionGain : hint_range(0.0, 2.0) = 0.723;

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
  float brush_mask = texture(u_MainTex, UV).a;
  vec4 color = brush_mask * v_color;

  ALBEDO = color.rgb;
  ALPHA = color.a;
}
