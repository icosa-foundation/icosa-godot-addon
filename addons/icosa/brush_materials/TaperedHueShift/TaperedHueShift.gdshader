shader_type spatial;
render_mode unshaded, depth_draw_always, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_Cutoff : hint_range(0.0, 1.0) = 0.5;

// Hue to RGB conversion from ColorSpace.cginc
vec3 hue06_to_base_rgb(float hue06) {
  float r = -1.0 + abs(hue06 - 3.0);
  float g = 2.0 - abs(hue06 - 2.0);
  float b = 2.0 - abs(hue06 - 4.0);
  return clamp(vec3(r, g, b), 0.0, 1.0);
}

void fragment() {
  vec4 c = texture(u_MainTex, UV) * COLOR;

  // Discard transparent pixels
  if (c.a < u_Cutoff) {
    discard;
  }

  // Create hue shift effect
  float shift = 5.0 + COLOR.r + COLOR.g + COLOR.b + COLOR.a;
  float hueInput = 4.5 + COLOR.r * 0.5;
  vec3 hueShiftColor = hue06_to_base_rgb(hueInput);

  // Create vignette effect for hue blending (uses x component for strip ends)
  float vignette = pow(abs(UV.x - 0.5) * 2.0, 2.0);

  // Blend original color with hue-shifted color based on vignette
  vec3 finalColor = mix(c.rgb, hueShiftColor, clamp(vignette, 0.0, 1.0));

  ALBEDO = finalColor;
  ALPHA = 1.0;
}
