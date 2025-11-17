shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;

void fragment() {
  // Alpha-only texture (use .w channel)
  float brush_mask = texture(u_MainTex, UV).a;

  ALBEDO = brush_mask * COLOR.rgb;
  ALPHA = 1.0;
}
