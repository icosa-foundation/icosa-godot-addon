shader_type spatial;
render_mode unshaded, depth_draw_always, cull_disabled, alpha_to_coverage_and_one;//, depth_prepass_alpha;//_and_one;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
//uniform float u_Cutoff : hint_range(0.0, 1.0) = 0.5;
//uniform float aa_amount : hint_range(0.0, 4.0) = 1.0;

// Hue to RGB conversion from ColorSpace.cginc
vec3 hue06_to_base_rgb(float hue06) {
  float r = -1.0 + abs(hue06 - 3.0);
  float g = 2.0 - abs(hue06 - 2.0);
  float b = 2.0 - abs(hue06 - 4.0);
  return clamp(vec3(r, g, b), 0.0, 1.0);
}


void fragment() {
  vec4 c = texture(u_MainTex, UV) * COLOR;
  ALPHA_SCISSOR_THRESHOLD = 0.001; //u_Cutoff - 0.9;
  ALPHA_ANTIALIASING_EDGE = 0.5; //u_Cutoff + 0.2;

  // Create hue shift effect
  float shift = 5.0 + COLOR.r + COLOR.g + COLOR.b + COLOR.a;
  float hueInput = 4.5 + COLOR.r * 0.5;
  vec3 hueShiftColor = hue06_to_base_rgb(hueInput);

  // Create vignette effect for hue blending (uses x component for strip ends)
  float vignette = pow(abs(UV.x - 0.5) * 2.0, 2.0);

  // Blend original color with hue-shifted color based on vignette
  vec3 finalColor = mix(c.rgb, hueShiftColor, clamp(vignette, 0.0, 1.0));

  ALBEDO = finalColor;
  ALPHA = c.a;
}
