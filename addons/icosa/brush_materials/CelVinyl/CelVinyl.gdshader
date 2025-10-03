shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

#include "res://addons/icosa/brush_materials/_includes/fog_functions.gdshaderinc"

uniform sampler2D u_MainTex : source_color, filter_linear_mipmap;
uniform float u_Cutoff : hint_range(0.0, 1.0) = 0.5;

varying float v_fog_coord;

void vertex() {
  v_fog_coord = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
  vec4 tex = texture(u_MainTex, UV) * COLOR;

  if (tex.a <= u_Cutoff) {
    discard;
  }

  vec3 final_color = apply_fog(tex.rgb, v_fog_coord);

  ALBEDO = final_color;
  ALPHA = 1.0;
}
