shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform vec4 u_TintColor : source_color = vec4(1.0);
uniform float u_EmissionGain : hint_range(0.0, 1.0) = 0.5;

float rand_1_05(vec2 uv) {
  float noise = fract(sin(dot(uv, vec2(12.9898, 78.233) * 2.0)) * 43758.5453);
  return noise;
}

void fragment() {
  // Unity's _Time.z = time*2, _Time.y = time
  float time_z = TIME * 2.0;
  float time_y = TIME;

  // Create parametric flowing UV's
  vec2 uvs = UV;
  float row_id = floor(uvs.y * 5.0);
  float row_rand = rand_1_05(vec2(row_id, row_id));
  uvs.x += row_rand * 200.0;

  vec2 sins = sin(uvs.x * vec2(10.0, 23.0) + time_z * vec2(5.0, 3.0));
  uvs.y = 5.0 * uvs.y + dot(vec2(0.05, -0.05), sins);

  // Scrolling UVs
  uvs.x *= 0.5 + row_rand * 0.3;
  uvs.x -= time_y * (1.0 + mod(row_id * 1.61803398875, 1.0) - 0.5);

  // Sample final texture
  vec4 tex = texture(u_MainTex, uvs);

  // Boost hot spot in texture
  tex += pow(tex, vec4(2.0, 2.0, 2.0, 2.0)) * 55.0;

  // Clean up border pixels filtering artifacts
  tex *= mod(uvs.y, 1.0); // top edge
  tex *= mod(uvs.y, 1.0); // top edge
  tex *= 1.0 - mod(uvs.y, 1.0); // bottom edge
  tex *= 1.0 - mod(uvs.y, 1.0); // bottom edge

  vec4 color = COLOR * tex * exp(u_EmissionGain * 5.0);

  ALBEDO = color.rgb * color.a;
  ALPHA = 1.0;
}
