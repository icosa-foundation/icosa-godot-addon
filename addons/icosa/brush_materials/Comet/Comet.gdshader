shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform sampler2D u_AlphaMask : source_color, filter_linear_mipmap;
uniform float u_Speed : hint_range(0.0, 5.0) = 1.0;
uniform float u_EmissionGain : hint_range(0.0, 1.0) = 0.5;

void fragment() {
  // Unity's _Time.y = time, so just use TIME
  float time = TIME * -u_Speed;

  // Set up staggered scrolling for fire effect
  vec2 scroll_uv = UV;
  vec2 scroll_uv2 = UV;
  vec2 scroll_uv3 = UV;
  scroll_uv.y += time;
  scroll_uv.x += time;
  scroll_uv2.x += time * 1.5;
  scroll_uv3.x += time * 0.5;

  // Each channel has its own tileable pattern scrolling at different rates
  float r = texture(u_MainTex, scroll_uv).r;
  float g = texture(u_MainTex, scroll_uv2).g;
  float b = texture(u_MainTex, scroll_uv3).b;

  // Combine all channels
  float gradient_lookup = (r + g + b) / 3.0;
  // Rescale lookup value along stroke
  gradient_lookup *= (1.0 - UV.x);
  gradient_lookup = (pow(gradient_lookup, 2.0) + 0.125) * 3.0;

  // Falloff at start of stroke
  float falloff = max((0.2 - UV.x) * 5.0, 0.0);

  // Sample gradient texture (red channel only)
  float u = clamp(gradient_lookup + falloff, 0.0, 1.0);
  float tex = texture(u_AlphaMask, vec2(u, 0.0)).r;

  vec3 final_color = (tex * COLOR.rgb);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
