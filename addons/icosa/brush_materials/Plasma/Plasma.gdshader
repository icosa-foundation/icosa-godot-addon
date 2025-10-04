shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform sampler2D u_MainTex : filter_linear_mipmap;
uniform vec4 u_MainTex_ST = vec4(0.5, 1.0, 0.0, 0.0); // xy: tiling, zw: offset

varying vec2 v_texcoord0;

void vertex() {
  // Apply texture tiling and offset (matching GLSL vertex shader)
  v_texcoord0 = UV * u_MainTex_ST.xy + u_MainTex_ST.zw;
}

void fragment() {
  // Tuning constants for 3 lines
  vec3 A = vec3(0.55, 0.3, 0.7);
  vec3 aRate = vec3(1.2, 1.0, 1.33);
  vec3 M = vec3(1.0, 2.2, 1.5);  // kind of a multiplier on A's values
  vec3 bRate = vec3(1.5, 3.0, 2.25) + M * aRate;
  vec3 LINE_POS = vec3(0.5, 0.5, 0.5);
  vec3 LINE_WIDTH = vec3(0.012, 0.012, 0.012);

  // Calculate uvs for each line (use scaled UVs from vertex shader)
  vec3 us = A * v_texcoord0.x - aRate * TIME;

  vec3 tmp = M * A * v_texcoord0.x - bRate * TIME;
  tmp = abs(fract(tmp) - 0.5);
  vec3 vs = vec3(v_texcoord0.y) + 0.4 * COLOR.a * vec3(1.0, -1.0, 1.0) * tmp;
  vs = clamp(mix((vs - 0.5) * 4.0, vs, sin((3.14159 / 2.0) * COLOR.a)), 0.0, 1.0);

  vec4 tex = texture(u_MainTex, vec2(abs(us[0]), vs[0]));
  tex += texture(u_MainTex, vec2(us[1], vs[1]));
  tex += texture(u_MainTex, vec2(us[2], vs[2]));

  // render 3 procedural lines
  vec3 procline = vec3(1.0, 1.0, 1.0) - clamp(pow(abs((vs - LINE_POS) / LINE_WIDTH), vec3(2.0, 2.0, 0.2)), 0.0, 1.0);
  tex += dot(procline, vec3(1.0, 1.0, 1.0)) * 0.5;

  // adjust brightness; modulate by color
  tex *= 0.8 * (1.0 + 30.0 * pow((1.0 - COLOR.a), 5.0));
  vec4 i_color = COLOR;
  i_color.a = 1.0; // kill any other alpha values

  vec4 c = i_color * tex;

  ALBEDO = c.rgb * c.a;
  ALPHA = 1.0;
}
