shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_Speed : hint_range(0.0, 1.0) = 1.0;

void fragment() {
  // Simple scrolling
  // Unity's GetTime().y = _Time.y = time
  float time = TIME * u_Speed;
  vec2 scrollUV = UV;
  scrollUV.x += time * 0.5;

  vec4 tex = texture(u_MainTex, scrollUV);
  vec4 color = tex * COLOR;

  // Premultiply alpha
  color.rgb *= color.a;

  ALBEDO = color.rgb;
  ALPHA = color.a;
}
