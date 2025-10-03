shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_EmissionGain : hint_range(0.0, 1.0) = 0.5;

vec4 bloomColor(vec4 color, float gain) {
  // Guarantee that there's at least a little bit of all 3 channels.
  // This makes fully-saturated strokes (which only have 2 non-zero
  // color channels) eventually clip to white rather than to a secondary.
  float cmin = length(color.rgb) * 0.05;
  color.rgb = max(color.rgb, vec3(cmin, cmin, cmin));
  // If we try to remove this pow() from .a, it brightens up
  // pressure-sensitive strokes; looks better as-is.
  color.r = pow(color.r, 2.2);
  color.g = pow(color.g, 2.2);
  color.b = pow(color.b, 2.2);
  color.a = pow(color.a, 2.2);
  color.rgb *= 2.0 * exp(gain * 10.0);
  return color;
}

void fragment() {
  float _Scroll1 = 20.0;
  float _Scroll2 = 0.0;
  float _DisplacementIntensity = 0.1;
  // Unity's _Time.x = time/20, so we need TIME/20.0 in Godot
  float time_x = TIME / 20.0;

  vec4 bloomed_color = bloomColor(COLOR, u_EmissionGain);

  float displacement = texture(u_MainTex, UV + vec2(-time_x * _Scroll1, 0.0)).a;
  vec4 tex = texture(u_MainTex, UV + vec2(-time_x * _Scroll2, 0.0) - displacement * _DisplacementIntensity);

  vec4 final_color = bloomed_color * tex;

  ALBEDO = final_color.rgb;
  ALPHA = final_color.a;
}
