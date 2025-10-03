shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_Cutoff : hint_range(0.0, 1.0) = 0.067;

void fragment() {
  vec4 tex_color = texture(u_MainTex, UV);
  float brush_mask = tex_color.a * COLOR.a;

  if (brush_mask <= u_Cutoff) {
    discard;
  }

  ALBEDO = tex_color.rgb * COLOR.rgb;
  ALPHA = brush_mask;
}
