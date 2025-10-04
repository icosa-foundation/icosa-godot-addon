shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform vec4 u_TintColor : source_color = vec4(1.0);

void fragment() {
  // Alpha-only texture (use .w channel)
  vec4 final_color = COLOR * u_TintColor * texture(u_MainTex, UV).a;

  ALBEDO = final_color.rgb;
  ALPHA = final_color.a;
}
