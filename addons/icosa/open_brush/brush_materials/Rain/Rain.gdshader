shader_type spatial;
render_mode unshaded, blend_add, depth_draw_opaque, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_NumSides : hint_range(1.0, 20.0) = 6.0;
uniform float u_Speed : hint_range(0.1, 5.0) = 1.0;

float rand_1_05(vec2 uv) {
  float noise = fract(sin(dot(uv, vec2(12.9898, 78.233) * 2.0)) * 4550.0);
  return abs(noise) * 0.7;
}

void vertex() {
  // Inflate the tube outward using radius from CUSTOM0.z
  // GLTF importer maps _TEXCOORD_0 -> _CUSTOM0, accessible as CUSTOM0
  float radius = CUSTOM0.z;

  VERTEX += NORMAL * 1.5 * radius;
}

void fragment() {
  float u_scale = u_Speed;
  // Unity's _Time.y = time
  float time_scale = 0.3;
  float t = mod(TIME * time_scale * 4.0 * u_scale, u_scale);

  // Rescale U coord and animate it
  vec2 uvs = UV;
  float u = uvs.x * u_scale - t;

  // Calculate face ID for randomization
  float row_id = float(int(uvs.y * u_NumSides));
  float rand = rand_1_05(vec2(row_id));

  // Randomize animation by row ID
  u += rand * TIME * time_scale * 2.75 * u_scale;

  // Wrap U coordinate
  u = mod(u, u_scale);

  // Rescale V coord for each strip
  float v = uvs.y * u_NumSides;

  vec2 tiledUV = vec2(u, v);
  vec4 tex = texture(u_MainTex, tiledUV);

  // Clip texture outside 0-1 U range
  tex = (u < 0.0) ? vec4(0.0) : tex;
  tex = (u > 1.0) ? vec4(0.0) : tex;

  // Fade at stroke edges
  float fade = pow(abs(UV.x * 0.25), 9.0);
  vec4 color = COLOR * tex;
  vec4 finalColor = mix(color, vec4(0.0), clamp(fade, 0.0, 1.0));

  ALBEDO = finalColor.rgb * finalColor.a;
  ALPHA = finalColor.a;
}
