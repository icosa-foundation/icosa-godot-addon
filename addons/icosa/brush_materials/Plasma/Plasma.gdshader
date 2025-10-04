shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;

void fragment() {
  // Tuning constants for 3 lines
  vec3 A = vec3(0.55, 0.3, 0.7);
  vec3 aRate = vec3(1.2, 1.0, 1.33);
  vec3 M = vec3(1.0, 2.2, 1.5);
  vec3 bRate = vec3(1.5, 3.0, 2.25) + M * aRate;
  vec3 LINE_POS = vec3(0.5, 0.5, 0.5);
  vec3 LINE_WIDTH = vec3(0.012, 0.012, 0.012);

  // Calculate UVs for each line
  // Unity's _Time.y = time, so just use TIME
  vec3 us = A * UV.x - aRate * TIME;

  vec3 tmp = M * A * UV.x - bRate * TIME;
  tmp = abs(fract(tmp) - 0.5);
  vec3 vs = vec3(UV.y) + 0.4 * COLOR.a * vec3(1.0, -1.0, 1.0) * tmp;
  vs = clamp(mix((vs - 0.5) * 4.0, vs, sin((3.14159 / 2.0) * COLOR.a)), 0.0, 1.0);

  vec4 tex = texture(u_MainTex, vec2(abs(us.x), vs.x));
  tex += texture(u_MainTex, vec2(us.y, vs.y));
  tex += texture(u_MainTex, vec2(us.z, vs.z));

  // Render 3 procedural lines
  vec3 procline = vec3(1.0) - clamp(pow((vs - LINE_POS) / LINE_WIDTH, vec3(2.0, 2.0, 2.0)), 0.0, 1.0);
  tex += dot(procline, vec3(1.0)) * 0.5;

  // Adjust brightness; modulate by color
  tex.rgb *= 0.8 * (1.0 + 30.0 * pow((vec3(1.0, 1.0, 0.1) - vec3(COLOR.a)), vec3(5.0)));
  tex *= COLOR;

  ALBEDO = tex.rgb * tex.a;
  ALPHA = 1.0;
}
