shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_EmissionGain : hint_range(0.0, 2.0) = 0.5;

vec4 get_rainbow_color(vec2 texcoord, float time) {
  texcoord = clamp(texcoord, 0.0, 1.0);

  // Create parametric UV's
  vec2 uvs = texcoord;
  float row_id = floor(uvs.y * 5.0);
  uvs.y *= 5.0;

  // Create parametric colors
  vec4 tex = vec4(0.0, 0.0, 0.0, 1.0);

  float row_y = mod(uvs.y, 1.0);

  // Animate row cycling
  row_id = ceil(mod(row_id + time, 5.0)) - 1.0;

  // Assign rainbow colors
  tex.rgb = row_id == 0.0 ? vec3(1.0, 0.0, 0.0) : tex.rgb;  // Red
  tex.rgb = row_id == 1.0 ? vec3(0.7, 0.3, 0.0) : tex.rgb;  // Orange
  tex.rgb = row_id == 2.0 ? vec3(0.0, 1.0, 0.0) : tex.rgb;  // Green
  tex.rgb = row_id == 3.0 ? vec3(0.0, 0.2, 1.0) : tex.rgb;  // Blue
  tex.rgb = row_id == 4.0 ? vec3(0.4, 0.0, 1.2) : tex.rgb;  // Purple

  // Make rainbow lines pulse
  tex.rgb *= pow((sin(row_id * 1.0 + time) + 1.0) / 2.0, 5.0);

  // Make rainbow lines thin
  tex.rgb *= clamp(pow(row_y * (1.0 - row_y) * 5.0, 50.0), 0.0, 1.0);

  return tex;
}

void fragment() {
  vec4 color = COLOR;
  color.a = 1.0;

  vec4 tex = get_rainbow_color(UV, TIME);
  tex = color * tex * exp(u_EmissionGain * 3.0);

  ALBEDO = tex.rgb;
  EMISSION = tex.rgb;
  ALPHA = tex.a;
}
