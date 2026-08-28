shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://addons/icosa/open_brush/brush_materials/_includes/fog_functions.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform vec4 u_TintColor : source_color = vec4(1.0);
uniform float u_QuantizeRate = 5.0;

varying vec4 v_color;
varying vec2 v_uv;
varying float v_fog_coord;

void vertex() {
  vec4 world_pos = MODEL_MATRIX * vec4(VERTEX, 1.0);
  float birth_time = CUSTOM1.w;
  float lifetime = TIME - birth_time;
  float phase = mod(lifetime, 1.0);
  float pulse = pow(phase, 3.0);

  world_pos.xyz = ceil(world_pos.xyz * u_QuantizeRate) / u_QuantizeRate;
  world_pos.xyz += normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz) * pulse * 0.1;

  mat4 inv_model = inverse(MODEL_MATRIX);
  VERTEX = (inv_model * world_pos).xyz;

  v_color = vec4(2.0 * COLOR.rgb * pulse, COLOR.a);
  v_uv = UV;
  v_fog_coord = (VIEW_MATRIX * world_pos).z;
}

void fragment() {
  vec4 tex_color = texture(u_MainTex, v_uv);
  vec4 color = v_color * u_TintColor * tex_color;
  vec3 final_color = color.rgb * max(color.a, tex_color.a);
  final_color = apply_fog(final_color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
