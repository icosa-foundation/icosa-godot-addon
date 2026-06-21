shader_type spatial;
render_mode unshaded, blend_sub, cull_disabled;

void fragment() {
  ALBEDO = vec3(0.0);
  ALPHA = 0.0;
}
