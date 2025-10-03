shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

// Fire2 shader - Animated fire particles with scrolling UVs and displacement
// Based on Fire2-53d753ef-083c-45e1-98e7-4459b4471219

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform sampler2D u_DisplaceTex : source_color, filter_linear_mipmap;
uniform float u_EmissionGain : hint_range(0.0, 2.0) = 0.405;
uniform float u_Scroll1 : hint_range(0.0, 30.0) = 15.0;
uniform float u_Scroll2 : hint_range(0.0, 30.0) = 0.0;
uniform float u_DisplacementIntensity : hint_range(0.0, 1.0) = 0.04;

vec4 bloom_color(vec4 color, float gain) {
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
  // Bloom the vertex color with emission gain
  vec4 bloomed_color = bloom_color(COLOR, u_EmissionGain);

  // Unity's _Time.x = time/20, so we need TIME/20.0 in Godot
  float time_x = TIME / 20.0;

  // Animated scrolling displacement
  float displacement = texture(u_DisplaceTex, UV + vec2(-time_x * u_Scroll1, 0.0)).a;

  // Sample main texture with scrolling and displacement
  vec4 tex = texture(u_MainTex, UV + vec2(-time_x * u_Scroll2, 0.0) - displacement * u_DisplacementIntensity);

  vec4 final_color = bloomed_color * tex;

  ALBEDO = final_color.rgb * final_color.a * 5.0;
  ALPHA = tex.a;
}
