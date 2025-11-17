shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

// SoftHighlighter shader - Soft additive edges
// Based on SoftHighlighter-accb32f5-4509-454f-93f8-1df3fd31df1b

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_Opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
  float brush_mask = texture(u_MainTex, UV).a;
  vec3 final_color = brush_mask * COLOR.rgb;

  ALBEDO = final_color * u_Opacity;
  ALPHA = 1.0;
}
