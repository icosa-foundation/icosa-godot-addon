shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform vec4 u_TintColor : source_color = vec4(1.0);
uniform bool u_IsLegacyOpenBrushGltf = false;

void vertex() {
  vec4 source_data = u_IsLegacyOpenBrushGltf ? vec4(CUSTOM0.yzw, 0.0) : CUSTOM1;
  float size = max(length(source_data.xyz), 0.0001);
  float lifetime = TIME - source_data.w;
  float release = clamp(lifetime, 0.0, 1.0);

  vec4 world_pos = u_IsLegacyOpenBrushGltf ? MODEL_MATRIX * vec4(VERTEX, 1.0) : vec4(VERTEX, 1.0);
  float q = (1.0 / size) * 0.5;
  q += 5.0 * clamp(1.0 - release * 10.0, 0.0, 1.0);
  world_pos.xyz = ceil(world_pos.xyz * q) / q;
  VERTEX = u_IsLegacyOpenBrushGltf ? (inverse(MODEL_MATRIX) * world_pos).xyz : world_pos.xyz;
}

void fragment() {
  // Alpha-only texture (use .w channel)
  vec4 final_color = COLOR * u_TintColor * texture(u_MainTex, UV).a;

  ALBEDO = final_color.rgb;
  ALPHA = final_color.a;
}
