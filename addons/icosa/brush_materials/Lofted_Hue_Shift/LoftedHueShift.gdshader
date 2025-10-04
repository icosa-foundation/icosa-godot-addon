shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_Opacity : hint_range(0.0, 1.0) = 1.0;

// Hue to RGB conversion from ColorSpace.cginc
vec3 hue06_to_base_rgb(float hue06) {
  float r = -1.0 + abs(hue06 - 3.0);
  float g = 2.0 - abs(hue06 - 2.0);
  float b = 2.0 - abs(hue06 - 4.0);
  return clamp(vec3(r, g, b), 0.0, 1.0);
}

void fragment() {
  // Sample texture and multiply by vertex color
  vec4 tex = texture(u_MainTex, UV) * COLOR;

  // Create hue shift based on color
  float shift = 5.0 + COLOR.r;
  vec3 hueshift = hue06_to_base_rgb(COLOR.r * shift);
  vec4 colorShift = vec4(hueshift, 1.0);

  // Create vignette effect from center
  vec2 centeredUV = abs(UV - 0.5) * 2.0;
  float huevignette = pow(length(centeredUV), 2.0);

  // Lerp between original texture and hue-shifted color
  vec4 color = mix(tex, colorShift, clamp(huevignette, 0.0, 1.0));

  color.rgb *= color.a;
  ALBEDO = color.rgb;
  ALPHA = color.a;
}
