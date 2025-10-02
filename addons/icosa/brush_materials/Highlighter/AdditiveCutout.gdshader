shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

#include "res://addons/icosa/brush_materials/_includes/fog_functions.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_Opacity : hint_range(0.0, 1.0) = 1;
uniform float u_Cutoff : hint_range(0.0, 1.0) = 0.5;

varying float v_fog_coord;

void vertex() {
  v_fog_coord = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
  vec4 tex_color = texture(u_MainTex, UV);
  float brush_mask = tex_color.a * COLOR.a;

  if (brush_mask <= u_Cutoff) {
    discard;
  }

  vec3 final_color = tex_color.rgb * COLOR.rgb;
  final_color = apply_fog(final_color, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = tex_color.a * u_Opacity;
}
