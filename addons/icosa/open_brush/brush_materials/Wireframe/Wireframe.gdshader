shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

void fragment() {
  // Wrap UVs into [0,1] to match Unity behavior
  vec2 uv = fract(UV);

  // Edge mask in UV space: two lines across center forming a grid
  float w = 0.0;
  w = (abs(uv.x - 0.5) > 0.45) ? 1.0 : 0.0;
  w += (abs(uv.y - 0.5) > 0.45) ? 1.0 : 0.0;

  vec4 final_color = COLOR * w;

  ALBEDO = final_color.rgb;
  ALPHA = final_color.a;
}
