shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

uniform float u_Opacity : hint_range(0.0, 1.0) = 1.0;

// From ColorSpace.cginc - hue06_to_base_rgb function
vec3 hue06_to_base_rgb(float hue06) {
  float r = -1.0 + abs(hue06 - 3.0);
  float g = 2.0 - abs(hue06 - 2.0);
  float b = 2.0 - abs(hue06 - 4.0);
  return clamp(vec3(r, g, b), 0.0, 1.0);
}

// From ColorSpace.cginc - cy_to_rgb function
vec3 cy_to_rgb(vec3 base_rgb, float chroma, float luma) {
  vec3 g_max_luma = vec3(0.299, 0.587, 0.114);
  float rgb_luma = dot(base_rgb, g_max_luma);
  if (luma < rgb_luma) {
    chroma *= luma / rgb_luma;
  } else if (luma < 1.0) {
    chroma *= (1.0 - luma) / (1.0 - rgb_luma);
  }
  return (base_rgb - rgb_luma) * chroma + luma;
}

void fragment() {
  // Slice uses CUSTOM0 for color space data: (chroma, luma, hue_position)
  // GLTF importer maps _TEXCOORD_0 -> _CUSTOM0, accessible as CUSTOM0
  vec3 color_data = CUSTOM0.xyz;

  // Calculate hue: mod(z * 5, 6)
  float hue = mod(color_data.z * 5.0, 6.0);
  vec3 base_rgb = hue06_to_base_rgb(hue);

  // cy_to_rgb(base_rgb, chroma, luma)
  vec3 finalColor = cy_to_rgb(base_rgb, color_data.x, color_data.y);

  ALBEDO = clamp(finalColor, 0.0, 1.0);
  ALPHA = u_Opacity;
}
